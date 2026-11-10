# Integración continua

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define comprobaciones y artefactos de la canalización.

<a id="s28"></a>

## Integración continua

La canalización mínima ejecuta:

```powershell
dotnet restore
dotnet format --verify-no-changes
dotnet build --no-restore
dotnet test --no-build --no-restore
```

Además debería:

- analizar vulnerabilidades;
- generar cobertura;
- validar migraciones pendientes;
- producir artefactos reproducibles;
- publicar una imagen o paquete versionado;
- impedir despliegue si fallan pruebas o análisis críticos.
