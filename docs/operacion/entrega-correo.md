# Configuración y operación del correo

[Índice de documentación](../README.md) · [Adopción del proyecto](../adopcion-del-proyecto.md)

Define configuración de proveedores, garantías de entrega y recuperación de reintentos.

<a id="tema-configuracion-del-proveedor"></a>

## Configuración del proveedor

```json
{
  "Email": {
    "Enabled": true,
    "Provider": "Resend",
    "From": {
      "Address": "notificaciones@example.com",
      "DisplayName": "[NombreProyecto]"
    },
    "Resend": {
      "ApiKey": ""
    },
    "Google": {
      "Mode": "Smtp",
      "Host": "smtp.gmail.com",
      "Port": 587,
      "UseStartTls": true,
      "User": "",
      "OAuthClientId": "",
      "OAuthClientSecret": "",
      "RefreshToken": ""
    },
    "Delivery": {
      "BatchSize": 25,
      "MaxAttempts": 8,
      "InitialRetrySeconds": 30
    }
  }
}
```

El archivo anterior solo muestra la forma de la configuración. Las API keys,
client secrets y refresh tokens DEBEN llegar mediante User Secrets, variables de
entorno o un almacén de secretos; nunca se guardan en `appsettings*.json` reales
ni se versionan. Las Options se validan al inicio según el proveedor elegido. Se
prefiere OAuth 2.0 para Google; una contraseña de aplicación no es la estrategia
base y cualquier excepción debe documentarse.


<a id="tema-garantias-de-entrega-y-reintentos"></a>

## Garantías de entrega y reintentos

El Outbox proporciona procesamiento al menos una vez. Si el proveedor acepta el
correo y el Worker falla antes de guardar `Sent`, el siguiente intento puede
repetir el envío. Una clave local o un `Message-Id` estable no garantiza que el
proveedor deduplique; no se promete entrega exactamente una vez.

- La clave de idempotencia identifica una intención de negocio y tiene una
  restricción única en el ámbito definido (por tenant cuando aplique). Un
  reencolado con la misma clave y contenido equivalente reutiliza la intención;
  con contenido distinto se rechaza. La restricción resuelve las carreras.
- Antes del primer envío se persisten el proveedor, `From`, `ReplyTo` resueltos
  y una huella del contenido preparado. Los reintentos mantienen esos valores,
  destinatarios, plantilla, versión, modelo y clave. Un cambio de contenido se
  detecta antes de enviar y requiere intervención; no reutiliza la misma clave
  con otro payload. Un cambio de proveedor no se aplica automáticamente a un
  mensaje ya intentado.
- La deduplicación nativa solo se considera una garantía dentro del alcance y
  período documentados por el proveedor elegido. El proyecto define qué hacer
  cuando un reintento supera ese período o el resultado del envío es incierto:
  consultar/reconciliar si existe soporte, aceptar el riesgo de duplicado o
  detener el reintento para revisión.
- Las opciones de recuperación de bloqueos, timeout, backoff, límite de intentos
  y reanudación de `DeadLetter` se documentan por proyecto. Una reanudación
  conserva la identidad original; un nuevo envío intencional usa otra clave.


## Guías relacionadas

- [Correo y Outbox](../arquitectura/correo-y-outbox.md)
- [Configuración mediante Options](configuracion.md)
