# Estrategia de pruebas

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define cobertura por capa y escenarios de inicialización de base de datos.

<a id="s24"></a>

## Pruebas

<a id="tema-domain"></a>

### Domain

- invariantes de entidades;
- factories de bases concretas e hijas: tipos devueltos, inicialización de
  propiedades heredadas, identificador compartido y rechazo de datos inválidos
  de la base y de la entidad hija;
- value objects;
- reglas puras.

<a id="tema-application"></a>

### Application

- validators;
- handlers;
- behaviors;
- mapeos en memoria propios de Application y handlers con servicios de lectura
  falsos que devuelven Results materializados;
- uso correcto de Unit of Work;
- encolado de intención mediante `IEmailOutbox`, selección de plantilla y
  categoría aprobadas, y modelo suficiente sin invocar un proveedor real.

<a id="tema-infrastructure"></a>

### Infrastructure

- configuraciones EF Core;
- materialización de jerarquías con los constructores no públicos y la
  estrategia de herencia configurada, conservando las claves heredadas;
- configuraciones de proyección Mapster y consultas que seleccionan solo las
  columnas consumidas, con filtros, orden estable y paginación;
- índices y restricciones;
- consultas del proveedor real;
- migraciones;
- commit y rollback;
- concurrencia;
- selección del adaptador de correo, reintentos, idempotencia y procesamiento
  concurrente del Outbox;
- atomicidad entre cambios de negocio y registro de Outbox, recuperación de
  bloqueos y rechazo de actualizaciones de un Worker que perdió la propiedad;
- renderizado de versiones antiguas tras un despliegue, deserialización segura,
  remitentes aprobados y estabilidad del contenido entre reintentos;
- resultado incierto después de aceptación del proveedor y antes de guardar
  `Sent`, incluyendo el riesgo de duplicados sin deduplicación nativa.

<a id="tema-api"></a>

### API

- autenticación y autorización;
- descubrimiento y mapeo de módulos Carter;
- contratos HTTP;
- mapeos Request a mensajes CQRS y Results a Responses usando el `IMapper`
  registrado; composición única de configuraciones sin parejas duplicadas;
- errores ApiErrorResponse para excepciones, JSON/binding, validación, 401/403
  y estados sin cuerpo, con códigos y campos JSON públicos;
- serialización de errors:null, ausencia de cuerpos en HEAD/204 y conservación
  de estados y headers de protocolo; respuestas sin datos internos ni de otros tenants;
- envelopes ApiSuccessResponse<T>, paginación, Location y 204 sin cuerpo;
- ausencia de code en respuestas exitosas y presencia del código estable en
  errores, con las excepciones de formato documentadas;
- excepción de POST /api/sesion: respuesta directa, cookie para Web y JWT para
  móvil, rechazos genéricos sin revelar cuenta o empresa;
- mapeo de excepciones mediante el `IExceptionHandler` central;
- eventos estructurados de Serilog sin datos sensibles;
- serialización de records;
- OpenAPI;
- correlación W3C entre respuestas, logs y trazas, con propagación HTTP;
- health checks separados: `live` sin dependencias externas y `ready` sensible
  a inicialización, drenaje y disponibilidad de dependencias críticas;
- continuidad del servicio ante fallo del exportador y exclusión de datos
  sensibles y etiquetas de alta cardinalidad de la telemetría.

Las pruebas de persistencia crítica deben ejecutarse contra el mismo motor usado
en producción, preferiblemente mediante contenedores efímeros.


<a id="tema-pruebas-de-aceptacion-de-inicializacion"></a>

## Pruebas de aceptación de inicialización

Las pruebas automatizadas usan el motor relacional real o una instancia efímera
equivalente al destino. No se usa EF InMemory para probar migraciones, permisos
o bloqueos. DEBEN cubrir:

- inicialización deshabilitada sin resolver/abrir contexto ni ejecutar seeders;
- base inexistente con creación autorizada y con creación prohibida;
- base existente vacía sin migraciones aplicadas;
- base con migraciones pendientes y base completamente actualizada;
- esquema pendiente con ApplyMigrations=false, sin ejecutar seeders;
- repetición de seeders sin duplicados, preservación de datos operativos y
  orden determinista de ejecución;
- fallo de un seeder, rollback de siembra y recuperación tras reinicio;
- credenciales inválidas y permisos insuficientes, sin clasificarlos como
  base inexistente ni intentar crearla por ese motivo;
- fallo/timeout de bloqueo de migración y respuesta nula del proveedor cuando
  aplique, sin continuar el arranque;
- múltiples instancias sin migración/siembra simultánea;
- fallo crítico antes de aceptar solicitudes y código de salida distinto de cero;
- configuración Production con CreateDatabase=true rechazada.
