# Logging y observabilidad

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define correlación, logs, trazas, métricas, probes y alertas.

<a id="s23"></a>

## Logging con Serilog y observabilidad

Serilog es el proveedor único de logging de la aplicación. Se usa
`Serilog.AspNetCore` 10.0.0 y configuración en dos etapas para capturar errores
que ocurran antes de construir el host.

```xml
<PackageReference Include="Serilog.AspNetCore" Version="10.0.0" />
<PackageReference Include="Serilog.Settings.Configuration"
                  Version="[VersionCompatible]" />
```

Configuración base de `Program.cs`:

```csharp
using Serilog;
using System.Diagnostics;

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    Activity.DefaultIdFormat = ActivityIdFormat.W3C;
    Activity.ForceDefaultIdFormat = true;

    var builder = WebApplication.CreateBuilder(args);

    builder.Services.AddSerilog((services, configuration) => configuration
        .ReadFrom.Configuration(builder.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext());

    // Integrar aquí los registros de OpenTelemetry y Health Checks descritos abajo.
    var app = builder.Build();

    app.Use(async (context, next) =>
    {
        var traceId = RequestCorrelation.GetTraceId(context);
        context.Response.OnStarting(() =>
        {
            context.Response.Headers["X-Trace-Id"] = traceId;
            return Task.CompletedTask;
        });

        using (Serilog.Context.LogContext.PushProperty("TraceId", traceId))
        using (Serilog.Context.LogContext.PushProperty(
            "RequestId", context.TraceIdentifier))
        {
            await next(context);
        }
    });

    app.UseSerilogRequestLogging(options =>
    {
        options.EnrichDiagnosticContext = (context, httpContext) =>
        {
            context.Set("RequestHost", httpContext.Request.Host.Value);
            context.Set("RequestScheme", httpContext.Request.Scheme);
            context.Set("TraceId", RequestCorrelation.GetTraceId(httpContext));
            context.Set("RequestId", httpContext.TraceIdentifier);
            context.Set("SpanId", Activity.Current?.SpanId.ToString());
        };
    });

    app.UseExceptionHandler();
    app.MapCarter();
    app.Run();
}
catch (Exception exception)
{
    Log.Fatal(exception, "La aplicación terminó inesperadamente");
    Environment.ExitCode = 1;
}
finally
{
    Log.CloseAndFlush();
}
```

Configuración mínima en `appsettings.json`:

```json
{
  "Serilog": {
    "Using": ["Serilog.Sinks.Console"],
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.Hosting.Lifetime": "Information"
      }
    },
    "WriteTo": [
      {
        "Name": "Console"
      }
    ],
    "Enrich": ["FromLogContext"]
  }
}
```

La sección predeterminada `Logging` se elimina para evitar dos configuraciones
paralelas. Los sinks adicionales se seleccionan por ambiente y deben soportar
la política de retención definida por el proyecto.

El resto del código inyecta `ILogger<T>`; la API estática `Log` se reserva para
el arranque y terminación del host.

Reglas de logging:

- usar plantillas estructuradas: `"Usuario {UserId} creado"`;
- no interpolar strings en mensajes de log;
- incluir `TraceId`, `SourceContext` y contexto funcional necesario;
- no registrar contraseñas, tokens, secretos ni datos personales completos;
- no serializar entidades completas en logs;
- usar `Information` para hitos, `Warning` para situaciones recuperables y
  `Error` para fallos inesperados;
- configurar sinks por ambiente;
- usar salida estructurada JSON en producción;
- ajustar categorías ruidosas de Microsoft a `Warning` cuando corresponda;
- permitir que `UseSerilogRequestLogging` emita una sola entrada por solicitud.

<a id="tema-correlacion-obligatoria"></a>

### Correlación obligatoria

Cada solicitud DEBE tener un `TraceId` W3C, representado por 32 caracteres
hexadecimales, común a los logs, la traza, `ApiErrorResponse.TraceId` y el
encabezado de respuesta `X-Trace-Id`. Los éxitos y la sesión usan ese encabezado
para correlación, sin añadir traceId a sus cuerpos definidos.
`HttpContext.TraceIdentifier` se conserva como `RequestId` local, distinto del
identificador distribuido. Los logs asociados a un span también incluyen su
`SpanId`; los eventos de arranque sin solicitud pueden carecer de ambos.

La API usa el contexto W3C `traceparent`/`tracestate` validado por la
instrumentación de .NET. Sin contexto válido se inicia una nueva traza. No se
copia un encabezado arbitrario como identificador confiable ni se usa el
contexto de tracing para identidad, tenant o autorización. El identificador se
mantiene aunque el muestreo descarte la exportación de esa traza.

`RequestCorrelation` reside en `Api/Common/Observability/RequestCorrelation.cs`:

