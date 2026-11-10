# Contratos y mapeo entre capas

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define la frontera de los contratos HTTP, los Results y la propiedad de los mapeos Mapster.

<a id="s8"></a>

## Contratos HTTP y resultados de Application

Los contratos de transporte HTTP pertenecen a `[NombreProyecto].Api`; los
mensajes y resultados de los casos de uso pertenecen a
`[NombreProyecto].Application`. Aunque tengan campos equivalentes, son modelos
distintos con responsabilidades y ciclos de cambio diferentes.

Los contratos `Request` y `Response` de HTTP DEBEN implementarse como
`sealed record`, en archivos independientes bajo
`Api/Features/[Feature]/Contracts/Requests` o
`Api/Features/[Feature]/Contracts/Responses`, con namespaces coherentes con esas
rutas. No se declaran dentro de un módulo Carter ni en el archivo del endpoint.

Application NO DEBE referenciar tipos de API, HTTP, Carter o ASP.NET Core. Sus
Commands, Queries y resultados (`Result`) representan casos de uso y no deben
nombrarse ni diseñarse como contratos JSON. Un handler devuelve un `Result` de
Application; el endpoint lo adapta a un `Response` público de API.

El endpoint transforma el `Request` HTTP a `Command` o `Query` antes de llamar a
Mediator y transforma el resultado de Application a `Response` después de
recibirlo. Ambas transformaciones usan Mapster. La API es la única capa que
conoce simultáneamente los contratos HTTP y los mensajes de Application.

Archivo `Api/Features/Recursos/Contracts/Requests/CrearRecursoRequest.cs`:

```csharp
public sealed record CrearRecursoRequest(
    string Nombre,
    decimal Valor,
    DateOnly Fecha);
```

Archivo `Api/Features/Recursos/Contracts/Responses/RecursoResponse.cs`:

```csharp
public sealed record RecursoResponse(
    Guid Id,
    string Nombre,
    decimal Valor,
    DateOnly Fecha,
    bool Activo);
```

Reglas:

- reservar `Request` y `Response` para contratos HTTP de API; usar `Result` para
  resultados de casos de uso en Application;
- usar un archivo por contrato o resultado y mantener el nombre del archivo
  igual al tipo;
- cada record de resultado DEBE declararse en su propio archivo bajo
  `Application/Features/[Feature]/Results`, con nombre igual al tipo. NO se
  agrupan varios records en un archivo de Results, aunque estén relacionados
  o uno sea utilizado como elemento o detalle de otro. Los records auxiliares
  de un resultado también tienen archivos independientes en esa carpeta;
- los Results NO se declaran dentro ni en el mismo archivo de un Command,
  Query, handler u otro Result;
- no declarar contratos HTTP dentro ni en el mismo archivo de un endpoint
  Carter;
- crear contratos separados para alta, actualización y respuesta;
- usar `IReadOnlyList<T>` para colecciones de salida;
- marcar nullable solo lo realmente opcional;
- no reutilizar contratos HTTP como Commands, Queries, Results o entidades de
  persistencia;
- no exponer secretos ni propiedades internas en contratos públicos;
- evitar lógica de negocio dentro de contratos y resultados.

Los comandos, consultas y notificaciones también DEBERÍAN ser `sealed record`.


<a id="s11"></a>

## Mapeo con Mapster

Mapster es el mapeador oficial. AutoMapper NO forma parte de esta especificación.

Toda transformación entre modelos de capas o contratos DEBE realizarse con
Mapster. Esta regla incluye:

- `Request` hacia `Command` o `Query` en los endpoints;
- resultados de Application hacia `Response` HTTP en API;
- entidades y value objects hacia resultados de Application;
- modelos de servicios externos hacia modelos de Application;
- proyecciones de lectura desde `IQueryable` hacia resultados de Application;
- transformaciones entre contratos cuando representen modelos diferentes.

Los endpoints y handlers no deben construir manualmente contratos ni resultados
de salida mediante asignaciones propiedad por propiedad ni repetir bloques de conversión. El mapeo
manual solo se admite cuando Mapster no pueda expresar la transformación de
forma segura o traducible; la excepción debe quedar documentada junto al código
y cubierta por pruebas.

<a id="tema-ubicacion-de-configuraciones"></a>

