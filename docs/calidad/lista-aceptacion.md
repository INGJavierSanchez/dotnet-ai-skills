# Lista de aceptación

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Permite comprobar la adopción de las guías. Cada grupo enlaza sus fuentes normativas.

<a id="s31"></a>

## Lista de aceptación

<a id="tema-estructura"></a>

### Estructura

Guías de referencia: [Fundamentos y estructura de la solución](../arquitectura/fundamentos.md) · [Modelo de dominio](../arquitectura/dominio.md) · [Convenciones de código y tipos de datos](../desarrollo/convenciones-codigo.md).

- [ ] La solución contiene Domain, Application, Infrastructure y Api.
- [ ] Las referencias siguen la dirección definida.
- [ ] Los archivos C# que declaran namespace usan ámbito de archivo con `;`,
  sin bloque de llaves, y un nombre coherente con la capa y carpeta.
- [ ] Las desviaciones tienen ADR.
- [ ] Las entidades, propiedades, value objects, enumeraciones, eventos,
  excepciones y métodos de negocio están nombrados en español.
- [ ] Todas las entidades están directamente en la raíz de `Domain/Entities`,
  usan el namespace `.Domain.Entities` y no existen subcarpetas para entidades.
- [ ] Todas las enumeraciones están directamente en la raíz de `Domain/Enums`,
  usan el namespace `.Domain.Enums` y no existen subcarpetas para enumeraciones.
- [ ] Cada entidad y enumeración pública está en un archivo del mismo nombre.
- [ ] Las entidades hijas reutilizan los miembros de su base, sin ocultarlos
  ni declarar campos equivalentes para la misma responsabilidad; los campos
  adicionales representan conceptos de negocio o relaciones distintos.
- [ ] Las entidades declaran campos y propiedades antes de los constructores;
  después ubican factories, métodos de negocio y auxiliares privados, en ese orden.
- [ ] Las entidades concretas se crean mediante factories estáticas de Domain;
  no exponen constructores públicos y todas sus rutas de creación de negocio
  validan invariantes. Handlers y seeders no usan new para construirlas.
- [ ] Las bases heredables tienen constructores protegidos compatibles con
  las hijas; las entidades sealed tienen constructores privados. Una base
  concreta que se crea por negocio conserva su factory sin hacerse abstracta.
- [ ] La factory de una hija devuelve su propio tipo y construye un único
  objeto cuya parte heredada se inicializa con base(...); no llama a la factory
  de la base ni duplica su identificador.
- [ ] Existe `Application/Common/Extensions/EnumExtensions.cs`; Domain no
  depende de esta utilidad de conversión o presentación.
- [ ] Las conversiones desde texto verifican `Enum.TryParse` y `Enum.IsDefined`,
  incluyendo pruebas para valores vacíos, desconocidos y numéricos.
- [ ] Las propiedades enum se validan antes de asignarse en constructores,
  factories y métodos de cambio: Enum.IsDefined para enums ordinarios y
  validación específica para Flags, sin depender de extensiones de Application
  desde Domain. Las pruebas cubren valores desconocidos, cero y null si aplica.
- [ ] Existe `Domain/Exceptions/DomainException.cs` y el manejador central la
  traduce a HTTP `400` mediante ApiErrorResponse.
- [ ] `DomainException` no está registrada como entidad de EF Core ni contiene
  conceptos HTTP.
- [ ] Las invariantes y decisiones de negocio están en entidades, value objects
  o Domain Services, no duplicadas en handlers.
- [ ] `Handler`, `Command`, `Query`, `Repository`, `Service`, `Validator` y los
  demás roles o sufijos técnicos permanecen en inglés.
- [ ] Los métodos técnicos impuestos por frameworks, patrones o contratos
  externos no se traducen artificialmente.

<a id="tema-contratos-y-casos-de-uso"></a>

### Contratos y casos de uso

