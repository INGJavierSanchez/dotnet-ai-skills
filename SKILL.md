---
name: dotnet-ai-skills
description: "Implementar o revisar APIs .NET con las convenciones de este repositorio: entidades y factories, CQRS, EF Core, contratos HTTP, seguridad y operación. Usar al adoptar esta base técnica, crear funcionalidades o revisar su cumplimiento; no aplica a tareas de IA ajenas a .NET ni a cambios exclusivos de diseño visual."
---

# Desarrollo .NET con agentes de IA

Implementa la tarea solicitada usando las reglas técnicas de este paquete.
`docs/` contiene las referencias mantenidas; carga solo las que correspondan al
trabajo actual. La skill y sus referencias deben permanecer en la misma carpeta.

## Contexto y alcance

1. Revisa las instrucciones locales del proyecto, los archivos afectados,
   `.csproj`, versiones centrales y registros de DI antes de editar código.
   Identifica motor relacional, proveedor EF Core y contratos HTTP existentes.
2. En un proyecto nuevo, usa [adopción del proyecto](docs/adopcion-del-proyecto.md)
   para completar las decisiones necesarias. Los nombres entre corchetes de los
   ejemplos son marcadores: reemplázalos con los del proyecto real.
3. En un proyecto existente, determina si ya adoptó esta base o qué parte quiere
   adoptar el usuario. Una petición acotada no implica migrar librerías,
   reorganizar todo el repositorio ni reemplazar contratos públicos.
4. Respeta las decisiones explícitas del usuario y las instrucciones aplicables
   del proyecto. Si una diferencia afecta la tarea, señala su consecuencia y
   documenta la decisión con el mecanismo del proyecto. Pregunta solo si falta
   una decisión que cambia el resultado y no puede inferirse del contexto.

## Elegir referencias

Selecciona por responsabilidad, no por coincidencia aislada de palabras. Usa el
[índice](docs/README.md) para localizar detalles; no leas todas las guías para
resolver una tarea pequeña.

