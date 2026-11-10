# Convenciones de código y tipos de datos

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define idioma, archivos, herencia de entidades, orden de miembros, namespaces, fechas y sintaxis LINQ.

<a id="tema-reutilizacion-de-campos-de-la-entidad-base"></a>

## Reutilización de campos de la entidad base

Cuando el proyecto adopte una entidad base, las entidades que hereden de ella
DEBEN reutilizar sus campos y propiedades. NO DEBEN declarar miembros que
dupliquen la misma responsabilidad, aunque tengan otro nombre o tipo, ni ocultar
miembros heredados mediante `new`.

Esta regla incluye identificadores, auditoría de creación y modificación,
metadatos de baja lógica, pertenencia a empresa y tokens de concurrencia cuando
estén definidos en la base. Por ejemplo, una entidad que hereda `Id` no agrega
`RecursoId` como segundo identificador de sí misma; si hereda `FechaCreacion`,
no agrega `FechaRegistro` para representar el mismo momento. Una base que
representa la baja con `FechaEliminacion` no se complementa con otro indicador
persistido equivalente que pueda contradecirla.

Los campos de negocio con significado diferente y las claves foráneas a otras
entidades sí pueden declararse en la entidad hija. Por ejemplo, `EmpresaId`
puede identificar una relación de negocio distinta de la pertenencia al tenant,
si esa diferencia está definida explícitamente en el modelo. Una fecha de
afiliación puede coexistir con `FechaCreacion` cuando representa otro evento.
Cada dato tiene una única fuente de verdad; si se necesita otro nombre en el
contrato HTTP, se resuelve mediante el mapeo de API.

Esta regla no obliga a adoptar una entidad base universal: el proyecto define
qué responsabilidades comparte cada base y evita heredar campos que no aplican
a una entidad.

<a id="tema-orden-de-miembros-de-las-entidades"></a>

## Orden de miembros de las entidades

Los miembros de cada entidad DEBEN declararse en este orden:

1. campos de respaldo, constantes y campos estáticos, cuando existan;
2. propiedades de la entidad, incluidas las propiedades de navegación;
3. constructores, incluido el constructor reservado para persistencia cuando
   sea necesario;
4. factories y métodos que expresan comportamiento de negocio;
5. métodos auxiliares privados.

En esta convención, los atributos de la entidad se entienden como sus datos
(campos y propiedades), que aparecen antes de los constructores. Los atributos
C# de anotación, si están permitidos por las reglas del documento, permanecen
inmediatamente encima del tipo o miembro al que se aplican.