Guías de referencia: [Application, CQRS y validación](../arquitectura/application-cqrs.md) · [Contratos y mapeo entre capas](../arquitectura/contratos-y-mapeo.md) · [Convenciones de código y tipos de datos](../desarrollo/convenciones-codigo.md).

- [ ] Los contratos HTTP `Request` y `Response` son `sealed record` y viven en
  API bajo `Features/[Feature]/Contracts/Requests` o `Responses`.
- [ ] Cada contrato HTTP y cada resultado `Result` de Application está en un
  archivo independiente con nombre y namespace coherentes con su tipo y ruta.
- [ ] Cada record de resultado, incluidos sus records auxiliares, está en su
  propio archivo bajo Results; no hay varios records en un mismo archivo ni
  Results declarados dentro de archivos de Commands, Queries o handlers.
- [ ] Application no referencia contratos HTTP, Carter ni ASP.NET Core.
- [ ] Los handlers devuelven resultados propios de Application; los endpoints
  los adaptan a los contratos `Response` de API mediante Mapster.
- [ ] API adapta sus contratos `Request` a Commands/Queries mediante Mapster.
- [ ] Ningún contrato HTTP está anidado o declarado en el mismo archivo de un
  endpoint o módulo Carter.
- [ ] Los comandos y consultas usan martinothamar/Mediator.
- [ ] Cada Command comparte archivo con su CommandHandler y cada Query con su
  QueryHandler; el archivo se nombra según el mensaje, declara primero el
  mensaje y después el handler bajo el mismo namespace con ámbito de archivo.
- [ ] No existen archivos separados para CommandHandlers o QueryHandlers;
  contratos HTTP, Results y validators permanecen en archivos independientes.
- [ ] Todos los `CommandHandler`, `QueryHandler` y `NotificationHandler` están
  en Application, junto a su caso de uso.
- [ ] No existen handlers CQRS en Domain, Infrastructure ni Api.
- [ ] Los handlers coordinan persistencia exclusivamente mediante abstracciones
  de Application e `IUnitOfWork`, sin depender directamente de EF Core.
- [ ] Los handlers orquestan obtención de datos, llamadas al dominio, servicios
  externos y persistencia, pero no implementan reglas propias del dominio.
- [ ] Ningún handler se inyecta directamente en otro handler.
- [ ] La lógica compartida está extraída a Domain Services, Application
  Services, Query Services u otros componentes apropiados.
- [ ] El uso de `IMediator.Send()` desde un handler es excepcional, está
  justificado y no crea cadenas ni ciclos entre casos de uso.
- [ ] Las acciones derivadas desacopladas utilizan `INotification` y
  `INotificationHandler`.
- [ ] Los efectos externos que requieren entrega durable utilizan Outbox y no
  dependen únicamente de notificaciones en memoria.
- [ ] No existe referencia a MediatR.
- [ ] FluentValidation cubre entradas externas.
- [ ] Mapster reemplaza completamente a AutoMapper.
- [ ] No existe referencia a AutoMapper.
- [ ] Los mapeos entre contratos HTTP, mensajes CQRS, resultados de Application
  y modelos externos se realizan con Mapster.
- [ ] Las consultas proyectan a resultados de Application con
  `ProjectToType<T>()` antes de materializar; API los adapta a contratos HTTP.
- [ ] Los QueryHandlers consumen contratos de lectura de Application; sus
  implementaciones EF Core residen en Infrastructure y devuelven resultados
  materializados sin exponer IQueryable, DbContext ni contratos HTTP.
- [ ] Los mapeos en memoria de Application, proyecciones de Infrastructure y
  mapeos HTTP de API se ubican junto a su funcionalidad en la capa correspondiente.
- [ ] Cada pareja origen/destino tiene un único propietario y no depende del
  orden de escaneo para sobrescribir reglas.
- [ ] El host compone una instancia explícita de TypeAdapterConfig; IMapper y
  las proyecciones usan esa instancia, sin GlobalSettings ni Adapt sin config.
- [ ] La configuración queda terminada antes de atender solicitudes; se
  validan mapeos en memoria y traducción SQL con el proveedor real.
