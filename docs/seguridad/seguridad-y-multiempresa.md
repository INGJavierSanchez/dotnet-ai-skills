# Seguridad mínima y multiempresa

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define controles transversales y aislamiento por tenant.

<a id="s19"></a>

## Multiempresa opcional

Si el proyecto es multiempresa, debe definir `ITenantContext` y aplicar defensa
en profundidad:

1. resolver el tenant desde una identidad validada;
2. aplicar filtros globales de lectura;
3. asignar y validar tenant en `SaveChanges`;
4. incluir tenant en claves e índices cuando corresponda;
5. prohibir que DTO operativos modifiquen `TenantId`;
6. probar cruces de tenant en lectura y escritura.

`IgnoreQueryFilters` solo se utiliza en flujos administrativos o de
autenticación con condiciones explícitas.

### Resolución del contexto de empresa

En proyectos que utilicen `empresaId`, el contexto se obtiene de una identidad
validada, nunca de un campo libre del Request:

- Claim `empresaId` de la sesión cookie o del JWT validado, según el cliente.
- `X-Api-Key` en endpoints que declaren expresamente ese mecanismo. La clave
  debe validarse del lado del servidor y resolverse a una empresa habilitada;
  su presencia no demuestra autenticidad. No se usa como sustituto global de
  las cookies/JWT de usuarios ni se registra su valor. Un endpoint «público con
  API key» sigue requiriendo una credencial válida para ese contrato.
- `X-Empresa-Id` cuando una identidad de administrador de plataforma tenga
  autorización explícita para operar sobre la empresa seleccionada. No se
  acepta para sobrescribir el tenant de un usuario ordinario. Se valida el
  ámbito y se audita el cambio de contexto sin datos sensibles.

La autenticación ausente o inválida devuelve `401` (UNAUTHORIZED,
API_KEY_REQUIRED o API_KEY_INVALID según la política del endpoint). Con identidad
válida, la falta de una selección empresarial requerida devuelve `400` con
TENANT_CONTEXT_REQUIRED; seleccionar una empresa fuera del ámbito permitido
devuelve `403`. Los mensajes no revelan información de otras empresas.

Un recurso fuera del tenant actual se trata como inexistente y devuelve `404`,
sin consultas auxiliares que revelen si existe en otro tenant. Los repositorios
y QueryServices aplican el contexto tanto a lecturas como a escrituras. Todos
estos rechazos utilizan [ApiErrorResponse](../arquitectura/respuestas-api.md),
con código obligatorio y traceId, no respuestas parciales sin code.


<a id="s26"></a>

## Seguridad mínima

- HTTPS obligatorio.
- CORS restringido a orígenes conocidos.
- consultas parametrizadas mediante EF Core.
- límites de tamaño para solicitudes y archivos.
- validación de entrada.
- rate limiting en endpoints sensibles.
- secretos externos al repositorio.
- dependencias auditadas.
- errores sin información interna.
- privilegios mínimos para el usuario de base de datos.
