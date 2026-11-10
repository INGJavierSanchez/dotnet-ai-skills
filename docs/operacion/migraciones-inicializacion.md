# Migraciones e inicialización de base de datos

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define aprovisionamiento, inicialización, seeders, exclusividad y diagnóstico de despliegue.

<a id="s25"></a>

## Migraciones

- Infrastructure contiene las migraciones.
- API es el proyecto de inicio.
- Cada migración se revisa antes de aplicarse.
- Una migración destructiva requiere respaldo y estrategia de reversión.
- No se usa `EnsureCreated` ni `EnsureCreatedAsync` cuando el proyecto trabaja
  con migraciones, en ningún ambiente; tampoco `EnsureDeleted` ni
  `EnsureDeletedAsync` como parte del arranque o recuperación.
- Las migraciones no se ejecutan concurrentemente desde múltiples réplicas.

Ejemplo:

```powershell
dotnet tool restore

dotnet tool run dotnet-ef migrations add NombreMigracion `
  --project src/[NombreProyecto].Infrastructure `
  --startup-project src/[NombreProyecto].Api

dotnet tool run dotnet-ef database update `
  --project src/[NombreProyecto].Infrastructure `
  --startup-project src/[NombreProyecto].Api
```

<a id="tema-inicializacion-automatica-controlada"></a>

### Inicialización automática controlada

El proyecto DEBE implementar un servicio genérico, reutilizable y asíncrono
`DatabaseInitializer<TDbContext>`, con restricción `where TDbContext : DbContext`,
cuando necesite preparar o verificar la base durante el despliegue o arranque.
Reside en `Infrastructure/Persistence/Initialization`, se registra como scoped
y comparte el contexto scoped con los seeders y `IUnitOfWork`. API lo invoca
antes de `RunAsync()`, sin aceptar solicitudes de negocio mientras se ejecuta.
Los Workers que consuman datos tampoco comienzan a procesar trabajo antes de
completar la inicialización requerida.

El inicializador es infraestructura técnica: PUEDE acceder a EF Core para
inspeccionar la base y ejecutar migraciones. Esto no habilita acceso directo a
DbContext desde handlers de Application. La creación de una base y la migración
de su esquema no son un guardado ordinario de negocio: se ejecutan mediante las
APIs de administración de EF Core, fuera de una transacción de IUnitOfWork que
envuelva todo el proceso. Las escrituras de seeders se confirman mediante
IUnitOfWork según las reglas siguientes.

<a id="tema-options-de-inicializacion"></a>

#### Options de inicialización