| Trabajo solicitado | Referencias que debes consultar |
| --- | --- |
| Iniciar una solución o cambiar dependencias entre capas | [Fundamentos](docs/arquitectura/fundamentos.md), [adopción](docs/adopcion-del-proyecto.md) y [composición](docs/arquitectura/composicion-y-dependencias.md). |
| Crear o modificar entidades, herencia o enums | [Dominio](docs/arquitectura/dominio.md), [convenciones](docs/desarrollo/convenciones-codigo.md); [enumeraciones](docs/desarrollo/enumeraciones.md) para conversiones y presentación. |
| Implementar Commands, Queries, handlers o validación | [Application y CQRS](docs/arquitectura/application-cqrs.md), más las referencias de dominio o persistencia que utilice el caso de uso. |
| Implementar consultas, repositorios o proyecciones EF Core | [Persistencia](docs/arquitectura/persistencia-y-consultas.md), [mapeo](docs/arquitectura/contratos-y-mapeo.md) y [Unit of Work](docs/arquitectura/unit-of-work.md). |
| Crear endpoints, DTO o cambiar respuestas | [API HTTP](docs/arquitectura/api-http.md), [respuestas](docs/arquitectura/respuestas-api.md), [errores](docs/arquitectura/errores-http.md) y [mapeo](docs/arquitectura/contratos-y-mapeo.md). |
| Autenticar usuarios, autorizar o aislar empresas | [Autenticación](docs/seguridad/autenticacion-autorizacion.md), [seguridad y multiempresa](docs/seguridad/seguridad-y-multiempresa.md); [mensajes públicos](docs/seguridad/mensajes-publicos.md) para textos de errores. |
| Configurar servicios, Workers, logs o probes | [Options](docs/operacion/configuracion.md) y [observabilidad](docs/operacion/observabilidad.md). |
| Preparar una base, migraciones o seeders | [Migraciones e inicialización](docs/operacion/migraciones-inicializacion.md), [Options](docs/operacion/configuracion.md) y [Unit of Work](docs/arquitectura/unit-of-work.md). |
| Enviar notificaciones por correo | [Correo y Outbox](docs/arquitectura/correo-y-outbox.md) y [operación de correo](docs/operacion/entrega-correo.md). |
| Modificar calendarios de los clientes Web o móvil | [Localización](docs/interfaz/localizacion-calendarios.md) y [tipos de fecha](docs/desarrollo/convenciones-codigo.md#tema-fechas-sin-componente-de-hora). |
| Añadir pruebas, configurar CI o revisar cumplimiento | [Pruebas](docs/calidad/pruebas.md), [CI](docs/calidad/integracion-continua.md) y los apartados relevantes de [aceptación](docs/calidad/lista-aceptacion.md). |
| Actualizar dependencias o cambiar de versión de .NET | [Adopción](docs/adopcion-del-proyecto.md), [fundamentos](docs/arquitectura/fundamentos.md) y [composición](docs/arquitectura/composicion-y-dependencias.md); comprobar `TargetFramework` y versiones centrales. |
| Cambiar autenticación, sesión o aislamiento | [Autenticación](docs/seguridad/autenticacion-autorizacion.md), [seguridad y multiempresa](docs/seguridad/seguridad-y-multiempresa.md), [mensajes públicos](docs/seguridad/mensajes-publicos.md) y [respuestas](docs/arquitectura/respuestas-api.md). |
| Cambiar OpenAPI o contratos HTTP | [API HTTP](docs/arquitectura/api-http.md), [respuestas](docs/arquitectura/respuestas-api.md), [errores](docs/arquitectura/errores-http.md) y [mapeo](docs/arquitectura/contratos-y-mapeo.md). |
| Revisar rendimiento o consultas | [Persistencia](docs/arquitectura/persistencia-y-consultas.md), [observabilidad](docs/operacion/observabilidad.md) y [pruebas](docs/calidad/pruebas.md). |
| Cambiar CI, despliegue o telemetría | [CI](docs/calidad/integracion-continua.md), [observabilidad](docs/operacion/observabilidad.md), [configuración](docs/operacion/configuracion.md) y [migraciones](docs/operacion/migraciones-inicializacion.md). |

## Flujo de trabajo y entrega

1. **Descubrir:** lee instrucciones locales, identifica `TargetFramework`, SDK,
   paquetes, proveedor de datos y archivos afectados.
2. **Decidir:** distingue convenciones adoptadas, desviaciones y decisiones
   pendientes; no actualices dependencias por inferencia.
3. **Planificar:** selecciona las referencias aplicables y resume el plan antes
   de editar cuando el cambio abarque varias capas.
4. **Implementar o revisar:** en una revisión no modifiques archivos salvo que se
   solicite explícitamente.
5. **Verificar:** ejecuta las pruebas y comprobaciones que permita el proyecto;
   separa resultados ejecutados de pendientes.
6. **Entregar:** informa archivos modificados, evidencia, riesgos y supuestos.

## Aplicar la base técnica

Cuando el proyecto haya adoptado estas convenciones, protege estos límites:

- **Domain:** las factories públicas crean entidades válidas; los constructores
  son privados en entidades finales y protegidos cuando lo requiere la herencia.
  La hija inicializa la parte heredada con `base(...)`, sin crear otro objeto ni
  duplicar campos. Valida enums ordinarios con `Enum.IsDefined`; Flags requiere
  su propia comprobación. Las modificaciones pasan por métodos de dominio.
- **Application:** todos los handlers CQRS permanecen en esta capa. Command y
  handler comparten archivo; Query y handler comparten archivo. Cada Result,
  incluidos records auxiliares, conserva un archivo independiente en Results.
  El handler orquesta; no reemplaza las invariantes de Domain ni llama a EF Core.
- **Persistencia:** usa el repositorio genérico y QueryServices según sus
  contratos. Infrastructure materializa las consultas y proyecta con Mapster
  antes de cargar resultados; no expone IQueryable a Application. Identifica
  quién guarda antes de añadir transacciones; no introduzcas guardados duplicados
  ni commits parciales entre handler y behavior.
- **Mapeo:** API adapta Request a mensaje CQRS y Result a Response. La factory,
  llamada explícitamente por el caso de uso, crea la entidad. Mapster no
  sobrescribe su estado ni oculta esa creación. Respeta la configuración
  explícita compartida por host y la propiedad de cada mapeo.
- **Contratos HTTP:** los éxitos con contenido tienen success, message y data,
  sin code. Los errores tienen success=false, code, message, errors y traceId.
  Respeta las excepciones de sesión, HEAD/204 y probes. No restaures el anterior
  envelope de Problem Details ni códigos de éxito eliminados de estas guías.
- **Configuración y seguridad:** consume Options tipadas; limita IConfiguration
  a la composición. Conserva cookie HttpOnly y antiforgery para Web y JWT Bearer
  para móvil cuando ambos clientes estén habilitados. Nunca tomes identidad o
  tenant de datos no validados ni expongas Exception.Message en respuestas.
- **Efectos y operación:** usa Outbox para correo de negocio, con la intención
  en la misma transacción que los cambios. No hagas llamadas externas dentro
  de la transacción ni ejecutes migraciones simultáneas desde las réplicas.
- **Código y fechas:** usa namespaces con ámbito de archivo, miembros de negocio
  en español y roles técnicos en inglés. Usa DateOnly para fechas sin hora;
  conserva hora local e instante con zona como conceptos distintos.

Estas reglas orientan la implementación; no autorizan cambios en una base real,
un despliegue o la publicación de código. Usa las herramientas disponibles y
la autorización de la tarea. Una referencia a un paquete o un método propio en
un ejemplo no demuestra que exista en el proyecto: compruébalo antes de usarlo.

## Comprobar y entregar

- Revisa la [lista de aceptación](docs/calidad/lista-aceptacion.md) solo en los
  apartados afectados. Si la petición es una revisión, entrega hallazgos con
  ubicación, efecto y corrección propuesta; no modifiques código sin encargo.
- Para cambios de código, ejecuta las comprobaciones y pruebas pertinentes que
  permita el proyecto. Para consultas y migraciones, verifica el proveedor real;
  EF InMemory no demuestra traducción SQL, integridad, permisos o bloqueos.
- Si modificas solo documentación, comprueba referencias, ejemplos y consistencia
  del contrato. No presentes fragmentos documentales como implementación compilada.
- Informa qué cambió, qué se verificó y qué sigue sin comprobarse. No atribuyas
  un fallo de despliegue a una causa que no esté respaldada por evidencia.
