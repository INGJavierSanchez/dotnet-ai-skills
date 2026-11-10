# Correo y Outbox

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define contratos, responsabilidades y la entrega desacoplada de correo.

<a id="s20"></a>

## Notificaciones por correo electrónico

Si el proyecto habilita correo, DEBE poder seleccionar Google o Resend sin
acoplar los casos de uso al proveedor. Application define los contratos de
encolado, renderizado y envío; Infrastructure implementa la persistencia del
Outbox, las plantillas y los adaptadores. Los contratos se declaran en archivos
independientes bajo `Application/Abstractions/Messaging/Email`; los modelos de
plantilla se ubican junto a su funcionalidad en Application.

<a id="tema-intencion-pendiente-y-correo-preparado"></a>

### Intención pendiente y correo preparado

El mensaje pendiente representa la intención de enviar una notificación. El
handler proporciona plantilla, versión, modelo tipado y destinatarios a
`IEmailOutbox`. No proporciona HTML, asunto libre ni una dirección `From`.

```csharp
public sealed record EmailNotification<TModel>(
    string Template,
    int Version,
    TModel Model,
    IReadOnlyList<EmailAddress> To,
    string IdempotencyKey,
    string SenderCategory = "Notifications",
    IReadOnlyList<EmailAddress>? Cc = null,
    IReadOnlyList<EmailAddress>? Bcc = null);

public interface IEmailOutbox
{
    Task<Guid> EnqueueAsync<TModel>(
        EmailNotification<TModel> notification,
        CancellationToken cancellationToken = default);
}
```

La implementación de `IEmailOutbox` valida el identificador y versión contra un
catálogo de plantillas aprobado, comprueba el tipo de modelo y serializa una
instantánea de sus datos. Agrega el registro al mismo DbContext scoped que los
repositorios; NO llama a `SaveChanges`, confirma una transacción ni usa otra
conexión para guardar el mensaje. El identificador devuelto no implica que el
registro ya esté confirmado. `IUnitOfWork` confirma negocio y Outbox juntos.

`EmailOutboxMessage` es el registro de persistencia implementado en
Infrastructure, no un contrato HTTP ni una entidad de negocio de Domain. Guarda
`ModelJson`, no referencias a objetos mutables ni entidades rastreadas. El
modelo debe contener los datos necesarios para renderizar sin volver a consultar
estado de negocio que pudiera haber cambiado.

La regla de ubicación en `Domain/Entities` aplica a entidades de negocio; los
registros técnicos de entrega como `EmailOutboxMessage` permanecen en
Infrastructure y tienen su configuración EF Core explícita.

Después del commit, el Worker prepara un `EmailMessage`: resuelve el remitente,
renderiza asunto, HTML y texto plano, valida el mensaje y llama a `IEmailSender`.
Este último recibe exclusivamente el correo preparado y adapta la solicitud al
proveedor; no selecciona plantillas, no deserializa modelos ni consulta el Outbox.

```csharp
public sealed record EmailAddress(string Address, string? DisplayName = null);

public sealed record EmailMessage(
    EmailAddress From,
    IReadOnlyCollection<EmailAddress> To,
    string Subject,
    string HtmlBody,
    string TextBody,
    string IdempotencyKey,
    IReadOnlyCollection<EmailAddress>? Cc = null,
    IReadOnlyCollection<EmailAddress>? Bcc = null,
    EmailAddress? ReplyTo = null);

public sealed record EmailSendResult(
    string Provider,
    string ProviderMessageId);

public interface IEmailSender
{
    Task<EmailSendResult> SendAsync(
        EmailMessage message,
        CancellationToken cancellationToken = default);
}
```

Los handlers de negocio dependen de `IEmailOutbox` y registran intenciones de
envío; no llaman directamente a `IEmailSender`. El Worker resuelve los servicios
scoped dentro de un scope por lote o mensaje; no captura el DbContext scoped en
el constructor de un `BackgroundService` singleton. Las clases específicas del
proveedor permanecen en Infrastructure:

- `ResendEmailSender` utiliza el paquete oficial `Resend` y `IResend`;
- `GoogleSmtpEmailSender` utiliza MailKit contra `smtp.gmail.com` con OAuth 2.0
  y TLS;
- `GoogleGmailApiEmailSender` PUEDE utilizar `Google.Apis.Gmail.v1` cuando el
  proyecto necesite Gmail API en vez de SMTP;
- el proyecto elige exactamente un transporte: `Resend`, `GoogleSmtp` o
  `GoogleGmailApi`.

No se registran indistintamente varios adaptadores como la misma implementación
predeterminada. Un facade o factory selecciona el adaptador configurado; también
pueden usarse servicios con clave de .NET. Scrutor descubre servicios internos,
pero el registro de clientes externos, `HttpClient`, Options y selección del
proveedor DEBE ser explícito.

