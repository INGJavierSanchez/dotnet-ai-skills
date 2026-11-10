# .NET AI Skills

Skill reutilizable para orientar a agentes de IA al implementar y revisar APIs
empresariales .NET. Incluye una entrada principal, `dotnet-ai-skills`, y
referencias temáticas de arquitectura, desarrollo, seguridad, operación,
calidad e interfaz. La base para proyectos nuevos es .NET 10.

## Qué incluye

- [SKILL.md](SKILL.md): cuándo aplicar la skill, cómo abordar una tarea y qué
  referencias cargar según el trabajo solicitado.
- [docs/](docs/README.md): reglas y ejemplos mantenidos como una única fuente.
- [Adopción del proyecto](docs/adopcion-del-proyecto.md): decisiones que deben
  completarse al aplicar la base técnica.
- [Lista de aceptación](docs/calidad/lista-aceptacion.md): criterios para revisar
  el resultado sin cargar todos los detalles en cada tarea.

El repositorio se instala como una skill principal con referencias por tema:

```text
dotnet-ai-skills/
├── SKILL.md
├── agents/openai.yaml
└── docs/
    ├── arquitectura/
    ├── desarrollo/
    ├── seguridad/
    ├── operacion/
    ├── calidad/
    └── interfaz/
```

## Uso con un agente de IA

Clona o descarga el repositorio completo:

```bash
git clone https://github.com/joseriospacheco/dotnet-ai-skills.git
```

Registra la carpeta completa como skill según el mecanismo de tu agente.
Si el agente admite invocación por nombre, después de registrarla puedes pedir:

```text
Usa $dotnet-ai-skills para implementar el alta de un recurso en este proyecto.
Conserva sus versiones y aplica las convenciones a los archivos afectados.
```

También puedes indicarle directamente que lea el archivo:

```text
Lee SKILL.md de dotnet-ai-skills y las referencias necesarias para revisar
las entidades, sus factories y los mapeos de esta funcionalidad.
Entrega hallazgos antes de modificar código.
```

Mantén `SKILL.md` y `docs/` juntos al instalar o copiar la skill. El archivo de
entrada carga referencias de forma progresiva: no hace falta adjuntar todas
las guías en cada petición. La instalación no se realiza por clonar el repo;
depende del registro de skills de la herramienta utilizada.

### Comprobar la instalación

Desde la raíz del repositorio, ejecuta:

```powershell
pwsh ./scripts/validate-repository.ps1
```

La comprobación valida la estructura mínima y los enlaces relativos de Markdown.
No requiere restaurar paquetes ni conexión de red.

Conserva `SKILL.md`, `README.md`, `agents/openai.yaml`, `docs/` y `scripts/` al
copiar la skill a otra ubicación.

## Alcance

En proyectos nuevos, completa la adopción antes de implementar decisiones que
dependan del motor de datos, autenticación o despliegue. En proyectos existentes,
las instrucciones locales y las decisiones explícitas del usuario delimitan qué
convenciones se adoptan; una tarea pequeña no implica migrar todo el stack.

Los agentes pueden implementar funcionalidades, revisar cumplimiento y preparar
cambios usando estas referencias. Aplicar una skill no concede autorización
para desplegar, modificar datos de producción o publicar código.

## Compatibilidad

La base normativa está escrita para .NET 10. Antes de aplicar reglas dependientes
de plataforma, comprueba `TargetFramework`, el SDK, `Directory.Packages.props` y
los paquetes relevantes del proyecto.

| Proyecto | Tratamiento |
| --- | --- |
| .NET 10 | Aplicar la base directamente y fijar versiones en la adopción. |
| .NET 8 o .NET 9 | Aplicar principios y contratos; adaptar APIs incompatibles y documentar la desviación. |
| Otra versión o framework | No asumir compatibilidad: presentar el impacto y pedir confirmación antes de migrar. |

Una diferencia de versión no autoriza actualizar el framework como parte de una
tarea funcional. Registra una ADR cuando la adaptación cambie una convención,
un contrato público o una garantía operativa.

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

Mantén los criterios de selección y el flujo de trabajo en `SKILL.md`. Actualiza
cada regla detallada en su guía propietaria dentro de `docs/`, sin duplicarla
en otra skill. Documenta excepciones mediante ADR y revisa enlaces y ejemplos
al cambiar contratos.

Los fragmentos de código de las referencias son ejemplos; los resultados de
compilación y pruebas deben verificarse en el proyecto donde se apliquen.