### Ubicación de configuraciones

Cada configuración `IRegister` pertenece a la capa que ejecuta la transformación:

| Transformación | Ubicación |
| --- | --- |
| Entidad o value object materializado hacia `Result` | `Application/Features/[Feature]/Mapping` |
| Proyección EF Core hacia `Result` | `Infrastructure/Persistence/QueryServices/[Feature]/Mapping` |
| Modelo de proveedor externo hacia modelo de Application | Infrastructure, junto al adaptador |
| `Request` HTTP hacia Command/Query y `Result` hacia `Response` | `Api/Features/[Feature]/Mapping` |

Las configuraciones de Application solo usan tipos de Application y Domain;
las de Infrastructure pueden usar esos tipos y sus propios modelos técnicos;
las de API pueden referenciar contratos HTTP y mensajes/resultados de Application.
Domain no contiene configuraciones ni dependencias de Mapster.

Ejemplo de mapeo en memoria ubicado en
`Application/Features/Recursos/Mapping/RecursoMappingConfig.cs`:

```csharp
using Mapster;
using [NombreProyecto].Application.Features.Recursos.Results;
using [NombreProyecto].Domain.Entities;

namespace [NombreProyecto].Application.Features.Recursos.Mapping;

public sealed class RecursoMappingConfig : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        config.NewConfig<Recurso, CrearRecursoResult>();
    }
}
```

<a id="tema-composicion-y-uso-de-configuracion"></a>

### Composición y uso de configuración

API reúne las configuraciones de las capas en una única instancia explícita de
`TypeAdapterConfig` por host. Un Worker independiente compone su propia instancia
con los ensamblados que utiliza. Los marcadores de ensamblado son tipos propios
de cada proyecto y el escaneo se limita a esos ensamblados conocidos:

```csharp
using Mapster;
using MapsterMapper;

var mapsterConfig = new TypeAdapterConfig();
mapsterConfig.Scan(
    typeof(ApplicationAssemblyMarker).Assembly,
    typeof(InfrastructureAssemblyMarker).Assembly,
    typeof(ApiAssemblyMarker).Assembly);

mapsterConfig.Compile();
builder.Services.AddSingleton(mapsterConfig);
builder.Services.AddScoped<IMapper, ServiceMapper>();
```

El registro es explícito; Scrutor no vuelve a registrar `TypeAdapterConfig` ni
`IMapper`. Toda configuración se completa antes de servir solicitudes y no se
modifica en ejecución. `Compile()` verifica mapeos de objetos en memoria;
no demuestra que las proyecciones puedan traducirse a SQL. Esa garantía se
comprueba ejecutando las consultas con el motor de base de datos del proyecto.

Se usa `MapsterMapper.IMapper` inyectado para objetos materializados y el mismo
`TypeAdapterConfig` inyectado para `ProjectToType<T>(config)`. También se admite
`Adapt<T>(config)` cuando se pasa esa instancia explícitamente. NO se utiliza
`Adapt<T>()` sin configuración ni `TypeAdapterConfig.GlobalSettings`; así se
evitan dos fuentes de configuración con comportamiento distinto.

Una pareja origen/destino tiene un único registro propietario. No se depende del
orden de escaneo ni se registra la misma pareja en varias capas para sobrescribir
reglas. Cuando una salida de lectura y una de comando necesiten configuraciones
distintas, se definen Results distintos para sus casos de uso. Las proyecciones
no invocan servicios DI, métodos de dominio, acceso de red ni conversiones que
el proveedor no pueda traducir; las reglas de negocio siguen perteneciendo a
Domain.

Reglas:

- usar `Adapt<T>(config)` o `IMapper.Map<T>()` para objetos materializados;
- usar `ProjectToType<T>()` sobre `IQueryable` para lecturas y hacerlo antes
  de `ToListAsync`, `SingleAsync` u otra materialización;
- evitar materializar entidades completas antes de proyectar;
- declarar explícitamente conversiones no triviales;
- probar las configuraciones críticas;
- no ocultar reglas de negocio dentro del mapeo;
- ubicar las configuraciones `IRegister` según la tabla anterior, componerlas
  explícitamente en el host y validar mapeos en memoria y proyecciones SQL;
