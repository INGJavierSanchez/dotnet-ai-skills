# Adopción y decisiones del proyecto

[Índice de documentación](README.md) · [Adopción del proyecto](adopcion-del-proyecto.md)

Completar esta guía al adoptar la base técnica. Reúne plataforma, versiones, decisiones configurables y el procedimiento de excepciones mediante ADR.

<a id="tema-especificacion-base-de-arquitectura-para-proyectos-net"></a>

## Especificación base de arquitectura para proyectos .NET

> Plantilla reutilizable para iniciar APIs empresariales con .NET 10.
>
> Reemplace los valores entre corchetes, por ejemplo `[NombreProyecto]`, antes
> de adoptar este documento en un proyecto concreto.


<a id="s2"></a>

## Cómo utilizar esta especificación

Al comenzar un proyecto:

1. reemplazar `[NombreProyecto]` por el nombre real;
2. definir el motor de base de datos y su proveedor EF Core;
3. decidir si autenticación, multiempresa y eventos internos son necesarios;
4. fijar las versiones exactas en administración central de paquetes;
5. documentar cualquier desviación mediante una ADR;
6. completar [la lista de aceptación](calidad/lista-aceptacion.md).

Términos normativos:

- **DEBE**: requisito obligatorio;
- **NO DEBE**: práctica prohibida;
- **DEBERÍA**: recomendación que requiere justificación para omitirse;
- **PUEDE**: decisión opcional dependiente del proyecto.

<a id="s3"></a>

## Plataforma y librerías

| Componente | Versión base | Uso |
| --- | --- | --- |
| .NET | 10 | Runtime y SDK. |
| ASP.NET Core | 10 | Host HTTP, Minimal APIs, middleware, DI y configuración. |
| Carter | 10.0.0 | Organización modular de endpoints Minimal API. |
| Entity Framework Core | 10 | ORM, consultas, transacciones y migraciones. |
| FluentValidation | Versión aprobada | Validación de contratos y mensajes. |
| Mapster | Versión aprobada | Mapeo y proyección de DTO. |
| Mapster.DependencyInjection | Versión compatible | Integración de Mapster con DI. |
| Mapster.EFCore | Versión compatible | Proyección de `IQueryable` a DTO. |
| Mediator.Abstractions | 3.x | Comandos, consultas, notificaciones y handlers. |
| Mediator.SourceGenerator | 3.x | Generación de mediator y registros de handlers. |
| Scrutor | 7.0.0 | Registro de dependencias por convención. |
| Serilog.AspNetCore | 10.0.0 | Logging estructurado y registro de solicitudes HTTP. |
| Serilog.Settings.Configuration | Versión compatible | Configuración de Serilog desde `appsettings`. |
| OpenTelemetry.Extensions.Hosting | Versión aprobada | Registro de trazas y métricas en API y Workers. |
| OpenTelemetry.Instrumentation.AspNetCore | Versión compatible | Instrumentación HTTP del host. |
| OpenTelemetry.Instrumentation.Http | Versión compatible | Instrumentación y propagación en HttpClient. |
| OpenTelemetry.Exporter.OpenTelemetryProtocol | Versión compatible | Exportación OTLP al collector configurado. |
| Resend | Versión aprobada | Adaptador de correo mediante el SDK oficial de Resend, si se selecciona este proveedor. |
| MailKit | Versión aprobada | Cliente SMTP con OAuth 2.0 para Google, si se selecciona Google SMTP. |
| Google.Apis.Gmail.v1 | Versión aprobada | Cliente de Gmail API, solo si el proyecto elige este transporte en lugar de SMTP. |
| Proveedor EF Core | Según motor | Integración con `[MotorBaseDatos]`. |
| JwtBearer | 10.x, si aplica | Autenticación JWT. |
| OpenAPI/Swagger | Versión aprobada | Documentación del contrato HTTP. |
| Framework de pruebas | MSTest, xUnit o NUnit | Pruebas automatizadas. |

Las versiones deben fijarse centralmente mediante `Directory.Packages.props`
cuando la solución contenga varios proyectos.


<a id="s29"></a>

## Decisiones obligatorias

