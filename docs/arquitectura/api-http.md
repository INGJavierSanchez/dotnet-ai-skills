# API HTTP y OpenAPI

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define endpoints, baja de recursos inmutables, envelopes y documentación HTTP.

<a id="s15"></a>

## Capa API y endpoints con Carter

`[NombreProyecto].Api` es la raíz de composición y contiene:

- `Program.cs`;
- módulos Carter organizados por funcionalidad;
- configuración de DI;
- middleware;
- autenticación y autorización;
- manejo global de excepciones;
- OpenAPI;
- health checks.

La API usa
[`Carter 10.0.0`](https://www.nuget.org/packages/Carter/10.0.0) sobre ASP.NET
Core Minimal APIs. No se utilizan controladores MVC para los endpoints del
proyecto.

```xml
<PackageReference Include="Carter" Version="10.0.0" />
```

Registro y mapeo global:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCarter();

var app = builder.Build();

app.MapCarter();
app.Run();
```

Cada funcionalidad expone un módulo que implementa `ICarterModule`. El módulo
crea un `RouteGroupBuilder` con el prefijo común y configura tags, políticas y
metadatos compartidos.

```csharp
public sealed class RecursosModule : ICarterModule
{
    public void AddRoutes(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/recursos")
            .WithTags("Recursos")
            .RequireAuthorization();

        group.MapGet("/{id:guid}", GetByIdAsync)
            .WithName("GetRecursoById")
            .Produces<ApiSuccessResponse<RecursoResponse>>(StatusCodes.Status200OK)
            .Produces<ApiErrorResponse>(StatusCodes.Status404NotFound)
            .IncludeInOpenApi();

        group.MapPost("/", CreateAsync)
            .WithName("CreateRecurso")
            .Produces<ApiSuccessResponse<RecursoResponse>>(StatusCodes.Status201Created)
            .Produces<ApiErrorResponse>(StatusCodes.Status400BadRequest)
            .IncludeInOpenApi();
    }

    private static async Task<IResult> GetByIdAsync(
        Guid id,
        IMediator mediator,
        IMapper mapper,
        HttpContext httpContext,
        CancellationToken cancellationToken)
    {
        var response = await mediator.Send(
            new GetRecursoByIdQuery(id),
            cancellationToken);

        var httpResponse = mapper.Map<RecursoResponse>(response);
        return Results.Ok(ApiResponses.Success(
            httpResponse, "Recurso consultado correctamente."));
    }

    private static async Task<IResult> CreateAsync(
        CrearRecursoRequest request,
        IMediator mediator,
        IMapper mapper,
        HttpContext httpContext,
        CancellationToken cancellationToken)
    {
        var command = mapper.Map<CrearRecursoCommand>(request);
        var result = await mediator.Send(command, cancellationToken);
        var response = mapper.Map<RecursoResponse>(result);

        return Results.CreatedAtRoute(
            "GetRecursoById",
            new { id = response.Id },
            ApiResponses.Success(
                response,
                "Recurso creado correctamente."));
    }
}
```

Reglas de organización:

- un módulo Carter por funcionalidad o agregado, no un módulo monolítico;
- todos los endpoints de un módulo comparten un prefijo `/api/[recurso]`;
- los handlers HTTP son métodos privados estáticos o lambdas breves;
- los contratos `Request` y `Response` HTTP residen en API, en archivos
  independientes bajo `Features/[Feature]/Contracts`;
- Application no referencia contratos HTTP y devuelve tipos `Result` propios;
- API adapta `Request` a `Command`/`Query` y `Result` a `Response` con Mapster;
- el endpoint adapta el request a comando o consulta y usa `IMediator`;
- autorización, CORS, rate limiting y tags se aplican al grupo cuando sean
  comunes;
- cada ruta declara nombre estable, códigos de respuesta y metadatos OpenAPI;
- Carter descubre y registra `ICarterModule`; Scrutor no debe volver a
  registrarlos;
- la validación de Application mediante el pipeline de Mediator es la fuente
  principal; las extensiones de validación de Carter solo se usan para reglas
  exclusivamente HTTP y no deben duplicar las reglas del caso de uso.

Un endpoint Carter debe ser delgado:

1. recibe y enlaza parámetros o un request record;
2. adapta el request a un comando o consulta;
3. lo envía mediante `IMediator`;
4. traduce el resultado a `IResult` o `TypedResults`;
5. declara metadatos OpenAPI.

Un módulo Carter NO debe:

- acceder directamente al DbContext;
- controlar transacciones;
- implementar reglas de negocio;
- devolver entidades EF Core;
- declarar records o clases de petición y respuesta dentro del módulo o al final
  del mismo archivo;
- resolver servicios mediante service locator.

<a id="tema-baja-de-entidades-inmutables"></a>

### Baja de entidades inmutables

Para recursos cuyo contenido de negocio sea inmutable después de su creación,
la API DEBE representar su retirada mediante `DELETE /api/[recurso]/{id}`.
NO se exponen rutas `PUT /{id}/activar` ni `PUT /{id}/desactivar`, ni acciones
equivalentes mediante otros verbos para alternar su disponibilidad. Esta regla
aplica a entidades declaradas inmutables por el modelo del proyecto; usar un
`sealed record` como DTO no convierte por sí solo a la entidad en inmutable.

Ejemplo para el grupo `/api/recursos`, cuando `Recurso` se haya definido como
inmutable en el proyecto:

```csharp
group.MapDelete("/{id:guid}", EliminarAsync)
    .WithName("EliminarRecurso")
    .Produces(StatusCodes.Status204NoContent)
    .Produces<ApiErrorResponse>(StatusCodes.Status404NotFound)
    .Produces<ApiErrorResponse>(StatusCodes.Status409Conflict)
    .Produces<ApiErrorResponse>(StatusCodes.Status400BadRequest)
    .IncludeInOpenApi();
```

`EliminarAsync` es un handler HTTP delgado: envía
`EliminarRecursoCommand` mediante Mediator y devuelve
`Results.NoContent()` después de confirmar la baja. El CommandHandler permanece
en Application, comprueba autorización y reglas de negocio, y coordina la baja
mediante repositorios e `IUnitOfWork`. El módulo Carter no modifica estado ni
ejecuta borrado directamente en EF Core.

El proyecto define si la baja es física o lógica según integridad referencial,
historial y retención. En una baja lógica, se conserva el contenido de negocio
inmutable y se registra la retirada mediante metadatos de ciclo de vida o un
registro separado; no se introduce un mecanismo de activación/desactivación
reversible. El recurso retirado deja de aparecer en consultas operativas y su
consulta individual devuelve `404`; las consultas históricas requieren un
contrato y permisos explícitos.

La operación DEBE ser idempotente: repetirla no restaura el recurso ni vuelve
a ejecutar efectos de negocio. La primera baja completada devuelve `204` sin
cuerpo. Si el recurso ya no está disponible, incluido un DELETE repetido, se
devuelve `404` conforme a la política de recurso inexistente; la diferencia de
código HTTP no cambia el efecto idempotente. Si existen dependencias que impiden
la baja, se devuelve `409`; otras invariantes incumplidas usan `400`. No se
borran dependencias en cascada sin una regla explícita del dominio. La baja y
los efectos durables de Outbox se confirman juntos y no generan nuevas
notificaciones por cada repetición.

Esta convención utiliza la semántica de
[DELETE definida en RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.5).

<a id="tema-manejo-estandarizado-de-respuestas"></a>

### Manejo estandarizado de respuestas

El contrato propietario se define en [Respuestas estandarizadas del API](respuestas-api.md).
Los éxitos con contenido usan `ApiSuccessResponse<T>` con success,
message y data. Los errores usan `ApiErrorResponse` con success=false, code,
message, errors y traceId. No se utiliza Problem Details como cuerpo público.

`POST /api/sesion` conserva un contrato directo de autenticación. Las respuestas
204/HEAD no tienen cuerpo, y las probes conservan su contrato operativo mínimo.
Las páginas usan `ApiSuccessResponse<PagedData<TResponse>>`. La nueva guía
incluye los tipos, estados HTTP, códigos y ejemplos de consumo del frontend.

<a id="s22"></a>

## OpenAPI

La documentación debe incluir:

- rutas y métodos;
- esquemas request/response;
- códigos exitosos y de error;
- paginación y filtros;
- esquemas de seguridad Cookie y Bearer cuando aplique la autenticación mixta,
  con alternativas OR para endpoints compartidos y esquema exclusivo para rutas
  específicas de un cliente; requisito `X-XSRF-TOKEN` documentado para escrituras
  con cookie, sin publicar cookies ni tokens reales;
- ejemplos sin datos sensibles.

OpenAPI es parte del contrato y debe verificarse en integración.
