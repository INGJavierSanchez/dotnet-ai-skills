# Respuestas estandarizadas del API

[Índice de documentación](../README.md) · [API HTTP](api-http.md)

Esta guía define el contrato público de respuestas. Sustituye el envelope
anterior `ApiResponse<T>` y el uso de Problem Details para errores de negocio.
La escritura centralizada de errores se define en [errores HTTP](errores-http.md).

La adopción reemplaza un contrato público anterior: los consumidores y OpenAPI
deben actualizarse juntos o introducir una versión de API si hay clientes que
dependen del formato anterior. No se alternan los dos envelopes en una misma
ruta sin un mecanismo explícito de versión.

<a id="tema-alcance"></a>

## Alcance y excepciones

Todos los endpoints de negocio utilizan respuestas uniformes para éxitos y
errores. Se mantienen los códigos HTTP reales, sin devolver `200` para errores.

- `POST /api/sesion` devuelve los datos de autenticación directamente, sin
  envelope, según el flujo de [sesión](#tema-sesion).
- `204 No Content` y las respuestas a `HEAD` no contienen cuerpo.
- `/health/live` y `/health/ready` conservan el contrato operativo mínimo de
  [Health Checks](../operacion/observabilidad.md#s23).
- Si se integran endpoints de protocolos externos, su contrato propio requiere
  una excepción explícita y documentada; no se altera un protocolo por envolverlo.

Los tipos y helpers residen en API, bajo `Api/Common/Responses`, en archivos
independientes con namespace `[NombreProyecto].Api.Common.Responses`.
Application continúa devolviendo Results, no envelopes HTTP.

<a id="tema-respuestas-exitosas"></a>

## Respuestas exitosas

```json
{
  "success": true,
  "message": "Recurso consultado correctamente.",
  "data": {
    "id": "48b92837-f08a-4a32-a1ca-a5f18b34f341",
    "nombre": "Ejemplo"
  }
}
```

`success` siempre es true y `message` es un texto público
obligatorio. `data` admite un DTO, colección o valor; una colección sin elementos
se devuelve vacía, no como null. Un recurso individual ausente genera `404`.
No se añaden entidades EF Core, secretos ni campos internos al contrato.

Archivo `ApiSuccessResponse.cs`:

```csharp
namespace [NombreProyecto].Api.Common.Responses;

public sealed record ApiSuccessResponse<T>(string Message, T Data)
{
    public bool Success => true;
}
```

Archivo `ApiResponses.cs`:

```csharp
namespace [NombreProyecto].Api.Common.Responses;

public static class ApiResponses
{
    public static ApiSuccessResponse<T> Success<T>(
        T data, string message) => new(message, data);
}
```

Los mensajes provienen de constantes o catálogos aprobados. La
serialización global usa camelCase; el cliente no depende del orden de campos.
Los éxitos no incluyen traceId en el cuerpo: la correlación está disponible en
`X-Trace-Id` y en logs. Los errores sí lo incluyen en el cuerpo.
El campo `code` se reserva a respuestas de error; no se envía en éxitos.

### Listados y páginas

```json
{
  "success": true,
  "message": "Recursos consultados correctamente.",
  "data": [{ "id": "48b92837-f08a-4a32-a1ca-a5f18b34f341", "nombre": "Ejemplo" }]
}
```

Un listado paginado utiliza `ApiSuccessResponse<PagedData<TResponse>>`.
`PagedData<T>` y `PaginationMetadata` se declaran en archivos independientes de
API. Los modelos paginados internos de Application se adaptan a estos contratos.

```csharp
public sealed record PaginationMetadata(
    int Page, int PageSize, int TotalItems, int TotalPages);
```

```csharp
public sealed record PagedData<T>(
    IReadOnlyList<T> Items, PaginationMetadata Pagination);
```

### Creación y fechas de reserva

Una creación terminada responde `201 Created`, con `Location` y este envelope.
Ejemplo del contenido para una reserva:

```json
{
  "success": true,
  "message": "Tu reserva fue creada correctamente.",
  "data": {
    "id": "48b92837-f08a-4a32-a1ca-a5f18b34f341",
    "fecha": "2026-10-30",
    "horaInicio": "08:30:00",
    "horaFin": "09:00:00"
  }
}
```

La fecha sin hora usa DateOnly; las horas locales de inicio y fin del ejemplo
usan TimeOnly con precisión de segundos, separadas de la fecha. No se oculta
horaInicio dentro de un timestamp en fecha. Los instantes con zona mantienen
su semántica y no se convierten implícitamente en horas locales.

<a id="tema-respuestas-error"></a>

## Respuestas de error

```json
{
  "success": false,
  "code": "RESOURCE_NOT_FOUND",
  "message": "El recurso no fue encontrado.",
  "errors": null,
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

`success` siempre es false. `code` y `message` son obligatorios y proceden del
[catálogo público](../seguridad/mensajes-publicos.md), nunca de Exception.Message.
`errors` siempre está presente: contiene detalles seguros o null. Para
validación es un diccionario de campos y mensajes; otros errores pueden usar
un objeto, array o texto documentado en OpenAPI. No contiene stack traces,
SQL, credenciales ni información de otros tenants.

Archivo `ApiErrorResponse.cs`:

```csharp
using System.Text.Json.Serialization;

namespace [NombreProyecto].Api.Common.Responses;

public sealed record ApiErrorResponse(
    string Code,
    string Message,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.Never)] object? Errors,
    string TraceId)
{
    public bool Success => false;
}
```

El atributo conserva errors:null aunque la configuración global omita valores
nulos. TraceId es el identificador W3C de 32 caracteres hexadecimales definido
en [observabilidad](../operacion/observabilidad.md#tema-correlacion-obligatoria),
coincidente con logs, traza y X-Trace-Id. No se usa el RequestId local en su lugar.
Estos errores se escriben como `application/json`, sin envolverlos en la
respuesta de éxito ni mezclarlos con `application/problem+json`.

### Validación de campos

```json
{
  "success": false,
  "code": "VALIDATION_ERROR",
  "message": "Revisa la información ingresada.",
  "errors": {
    "nombres": ["El nombre es obligatorio."],
    "correo": ["El correo electrónico no es válido."]
  },
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

Los nombres de errors corresponden al JSON público, no necesariamente al nombre
CLR del Command. La API traduce campos cuando Request y Command difieren; no
publica directamente nombres internos ni valores rechazados. JSON mal formado,
parámetros inválidos y FluentValidation utilizan este mismo envelope; cuando no
sea posible asociar el fallo a una propiedad se utiliza una clave general
documentada, como `request`. Un campo puede tener varios mensajes.

<a id="tema-estados-http"></a>

## Estados HTTP

| Estado | Uso y contrato |
| --- | --- |
| `200` | Consulta, actualización o eliminación terminada con cuerpo ApiSuccessResponse. |
| `201` | Recurso creado, envelope de éxito y Location. |
| `202` | Trabajo aceptado y todavía no terminado; datos de seguimiento cuando aplique. No se usa para una cancelación ya completada. |
| `204` | Operación terminada sin cuerpo, incluida la baja definida en la guía HTTP. |
| `400` | Entrada inválida o regla de negocio incumplida: VALIDATION_ERROR, DOMAIN_RULE_VIOLATION u otro código público aprobado. |
| `401` | Falta autenticación válida: UNAUTHORIZED; API_KEY_REQUIRED o API_KEY_INVALID si la ruta requiere API key. |
| `403` | Identidad válida sin permisos: FORBIDDEN. |
| `404` | Recurso inexistente o no accesible en el tenant actual: RESOURCE_NOT_FOUND o código específico. |
| `409` | Conflicto con información existente o concurrencia: RESOURCE_CONFLICT o código específico. |
| `500` | Fallo inesperado: INTERNAL_SERVER_ERROR y mensaje genérico. |

Los estados técnicos como `405`, `413`, `415` y `429` conservan su significado
y usan ApiErrorResponse cuando API genera el cuerpo. Los headers de protocolo,
como Allow, Retry-After y WWW-Authenticate, se conservan. En este contrato las
DomainException ordinarias se traducen a `400`, sustituyendo el anterior `422`.

## Códigos estables de error

Los errores usan UPPER_SNAKE_CASE, por ejemplo `VALIDATION_ERROR`,
`RESOURCE_NOT_FOUND`, `RESOURCE_CONFLICT` e `INTERNAL_SERVER_ERROR`.
Los proyectos pueden usar códigos específicos de su API, como
`SERVICE_NOT_FOUND` o `CLIENT_DOCUMENT_DUPLICATE`. Los éxitos se identifican
mediante el estado HTTP, success y data, sin un código de resultado adicional.

Los sufijos `_CREATE_FAILED` y `_UPDATE_FAILED` solo se usan con una condición
definida y un estado HTTP apropiado; no convierten todos los fallos en `400`.
El frontend decide por code y estado HTTP, nunca comparando message. El código
de negocio no determina identidad, empresa ni permisos.

### Escritor común de errores

Archivo `Api/Common/Responses/DirectSessionResponseMetadata.cs`:

```csharp
namespace [NombreProyecto].Api.Common.Responses;

public sealed class DirectSessionResponseMetadata { }
```

Archivo `Api/Common/Responses/ApiErrorWriter.cs`. El endpoint de sesión agrega
`.WithMetadata(new DirectSessionResponseMetadata())`; no se determina la
excepción con coincidencias parciales del texto de la URL.

```csharp
namespace [NombreProyecto].Api.Common.Responses;

public static class ApiErrorWriter
{
    public static async Task WriteAsync(
        HttpContext context,
        int status,
        string code,
        string message,
        object? errors = null,
        CancellationToken cancellationToken = default)
    {
        context.Response.StatusCode = status;

        if (HttpMethods.IsHead(context.Request.Method))
        {
            return;
        }

        if (context.GetEndpoint()?.Metadata
            .GetMetadata<DirectSessionResponseMetadata>() is not null)
        {
            await context.Response.WriteAsJsonAsync(
                new { error = message }, cancellationToken);
            return;
        }

        await context.Response.WriteAsJsonAsync(
            new ApiErrorResponse(
                code, message, errors, RequestCorrelation.GetTraceId(context)),
            cancellationToken);
    }
}
```

`RequestCorrelation` se importa desde el namespace propio definido en la guía de
observabilidad. El llamador no utiliza este escritor después de iniciar la
respuesta ni sobre probes. Manejador de excepciones, validación, challenge,
forbid y status-code pages comparten este contrato y evitan escribir dos veces.

<a id="tema-sesion"></a>

## Excepción de POST /api/sesion

El inicio de sesión no usa ApiSuccessResponse. Su contrato directo se define
por flujo explícito, conforme a [autenticación](../seguridad/autenticacion-autorizacion.md):
cookie HttpOnly para Angular Web y JWT Bearer para móvil. El flujo no se
selecciona por User-Agent ni por una credencial ambigua.

En móvil, la respuesta exitosa incluye directamente token y los datos públicos
de identidad, por ejemplo usuario, rol y empresaId cuando corresponda. El cliente
lee `response.token`; el contrato final de expiración y renovación se documenta
según el emisor. No se incluyen tokens reales en ejemplos o logs.

```json
{
  "token": "<access-token>",
  "usuario": "gestor",
  "rol": "Gestor",
  "empresaId": "<identificador-de-empresa>"
}
```

En Web se emite Set-Cookie con las protecciones de la guía de autenticación y
se devuelven directamente los datos públicos de sesión, sin token accesible a
JavaScript. La excepción de envelope no obliga a cambiar el método de autenticación.

Un rechazo de credenciales en este endpoint utiliza `401` y la respuesta directa:

```json
{ "error": "Credenciales inválidas o acceso no disponible." }
```

El texto es genérico y no distingue cuenta inexistente, contraseña incorrecta o
empresa inactiva. Un fallo interno conserva `500` y un texto seguro bajo error.
La excepción de formato se aplica solo a este endpoint; conserva X-Trace-Id,
rate limiting y CSRF del flujo web. Su metadata y tests deben asegurar la misma
salida para validación, autenticación y errores inesperados, sin exponer detalles.

## Tipos de consumo del frontend

Cada interfaz se mantiene en un archivo propio del cliente:

```typescript
export interface ApiSuccessResponse<T> {
  success: true;
  message: string;
  data: T;
}
```

```typescript
export interface ApiErrorResponse {
  success: false;
  code: string;
  message: string;
  errors: Record<string, string[]> | string[] | string | null;
  traceId: string;
}
```

Cuando un endpoint defina otro objeto en errors, el cliente amplía explícitamente
ese tipo según OpenAPI. El flujo normal consume response.data; el manejo de error
consume code, message, errors y traceId. Un error de red o proxy sin JSON válido
requiere un fallback local; no se asume que todos los errores del navegador
sean ApiErrorResponse. El login utiliza sus propios tipos de respuesta directa.
