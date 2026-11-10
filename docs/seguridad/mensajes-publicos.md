# Mensajes públicos de errores

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define el catálogo seguro de errores y su separación de los mensajes de diagnóstico.

<a id="tema-politica-de-mensajes-publicos"></a>

## Política de mensajes públicos

La API NO DEBE copiar `Exception.Message`, `InnerException.Message` ni
`Exception.ToString()` en respuestas HTTP, incluso para errores distintos de
500. Esta política se aplica en todos los ambientes.

Un texto de `DomainException.Message` solo es apto para comunicación pública
cuando ha sido revisado y registrado como texto fijo en el catálogo de errores
de API. El manejador devuelve el texto del catálogo por código; nunca usa el
mensaje de la instancia como fallback. Domain conserva sus códigos sin depender
del catálogo ni de conceptos HTTP.

El catálogo DEBE cumplir estas reglas:

- contiene únicamente códigos y mensajes aprobados para exposición pública;
- los mensajes explican qué impide la operación sin incluir SQL, nombres de
  tablas, rutas físicas, stack traces, detalles de proveedores ni configuración;
- no incorpora contraseñas, tokens, datos personales, identificadores sensibles
  ni valores de entrada interpolados;
- no revela existencia de cuentas, pertenencia a empresas ni otros hechos que el
  consumidor no esté autorizado a conocer; esos casos usan mensajes genéricos;
- los códigos desconocidos devuelven `DOMAIN_RULE_VIOLATION` y un mensaje
  genérico, sin exponer el código interno original;
- la localización, si aplica, se resuelve en API por código y recursos aprobados.

El catálogo reside en `Api/Common/Errors/PublicDomainErrors.cs`. Ejemplo mínimo:

```csharp
public static class PublicDomainErrors
{
    private static readonly IReadOnlyDictionary<string, string> Messages =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["DOMAIN_RULE_VIOLATION"] =
                "La operación no cumple una regla de negocio."
        };

    public static (string Code, string Message) Resolve(string code)
    {
        return Messages.TryGetValue(code, out var message)
            ? (code, message)
            : ("DOMAIN_RULE_VIOLATION", Messages["DOMAIN_RULE_VIOLATION"]);
    }
}
```

Los errores de recurso inexistente, conflicto e inesperados utilizan textos
genéricos aprobados. Los mensajes de validación por campo también DEBEN ser
seguros y no incluir el valor rechazado; su conversión al diccionario `errors`
de `ApiErrorResponse` sigue [el contrato de validación](../arquitectura/respuestas-api.md#tema-respuestas-error).


## Guías relacionadas

- [Manejo de errores HTTP](../arquitectura/errores-http.md)