- [ ] No existen conversiones manuales repetitivas en endpoints o handlers.
- [ ] Las excepciones de mapeo manual están justificadas y probadas.
- [ ] Mapster no se utiliza para saltarse constructores, factories, métodos ni
  invariantes del dominio.

<a id="tema-dependencias"></a>

### Dependencias

Guías de referencia: [Composición e inyección de dependencias](../arquitectura/composicion-y-dependencias.md) · [Configuración mediante Options](../operacion/configuracion.md).

- [ ] Scrutor 7.0.0 registra solo dependencias marcadas.
- [ ] Los lifetimes scoped, transient y singleton son coherentes.
- [ ] Mediator, DbContext, Options y autenticación tienen registro explícito.
- [ ] La configuración se consume mediante Options tipadas inyectadas, con
  sección centralizada y validación al inicio; no hay lecturas directas de
  IConfiguration, archivos, variables de entorno o secretos fuera de la raíz
  de composición para obtener configuración de aplicación.
- [ ] IOptions, IOptionsSnapshot e IOptionsMonitor se eligen según el lifetime
  y las necesidades de recarga; los singletons no capturan IOptionsSnapshot.
- [ ] El contenedor se valida al inicio o mediante pruebas.

<a id="tema-persistencia"></a>

### Persistencia

Guías de referencia: [Persistencia y consultas](../arquitectura/persistencia-y-consultas.md) · [Unit of Work y transacciones](../arquitectura/unit-of-work.md) · [Migraciones e inicialización de base de datos](../operacion/migraciones-inicializacion.md) · [Convenciones de código y tipos de datos](../desarrollo/convenciones-codigo.md).

- [ ] DatabaseInitializer usa Options tipadas y completa las etapas requeridas
  antes de aceptar tráfico; Enabled=false no abre ni resuelve el contexto.
- [ ] La base inexistente se distingue de fallos de conexión o permisos; solo
  se crea con autorización explícita y CreateDatabase=false en Production.
- [ ] Las migraciones pendientes se aplican antes de los seeders; un esquema
  actualizado no se recrea y un esquema incompatible detiene la inicialización.
- [ ] Los seeders se ejecutan ordenados, insertan solo datos faltantes y son
  idempotentes, con restricciones únicas y transacción mediante IUnitOfWork.
- [ ] Migraciones y seeders tienen un único ejecutor o exclusividad distribuida
  probada; las réplicas no compiten para inicializar.
- [ ] No se usan EnsureCreated ni EnsureDeleted como sustituto de migraciones
  o recuperación; no se falsea el historial para continuar el arranque.
- [ ] Fallos de bloqueo/proveedor se diagnostican con versiones y servidor real;
  no se ignoran ni se convierten resultados nulos en bloqueo adquirido.
- [ ] Los errores críticos impiden aceptar tráfico y terminan con código distinto
  de cero; logs y configuración no exponen credenciales.
- [ ] Las pruebas de inicialización cubren existencia, creación, migraciones,
  repetición de seeders, credenciales, permisos, bloqueos y múltiples instancias
  con un motor relacional equivalente al destino.
- [ ] Solo existen `IRepository<TEntity>` y `EfRepository<TEntity>` como repositorio; no hay repositorios por entidad.
- [ ] `QueryServices` reúne consultas específicas y proyecciones, con contratos en Application e implementaciones por funcionalidad en Infrastructure.
- [ ] `GetByIdAsync` y las consultas para modificación garantizan seguimiento explícito; las lecturas a Result no lo requieren.
- [ ] `Add`, `AddRange` y `Remove` no guardan; no existe un `Update` genérico ni se expone IQueryable.
- [ ] El genérico abierto se registra una sola vez, scoped, y comparte contexto con las consultas y Unit of Work.
- [ ] Las pruebas cubren seguimiento, altas por lote, borrado diferido, resolución de DI y ausencia de guardados anticipados.

