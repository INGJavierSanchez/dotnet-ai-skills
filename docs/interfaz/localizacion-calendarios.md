# Localización de calendarios

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define los requisitos de presentación en español para Web y móvil.

<a id="tema-calendarios-en-espanol"></a>

## Calendarios en español

Todos los calendarios y selectores de fecha visibles al usuario, incluidos los
de Angular Web y la app móvil, DEBEN presentarse en español. Esto incluye nombres
de meses, días de la semana, abreviaturas, encabezados, botones como «Hoy»,
«Aceptar» y «Cancelar», mensajes de validación y etiquetas de accesibilidad.

La configuración regional se establece explícitamente en el cliente y en el
componente de calendario; no se depende del idioma del navegador o del sistema
operativo para garantizar el español. El proyecto define una variante regional
española, por ejemplo `es-CO`, y aplica de forma coherente el formato de fecha y
el primer día de la semana correspondiente. Los componentes nativos cuya
presentación dependa del sistema deben verificarse; si no permiten asegurar
el idioma requerido, se utiliza un componente que permita configurarlo.

La localización es una regla de presentación: los contratos HTTP conservan ISO
8601 y no envían nombres de meses ni fechas en formato regional como valores de
fecha. Una fecha de calendario sin hora conserva su semántica de `DateOnly`;
los instantes se presentan según la zona horaria definida por el proyecto, sin
cambiar de día accidentalmente por una conversión de zona horaria.


## Guías relacionadas

- [Convenciones de código y tipos de datos](../desarrollo/convenciones-codigo.md)
