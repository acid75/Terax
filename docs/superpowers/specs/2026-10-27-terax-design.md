# Terax: enviar con un gesto

Aplicación real Flutter para Android y Windows, aprobada en conversación con «dale» después de proponer aplicaciones reales, Wi-Fi local y QR.

## Experiencia
Elegir una imagen u otro archivo, conectar el destino mediante su QR o código y deslizar la tarjeta hacia arriba. La tarjeta sale hacia el destino mientras el progreso refleja bytes reales. En la PC una tarjeta de recepción aparece, verifica el hash y permite abrir el archivo. La apertura automática es una opción explícita para imágenes decodificables en Windows. También existe un botón accesible de envío y se respeta movimiento reducido.

## Arquitectura y decisiones de implementación
Un proyecto Flutter con receptor y cliente HTTPS en Dart, archivos transmitidos por streaming, SHA-256, credencial persistente y huella de certificado fijada por QR. Tras la aclaración del usuario, el QR autoriza una sola vez: identidad y equipos se guardan cifrados. La primera conexión intercambia la dirección de retorno. Descubrimiento UDP con HMAC y nonce permite reconectar ante cambios de IP/puerto, verificando después la huella HTTPS. Ambos equipos deben estar en la misma LAN. BLE anuncia la PC y detecta cercanía aproximada desde Android con filtrado RSSI; no autoriza dispositivos ni sustituye Wi-Fi. Restablecer vínculos rota credenciales y certificado para invalidar códigos anteriores.

## Alternativas
Se propusieron aplicaciones reales o demo visual. Se sigue la recomendación de aplicaciones reales tras la autorización del usuario. Flutter comparte interfaz y transporte; un receptor Tauri separado añadiría una segunda plataforma sin beneficiar este primer flujo.

## Límites
Sin nube, UWB, reanudación, bandeja ni servicio en segundo plano en esta entrega. Máximo 1 GiB por archivo y una recepción simultánea. Se conservan archivos en documentos privados de la app, con nombres saneados y sin sobrescribir. HTTPS verifica la huella recibida fuera de banda. No se abren ejecutables automáticamente. BLE depende del hardware y permisos; se conserva el flujo Wi-Fi si no está disponible. Pruebas de transporte por loopback y compilación local no sustituyen prueba física Android-PC.