- [ ] Las consultas EF Core usan sintaxis de métodos como convención; la
  sintaxis de consulta se reserva para casos donde mejora la legibilidad y
  conserva las reglas de proyección, paginación y materialización asíncrona.
- [ ] EF Core tiene configuraciones separadas por entidad.
- [ ] Las consultas parciales proyectan columnas antes de materializar.
- [ ] Los listados de lectura usan `AsNoTracking` y resultados proyectados; API
  adapta esos resultados a sus contratos `Response`.
- [ ] No se cargan blobs o columnas extensas si no son consumidos.
- [ ] El SQL manual evita seleccionar columnas no utilizadas.
- [ ] Todas las confirmaciones usan `IUnitOfWork`.
- [ ] Los handlers no administran transacciones directamente.
- [ ] Existen pruebas de commit y rollback.
- [ ] Las restricciones de base respaldan las reglas de unicidad.

<a id="tema-api-y-seguridad"></a>

### API y seguridad

Guías de referencia: [API HTTP y OpenAPI](../arquitectura/api-http.md) · [Manejo de errores HTTP](../arquitectura/errores-http.md) · [Autenticación y autorización](../seguridad/autenticacion-autorizacion.md) · [Seguridad mínima y multiempresa](../seguridad/seguridad-y-multiempresa.md) · [Mensajes públicos de errores](../seguridad/mensajes-publicos.md).

- [ ] Los endpoints están organizados en módulos Carter por funcionalidad.
- [ ] No se usan controladores MVC para la API.
- [ ] Los módulos Carter son delgados y delegan mediante `IMediator`.
- [ ] Cada endpoint declara nombre, respuestas, autorización y OpenAPI.
- [ ] Los éxitos con contenido usan ApiSuccessResponse<T> con success=true,
  message y data, sin code; POST /api/sesion conserva su contrato directo.
- [ ] Los listados paginados usan `PagedData<T>` y `PaginationMetadata`.
- [ ] Las respuestas `201` incluyen `Location`.
- [ ] Las respuestas `204` no incluyen cuerpo.
- [ ] Los recursos de negocio inmutables usan `DELETE /{id}` para su baja y no
  exponen endpoints de activar/desactivar ni actualización de su contenido.
- [ ] La baja física o lógica, la exclusión de consultas operativas y el acceso
  histórico están definidos; repetir DELETE no restaura ni duplica efectos.
- [ ] La baja confirma mediante IUnitOfWork, respeta integridad y autorización,
  y devuelve `204`, `404`, `409` o `400` según las reglas documentadas.
- [ ] Los errores usan ApiErrorResponse, nunca el envelope de éxito ni HTTP
  200; incluyen success=false, code, message, errors (incluso null) y traceId.
- [ ] Existe un único `IExceptionHandler` centralizado.
- [ ] La validación automática, FluentValidation, binding y errores de
  autenticación/autorización producen el mismo contrato, salvo la sesión.
- [ ] POST /api/sesion devuelve error directo seguro con 401 para credenciales
  inválidas; Web conserva cookies y móvil obtiene JWT sin cambiar los esquemas.
- [ ] El frontend decide por code y estado HTTP; los nombres de errors coinciden
  con los campos JSON y no revelan valores rechazados.
- [ ] Las respuestas HTTP no copian mensajes ni detalles de instancias de
  excepciones; los errores de dominio usan el catálogo público de API.
- [ ] Solo los códigos aprobados se exponen; un código desconocido devuelve
  `DOMAIN_RULE_VIOLATION` y su mensaje genérico.
- [ ] Los mensajes públicos no incluyen valores de entrada, datos sensibles ni
  hechos que el consumidor no esté autorizado a conocer.
- [ ] Hay pruebas del mensaje aprobado, fallback para códigos desconocidos y
  ausencia de detalles sensibles de `Message` e `InnerException` en respuestas.