```csharp
using System.Diagnostics;

public static class RequestCorrelation
{
    private static readonly object TraceIdKey = new();

    public static string GetTraceId(HttpContext context)
    {
        if (context.Items.TryGetValue(TraceIdKey, out var cached))
        {
            return (string)cached!;
        }

        var traceId = Activity.Current is { IdFormat: ActivityIdFormat.W3C } activity
            ? activity.TraceId.ToString()
            : ActivityTraceId.CreateRandom().ToString();

        context.Items[TraceIdKey] = traceId;
        return traceId;
    }
}
```

El fallback solo mantiene la correlación cuando falta una Activity; no crea un
span. En el host instrumentado las pruebas DEBEN comprobar que existe una
Activity HTTP W3C y que el identificador corresponde a la traza real. El
middleware de correlación se ejecuta antes del logging de solicitudes y del
manejador de excepciones; el manejador envuelve autenticación, autorización y
endpoints. Si clientes de navegador necesitan leer `X-Trace-Id`, CORS expone
explícitamente ese encabezado.

<a id="tema-tracing-distribuido-obligatorio"></a>

### Tracing distribuido obligatorio

API y Workers DEBEN configurar OpenTelemetry para exportar trazas y métricas.
Application emite instrumentación propia mediante `ActivitySource` y `Meter`
de la BCL, sin depender del SDK de OpenTelemetry. Domain conserva sus reglas
puras. API/Infrastructure registran las fuentes y meters concretos utilizados.

Se DEBEN instrumentar solicitudes ASP.NET Core, llamadas salientes HttpClient,
casos de uso relevantes y procesamiento del Outbox. Las operaciones de base de
datos requieren instrumentación compatible con el proveedor elegido; se
documenta su paquete y fuente, evitando spans duplicados de EF Core y del driver.
No se exportan parámetros SQL ni sentencias con datos sensibles.

El host configura `service.name` estable, versión del servicio, ambiente e
identidad de instancia. Endpoint OTLP, credenciales, protocolo, muestreo,
intervalos y límites de exportación se configuran por ambiente y se validan al
inicio. Las credenciales se obtienen del almacén de secretos. El siguiente
fragmento se integra antes de `builder.Build()` y requiere paquetes compatibles
fijados centralmente:

```csharp
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(builder.Environment.ApplicationName))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSource("[NombreProyecto].Application", "[NombreProyecto].Infrastructure")
        .AddOtlpExporter())
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddMeter("[NombreProyecto].Application", "[NombreProyecto].Infrastructure")
        .AddOtlpExporter());
```

Paquetes mínimos: `OpenTelemetry.Extensions.Hosting`,
`OpenTelemetry.Instrumentation.AspNetCore`,
`OpenTelemetry.Instrumentation.Http` y
`OpenTelemetry.Exporter.OpenTelemetryProtocol`. Este fragmento muestra el
registro; cada proyecto DEBE completar resource, muestreo y Options de
exportación. No agrega un segundo proveedor de logging: Serilog sigue siendo
el proveedor de logs. Si el proyecto exporta logs por OTLP, usa un único camino
de exportación y evita duplicarlos.

HttpClient propaga el contexto de traza mediante la instrumentación. Para el
Outbox, se guarda el contexto de origen necesario (TraceId, SpanId y flags) como
metadatos técnicos; no se guarda baggage sensible. Cada intento del Worker
inicia un nuevo span o traza con un enlace al contexto de origen, sin mantener
una Activity abierta entre el commit y el envío. `NotificationId`, intento y
proveedor se incluyen en logs y spans de ese intento. Si Mediator emite señales
BCL, se registran sus fuentes/meters reales y se evita duplicar el mismo caso
de uso con un behavior propio.

El muestreo y sus límites DEBEN quedar documentados. No se promete conservar
todos los errores al decidir el muestreo al inicio de la traza; si se necesita retención selectiva
de errores, se define muestreo posterior en el collector. Un fallo del collector
no bloquea solicitudes ni marca el servicio como no disponible: las colas de
exportación son acotadas y sus descartes y errores se monitorizan.

<a id="tema-metricas-minimas-y-cardinalidad"></a>

### Métricas mínimas y cardinalidad

| Señal obligatoria | Medición |
| --- | --- |
| HTTP | Conteo/tasa de solicitudes, duración y distribución por estado y ruta normalizada. |
| Casos de uso | Conteo, duración y resultado por nombre estable de operación. |
| Dependencias | Duración y fallos de HTTP saliente y persistencia crítica. |
| Runtime | CPU, memoria, GC y saturación del ThreadPool mediante meters o monitorización del entorno. |
| Outbox, si aplica | Pendientes, edad del pendiente más antiguo, intentos, aceptación del proveedor, fallos y DeadLetter. |

