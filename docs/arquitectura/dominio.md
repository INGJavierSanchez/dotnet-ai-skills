# Modelo de dominio

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define las responsabilidades de Domain, sus entidades, invariantes y excepciones.

<a id="s6"></a>

## Capa Domain

`[NombreProyecto].Domain` contiene el modelo y las reglas esenciales del
negocio.

Estructura mínima obligatoria:

```text
[NombreProyecto].Domain/
├── Entities/
│   ├── Usuario.cs
│   ├── Empresa.cs
│   └── Vehiculo.cs
├── Enums/
│   ├── RolUsuario.cs
│   └── EstadoCredencial.cs
├── ValueObjects/
├── Events/
├── Services/
└── Exceptions/
    └── DomainException.cs
```

Todas las entidades DEBEN estar directamente en la raíz de la carpeta
`Domain/Entities` y usar el namespace `[NombreProyecto].Domain.Entities`. No se
permiten subcarpetas dentro de `Entities`; por ejemplo, `Viaje.cs` debe ubicarse
en `Domain/Entities/Viaje.cs` y no en `Entities/Operaciones/Viaje.cs`.

Todas las enumeraciones DEBEN estar directamente en la raíz de `Domain/Enums` y
usar `[NombreProyecto].Domain.Enums`. No se permiten subcarpetas dentro de
`Enums`; por ejemplo, `EstadoViaje.cs` debe ubicarse en
`Domain/Enums/EstadoViaje.cs` y no en `Domain/Enums/Operaciones/EstadoViaje.cs`.

Cada entidad o enumeración pública se declara en su propio archivo con el mismo
nombre del tipo. Ninguna entidad puede quedar directamente en la raíz de Domain
ni fuera de `Entities`, y ninguna enumeración puede quedar fuera de `Enums`.


<a id="tema-excepcion-de-negocio"></a>

## Excepción de negocio

Domain DEBE declarar `DomainException` en
`Domain/Exceptions/DomainException.cs`, con namespace
`[NombreProyecto].Domain.Exceptions`. Es una clase del modelo de dominio para
representar una regla de negocio incumplida; no es una entidad persistente, no
se incluye en el `DbContext` y no se mapea como tabla de Entity Framework.

```csharp
namespace [NombreProyecto].Domain.Exceptions;

public class DomainException : Exception
{
    public DomainException(string message)
        : this("DOMAIN_RULE_VIOLATION", message)
    {
    }

    public DomainException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    public DomainException(
        string code,
        string message,
        Exception innerException)
        : base(message, innerException)
    {
        Code = code;
    }

    public string Code { get; }
}
```