<a id="tema-control-del-remitente"></a>

### Control del remitente

El componente de preparación del Worker, implementado en Infrastructure,
resuelve `SenderCategory` mediante configuración validada del servidor. La
categoría predeterminada `Notifications` utiliza `Email:From`. Categorías
adicionales, como `Support`, requieren una lista explícita de direcciones,
dominios y `ReplyTo` autorizados para el proveedor elegido.

La categoría la establece el caso de uso; no se toma libremente de un request
HTTP. Un remitente desconocido o no autorizado detiene el envío. El modelo de
plantilla no puede sobrescribir `From` ni `ReplyTo`. El adaptador verifica que
los valores del `EmailMessage` preparado pertenecen a la configuración aprobada.
En proyectos multiempresa, esta resolución también valida la pertenencia del
remitente y de la notificación al tenant correspondiente.


<a id="tema-entrega-confiable-con-outbox"></a>

## Entrega confiable con Outbox

El envío de correos que resulte de una operación de negocio DEBE usar un Outbox:

1. el handler realiza los cambios de negocio y llama a `IEmailOutbox.EnqueueAsync`;
2. `IUnitOfWork` confirma ambos en la misma transacción;
3. un `BackgroundService` o Worker reclama lotes pendientes;
4. el Worker resuelve el remitente y la plantilla versionada, renderiza y valida
   el correo preparado; luego llama a `IEmailSender` fuera de la transacción;
5. registra el identificador del proveedor y marca el mensaje como `Sent` en una
   transacción breve. `Sent` significa aceptado por el proveedor, no entregado al
   buzón; entrega, rebote y queja se registran separadamente cuando estén disponibles.

No se realiza una llamada de red al proveedor dentro de la transacción de base
de datos. El Outbox debe almacenar como mínimo identificador, plantilla y
versión, modelo serializado, destinatarios To/Cc/Bcc, categoría del remitente,
clave de idempotencia, estado, intentos, próximo intento, fecha de creación,
fecha de aceptación, proveedor, identificador del proveedor, propietario y
vencimiento del bloqueo, y último error clasificado sin datos sensibles. Si
aplica multiempresa, también guarda el tenant. Sus estados base son `Pending`,
`Processing`, `Sent`, `Failed` y `DeadLetter`.

`Pending` está listo para reclamar; `Processing` tiene un bloqueo temporal;
`Failed` espera un reintento programado; `DeadLetter` requiere intervención por
un fallo permanente o intentos agotados. El reclamo es atómico y usa un token de
propiedad para que un Worker cuyo bloqueo expiró no actualice el estado de otro.
El tiempo de bloqueo y su renovación deben cubrir el renderizado y envío. No se
mantiene una transacción de base de datos abierta durante la llamada de red.
El reclamo, la preparación persistida y las actualizaciones de estado se
confirman mediante `IUnitOfWork` en scopes y transacciones breves; el Worker no
comparte un DbContext entre operaciones concurrentes. Si pierde el bloqueo,
deja de iniciar envíos y no confirma estados; un envío ya aceptado por el
proveedor puede seguir requiriendo reconciliación.

Los reintentos usan backoff exponencial con jitter y un máximo configurable. La
misma clave de idempotencia se conserva en todos los intentos; cuando el
proveedor soporte idempotencia nativa, el adaptador debe transmitirla. La toma
de mensajes pendientes debe ser segura ante varios workers y recuperar
mensajes cuyo bloqueo haya expirado. El consumidor actualiza estados de forma
idempotente y diferencia errores transitorios de errores permanentes.


<a id="tema-plantillas-eventos-y-seguridad"></a>

## Plantillas, eventos y seguridad

- Las plantillas HTML DEBEN implementarse con Razor en archivos `.cshtml` y
  modelos fuertemente tipados mediante `@model`; no se construye HTML mediante
  concatenación de cadenas en handlers o servicios.
- `RazorEmailTemplateRenderer` implementa `IEmailTemplateRenderer` en
  Infrastructure y utiliza el motor Razor de ASP.NET Core para renderizar fuera
  de controllers y sin depender de una solicitud HTTP real.
- Las vistas de correo se compilan al publicar la aplicación. La compilación en
  tiempo de ejecución solo PUEDE habilitarse explícitamente en desarrollo.
- Un layout exclusivo de correo concentra encabezado, pie, identidad visual y
  estilos compatibles con clientes de email. Partial views reutilizan bloques
  como botones, datos de contacto y avisos.