- [ ] Los endpoints y handlers no duplican `try/catch` ni logs de excepciones.
- [ ] OpenAPI refleja el contrato real.
- [ ] Code se reserva a errores y utiliza códigos estables; los éxitos no
  incluyen code. HTTP 202 se reserva a trabajo pendiente, no a una operación finalizada.
- [ ] El contexto de empresa proviene de cookie/JWT o API key validados; solo
  un administrador autorizado puede seleccionar empresa con X-Empresa-Id.
- [ ] Un recurso de otro tenant devuelve 404 sin revelar su existencia y los
  errores de contexto incluyen un code obligatorio.
- [ ] Los secretos no están versionados.
- [ ] CORS y HTTPS están configurados.
- [ ] Autenticación y autorización tienen pruebas, si aplican.
- [ ] Angular Web usa una cookie de autenticación HttpOnly, Secure y con
  SameSite/ámbito definidos; no guarda access tokens en almacenamiento JavaScript.
- [ ] Las operaciones de escritura con cookie, el login y el logout web validan
  antiforgery; tokens ausentes o inválidos impiden ejecutar el caso de uso.
- [ ] CORS permite únicamente orígenes aprobados con credenciales; Angular envía
  cookies y token CSRF solo a la API confiable, incluido el escenario entre orígenes.
- [ ] La app móvil usa JWT Bearer validado y almacenamiento seguro; emisión,
  renovación y revocación están documentadas.
- [ ] La selección de esquema es explícita; un Bearer inválido no permite
  fallback a cookie ni mezcla identidades, aunque ambas credenciales estén presentes.
- [ ] Ambos esquemas aplican las mismas políticas de usuario/permisos/tenant;
  challenge y forbid devuelven ApiErrorResponse `401`/`403` sin redirecciones HTML,
  con la excepción de formato definida para la sesión.
- [ ] Las réplicas comparten y protegen las claves de cookies; se prueban
  expiración, logout, revocación y renovación según las garantías elegidas.
- [ ] OpenAPI declara Cookie/Bearer como alternativas según la ruta y documenta
  antiforgery sin exponer credenciales reales.

<a id="tema-notificaciones-por-correo"></a>

### Notificaciones por correo

Guías de referencia: [Correo y Outbox](../arquitectura/correo-y-outbox.md) · [Configuración y operación del correo](../operacion/entrega-correo.md).

- [ ] Los handlers de negocio dependen de `IEmailOutbox`; el Worker utiliza
  `IEmailTemplateRenderer` e `IEmailSender` sin exponer SDK a Application.
- [ ] El proveedor se selecciona por configuración validada al inicio.
- [ ] Google usa OAuth 2.0 y TLS; Resend usa el SDK oficial.
- [ ] Credenciales y tokens no están en archivos versionados.
- [ ] Los correos de negocio se registran en el Outbox dentro de la misma
  transacción administrada por `IUnitOfWork`.
- [ ] `EnqueueAsync` agrega la intención al contexto compartido sin confirmar;
  un rollback revierte tanto el negocio como la intención.
- [ ] El Outbox conserva plantilla, versión, modelo serializado, destinatarios,
  categoría, clave de idempotencia y metadatos de procesamiento.
- [ ] El remitente y `ReplyTo` se resuelven desde configuración aprobada; ni
  requests HTTP ni modelos de plantilla pueden sobrescribirlos.
- [ ] `EmailMessage` contiene asunto, HTML, texto plano, remitente resuelto y
  clave de idempotencia; `IEmailSender` solo adapta y envía ese correo preparado.
- [ ] Los Workers crean scopes para dependencias scoped y reclaman mensajes
  mediante bloqueos recuperables con token de propiedad.
- [ ] Ningún correo se envía dentro de una transacción de base de datos.
- [ ] El worker implementa concurrencia segura, reintentos, backoff,
  idempotencia y estado `DeadLetter`.
- [ ] Las plantillas usan Razor `.cshtml`, modelos tipados, layout de correo y
  alternativa de texto plano.
- [ ] Las vistas Razor se renderizan fuera del contexto HTTP y se compilan al
  publicar.
