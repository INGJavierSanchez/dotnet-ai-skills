# Composición e inyección de dependencias

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define el registro de servicios y sus límites de composición.

<a id="s12"></a>

## Inyección de dependencias con Scrutor 7.0.0

Scrutor amplía `Microsoft.Extensions.DependencyInjection` con escaneo de
ensamblados y decoración.

```xml
<PackageReference Include="Scrutor" Version="7.0.0" />
```

Interfaces marcadoras:

```csharp
public interface IScopedDependency;
public interface ITransientDependency;
public interface ISingletonDependency;
```

Registro:

```csharp
builder.Services.Scan(scan => scan
    .FromAssembliesOf(
        typeof(ApplicationAssemblyMarker),
        typeof(InfrastructureAssemblyMarker))
    .AddClasses(c => c.AssignableTo<IScopedDependency>())
        .AsImplementedInterfaces()
        .WithScopedLifetime()
    .AddClasses(c => c.AssignableTo<ITransientDependency>())
        .AsImplementedInterfaces()
        .WithTransientLifetime()
    .AddClasses(c => c.AssignableTo<ISingletonDependency>())
        .AsImplementedInterfaces()
        .WithSingletonLifetime());
```

Scrutor NO DEBE registrar automáticamente:

- handlers de Mediator;
- módulos `ICarterModule`, descubiertos por Carter;
- `DbContext`;
- el repositorio genérico abierto `IRepository<>`, registrado explícitamente;
- autenticación y autorización;
- Options;
- clientes HTTP configurados;
- validadores si FluentValidation ya los descubre;
- servicios de framework.

Los filtros de escaneo deben usar marcadores explícitos. Se prohíbe registrar
indiscriminadamente todas las clases de un ensamblado.