- Cada plantilla tiene identificador, versión, archivo `.cshtml`, modelo
  `sealed record`, asunto y alternativa de texto plano. El Outbox guarda el
  identificador, la versión y el modelo serializado, no el HTML definitivo como
  representación de la intención.
- El catálogo resuelve `(Template, Version)` a archivos y tipo de modelo
  aprobados. No acepta rutas arbitrarias, nombres de tipos CLR ni metadatos de
  deserialización polimórfica aportados por el cliente. El renderer deserializa
  `ModelJson` al tipo conocido, valida su esquema y renderiza con `@model` tipado.
- Una versión publicada es inmutable, incluidos asunto, texto plano, layout y
  partials que puedan afectar el resultado. Los despliegues conservan sus
  archivos y el deserializador compatible mientras haya mensajes pendientes,
  en proceso, reintentables o recuperables que la referencien. No se sustituye
  una versión desconocida por la más reciente; se registra un fallo permanente
  y se deriva a `DeadLetter` para revisión.
- El renderizado debe ser determinista para una intención: fechas, cultura y
  datos variables necesarios se fijan en el modelo o metadatos versionados;
  no se usa la hora actual ni consultas a servicios externos para alterar el
  contenido entre intentos.
- Los valores del modelo se codifican para HTML; las plantillas no ejecutan
  contenido aportado por el usuario. `Html.Raw` queda prohibido para valores no
  confiables.
- Remitente y dominios autorizados se configuran del lado del servidor. El
  componente de preparación resuelve una categoría aprobada; el cliente y el
  modelo de plantilla no pueden elegir libremente `From` ni `ReplyTo`.
- Se validan destinatarios, encabezados y tamaño para impedir inyección y abuso.
  El contrato base no incluye adjuntos; si se incorporan, deben usar referencias
  durables con permisos, límites de tamaño y retención compatibles con reintentos.
- Los endpoints de webhook verifican autenticidad y toleran reintentos. Una
  restricción única sobre proveedor e identificador de evento, junto con una
  actualización transaccional, evita aplicar dos veces el mismo evento. Si el
  proveedor no ofrece identificador estable, el proyecto define una estrategia
  de deduplicación. Los eventos tardíos o fuera de orden no deben revertir estados
  posteriores; rebotes, quejas y entregas se registran cuando estén disponibles.
- No se registran cuerpos, tokens, API keys ni direcciones completas salvo que
  exista una necesidad explícita y una política de protección de datos.
- Modelos serializados y destinatarios del Outbox se consideran datos sensibles:
  se restringe su acceso y se define protección y retención. No se guardan
  contraseñas ni credenciales reutilizables; enlaces de un solo uso, si son
  necesarios, tienen expiración compatible con la política de entrega.
- Serilog incluye `NotificationId`, `Provider`, `Template`, `Attempt` y
  `ProviderMessageId`; también se miden envíos, fallos, reintentos y latencia.

Para pruebas se proporciona un `FakeEmailSender` o capturador en memoria. Las
pruebas no deben enviar correo real salvo suites de aceptación aisladas y
habilitadas explícitamente.

Contrato recomendado:

```csharp
public sealed record RenderedEmail(
    string Subject,
    string HtmlBody,
    string TextBody);

public interface IEmailTemplateRenderer
{
    Task<RenderedEmail> RenderAsync(
        string template,
        int version,
        string modelJson,
        CancellationToken cancellationToken = default);
}
```

Estructura sugerida:

```text
Infrastructure/
└── Notifications/
    └── Email/
        ├── Outbox/
        │   ├── EmailOutbox.cs
        │   ├── EmailOutboxMessage.cs
        │   └── EmailOutboxWorker.cs
        ├── Delivery/
        │   ├── EmailPreparationService.cs
        │   └── ConfiguredEmailSenderResolver.cs
        ├── Rendering/
        │   ├── EmailTemplateCatalog.cs
        │   └── RazorEmailTemplateRenderer.cs
        ├── Providers/
        │   ├── ResendEmailSender.cs
        │   ├── GoogleSmtpEmailSender.cs
        │   └── GoogleGmailApiEmailSender.cs
        └── Templates/
            ├── Shared/v1/_EmailLayout.cshtml
            ├── Shared/v1/_CallToAction.cshtml
            └── Account/
                ├── TemporaryCredential.v1.cshtml
                └── TemporaryCredential.v1.txt
```

Referencias oficiales para la implementación:

- [Resend .NET SDK](https://resend.com/dotnet);
- [Gmail SMTP y OAuth 2.0](https://developers.google.com/workspace/gmail/imap/imap-smtp);
- [Gmail API: envío de mensajes](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/send).


## Guías relacionadas

- [Configuración y operación del correo](../operacion/entrega-correo.md)
- [Estrategia de pruebas](../calidad/pruebas.md)