- [ ] El catálogo vincula identificador y versión a archivos y modelos aprobados;
  no acepta rutas ni tipos arbitrarios durante la deserialización.
- [ ] Las versiones y sus dependencias son inmutables y se conservan mientras
  existan mensajes que puedan procesarse o recuperarse.
- [ ] Los reintentos conservan proveedor, remitente, contenido y clave; un cambio
  de contenido se detecta antes de repetir la llamada al proveedor.
- [ ] `Sent` indica aceptación del proveedor; entregas y rebotes se registran
  separadamente, cuando estén disponibles.
- [ ] Ninguna plantilla usa `Html.Raw` con contenido no confiable.
- [ ] Webhooks, si existen, verifican autenticidad y son idempotentes.
- [ ] Las pruebas usan un emisor falso y cubren fallos, reintentos, concurrencia,
  deduplicación local y fallos entre aceptación del proveedor y guardado de `Sent`.
- [ ] Se documentan los límites de deduplicación del proveedor y la política
  ante resultados inciertos; no se promete entrega exactamente una vez.
- [ ] Modelos y destinatarios persistidos tienen protección y retención definidas.
- [ ] Logs y métricas no exponen el cuerpo del mensaje ni datos secretos.

<a id="tema-calidad"></a>

### Calidad

Guías de referencia: [Estrategia de pruebas](pruebas.md) · [Integración continua](integracion-continua.md) · [Logging y observabilidad](../operacion/observabilidad.md) · [Convenciones de código y tipos de datos](../desarrollo/convenciones-codigo.md) · [Localización de calendarios](../interfaz/localizacion-calendarios.md).

- [ ] Todos los datos que representan solo fecha usan DateOnly o DateOnly?,
  incluidos entidades, contratos, mensajes CQRS, Results y filtros; JSON usa
  yyyy-MM-dd y la persistencia un tipo fecha sin hora, sin conversiones de zona.
- [ ] Los calendarios y selectores de fecha de Web y móvil muestran meses, días,
  botones, mensajes y etiquetas de accesibilidad en español con configuración
  regional explícita; las fechas HTTP mantienen ISO 8601.
- [ ] Build sin warnings.
- [ ] Pruebas exitosas.
- [ ] Migraciones revisadas.
- [ ] Serilog registra solicitudes y errores con propiedades estructuradas.
- [ ] El TraceId W3C coincide en logs, span HTTP, ApiErrorResponse y X-Trace-Id;
  éxitos/sesión se correlacionan por header y RequestId permanece separado.
- [ ] OpenTelemetry exporta trazas y métricas con identidad del servicio y
  configuración por ambiente; Serilog no duplica la exportación de logs.
- [ ] Las llamadas salientes propagan contexto y los intentos del Outbox tienen
  spans propios enlazados al contexto de origen, sin baggage sensible.
- [ ] Existen métricas HTTP, casos de uso, dependencias y runtime; el Outbox
  incluye acumulación, antigüedad, fallos y DeadLetter cuando aplica.
- [ ] Las etiquetas de métricas tienen cardinalidad acotada y no contienen IDs,
  rutas concretas, datos personales ni mensajes de excepción.
- [ ] `/health/live` no consulta dependencias externas; `/health/ready` comprueba
  inicio, drenaje y dependencias críticas con timeout y cancelación.
- [ ] Las probes usan acceso operativo restringido y estado mínimo sin envelope
  ni detalles internos; readiness no saludable devuelve `503`.
- [ ] La caída del collector no bloquea negocio ni falla readiness; se observan
  colas acotadas, errores y descartes de exportación.
- [ ] Muestreo, retención, dashboards, objetivos y alertas tienen responsables y
  decisiones registradas; las pruebas cubren correlación y fallos de probes.
- [ ] No se registran secretos, tokens ni contraseñas.
- [ ] Dependencias sin vulnerabilidades críticas conocidas.
- [ ] Logs sin secretos ni datos personales innecesarios.
