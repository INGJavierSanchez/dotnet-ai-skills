# Referencias de .NET AI Skills

Referencias de la skill [dotnet-ai-skills](../SKILL.md) para APIs .NET 10 y sus
clientes. Se organizan por responsabilidad; cada regla tiene una guía propietaria.
Las guías conservan los requisitos normativos y ejemplos de la especificación
original. El flujo de trabajo para agentes y la selección de referencias están
en SKILL.md; este índice también permite consultar las guías directamente.

## Cómo utilizar estas guías

1. Completar [la adopción y las decisiones del proyecto](adopcion-del-proyecto.md).
2. Leer [los fundamentos de arquitectura](arquitectura/fundamentos.md) y las guías de las áreas que se implementen.
3. Comprobar [la lista de aceptación](calidad/lista-aceptacion.md).
4. Registrar las desviaciones mediante ADR según la guía de adopción.

Las guías de arquitectura definen responsabilidades y dependencias. Desarrollo establece convenciones; seguridad fija controles; operación define configuración y despliegue; calidad organiza verificaciones; interfaz define presentación. Las decisiones concretas del proyecto se completan en adopción, sin modificar la base reutilizable.

## Rutas rápidas

| Necesidad | Orden recomendado |
| --- | --- |
| Crear una API o funcionalidad nueva | [Adopción](adopcion-del-proyecto.md) → [fundamentos](arquitectura/fundamentos.md) → [Application/CQRS](arquitectura/application-cqrs.md) → [API HTTP](arquitectura/api-http.md) → [pruebas](calidad/pruebas.md). |
| Revisar una funcionalidad existente | [fundamentos](arquitectura/fundamentos.md) → guía de la responsabilidad afectada → [lista de aceptación](calidad/lista-aceptacion.md). |
| Cambiar contratos HTTP u OpenAPI | [API HTTP](arquitectura/api-http.md) → [respuestas](arquitectura/respuestas-api.md) → [errores](arquitectura/errores-http.md) → [mapeo](arquitectura/contratos-y-mapeo.md). |
| Cambiar persistencia o migraciones | [persistencia](arquitectura/persistencia-y-consultas.md) → [Unit of Work](arquitectura/unit-of-work.md) → [migraciones](operacion/migraciones-inicializacion.md) → [pruebas](calidad/pruebas.md). |
| Cambiar seguridad o multiempresa | [autenticación](seguridad/autenticacion-autorizacion.md) → [seguridad mínima](seguridad/seguridad-y-multiempresa.md) → [mensajes públicos](seguridad/mensajes-publicos.md). |
| Preparar CI y operación | [integración continua](calidad/integracion-continua.md) → [configuración](operacion/configuracion.md) → [observabilidad](operacion/observabilidad.md) → [aceptación](calidad/lista-aceptacion.md). |

La matriz no reemplaza las instrucciones locales ni la comprobación de versiones
descrita en [README](../README.md#compatibilidad).

## Regla de mantenimiento

Actualizar una regla en su guía propietaria y enlazarla desde las demás. La lista de aceptación resume requisitos y enlaza sus fuentes; no sustituye el texto normativo. Los fragmentos de código conservados son ejemplos y no equivalen a una aplicación compilada.

## Arquitectura

| Guía | Contenido |
| --- | --- |
| [Fundamentos y estructura de la solución](arquitectura/fundamentos.md) | Define capas, referencias permitidas y el flujo de una solicitud. |
| [Modelo de dominio](arquitectura/dominio.md) | Define las responsabilidades de Domain, sus entidades, invariantes y excepciones. |
| [Application, CQRS y validación](arquitectura/application-cqrs.md) | Define los casos de uso, la colaboración entre handlers y la validación de entradas. |
| [Contratos y mapeo entre capas](arquitectura/contratos-y-mapeo.md) | Define la frontera de los contratos HTTP, los Results y la propiedad de los mapeos Mapster. |
| [Composición e inyección de dependencias](arquitectura/composicion-y-dependencias.md) | Define el registro de servicios y sus límites de composición. |
| [Persistencia y consultas](arquitectura/persistencia-y-consultas.md) | Define el repositorio genérico, QueryServices, seguimiento y proyecciones. |
| [Unit of Work y transacciones](arquitectura/unit-of-work.md) | Define el contrato y las responsabilidades transaccionales. |
| [API HTTP y OpenAPI](arquitectura/api-http.md) | Define endpoints, baja de recursos inmutables, envelopes y documentación HTTP. |
| [Respuestas estandarizadas del API](arquitectura/respuestas-api.md) | Define éxitos, errores, códigos, validación, sesión y consumo del frontend. |
| [Manejo de errores HTTP](arquitectura/errores-http.md) | Define el manejador central y su traducción de excepciones al envelope de error. |
| [Correo y Outbox](arquitectura/correo-y-outbox.md) | Define contratos, responsabilidades y la entrega desacoplada de correo. |

## Desarrollo

| Guía | Contenido |
| --- | --- |
| [Convenciones de código y tipos de datos](desarrollo/convenciones-codigo.md) | Define idioma, archivos, herencia de entidades, orden de miembros, namespaces, fechas y sintaxis LINQ. |
| [Utilidades para enumeraciones](desarrollo/enumeraciones.md) | Define la ubicación y el comportamiento de las conversiones y etiquetas de enums. |

## Seguridad

| Guía | Contenido |
| --- | --- |
| [Autenticación y autorización](seguridad/autenticacion-autorizacion.md) | Define cookies para Angular Web, JWT para móvil, antiforgery y políticas comunes. |
| [Seguridad mínima y multiempresa](seguridad/seguridad-y-multiempresa.md) | Define controles transversales y aislamiento por tenant. |
| [Mensajes públicos de errores](seguridad/mensajes-publicos.md) | Define el catálogo seguro de errores y su separación de los mensajes de diagnóstico. |

## Operación

| Guía | Contenido |
| --- | --- |
| [Configuración mediante Options](operacion/configuracion.md) | Define cómo enlazar, validar y consumir configuración y secretos. |
| [Logging y observabilidad](operacion/observabilidad.md) | Define correlación, logs, trazas, métricas, probes y alertas. |
| [Migraciones e inicialización de base de datos](operacion/migraciones-inicializacion.md) | Define aprovisionamiento, inicialización, seeders, exclusividad y diagnóstico de despliegue. |
| [Configuración y operación del correo](operacion/entrega-correo.md) | Define configuración de proveedores, garantías de entrega y recuperación de reintentos. |

## Calidad

| Guía | Contenido |
| --- | --- |
| [Estrategia de pruebas](calidad/pruebas.md) | Define cobertura por capa y escenarios de inicialización de base de datos. |
| [Integración continua](calidad/integracion-continua.md) | Define comprobaciones y artefactos de la canalización. |
| [Lista de aceptación](calidad/lista-aceptacion.md) | Permite comprobar la adopción de las guías. Cada grupo enlaza sus fuentes normativas. |

## Interfaz

| Guía | Contenido |
| --- | --- |
| [Localización de calendarios](interfaz/localizacion-calendarios.md) | Define los requisitos de presentación en español para Web y móvil. |

## Adopción y navegación desde el documento anterior

- [Adopción, plataforma, decisiones y ADR](adopcion-del-proyecto.md).
- [Correspondencia con las secciones originales](mapa-documentacion.md).