Se utiliza el patrón Options de la [guía de configuración](configuracion.md#s21), sin leer configuración dentro
del servicio mediante IConfiguration. Cada tipo se declara en su propio archivo:

```csharp
public sealed class DatabaseInitializationOptions
{
    public const string SectionName = "DatabaseInitialization";

    public bool Enabled { get; init; }
    public bool CreateDatabase { get; init; }
    public bool ApplyMigrations { get; init; } = true;
    public bool RunSeeders { get; init; } = true;
}
```

Configuración de desarrollo, con creación deshabilitada salvo autorización
explícita del proyecto:

```json
{
  "DatabaseInitialization": {
    "Enabled": true,
    "CreateDatabase": false,
    "ApplyMigrations": true,
    "RunSeeders": true
  }
}
```

`Enabled=false` omite toda la inicialización: no resuelve ni abre el contexto,
no inspecciona el servidor, no obtiene bloqueos, no crea la base, no consulta
migraciones y no ejecuta seeders. Solo registra que está deshabilitada. Por ello,
el inicializador DEBE resolver su unidad de trabajo scoped de forma diferida
después de comprobar las Options, mediante una factory explícita; no activa
DbContext o seeders anticipadamente en su constructor. Este comportamiento no
sustituye las comprobaciones de readiness ni garantiza que el esquema esté listo.

En Production, `CreateDatabase=true` es una configuración inválida y debe
rechazarse al validar Options. La base se crea previamente desde el servidor o
panel de hosting. Las cadenas de conexión proceden de variables de entorno o un
gestor de secretos y se enlazan a Options tipadas; no aparecen en JSON versionado.

<a id="tema-secuencia-y-decisiones-obligatorias"></a>

#### Secuencia y decisiones obligatorias

`InitializeAsync(CancellationToken cancellationToken = default)` DEBE ejecutar
estas etapas y registrar su inicio y resultado:

1. Comprobar `Enabled` y validar la configuración del componente habilitado.
2. Obtener la exclusividad del proceso de inicialización según el despliegue.
   No se considera suficiente un `lock` o SemaphoreSlim local entre réplicas.
3. Validar la conexión y determinar si la base configurada existe usando una
   estrategia compatible con el proveedor relacional. No se interpreta un
   `CanConnectAsync()==false` como prueba de que la base no existe: puede indicar
   credenciales, red, TLS o permisos inválidos. Si la base no existe, una conexión
   al servidor/catálogo administrativo puede ser necesaria para distinguirlo;
   esa estrategia se implementa en un adaptador del proveedor y nunca elige
   silenciosamente otra base como destino de migraciones.
4. Si la base no existe, registrar ese hecho. Con `CreateDatabase=false`, lanzar
   un error claro que indique que debe aprovisionarse la base o autorizar la
   creación en un ambiente permitido. Con `CreateDatabase=true`, crear solo la
   base mediante la API relacional correspondiente y después validar la apertura
   de conexión contra el destino. No usar EnsureCreated para crear las tablas.
5. Diferenciar base inexistente, base existente vacía, esquema parcialmente
   creado y esquema actualizado. La ausencia de `__EFMigrationsHistory` no basta
   para afirmar que no hay tablas. Un esquema previo sin historial compatible
   exige diagnóstico/baseline revisado; no se intenta recrearlo ni se insertan
   entradas ficticias en el historial.
6. Consultar las migraciones pendientes con `GetPendingMigrationsAsync()` y
   registrar su número. Si el proceso debe actualizar o sembrar el esquema,
   comprobar que el artefacto incluye las migraciones y su snapshot; un modelo
   sin migraciones no se convierte en tablas automáticamente. Los cambios del
   modelo sin migración correspondiente requieren corregir el artefacto.
7. Con `ApplyMigrations=true` y migraciones pendientes, ejecutar
   `MigrateAsync(cancellationToken)` y verificar que no queden pendientes.
   Registrar migraciones aplicadas correctamente. Sin pendientes, registrar
   «Base actualizada» y continuar sin modificar el esquema. No ejecutar métodos
   Down, regenerar historial ni reaplicar migraciones confirmadas.
8. Con `ApplyMigrations=false`, no modificar el esquema. Si quedan pendientes,
   detener el arranque cuando esta inicialización deba garantizar compatibilidad;
   no ejecutar seeders sobre un esquema pendiente. La actualización debe hacerse
   previamente en el paso de despliegue autorizado.
9. Con `RunSeeders=true`, ejecutar los seeders únicamente después de verificar
   el esquema. Con `RunSeeders=false`, registrar la omisión. Al finalizar,
   liberar recursos/exclusividad y permitir que continúe el arranque.

Cancelar el arranque propaga CancellationToken hasta inspección, creación,
migraciones y seeders. Un error crítico se registra una sola vez con etapa,
tipo de fallo y código seguro del proveedor; conserva la excepción original
como causa interna y detiene el proceso. No se registran cadenas de conexión,
contraseñas ni valores sensibles. No se captura el error para continuar
aceptando tráfico con una inicialización incompleta.

<a id="tema-contrato-y-ejecucion-de-seeders"></a>

#### Contrato y ejecución de seeders

Application define el contrato en
`Application/Abstractions/Persistence/IDatabaseSeeder.cs`:

```csharp
public interface IDatabaseSeeder
{
    int Order { get; }

    Task SeedAsync(
        CancellationToken cancellationToken = default);
}
```

Las implementaciones residen en `Infrastructure/Persistence/Seeders`, son scoped
y se registran explícitamente. Se ordenan por `Order` ascendente; se DEBE
establecer un desempate determinista o exigir órdenes únicos. El inicializador
registra el nombre y el orden de cada seeder, así como éxito o fallo, sin
registrar sus datos sensibles. Los seeders de diferentes DbContexts se registran
en conjuntos separados para que cada inicializador ejecute solo los suyos.

- Son idempotentes: consultan qué claves de referencia ya existen e insertan
  únicamente los datos faltantes. Una clave natural estable y una restricción
  única de base respaldan la comprobación; una consulta previa por sí sola no
  elimina carreras.
- No eliminan ni sobrescriben información operativa, no recrean catálogos y no
  generan una nueva identidad para el mismo dato en cada reinicio. No se usan
  para cambios destructivos ni para crear credenciales predeterminadas.
- El inicializador controla la transacción de siembra mediante IUnitOfWork.
  Los seeders agregan los datos faltantes sin confirmar por su cuenta; si se
  necesitan guardados intermedios para dependencias entre seeders, se hacen
  mediante IUnitOfWork dentro de la misma transacción, sin commits parciales.
- Un fallo revierte la siembra correspondiente; las migraciones ya confirmadas
  no se deshacen automáticamente. El siguiente intento vuelve a inspeccionar
  esquema y datos, sin repetir cambios confirmados ni duplicar registros.
- No realizan llamadas externas irreversibles dentro de la transacción. Los
  efectos externos necesarios siguen la estrategia de Outbox.

Ejemplo de algoritmo idempotente para un catálogo genérico: definir las claves
requeridas, consultar las ya existentes, calcular la diferencia, agregar solo
las ausentes y confirmar mediante el coordinador de siembra. Una segunda
ejecución calcula una diferencia vacía y no modifica los registros existentes.

<a id="tema-registro-e-integracion-de-arranque"></a>

#### Registro e integración de arranque

Las Options, factories del inicializador, adaptadores del proveedor y conjuntos
de seeders se registran mediante extensiones explícitas de DI, antes de construir
el host. Las factories conservan los límites scoped y la omisión completa cuando
`Enabled=false`. La configuración de DbContext mantiene las convenciones del
proyecto; `AppDbContext` en el siguiente fragmento representa el contexto propio.

```csharp
builder.Services
    .AddOptions<DatabaseInitializationOptions>()
    .BindConfiguration(DatabaseInitializationOptions.SectionName)
    .Validate(
        options => !builder.Environment.IsProduction() || !options.CreateDatabase,
        "CreateDatabase debe permanecer en false en Production.")
    .ValidateOnStart();

// Extensión propia: registrar initializer, factories, adaptadores y seeders scoped.
builder.Services.AddDatabaseInitialization<AppDbContext>();

var app = builder.Build();

await using (var scope = app.Services.CreateAsyncScope())
{
    var initializer = scope.ServiceProvider
        .GetRequiredService<DatabaseInitializer<AppDbContext>>();

    await initializer.InitializeAsync(app.Lifetime.ApplicationStopping);
}

// Mapear endpoints y configurar middleware según el resto de la especificación.
await app.RunAsync();
```

`AddDatabaseInitialization<TDbContext>()` es una extensión que debe implementar
el proyecto; no es una API incorporada de EF Core. El bloque se integra dentro
del try de arranque de la [guía de observabilidad](observabilidad.md#s23). Si el catch registra `Log.Fatal`, también
DEBE relanzar el error o establecer `Environment.ExitCode = 1`: el supervisor
del proceso debe recibir una salida de fallo, no una terminación exitosa.

<a id="tema-produccion-y-multiples-instancias"></a>

#### Producción y múltiples instancias

En producción se prefiere un único paso de despliegue para migraciones y seeders,
con exclusividad verificada y permisos administrativos acotados a ese paso.
Las réplicas usan una cuenta con los permisos operativos necesarios y no crean
bases ni compiten para modificar el esquema. La exclusividad cubre tanto
migraciones como seeders, no solo una llamada a MigrateAsync.

Configuración de las réplicas, después de completar y verificar el paso de
despliegue:

```json
{
  "DatabaseInitialization": {
    "Enabled": false,
    "CreateDatabase": false,
    "ApplyMigrations": false,
    "RunSeeders": false
  }
}
```

El proceso único de despliegue usa `Enabled=true`, `CreateDatabase=false`,
`ApplyMigrations=true` y `RunSeeders=true`. Como alternativa, una única instancia
autorizada puede inicializar antes de habilitar las demás; el orquestador debe
garantizarlo. Un bloqueo distribuido, si se adopta, requiere soporte y pruebas
del motor/hosting, timeout, cancelación y liberación segura. No se desactiva el
bloqueo interno del proveedor como atajo para resolver un error de migración.

<a id="tema-diagnostico-de-fallos-del-proveedor-mysql"></a>

#### Diagnóstico de fallos del proveedor MySQL

Un error `InvalidCastException` de `DBNull` a `Int64` dentro de
`MySQLHistoryRepository.AcquireDatabaseLockAsync` identifica un fallo durante
la adquisición del bloqueo de migraciones en el proveedor, no una prueba de
base vacía, credenciales inválidas ni falta de permisos. La causa exacta se
determina con las versiones instaladas y el comportamiento del servidor.

Antes de volver a desplegar se DEBE:

1. Identificar el servidor real (MySQL o MariaDB), su versión, la versión de EF
   Core y el paquete/proveedor instalado. Validar su matriz de compatibilidad;
   no mezclar proveedores ni cambiar a otro sin revisar migraciones y modelo.
2. Comprobar el acceso al servidor y al esquema con la cuenta del despliegue,
   separando permisos de conexión, creación de base y modificación de esquema.
3. Revisar el mecanismo de bloqueo del proveedor y las restricciones del hosting.
   Si utiliza `GET_LOCK`, comprobar en una sesión controlada su resultado y
   liberar el bloqueo en esa misma sesión: `1` significa adquirido, `0` timeout
   y `NULL` error. No convertir `NULL` en éxito ni hacer un cast numérico sin
   comprobarlo. Esta verificación se basa en el comando real del proveedor, no
   en asumir que cualquier error de bloqueo tiene la misma causa.
4. Actualizar a una versión compatible con corrección verificada, o aplicar una
   estrategia de despliegue soportada y revisada (por ejemplo, script de
   migración generado y probado para el motor). Mover la misma llamada a otra
   fase no garantiza resolver un fallo que sigue estando en el proveedor.
5. Ejecutar migración y siembra desde un solo actor, verificar historial y esquema,
   y recién después habilitar tráfico. No recurrir a EnsureCreated, borrar la
   base, falsear el historial ni ignorar la excepción para arrancar.

Referencias oficiales:

- [Aplicación de migraciones EF Core](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying).
- [Código y compatibilidad de MySQL Connector/NET](https://github.com/mysql/mysql-connector-net).
- [Funciones de bloqueo de MySQL](https://dev.mysql.com/doc/refman/8.4/en/locking-functions.html).


## Guías relacionadas

- [Configuración mediante Options](configuracion.md)
- [Estrategia de pruebas](../calidad/pruebas.md)
- [Logging y observabilidad](observabilidad.md)
