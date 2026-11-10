# Manejo de errores HTTP

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define el manejador central y su traducción de excepciones al envelope de error.

<a id="s17"></a>

## Manejador centralizado de excepciones

La API DEBE tener una única implementación de `IExceptionHandler` que traduzca
las excepciones a [ApiErrorResponse](respuestas-api.md#tema-respuestas-error) y registre el incidente mediante
`ILogger<GlobalExceptionHandler>`. No se distribuyen bloques `try/catch`
repetitivos en módulos Carter, handlers de Mediator o repositorios.

Registro y middleware:

```csharp
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.Configure<RouteHandlerOptions>(options =>
    options.ThrowOnBadRequest = true);

var app = builder.Build();

app.UseSerilogRequestLogging();
app.UseExceptionHandler(new ExceptionHandlerOptions
{
    AllowStatusCode404Response = true
});
```


Implementación base:

El siguiente manejador utiliza `ApiErrorWriter`, definido en
[respuestas del API](respuestas-api.md), y el catálogo `PublicDomainErrors`,
definido en [la política de mensajes públicos](../seguridad/mensajes-publicos.md).
`IApiValidationErrorMapper` es un colaborador propio de API que traduce errores
de FluentValidation a campos JSON y mensajes seguros. Se implementa y registra
sin estado por solicitud como singleton, porque IExceptionHandler es singleton;
no captura IMapper scoped ni DbContext. Su contrato, en un archivo separado:

```csharp
public interface IApiValidationErrorMapper
{
    IReadOnlyDictionary<string, string[]> Map(
        HttpContext context,
        FluentValidation.ValidationException exception);
}
```

La implementación utiliza correspondencias explícitas Request/Command y metadata
del endpoint; no expone nombres internos ni valores rechazados. Se prueban sus
reglas por funcionalidad. Los mensajes públicos de validators deben estar
aprobados; la conversión no publica automáticamente cualquier texto de excepción.

```csharp
public sealed class GlobalExceptionHandler(
    ILogger<GlobalExceptionHandler> logger,
    IApiValidationErrorMapper validationMapper) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (httpContext.Response.HasStarted)
        {
            return false;
        }

        var domainError = exception is DomainException domain
            ? PublicDomainErrors.Resolve(domain.Code)
            : (Code: string.Empty, Message: string.Empty);

        var (status, code, message, level) = exception switch
        {
            ValidationException =>
                (StatusCodes.Status400BadRequest,
                 "VALIDATION_ERROR", "Revisa la información ingresada.",
                 LogLevel.Warning),
            BadHttpRequestException bad when bad.StatusCode is >= 400 and < 500 =>
                (bad.StatusCode,
                 "HTTP_REQUEST_REJECTED", "La solicitud no es válida.",
                 LogLevel.Warning),
            NotFoundException =>
                (StatusCodes.Status404NotFound,
                 "RESOURCE_NOT_FOUND", "El recurso no fue encontrado.",
                 LogLevel.Information),
            ConflictException =>
                (StatusCodes.Status409Conflict,
                 "RESOURCE_CONFLICT", "La operación genera un conflicto.",
                 LogLevel.Warning),
            DomainException =>
                (StatusCodes.Status400BadRequest,
                 domainError.Code, domainError.Message,
                 LogLevel.Warning),
            _ =>
                (StatusCodes.Status500InternalServerError,
                 "INTERNAL_SERVER_ERROR", "Ocurrió un error inesperado al procesar la solicitud.",
                 LogLevel.Error)
        };

        logger.Log(
            level,
            exception,
            "Error procesando {Method} {Path}. TraceId: {TraceId}",
            httpContext.Request.Method,
            httpContext.Request.Path,
            RequestCorrelation.GetTraceId(httpContext));

        object? errors = exception is ValidationException validation
            ? validationMapper.Map(httpContext, validation)
            : null;

        await ApiErrorWriter.WriteAsync(
            httpContext, status, code, message, errors, cancellationToken);
        return true;
    }
}
```

El manejador debe preservar el `CancellationToken`, evitar detalles internos en
errores 500 y producir el mismo formato de respuesta para toda la API. Cuando
recibe una `DomainException`, expone el código público aprobado en el campo
`code` y el mensaje resuelto por el catálogo. Un código
desconocido utiliza el fallback público, nunca el mensaje de la excepción.

Mapa recomendado:

| Error | Estado HTTP |
| --- | --- |
| Validación | `400 Bad Request` |
| Autenticación | `401 Unauthorized` |
| Autorización | `403 Forbidden` |
| Recurso inexistente | `404 Not Found` |
| Conflicto o concurrencia | `409 Conflict` |
| Regla de negocio no clasificable | `400 Bad Request` |
| Error inesperado | `500 Internal Server Error` |

ApiErrorResponse DEBE incluir `traceId` conforme a la [guía de observabilidad](../operacion/observabilidad.md#s23). No se exponen stack traces, SQL,
secretos ni rutas físicas en respuestas públicas de ningún ambiente. Que
`Message` sea de diagnóstico interno no autoriza guardar secretos en una
excepción: los logs DEBEN aplicar la política de protección de datos, incluyendo
la redacción o exclusión de información sensible de excepciones y sus causas.

Una excepción se registra una sola vez como error técnico. Los componentes que
la originan la propagan; no deben registrarla y volverla a lanzar. El evento de
finalización HTTP de Serilog es independiente y resume método, ruta, estado y
duración.

## Errores fuera del handler

El registro de servicios o un filtro de endpoints no basta para capturar todos
los errores HTTP. API DEBE completar estas rutas con el mismo escritor:

- JSON y binding de Minimal APIs: ThrowOnBadRequest se activa en todos los
  ambientes y se conserva BadHttpRequestException.StatusCode. Un `415` no se
  convierte en `500` ni se publica su Message.
- Si se utiliza validación automática adicional de ASP.NET Core/Carter, se
  adapta su salida al contrato, sin producir Problem Details en paralelo.
- `401`/`403`: los eventos de challenge/forbid y el manejador de autorización
  producen ApiErrorResponse, preservando WWW-Authenticate cuando aplique y sin
  redirecciones. Antiforgery y resolución de tenant usan el mismo contrato.
- Rutas desconocidas y otros estados sin cuerpo: un UseStatusCodePages
  personalizado escribe ApiErrorResponse únicamente cuando la respuesta está
  vacía y no iniciada, preservando estado y headers. No reenvuelve un error ya
  escrito ni transforma probes, `HEAD` o respuestas `204`.
- `POST /api/sesion` lleva DirectSessionResponseMetadata y devuelve su error
  directo seguro, conforme a [la excepción de sesión](respuestas-api.md#tema-sesion).
  Todos los generadores anteriores respetan esa metadata.

El manejador del ejemplo requiere los imports propios de API y ASP.NET Core,
las excepciones de Application/Domain y FluentValidation. No reemplaza el
registro de los colaboradores descritos ni las pruebas de esas rutas. Una
solicitud abortada no se informa como fallo de negocio ni como un error 500
escrito sobre una conexión cerrada; se define su clasificación en observabilidad.

Referencia: [Manejo de errores de ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0).


## Guías relacionadas

- [Mensajes públicos de errores](../seguridad/mensajes-publicos.md)
