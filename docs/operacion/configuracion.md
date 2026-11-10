# Configuración mediante Options

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define cómo enlazar, validar y consumir configuración y secretos.

<a id="s21"></a>

## Configuración

La configuración de la aplicación DEBE leerse mediante el patrón Options, con
clases tipadas por sección y validación al inicio. Handlers, servicios,
repositorios, adaptadores y Workers consumen esas opciones mediante DI; NO
inyectan `IConfiguration` ni leen directamente `appsettings`, variables de
entorno o secretos. Tampoco utilizan claves de texto dispersas con
`configuration["..."]`, `GetValue` o `GetSection` para obtener valores de negocio
o de integración.

La lectura de `IConfiguration` se limita a la raíz de composición (`Program.cs`
y extensiones de registro) para enlazar secciones a Options y configurar el
host, proveedores y librerías que requieran esa API. Esta excepción no autoriza
trasladar lecturas directas a las implementaciones de servicios.

Selección de la interfaz de consumo:

- `IOptions<T>` para configuración estable durante la vida del proceso;
- `IOptionsSnapshot<T>` para obtener opciones por scope cuando se requiere
  actualización entre scopes; no se inyecta en singletons;
- `IOptionsMonitor<T>` para componentes, incluidos singletons y Workers, que
  deban observar cambios de configuración. La recarga requiere soporte de la
  fuente y una política explícita de validación y aplicación de cambios.

Las clases Options DEBEN declarar el nombre de sección de forma centralizada,
validar los valores obligatorios, rangos y dependencias entre campos, y usar
`ValidateOnStart()`. `ValidateDataAnnotations()` cubre las anotaciones; las
reglas adicionales se implementan con validadores de Options. La configuración
inválida impide iniciar el componente habilitado, sin exponer secretos en los
errores. Un servicio deshabilitado no exige credenciales de un proveedor que no
utiliza. Ninguna clase Options contiene reglas de negocio del dominio.

Ejemplo de registro:

```csharp
builder.Services
    .AddOptions<JwtOptions>()
    .BindConfiguration(JwtOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

Fuentes, de menor a mayor precedencia:

1. `appsettings.json`;
2. `appsettings.{Environment}.json`;
3. User Secrets en desarrollo;
4. variables de entorno;
5. almacén de secretos del entorno.

Las cadenas de conexión, claves JWT y credenciales NO se versionan.