`Code` DEBE ser estable, legible por máquina y no contener información
sensible. `Message` describe la regla para diagnóstico interno y NO constituye
un mensaje público aprobado. La API resuelve el mensaje público mediante un
catálogo explícito por `Code`, según la [guía de errores HTTP](errores-http.md#s17). Las excepciones de negocio
especializadas PUEDEN heredar de esta clase, pero no deben contener estado HTTP,
dependencias de ASP.NET Core ni lógica de persistencia.

Se lanza para reglas válidas del dominio que impiden completar una operación;
no se utiliza para errores de programación, fallos de infraestructura,
validación sintáctica de DTO ni control de flujo ordinario.

<a id="tema-reglas-de-negocio"></a>

## Reglas de negocio

La lógica de negocio propiamente dicha DEBE vivir principalmente en Domain:

- una regla que protege el estado de una entidad pertenece a un método de esa
  entidad;
- un concepto inmutable con validaciones propias pertenece a un value object;
- una regla pura que involucra varias entidades y no encaja naturalmente en una
  sola puede implementarse en un Domain Service dentro de `Domain/Services`;
- una violación de estas reglas lanza `DomainException` o una especialización;
- las invariantes se aplican siempre, independientemente de si el caso de uso
  viene de HTTP, un Worker, una prueba o cualquier otro adaptador.

Domain no consulta repositorios, no inicia transacciones, no envía correos y no
conoce DTO, handlers ni proveedores externos. Recibe los datos necesarios para
evaluar sus reglas y devuelve estado, valores o eventos de dominio.

Puede contener:

- entidades;
- value objects;
- enumeraciones;
- eventos de dominio;
- excepciones estrictamente del dominio;
- reglas e invariantes sin dependencias externas.

No debe contener:

- Entity Framework Core;
- endpoints o conceptos HTTP;
- DTO de API;
- configuración;
- acceso a archivos, red o base de datos;
- referencias a Infrastructure o Api.

Las entidades EF Core permanecen como clases. Los value objects inmutables
pueden implementarse como `readonly record struct` o `sealed record` según su
semántica.


<a id="tema-creacion-mediante-factories"></a>

## Creación de entidades mediante factories

Toda entidad concreta de Domain que se cree desde un caso de uso DEBE exponer
una factory estática en la propia entidad. Su nombre expresa la intención de
negocio en español, por ejemplo `Crear` o `Registrar`. La factory se declara en
el mismo archivo de la entidad y devuelve una instancia válida; una creación
inválida se rechaza con DomainException o una especialización.

Los constructores de entidades NO DEBEN ser públicos. Son privados cuando no
necesiten ser invocados desde clases derivadas y protegidos cuando la herencia
lo requiera. Las bases abstractas no necesitan una factory para instanciarse.
Los constructores sin parámetros requeridos para materialización EF Core
permanecen privados o protegidos según corresponda y no constituyen una entrada
de creación para casos de uso.

La validación puede residir en el constructor no público o en una rutina de
dominio reutilizada por la factory; todas las rutas de creación de negocio DEBEN
proteger las mismas invariantes, sin duplicar reglas. La factory no consulta la
base de datos, no resuelve servicios desde DI ni realiza llamadas externas;
Application obtiene los datos necesarios y coordina la persistencia.

Handlers, servicios de Application, seeders y pruebas que creen entidades de
negocio utilizan sus factories, por ejemplo `Recurso.Crear(nombre, valor, fecha)`.
La llamada directa a `new Recurso(...)` queda limitada a la implementación
interna de creación de Domain. Mapster no construye entidades ni invoca una vía
de materialización para evitar la factory. La materialización de registros
existentes por EF Core es una responsabilidad distinta y no ejecuta un caso de
uso de creación.

Esta convención aplica a entidades de negocio, no obliga a crear factories para
DTO, Commands, Queries, Results, Options, excepciones ni registros técnicos de
Infrastructure. Las actualizaciones de una entidad existente se realizan
mediante sus métodos de comportamiento y conservan la validación de invariantes.

<a id="tema-factories-y-herencia"></a>

### Factories y herencia

La visibilidad de los constructores se define según el papel de la entidad:

| Tipo de entidad | Constructor de negocio | Factory pública |
| --- | --- | --- |
| Base abstracta | `protected` cuando lo necesitan las hijas. | No se instancia directamente. |
| Base concreta que admite herencia | `protected` para inicializar las hijas. | Propia, si se crean instancias de la base como entidad de negocio. |
| Entidad final `sealed` | `private`. | Propia, que devuelve el tipo concreto. |

Una base NO DEBE convertirse en abstracta únicamente para aplicar esta regla.
Si el modelo admite instancias de la base sin perfil derivado, puede seguir
siendo concreta y exponer su factory. Por ejemplo, una cuenta de usuario sin
perfil y un estudiante son dos tipos de instancia distintos que se crean con
sus respectivas factories.

La factory de una hija invoca su constructor no público; ese constructor llama
al de la base mediante `base(...)`. La llamada inicializa la parte heredada del
mismo objeto, sin crear una segunda entidad ni duplicar su identificador. La
factory de la hija NO llama a la factory de la base para construir la parte
heredada: esa llamada devolvería otra instancia y no sustituye `base(...)`.

Los constructores sin parámetros de bases heredables son `protected` cuando
deben ser accesibles desde las hijas. Los de entidades `sealed` son `private`.
Un constructor sin parámetros de una hija llama implícitamente a `base()`;
por tanto, ese constructor base debe existir y ser accesible cuando se utilice
esta vía de materialización. La base `Entidad` también conserva constructores
compatibles con la cadena de herencia.

Las factories estáticas no son métodos virtuales ni se sobrescriben
polimórficamente. Cada entidad concreta define una entrada que devuelve su
propio tipo; se usan nombres de intención distintos cuando sea necesario para
evitar ocultamientos o llamadas ambiguas entre factories heredadas.

#### Ejemplo de base concreta y entidad hija

Ejemplo reducido de accesibilidad y creación: no sustituye las validaciones
completas de identidad y datos personales de un proyecto. Se usan nombres de
factory distintos para que el tipo de entidad creado sea explícito. Cada clase
se declara en su propio archivo y reutiliza el `Id` heredado de `Entidad`.

Archivo `Domain/Entities/Usuario.cs`:

```csharp
using [NombreProyecto].Domain.Exceptions;

namespace [NombreProyecto].Domain.Entities;

public class Usuario : Entidad
{
    public string Correo { get; private set; } = string.Empty;

    protected Usuario() { }

    protected Usuario(string correo)
    {
        if (string.IsNullOrWhiteSpace(correo))
        {
            throw new DomainException(
                "CORREO_REQUERIDO", "El correo es obligatorio.");
        }

        Correo = correo.Trim();
    }

    public static Usuario CrearUsuario(string correo) => new(correo);
}
```

Archivo `Domain/Entities/Estudiante.cs`:

```csharp
using [NombreProyecto].Domain.Exceptions;

namespace [NombreProyecto].Domain.Entities;

public sealed class Estudiante : Usuario
{
    public string Codigo { get; private set; } = string.Empty;

    private Estudiante() { }

    private Estudiante(string correo, string codigo)
        : base(correo)
    {
        if (string.IsNullOrWhiteSpace(codigo))
        {
            throw new DomainException(
                "CODIGO_REQUERIDO", "El código es obligatorio.");
        }

        Codigo = codigo.Trim();
    }

    public static Estudiante CrearEstudiante(string correo, string codigo) =>
        new(correo, codigo);
}
```

Las llamadas desde un caso de uso identifican la entidad que se necesita:

```csharp
var usuario = Usuario.CrearUsuario(correo);
var estudiante = Estudiante.CrearEstudiante(correo, codigo);
```

Son dos creaciones independientes para ilustrar ambas entradas; crear un
estudiante no requiere crear ni persistir previamente un Usuario separado.

```text
Estudiante.CrearEstudiante(correo, codigo)
  -> constructor privado de Estudiante
     -> constructor protegido de Usuario mediante base(correo)
        -> inicialización heredada de Entidad
```

El mapeo EF Core debe reflejar la estrategia de herencia elegida y comprobar
que la materialización reconstruye la jerarquía y conserva la clave heredada.
No se añade un identificador de la base redundante ni se usa Mapster para crear
la entidad hija. La asignación de valores de presentación sigue el
[flujo de mapeo con factory](contratos-y-mapeo.md#tema-ejemplo-mapeo-con-factory).

### Ejemplo de entidad con factory

Archivo `Domain/Entities/Recurso.cs`. La base `Entidad`, definida en la
[guía de persistencia](persistencia-y-consultas.md#tema-codigo-base-entidad-e-interfaz-generica),
aporta el identificador; la entidad no lo duplica. Las reglas de nombre, valor
y fecha de este ejemplo ilustran invariantes del recurso ficticio.

```csharp
using [NombreProyecto].Domain.Exceptions;

namespace [NombreProyecto].Domain.Entities;

public sealed class Recurso : Entidad
{
    public string Nombre { get; private set; } = string.Empty;
    public decimal Valor { get; private set; }
    public DateOnly Fecha { get; private set; }
    public bool Activo { get; private set; }

    private Recurso() { }

    private Recurso(string nombre, decimal valor, DateOnly fecha)
    {
        if (string.IsNullOrWhiteSpace(nombre) || nombre.Trim().Length > 150)
        {
            throw new DomainException(
                "NOMBRE_RECURSO_INVALIDO", "El nombre del recurso no es válido.");
        }

        if (valor < 0)
        {
            throw new DomainException(
                "VALOR_RECURSO_INVALIDO", "El valor del recurso no puede ser negativo.");
        }

        if (fecha == default)
        {
            throw new DomainException(
                "FECHA_RECURSO_INVALIDA", "La fecha del recurso es obligatoria.");
        }

        Nombre = nombre.Trim();
        Valor = valor;
        Fecha = fecha;
        Activo = true;
    }

    public static Recurso Crear(string nombre, decimal valor, DateOnly fecha) =>
        new(nombre, valor, fecha);
}
```

El constructor de negocio privado centraliza las validaciones. La factory
estática es la entrada pública de creación, y el constructor privado sin
parámetros se reserva para EF Core. Los códigos de error que deban exponerse
se incorporan al catálogo de [mensajes públicos](../seguridad/mensajes-publicos.md);
no se publica directamente el mensaje de la excepción.

<a id="tema-validacion-de-propiedades-enum"></a>

## Validación de propiedades enum

Toda propiedad de tipo enum DEBE validarse antes de asignarse en los
constructores o factories que crean la entidad y en los métodos que permitan
modificarla. Para enumeraciones ordinarias se utiliza `Enum.IsDefined(valor)`;
un valor no declarado se rechaza mediante `DomainException` con código estable.
Esta regla es general y no depende de una entidad o enumeración concreta.

Declarar una propiedad como enum no impide recibir valores numéricos que no
existen en la enumeración. El valor cero también se rechaza si no está declarado;
si está declarado, las reglas de negocio determinan si es admisible. Para una
propiedad nullable, `null` solo se permite cuando sea opcional y todo valor
presente se valida de la misma forma.

Los setters permanecen restringidos para que los cambios de negocio pasen por
los métodos que protegen la entidad. La comprobación puede centralizarse en un
método privado cuando se reutilice en creación y modificación; no necesita
repetirse en cada lectura. Si la propiedad es inmutable, se protege su creación.

Domain utiliza directamente la API de `System.Enum` y no depende de
`EnumExtensions` de Application. La validación de entrada en Application
complementa esta protección y no la sustituye. Comprobar que un valor está
definido tampoco sustituye las reglas de elegibilidad o de transición de estado.

Las enumeraciones `[Flags]` requieren validación específica de los bits y
combinaciones permitidos, incluido el cero según su semántica. No se aplica
`Enum.IsDefined` como único criterio para aceptar combinaciones válidas que no
tengan un nombre declarado. Las pruebas de dominio cubren creación y
modificación con valores válidos, desconocidos y cero, además de null y Flags
cuando correspondan.

## Guías relacionadas

- [Convenciones de código y tipos de datos](../desarrollo/convenciones-codigo.md)
- [Mensajes públicos de errores](../seguridad/mensajes-publicos.md)