- no utilizar reflexión o mapeadores alternativos para eludir esta convención.

Mapster no sustituye al modelo de dominio. Crear una entidad o modificar su
estado NO se considera un simple mapeo: la creación se realiza mediante una
[factory de la entidad](dominio.md#tema-creacion-mediante-factories) y los cambios
mediante métodos de dominio para preservar invariantes. Mapster puede preparar
un modelo de entrada, pero no debe escribir propiedades privadas, saltarse
validaciones ni convertir un DTO directamente en una entidad parcialmente
válida.

<a id="tema-ejemplo-mapeo-con-factory"></a>

## Ejemplo: mapeo de contratos y creación mediante factory

El flujo de alta separa tres transformaciones de la creación de negocio:

```text
API:         CrearRecursoRequest -> CrearRecursoCommand
Application: CrearRecursoCommand -> Recurso.Crear(...) -> guardar
Application: Recurso -> CrearRecursoResult
API:         CrearRecursoResult -> RecursoResponse
```

La entidad y su factory se muestran en
[el ejemplo de Domain](dominio.md#tema-creacion-mediante-factories).
`CrearRecursoResult` conserva un archivo independiente en
`Application/Features/Recursos/Results/CrearRecursoResult.cs`:

```csharp
namespace [NombreProyecto].Application.Features.Recursos.Results;

public sealed record CrearRecursoResult(
    Guid Id,
    string Nombre,
    decimal Valor,
    DateOnly Fecha,
    bool Activo);
```

### Configuración HTTP en API

Archivo `Api/Features/Recursos/Mapping/RecursoHttpMappingConfig.cs`. Los tipos
referenciados se declaran en sus archivos respectivos; `RecursoDetalleResult`
es la salida de la consulta individual utilizada por el módulo HTTP.

```csharp
using Mapster;
using [NombreProyecto].Api.Features.Recursos.Contracts.Requests;
using [NombreProyecto].Api.Features.Recursos.Contracts.Responses;
using [NombreProyecto].Application.Features.Recursos.Commands.CrearRecurso;
using [NombreProyecto].Application.Features.Recursos.Results;

namespace [NombreProyecto].Api.Features.Recursos.Mapping;

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

El host descubre esta configuración y `RecursoMappingConfig` mediante el escaneo
explícito descrito arriba. Son ejemplos de los mismos archivos, no registros
adicionales que deban copiarse varias veces.

### Creación y mapeo dentro del handler

Este es el cuerpo de `Handle` en
`Application/Features/Recursos/Commands/CrearRecurso/CrearRecursoCommand.cs`,
que comparte archivo con el Command. El ejemplo completo del mensaje y handler
se mantiene en [la guía CQRS](application-cqrs.md#s9).

```csharp
var entity = Recurso.Crear(command.Nombre, command.Valor, command.Fecha);

repository.Add(entity);
await unitOfWork.SaveChangesAsync(cancellationToken);

return mapper.Map<CrearRecursoResult>(entity);
```

El ejemplo usa el guardado explícito de [Unit of Work](unit-of-work.md#s14).
La factory valida y crea; Mapster solo transforma la entidad materializada
en el resultado después del guardado. No se registra un mapeo
`CrearRecursoCommand -> Recurso`, ni un `ConstructUsing` que esconda la factory
dentro de Mapster.

### Mapeo dentro del endpoint

Este fragmento pertenece al método HTTP `CreateAsync` de `RecursosModule`;
recibe Request, `MapsterMapper.IMapper`, `IMediator`, `HttpContext` y
CancellationToken por los parámetros del endpoint:

```csharp
var command = mapper.Map<CrearRecursoCommand>(request);
var result = await mediator.Send(command, cancellationToken);
var response = mapper.Map<RecursoResponse>(result);

return Results.CreatedAtRoute(
    "GetRecursoById",
    new { id = response.Id },
    ApiResponses.Success(response, "Recurso creado correctamente."));
```

El [módulo HTTP completo](api-http.md#s15) declara la ruta de consulta
`GetRecursoById`, autorización y metadatos OpenAPI. El endpoint no crea ni
devuelve la entidad. En actualizaciones, el handler carga la entidad existente
y llama a sus métodos de dominio; no utiliza `mapper.Map(request, entity)`
para sobrescribir su estado.
