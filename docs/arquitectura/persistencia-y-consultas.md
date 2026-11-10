# Persistencia y consultas

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define el repositorio genérico, QueryServices, seguimiento y proyecciones.

<a id="s13"></a>

## Persistencia con Entity Framework Core

`[NombreProyecto].Infrastructure` contiene:

- `AppDbContext`;
- configuraciones `IEntityTypeConfiguration<T>`;
- un único repositorio genérico para operaciones básicas;
- implementación del Unit of Work;
- migraciones;
- interceptores de persistencia;
- adaptadores específicos del proveedor.

<a id="tema-repositorio-generico-y-consultas-unificadas"></a>

### Repositorio genérico y consultas unificadas

La persistencia DEBE utilizar un único contrato `IRepository<TEntity>` y una
única implementación `EfRepository<TEntity>`. NO se crean repositorios por
entidad ni subclases como `EfUsuarioRepository`. Todas las consultas específicas
se concentran en `QueryServices`, agrupadas por funcionalidad. No se mantiene
una carpeta paralela de servicios de lectura.

| Componente | Responsabilidad |
| --- | --- |
| `IRepository<TEntity>` | Obtener por ID con seguimiento, agregar, agregar lotes y marcar para borrado. |
| `EfRepository<TEntity>` | Implementar exclusivamente esas operaciones mediante EF Core. |
| `I[Feature]QueryService` | Definir búsquedas, verificaciones, agregados y proyecciones específicas. |
| `Ef[Feature]QueryService` | Ejecutar y materializar esas consultas en Infrastructure. |
| `IUnitOfWork` | Confirmar cambios y coordinar las transacciones de la [guía de Unit of Work](unit-of-work.md#s14). |
| Entidades y Domain Services | Aplicar invariantes y cambios de estado del negocio. |

Estructura obligatoria de persistencia:

```text
Application/Abstractions/
├── Persistence/IUnitOfWork.cs
├── Repositories/IRepository.cs
└── QueryServices/IRecursoQueryService.cs

Infrastructure/Persistence/
├── AppDbContext.cs
├── EfUnitOfWork.cs
├── Configurations/RecursoConfiguration.cs
├── Repositories/EfRepository.cs
├── QueryServices/
│   └── Recursos/
│       ├── EfRecursoQueryService.cs
│       └── Mapping/RecursoProjectionConfig.cs
└── Migrations/
```

`AppDbContext` es el nombre convencional de una clase propia del proyecto;
no es una palabra reservada ni determina el nombre de la base de datos.
El proveedor y la conexión se configuran en el host. Si existen varios contextos,
sus responsabilidades y registros deben quedar diferenciados explícitamente.

<a id="tema-codigo-base-entidad-e-interfaz-generica"></a>

#### Código base: entidad e interfaz genérica

Estos ejemplos adoptan `Guid` como clave y una base `Entidad`. Si el proyecto
ya tiene una base, DEBE reutilizarla sin duplicar `Id`. Otra estrategia de claves
requiere adaptar el contrato y su implementación consistentemente.
Cada tipo se guarda en su propio archivo.

```csharp
// Domain/Entities/Entidad.cs
namespace [NombreProyecto].Domain.Entities;

public abstract class Entidad
{
    public Guid Id { get; protected set; } = Guid.NewGuid();
}
```

```csharp
// Application/Abstractions/Repositories/IRepository.cs
using [NombreProyecto].Domain.Entities;

namespace [NombreProyecto].Application.Abstractions.Repositories;

public interface IRepository<TEntity> where TEntity : Entidad
{
    /// <summary>Obtiene una entidad con seguimiento; null si no existe.</summary>
    Task<TEntity?> GetByIdAsync(Guid id, CancellationToken cancellationToken);

    void Add(TEntity entity);
    void AddRange(IEnumerable<TEntity> entities);

    /// <summary>Marca un borrado físico autorizado previamente por el caso de uso.</summary>
    void Remove(TEntity entity);
}
```

<a id="tema-codigo-base-contexto-e-implementacion"></a>

#### Código base: contexto e implementación

```csharp
// Infrastructure/Persistence/AppDbContext.cs
using Microsoft.EntityFrameworkCore;

namespace [NombreProyecto].Infrastructure.Persistence;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options)
    : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

Cada entidad concreta utilizada por `Set<TEntity>()` DEBE formar parte del modelo,
por ejemplo mediante su `IEntityTypeConfiguration<TEntity>` en `Configurations`.
La restricción genérica no registra entidades automáticamente. Los ejemplos usan
`Set<Recurso>()`; declarar propiedades `DbSet<Recurso>` es opcional.

```csharp
// Infrastructure/Persistence/Repositories/EfRepository.cs
using Microsoft.EntityFrameworkCore;
using [NombreProyecto].Application.Abstractions.Repositories;
using [NombreProyecto].Domain.Entities;
using [NombreProyecto].Infrastructure.Persistence;

namespace [NombreProyecto].Infrastructure.Persistence.Repositories;

public sealed class EfRepository<TEntity>(AppDbContext context)
    : IRepository<TEntity> where TEntity : Entidad
{
    public Task<TEntity?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        context.Set<TEntity>()
            .AsTracking()
            .FirstOrDefaultAsync(entity => entity.Id == id, cancellationToken);

    public void Add(TEntity entity) => context.Set<TEntity>().Add(entity);

    public void AddRange(IEnumerable<TEntity> entities) =>
        context.Set<TEntity>().AddRange(entities);

    public void Remove(TEntity entity) => context.Set<TEntity>().Remove(entity);
}
```

Reglas obligatorias:

- `Add`, `AddRange` y `Remove` solo cambian el estado del contexto. No ejecutan
  `SaveChanges` ni confirman transacciones. Son síncronos en este caso base con
  IDs generados en memoria y sin generación de valores que requiera E/S.
- No se ofrece `Update` general: el handler carga la entidad, invoca sus métodos
  de dominio y confirma mediante `IUnitOfWork`.
- `Remove` es borrado físico. El caso de uso valida permisos, integridad y
  conservación histórica. Una baja lógica se realiza mediante el dominio sobre
  una entidad rastreada, sin llamar a `Remove`.
- No se exponen `IQueryable`, `DbSet`, expresiones de EF ni parámetros de
  seguimiento a los handlers.
- Filtros, uniones, paginación, proyecciones y búsquedas particulares pertenecen
  a `QueryServices`, no al repositorio genérico.
- Repositorio, consultas y Unit of Work comparten el mismo `AppDbContext` scoped.
  No se ejecutan operaciones paralelas sobre esa misma instancia.

<a id="tema-registro-del-generico-abierto-y-de-las-consultas"></a>

#### Registro del genérico abierto y de las consultas

El repositorio genérico se registra explícitamente una sola vez. No implementa
interfaces marcadoras de Scrutor, para evitar su registro duplicado.

```csharp
// Composición del host; importar los namespaces del proyecto correspondientes.
builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
```

`AppDbContext` se registra con `AddDbContext<AppDbContext>` y el proveedor
seleccionado. `EfUnitOfWork` y los QueryServices implementan `IScopedDependency`
y se registran con el escaneo de la [guía de composición](composicion-y-dependencias.md#s12); no se duplican con registros
explícitos. El contexto, Options y la configuración Mapster conservan sus
registros explícitos.

<a id="tema-consultas-para-lectura-y-para-modificacion"></a>

#### Consultas para lectura y para modificación

Las consultas de presentación devuelven `Result`, escalares o modelos paginados
materializados, con `AsNoTracking()` y proyección antes de materializar.
Las consultas que necesitan entidades para ejecutar comportamiento del dominio
PUEDEN devolverlas con `AsTracking()` explícito. El contrato DEBE documentar esta
garantía; no se utiliza un parámetro booleano `tracking`.

Por funcionalidad DEBERÍA existir una interfaz y una implementación que reúnan
las consultas relacionadas. Un contrato adicional solo se justifica por una
responsabilidad distinta, como cargar un lote de entidades para registrar notas;
permanece en `QueryServices`, sin crear otra carpeta principal de lectura.

Ejemplo de un contrato adicional para modificar un lote:

```csharp
// Application/Abstractions/QueryServices/IRecursoEdicionQueryService.cs
using [NombreProyecto].Domain.Entities;

namespace [NombreProyecto].Application.Abstractions.QueryServices;

public interface IRecursoEdicionQueryService
{
    /// <summary>Obtiene los recursos existentes del lote con seguimiento.</summary>
    Task<IReadOnlyList<Recurso>> GetForUpdateAsync(
        IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken);
}
```

```csharp
// Infrastructure/Persistence/QueryServices/Recursos/EfRecursoEdicionQueryService.cs
// Importar también el namespace de IScopedDependency definido por el proyecto.
using Microsoft.EntityFrameworkCore;
using [NombreProyecto].Application.Abstractions.QueryServices;
using [NombreProyecto].Domain.Entities;
using [NombreProyecto].Infrastructure.Persistence;

namespace [NombreProyecto].Infrastructure.Persistence.QueryServices.Recursos;

public sealed class EfRecursoEdicionQueryService(AppDbContext context)
    : IRecursoEdicionQueryService, IScopedDependency
{
    public async Task<IReadOnlyList<Recurso>> GetForUpdateAsync(
        IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken)
    {
        if (ids.Count == 0)
            return [];

        return await context.Set<Recurso>()
            .AsTracking()
            .Where(entity => ids.Contains(entity.Id))
            .ToListAsync(cancellationToken);
    }
}
```

`Recurso` representa la entidad de ejemplo del documento y debe heredar de
`Entidad`. Application valida el tamaño máximo del lote y el caso de uso decide
qué hacer si faltan IDs. Los QueryServices no agregan, eliminan ni guardan datos.
El seguimiento no implica bloqueo ni evita carreras. Cupos, saldos y exclusividad
requieren restricciones, tokens de concurrencia o coordinación transaccional
apropiada al proveedor; el repositorio genérico no resuelve esas garantías.

<a id="tema-implementaciones-de-consulta-y-proyeccion"></a>

### Implementaciones de consulta y proyección

Las implementaciones que consultan con EF Core residen en
`Infrastructure/Persistence/QueryServices/[Feature]` e implementan contratos de
Application. Infrastructure filtra, ordena, pagina y proyecta a los tipos
`Result` definidos en Application antes de materializar con CancellationToken.
Las consultas de presentación devuelven resultados materializados, valores
escalares o un resultado paginado propio de Application. Las consultas para
modificación pueden devolver entidades según el contrato anterior. Ninguna expone `IQueryable`, `DbSet`, `DbContext`
ni resultados HTTP. Para páginas se incluyen orden estable y desempate único,
y se documenta si el total y los elementos requieren una instantánea consistente.

Ejemplo por funcionalidad (el Query y su handler comparten archivo; los demás
tipos se declaran en archivos independientes):

```text
Application/Abstractions/QueryServices/IRecursoQueryService.cs

Application/Features/Recursos/
├── Queries/ListarRecursos/ListarRecursosQuery.cs  # Query y QueryHandler
├── Results/RecursoListadoResult.cs
└── Mapping/RecursoMappingConfig.cs

Infrastructure/Persistence/QueryServices/Recursos/
├── EfRecursoQueryService.cs
└── Mapping/RecursoProjectionConfig.cs

Api/Features/Recursos/
├── RecursosModule.cs
├── Contracts/Requests/ListarRecursosRequest.cs
├── Contracts/Responses/RecursoListadoResponse.cs
└── Mapping/RecursoHttpMappingConfig.cs
```

Resultado en `Application/Features/Recursos/Results/RecursoListadoResult.cs`:

```csharp
public sealed record RecursoListadoResult(Guid Id, string Nombre, decimal Valor);
```

Interfaz en `Application/Abstractions/QueryServices/IRecursoQueryService.cs`:

```csharp
public interface IRecursoQueryService
{
    Task<IReadOnlyList<RecursoListadoResult>> ListActiveAsync(
        CancellationToken cancellationToken);
}
```

Query y handler en
`Application/Features/Recursos/Queries/ListarRecursos/ListarRecursosQuery.cs`:

```csharp
public sealed record ListarRecursosQuery()
    : IQuery<IReadOnlyList<RecursoListadoResult>>;

public sealed class ListarRecursosQueryHandler(IRecursoQueryService queryService)
    : IQueryHandler<ListarRecursosQuery, IReadOnlyList<RecursoListadoResult>>
{
    public async ValueTask<IReadOnlyList<RecursoListadoResult>> Handle(
        ListarRecursosQuery query,
        CancellationToken cancellationToken) =>
        await queryService.ListActiveAsync(cancellationToken);
}
```

Implementación y configuración de proyección en Infrastructure:

```csharp
public sealed class RecursoProjectionConfig : IRegister
{
    public void Register(TypeAdapterConfig config) =>
        config.NewConfig<Recurso, RecursoListadoResult>();
}

public sealed class EfRecursoQueryService(
    AppDbContext dbContext,
    TypeAdapterConfig mapsterConfig)
    : IRecursoQueryService, IScopedDependency
{
    public async Task<IReadOnlyList<RecursoListadoResult>> ListActiveAsync(
        CancellationToken cancellationToken) =>
        await dbContext.Set<Recurso>()
            .AsNoTracking()
            .Where(x => x.Activo)
            .OrderBy(x => x.Nombre)
            .ThenBy(x => x.Id)
            .ProjectToType<RecursoListadoResult>(mapsterConfig)
            .ToListAsync(cancellationToken);
}
```

El ejemplo ilustra el límite entre capas para un catálogo pequeño. Los listados
que puedan crecer DEBEN añadir criterios y paginación limitada validados en
Application; Infrastructure los aplica antes de materializar. El handler no
remapea los Results ya devueltos por el servicio de lectura. API los adapta a
sus Responses y los envuelve según el contrato HTTP.

La configuración del modelo utiliza Fluent API. Debe definir explícitamente:

- claves primarias y alternas;
- longitudes máximas;
- precisión decimal;
- índices y unicidad;
- relaciones y comportamiento de borrado;
- conversiones de enumeraciones y value objects;
- restricciones de integridad;
- concurrencia optimista cuando aplique.

Las entidades NO deben contener atributos específicos del proveedor salvo que
exista una razón documentada.


<a id="tema-seleccion-explicita-de-columnas"></a>

## Selección explícita de columnas

Una consulta que no necesite todas las columnas de una tabla DEBE proyectar
explícitamente únicamente las columnas utilizadas. La proyección se realiza con
`ProjectToType<T>(mapsterConfig)` de Mapster en Infrastructure antes de
materializar la consulta. `Select`
manual se reserva para valores escalares o para una limitación de traducción de
Mapster debidamente documentada y probada.

```csharp
// Correcto: el caso de uso solo consume tres columnas.
var items = await dbContext.Set<Recurso>()
    .AsNoTracking()
    .Where(x => x.Activo)
    .ProjectToType<RecursoListadoResult>(mapsterConfig)
    .ToListAsync(cancellationToken);
```

```csharp
// Incorrecto: carga todas las columnas y después descarta la mayoría.
var entities = await dbContext.Set<Recurso>()
    .AsNoTracking()
    .ToListAsync(cancellationToken);

var items = entities.Select(x => new RecursoListadoResult(
    x.Id,
    x.Nombre,
    x.Valor));
```

Reglas:

- `ProjectToType<T>` se ejecuta antes de `ToListAsync`, `FirstAsync`,
  `SingleAsync` o cualquier otra materialización;
- los listados y consultas de solo lectura proyectan directamente a un resultado
  record de Application y usan `AsNoTracking`;
- la configuración de Mapster debe permanecer traducible a SQL;
- `Include` no se usa cuando una proyección puede obtener los datos requeridos;
- las columnas grandes, blobs y textos extensos se omiten si el caso de uso no
  los necesita;
- la paginación se aplica antes de materializar;
- las consultas SQL manuales enumeran las columnas en el `SELECT` cuando el
  consumidor no utiliza todas las columnas de la tabla;
- cargar la entidad completa es válido cuando el caso de uso realmente necesita
  todas sus columnas o cuando la entidad debe ser modificada y rastreada;
- la necesidad de una sola columna se resuelve proyectando esa columna, no
  cargando la entidad completa;
- nunca se devuelven entidades EF Core desde la API.

La configuración del mapeo HTTP se ubica en API; por ejemplo:

```csharp
public sealed class RecursoHttpMappingConfig : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        config.NewConfig<CrearRecursoRequest, CrearRecursoCommand>();
        config.NewConfig<CrearRecursoResult, RecursoResponse>();
        config.NewConfig<RecursoDetalleResult, RecursoResponse>();
    }
}
```

`RecursoDetalleResult` es la salida definida en Application para
`GetRecursoByIdQuery` e incluye los campos requeridos por `RecursoResponse`.
Su proyección desde `Recurso` se registra en Infrastructure, con una pareja de
tipos distinta de la salida `CrearRecursoResult` del comando. Los registros
HTTP se reúnen con los demás mediante el escaneo explícito de la [guía de contratos y mapeo](contratos-y-mapeo.md#s11).

Ejemplo con Mapster:

```csharp
var items = await dbContext.Set<Recurso>()
    .AsNoTracking()
    .Where(x => x.Activo)
    .ProjectToType<RecursoListadoResult>(mapsterConfig)
    .ToListAsync(cancellationToken);
```


## Guías relacionadas

- [Contratos y mapeo entre capas](contratos-y-mapeo.md)
- [Unit of Work y transacciones](unit-of-work.md)
- [Convenciones de código y tipos de datos](../desarrollo/convenciones-codigo.md)