Este orden no modifica la encapsulación: las propiedades conservan sus setters
restringidos y los constructores y métodos siguen protegiendo las invariantes.
La creación de negocio utiliza factories estáticas y constructores no públicos,
según [la guía de dominio](../arquitectura/dominio.md#tema-creacion-mediante-factories).
En herencia, la base conserva constructores protegidos accesibles y la hija
`sealed` constructores privados. Las factories de cada tipo concreto y la
cadena `base(...)` siguen [las reglas de factories y herencia](../arquitectura/dominio.md#tema-factories-y-herencia).


El lenguaje ubicuo y las reglas del dominio DEBEN nombrarse en español. Esto
incluye entidades, propiedades, value objects, enumeraciones, eventos,
excepciones y métodos que expresan comportamiento de negocio. Por ejemplo:
`Usuario`, `Empresa`, `Vehiculo`, `FechaAfiliacion`, `EstadoCredencial`,
`AfiliarVehiculo()` y `PuedeDespachar()`.

Los conceptos técnicos, patrones arquitectónicos, responsabilidades y sufijos
se mantienen en inglés. Por ejemplo: `Handler`, `Command`, `Query`,
`Repository`, `Service`, `Validator`, `Mapper`, `Factory`, `Provider`,
`Middleware`, `Behavior`, `Worker` y `Options`. El nombre completo PUEDE
combinar el término de negocio en español con el rol técnico en inglés:
`CrearUsuarioCommand`, `CrearUsuarioCommandHandler`, `IUsuarioQueryService`,
`UsuarioService` y `CrearUsuarioValidator`.

Los métodos técnicos definidos por .NET, una interfaz, un patrón o un SDK
conservan su nombre estándar en inglés, por ejemplo `Handle`, `SendAsync`,
`SaveChangesAsync` y `TryHandleAsync`. Solo los métodos que representan reglas o
acciones propias del dominio se nombran en español. También permanecen en su
idioma original `DbContext`, `CancellationToken`, `IExceptionHandler` y los
campos de protocolos o proveedores. La traducción no debe alterar contratos
externos estandarizados.


<a id="tema-sintaxis-de-consultas-linq"></a>

## Sintaxis de consultas LINQ

Las consultas EF Core DEBERÍAN utilizar sintaxis de métodos como convención
predeterminada: `Where`, `OrderBy`, `ThenBy`, `Skip`, `Take` y
`ProjectToType<T>(mapsterConfig)`, seguidos de materialización asíncrona con
`CancellationToken`. Esta forma permite seguir el filtrado, orden, paginación y
proyección de la consulta.

La sintaxis de consulta (`from`, `join`, `where`, `select`) PUEDE utilizarse
cuando mejore claramente la legibilidad, especialmente en consultas con varias
uniones. Ambas formas mantienen las mismas reglas de traducción al proveedor,
selección de columnas, orden estable, paginación y ejecución asíncrona. Elegir
sintaxis de consulta no autoriza eludir Mapster: el `select` necesario para
componer fuentes de una unión no sustituye la proyección final a `Result`;
una proyección manual de salida requiere la excepción de mapeo manual definida en [la guía de contratos y mapeo](../arquitectura/contratos-y-mapeo.md#s11).

La elección de sintaxis se basa en legibilidad; no se presume una mejora de
rendimiento por utilizar una u otra. Las consultas críticas se evalúan mediante
el SQL generado y su ejecución con el proveedor real.


<a id="s27"></a>

## Convenciones de código

<a id="tema-namespaces-con-ambito-de-archivo"></a>

### Namespaces con ámbito de archivo

Todos los archivos C# que declaren un namespace DEBEN utilizar namespace con
ámbito de archivo, terminado en punto y coma (`;`), sin un bloque de llaves.
Cada archivo declara un único namespace, coherente con su capa y carpeta.
El nombre utiliza `[NombreProyecto]`; por ejemplo, para un proyecto EduNet:

```csharp
namespace EduNet.Domain.Enums;
```

Las entidades utilizan `EduNet.Domain.Entities`, y las funcionalidades de
Application, Infrastructure y API conservan sus namespaces correspondientes.
El ejemplo `EduNet.Domain.Enums` no es un namespace común para todas las capas.
Los archivos con instrucciones de nivel superior, como `Program.cs`, pueden
omitir la declaración de namespace.


<a id="tema-fechas-sin-componente-de-hora"></a>

## Fechas sin componente de hora

Todo dato que represente únicamente una fecha de calendario DEBE declararse como
`DateOnly` o `DateOnly?` si es opcional. NO se utiliza `DateTime` ni
`DateTimeOffset` para esos datos, ni se simula una fecha sin hora mediante
medianoche, `.Date` o una hora fija.

Esta regla aplica a propiedades de entidades y value objects, contratos HTTP
Request/Response, Commands, Queries, Results, filtros y modelos de integración
propios. Ejemplos: fecha de nacimiento, fecha de matrícula y fecha de vigencia
cuando el negocio las define sin hora. El nombre de la propiedad no determina
su tipo: se utiliza la semántica del dato.

En contratos JSON, estas fechas se representan como `yyyy-MM-dd`, sin hora ni
offset. No se convierten a UTC ni se desplazan por zona horaria. Las columnas de
persistencia usan un tipo de fecha sin hora (`date` o equivalente del motor),
con mapeo EF Core compatible con el proveedor elegido.

`DateTime` y `DateTimeOffset` se reservan para datos que realmente requieran
hora según su semántica; por ejemplo, el instante de creación o de una auditoría
no se reduce a `DateOnly`. Cuando un contrato externo exija otro tipo, el
adaptador de Infrastructure realiza una conversión explícita y documentada,
sin propagar esa limitación a los modelos propios de la aplicación.

<a id="tema-reglas-generales"></a>

## Reglas generales

- nullable reference types habilitados;
- warnings tratados como errores en CI;
- métodos asíncronos terminan en `Async`;
- `CancellationToken` fluye desde HTTP hasta persistencia;
- un tipo público por archivo, salvo el par Command/CommandHandler o
  Query/QueryHandler, que DEBE compartir archivo según la [guía de CQRS](../arquitectura/application-cqrs.md#s9); cada
  record de resultado y cada contrato HTTP conserva su archivo independiente,
  incluso si está estrechamente relacionado con otros records;
- entidades, enumeraciones, propiedades y métodos de negocio nombrados en
  español;
- roles y sufijos técnicos como `Handler`, `Command`, `Repository` y `Service`
  conservados en inglés;
- métodos impuestos por .NET, patrones, protocolos o SDK externos conservados
  en su forma original;
- comentarios explican decisiones, no repiten el código;
- no se usa service locator;
- no se crean abstracciones sin un límite real que proteger.


## Guías relacionadas

- [Localización de calendarios](../interfaz/localizacion-calendarios.md)
