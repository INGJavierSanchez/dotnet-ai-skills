# Utilidades para enumeraciones

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define la ubicación y el comportamiento de las conversiones y etiquetas de enums.

<a id="tema-extensiones-para-enumeraciones"></a>

## Extensiones para enumeraciones

`EnumExtensions` es una utilidad de conversión y presentación, no una regla del
negocio. Por ello DEBE ubicarse en
`Application/Common/Extensions/EnumExtensions.cs`, con namespace
`[NombreProyecto].Application.Common.Extensions`. Domain no debe depender de
esta clase ni utilizar descripciones de presentación para tomar decisiones.

```csharp
using System.ComponentModel;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;

namespace [NombreProyecto].Application.Common.Extensions;

public static class EnumExtensions
{
    public static T[] ToArray<T>() where T : struct, Enum =>
        Enum.GetValues<T>();

    public static string ToStringValue<T>(this T value)
        where T : struct, Enum =>
        value.ToString();

    public static string GetDescription<T>(this T value)
        where T : struct, Enum
    {
        var field = value.GetType().GetField(value.ToString());
        var attribute = field?.GetCustomAttribute<DescriptionAttribute>();

        return attribute?.Description ?? ToTitleCase(value.ToString());
    }

    public static T ToEnum<T>(this string? value)
        where T : struct, Enum
    {
        if (TryParseDefined(value, out T result))
        {
            return result;
        }

        throw new ArgumentException(
            $"El valor '{value}' no existe en el Enum {typeof(T).Name}",
            nameof(value));
    }

    public static T? ToEnumOrDefault<T>(this string? value)
        where T : struct, Enum =>
        TryParseDefined(value, out T result) ? result : null;

    public static bool IsDefined<T>(this string? value)
        where T : struct, Enum =>
        TryParseDefined(value, out T _);

    private static bool TryParseDefined<T>(string? value, out T result)
        where T : struct, Enum
    {
        if (!string.IsNullOrWhiteSpace(value) &&
            Enum.TryParse(value, true, out result) &&
            Enum.IsDefined(result))
        {
            return true;
        }

        result = default;
        return false;
    }

    private static string ToTitleCase(string name)
    {
        if (string.IsNullOrEmpty(name))
        {
            return name;
        }

        var spaced = Regex.Replace(
            name.Replace('_', ' '),
            @"(?<=[a-z0-9])(?=[A-Z])",
            " ");

        var words = spaced.Split(
            [' '],
            StringSplitOptions.RemoveEmptyEntries);

        var result = new StringBuilder();

        for (var index = 0; index < words.Length; index++)
        {
            var lower = words[index].ToLowerInvariant();

            if (index > 0)
            {
                result.Append(' ');
            }

            result.Append(char.ToUpperInvariant(lower[0]));
            result.Append(lower.AsSpan(1));
        }

        return result.ToString();
    }
}
```

`ToEnum`, `ToEnumOrDefault` e `IsDefined` DEBEN comprobar tanto el parseo como
`Enum.IsDefined`. Para enumeraciones con `[Flags]` se requiere una implementación
específica y pruebas adicionales. Los enums de Domain NO DEBERÍAN incorporar
`DescriptionAttribute` únicamente para necesidades de interfaz. Si el sistema
requiere etiquetas localizadas o textos de presentación, estos se resuelven en
Application mediante recursos o un catálogo externo al modelo de dominio;
`GetDescription` conserva el nombre formateado como fallback.

La validación de propiedades enum al crear o modificar entidades se define en
[la guía de dominio](../arquitectura/dominio.md#tema-validacion-de-propiedades-enum).
Estas extensiones de Application no se utilizan desde Domain.