| Decisión | Elección base |
| --- | --- |
| Runtime | .NET 10 |
| Estilo | Arquitectura en capas por funcionalidades |
| Endpoints | Carter 10.0.0 con módulos por funcionalidad |
| Casos de uso | CQRS con martinothamar/Mediator |
| Colaboración entre handlers | Sin dependencia directa; servicios para reutilización, `Send` moderado y Notifications para efectos derivados |
| Contratos HTTP y mensajes CQRS | `sealed record`; contratos HTTP en API y mensajes/resultados en Application |
| Idioma del dominio | Entidades, enumeraciones, propiedades y métodos de negocio en español; roles técnicos en inglés |
| Respuestas | `ApiSuccessResponse<T>`, `ApiErrorResponse` y `PagedData<T>`; sesión con contrato directo |
| Mapeo | Mapster; no AutoMapper |
| Validación | FluentValidation |
| DI automático | Scrutor 7.0.0 con interfaces marcadoras |
| Logging | Serilog.AspNetCore 10.0.0 |
| Autenticación, si aplica | Angular Web con cookie HttpOnly y antiforgery; app móvil con JWT Bearer; autorización común y selección explícita de esquema |
| Observabilidad | TraceId W3C, OpenTelemetry para trazas/métricas y probes `/health/live` y `/health/ready` |
| Correo electrónico | `IEmailOutbox` para intención transaccional; Worker prepara correo y usa `IEmailSender` neutral con adaptadores Google/Resend |
| ORM | Entity Framework Core 10 |
| Persistencia básica | Único `IRepository<TEntity>` / `EfRepository<TEntity>`; contexto `AppDbContext` |
| Consultas específicas | `QueryServices` unificado por funcionalidad; sin repositorios especializados |
| Consultas | Proyección explícita de columnas salvo que se necesite la entidad completa |
| Lecturas y mapeos | Contratos/Results en Application, consultas EF Core y proyecciones en Infrastructure, mapeos HTTP en API; configuración Mapster única por host |
| Transacciones | Unit of Work explícito |
| Creación de entidades | Factories estáticas de Domain y constructores no públicos; ver [guía de dominio](arquitectura/dominio.md#tema-creacion-mediante-factories) |
| Errores HTTP | `IExceptionHandler` y escritor común de `ApiErrorResponse`; reglas de negocio en 400 |
| Documentación | OpenAPI |
| Pruebas | Unitarias, infraestructura e integración |

<a id="s30"></a>

## Decisiones por proyecto

Complete esta tabla al adoptar la plantilla:

| Decisión | Valor |
| --- | --- |
| Nombre | `[NombreProyecto]` |
| Motor de base de datos | `[MotorBaseDatos]` |
| Proveedor EF Core | `[ProveedorEFCore]` |
| Framework de pruebas | `[MSTest/xUnit/NUnit]` |
| Autenticación | `[Cookie Web + JWT móvil/Clientes habilitados/No aplica]` |
| Emisor de identidad | `[Proveedor OIDC/OAuth 2.0/Servicio propio]` |
| Sesión web | `[Nombre/Ámbito/SameSite/Duración/Inactividad/Revocación]` |
| Orígenes Angular autorizados | `[Orígenes exactos/Modo de credenciales]` |
| Antiforgery web | `[Inicialización/Entrega de token/Validación X-XSRF-TOKEN]` |
| Sesión móvil | `[Emisor/Audiencia/Duración/PKCE/Refresh/Revocación]` |
| Claves de protección de cookies | `[Almacén compartido/Nombre de aplicación/Rotación]` |
| Multiempresa | `[Sí/No]` |
| Correo habilitado | `[Sí/No]` |
| Proveedor de correo | `[Resend/GoogleSmtp/GoogleGmailApi]` |
| Remitente y dominio verificado | `[Dirección/Dominio]` |
| Categorías de remitente y ReplyTo autorizados | `[Categoría/Dirección/Ámbito]` |
| Política de reintentos | `[Máximo/Backoff]` |
| Bloqueos y timeout de envío | `[Duración/Renovación/Timeout]` |
| Deduplicación del proveedor | `[Soporte y período de idempotencia]` |
| Resultado de envío incierto | `[Reconciliar/Reintentar con riesgo/Revisión]` |
| Retención y recuperación del Outbox | `[Plazo/Protección/Reanudación de DeadLetter]` |
| Compatibilidad de plantillas | `[Conservación de versiones y modelos]` |
| Motor de plantillas | `Razor (.cshtml) con modelos tipados` |
| Estrategia de IDs | `[Guid/long/otro]` |
| Zona horaria | `[ZonaIANA]` |
| Calendarios de interfaz | `Español; variante regional [es-CO/es-ES/otra]` |
| Observabilidad | `[Proveedor]` |
| Identidad del servicio | `[service.name/Versión/Ambiente/Instancia]` |
| Exportación de telemetría | `[Endpoint OTLP/Protocolo/Intervalos/Límites]` |
| Muestreo de trazas | `[Política/Porcentaje/Retención de errores]` |
| Instrumentación de persistencia | `[Paquete/Fuentes/Política de SQL]` |
| Probes y dependencias críticas | `[Acceso/Checks/Timeout/Intervalo/Umbral]` |
| Objetivos operativos y alertas | `[Latencia/Disponibilidad/Umbrales/Responsables]` |
| Retención de telemetría | `[Plazos por señal/Protección de datos]` |
| Despliegue | `[Contenedor/Servicio/Otro]` |
| Inicialización de base | `[Proceso único de despliegue/Instancia autorizada/Deshabilitada]` |
| Aprovisionamiento de base | `[Responsable/Panel o servidor/CreateDatabase=false en Production]` |
| Compatibilidad de migraciones | `[Motor y versión/Proveedor EF Core y versión/Soporte de bloqueos]` |
| Seeders | `[Conjunto por contexto/Orden/Claves únicas/Transacción]` |


<a id="s32"></a>

## Regla para excepciones arquitectónicas

Cuando un requisito obligue a apartarse de esta especificación, el equipo DEBE
crear una ADR que documente:

- contexto;
- decisión;
- alternativas consideradas;
- consecuencias;
- fecha y responsables;
- condición para revisar o revertir la decisión.

La excepción debe ser local y no convertirse automáticamente en una nueva
convención para toda la solución.