Las duraciones usan histogramas con unidades y límites documentados; tasas y
percentiles se calculan en el backend. Las etiquetas DEBEN ser acotadas: método,
plantilla de ruta (`/api/recursos/{id}`), estado, operación y proveedor aprobado.
NO se usan IDs de usuario/tenant/recurso/notificación, TraceId, SpanId, URLs
completas, query strings, direcciones de correo ni mensajes de excepción como
etiquetas. La correlación con trazas utiliza exemplars cuando haya soporte.
Tokens, cuerpos HTTP, modelos de correo y datos personales tampoco se incluyen
en atributos de spans o baggage. Las probes se excluyen o separan del tráfico
de negocio para no distorsionar las métricas ni generar ruido.

<a id="tema-health-checks-de-vida-y-disponibilidad"></a>

### Health checks de vida y disponibilidad

Los hosts HTTP DEBEN exponer `/health/live` y `/health/ready` con el middleware
de Health Checks de ASP.NET Core. Son endpoints operativos: devuelven estado
mínimo en texto plano, sin `ApiSuccessResponse<T>`, detalles de excepciones ni nombres
internos de dependencias. Sus fallos usan `503`, sin envelope de error de negocio. Las reglas
de envelope y errores de negocio de la [guía de API HTTP](../arquitectura/api-http.md#s15) no se aplican a estas probes.

- **Vida (`live`)**: comprueba que el proceso responde. No consulta base de
  datos, correo, collector ni servicios remotos; una caída externa no debe
  provocar reinicios del proceso por esta probe.
- **Disponibilidad (`ready`)**: comprueba inicialización y dependencias críticas
  para admitir trabajo, incluida la base de datos cuando sea necesaria. Durante
  inicialización y drenaje del host devuelve `503`. Un sistema de correo con
  Outbox no deja de admitir operaciones por una caída del proveedor de correo
  si puede guardar intenciones; esa caída se detecta con métricas y alertas.
- `Healthy` devuelve `200`; `Degraded` y `Unhealthy` devuelven `503` en readiness.
  Los checks tienen timeout y cancelación, no escriben datos de negocio, no
  ejecutan migraciones ni envían correos de prueba. Se define intervalo y
  umbral de fallos de las probes para evitar oscilaciones y sobrecarga.
- Las probes se restringen al orquestador o red de operación. No dependen de
  autenticación de usuarios finales; si requieren autorización técnica, el
  orquestador debe poder proporcionarla. No se confía solo en el encabezado Host
  para restringir acceso. Los Workers independientes definen readiness según
  inicialización y capacidad de reclamar trabajo, y monitorizan su progreso.

Ejemplo de registro y mapeo, antes y después de `builder.Build()` respectivamente:

```csharp
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

builder.Services.AddHealthChecks()
    .AddCheck<StartupReadinessCheck>(
        "startup", tags: ["ready"], timeout: TimeSpan.FromSeconds(2))
    .AddCheck<DatabaseReadinessCheck>(
        "database", tags: ["ready"], timeout: TimeSpan.FromSeconds(2));

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false,
    AllowCachingResponses = false
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    AllowCachingResponses = false,
    ResultStatusCodes =
    {
        [HealthStatus.Healthy] = StatusCodes.Status200OK,
        [HealthStatus.Degraded] = StatusCodes.Status503ServiceUnavailable,
        [HealthStatus.Unhealthy] = StatusCodes.Status503ServiceUnavailable
    }
});
```

`StartupReadinessCheck` y `DatabaseReadinessCheck` son implementaciones propias
de `IHealthCheck`: API mantiene el estado de inicio/drenaje; Infrastructure
comprueba conectividad real con cancelación y timeout. Los dos segundos son un
valor ilustrativo configurable. Este fragmento requiere implementar y registrar
esos checks y aplicar las restricciones de acceso del despliegue; no es una
prueba automática de disponibilidad por sí solo.

<a id="tema-operacion-y-verificacion"></a>

### Operación y verificación

Cada proyecto DEBE definir responsables, retención, objetivos de latencia y
disponibilidad, dashboards y alertas con umbrales, ventanas y procedimiento de
respuesta. Como mínimo se alertan fallos sostenidos, saturación, pérdida de
telemetría y acumulación/DeadLetter del Outbox cuando aplique. Un `200` en una
probe no sustituye estas mediciones ni confirma entrega de correos.

Las pruebas verifican coincidencia del TraceId entre X-Trace-Id, errores, logs y span;
propagación con y sin `traceparent` válido; métricas con etiquetas acotadas;
ausencia de datos sensibles; `live` saludable con base de datos caída y `ready`
en `503`; inicio y drenaje no disponibles; y continuidad del servicio con el
exportador caído. Se usan recolectores locales o capturadores, no servicios
externos de producción.

Referencias oficiales:

- [Tracing distribuido en .NET](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/distributed-tracing-concepts).
- [Configuración de OpenTelemetry .NET](https://github.com/open-telemetry/opentelemetry-dotnet/blob/main/docs/builders/configure-opentelemetry-provider.md).
- [Health Checks de ASP.NET Core 10](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0).


## Guías relacionadas

- [API HTTP y OpenAPI](../arquitectura/api-http.md)
- [Configuración mediante Options](configuracion.md)
