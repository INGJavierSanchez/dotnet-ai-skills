# Guías técnicas para proyectos .NET

Especificaciones reutilizables para APIs empresariales con .NET 10 y sus clientes
Web y móviles. Las guías incluyen reglas normativas, ejemplos de código y una
lista de aceptación para adoptar la base técnica en cada proyecto.

## Empezar

1. Consultar el [índice de documentación](docs/README.md).
2. Completar la [adopción y las decisiones del proyecto](docs/adopcion-del-proyecto.md).
3. Revisar la [lista de aceptación](docs/calidad/lista-aceptacion.md).

## Áreas

| Área | Guía de entrada |
| --- | --- |
| Arquitectura | [Capas, dependencias y estructura](docs/arquitectura/fundamentos.md) |
| Desarrollo | [Convenciones de código y tipos](docs/desarrollo/convenciones-codigo.md) |
| Seguridad | [Autenticación y autorización](docs/seguridad/autenticacion-autorizacion.md) |
| Operación | [Configuración](docs/operacion/configuracion.md), [observabilidad](docs/operacion/observabilidad.md) y [migraciones](docs/operacion/migraciones-inicializacion.md) |
| Calidad | [Pruebas](docs/calidad/pruebas.md) e [integración continua](docs/calidad/integracion-continua.md) |
| Interfaz | [Localización de calendarios](docs/interfaz/localizacion-calendarios.md) |

El [documento de entrada original](ESPECIFICACION_BASE_ARQUITECTURA_DOTNET.md)
conserva su ruta. El [mapa de documentación](docs/mapa-documentacion.md) permite
ubicar las secciones anteriores a la reorganización.

## Mantener las guías

Actualizar cada regla en su guía propietaria y enlazarla desde las demás.
Documentar excepciones mediante ADR. Los fragmentos de código son ejemplos de
arquitectura y no constituyen una aplicación ejecutable por sí solos.
