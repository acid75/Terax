# Terax 0.5.4 (11): onda dentro de la app y permiso de audio

La onda de transferencia se había perdido al usar la presentación compacta: esa rama devolvía el vuelo y la franja inferior antes de dibujar EdgeMotion. Se añade una onda propia al overlay raíz de Flutter, independiente de la tarjeta compacta. El emisor la repliega hacia el borde superior; el receptor la expande desde el borde inferior. El archivo se dibuja encima. Dura 1,1 s y no queda cortada cuando el vuelo del archivo termina antes. Los fallos y la cancelación eliminan ambos efectos, cada transferencia se reproduce una vez y movimiento reducido omite la onda.

Es luz sobre los widgets en vivo, solo dentro de Terax: no usa el componente de captura de escritorio, no obtiene una imagen de la pantalla y no congela el contenido. Se retira de Ajustes el botón de captura de escritorio para que la interfaz solo ofrezca el efecto interno; se conserva el componente nativo sin invocarlo. El glow de conexión, la franja inferior y la apertura tras verificación se conservan. No se modifica protocolo, transporte, Bluetooth ni vinculación.

Android solicitaba fotos, pero no solicitaba el permiso de audio que photo_manager añadía al manifiesto combinado. Se declara READ_MEDIA_AUDIO expresamente y se solicita al primer arranque en Android 13+; en Android 6–12 corresponde READ_EXTERNAL_STORAGE. El usuario debe responder al diálogo del sistema: no se concede silenciosamente. La preferencia de solicitud evita insistir automáticamente tras rechazarla. Ajustes incluye una acción explícita para volver a solicitarla. Si Android bloqueó nuevas solicitudes por rechazos anteriores, su política puede exigir Ajustes del sistema.

El permiso es para leer archivos compartidos de audio. Rechazarlo no bloquea la reproducción de los sonidos incluidos, los selectores de archivos ni las transferencias. No se pide micrófono. Los dos MP3 elegidos por el usuario permanecen sin cambios.

Verificación: pruebas de dirección en píxeles reales, overlay del tamaño de la ventana, duración independiente, ejecución única, cancelación y movimiento reducido; puente de permisos automático y explícito y respuesta de denegación; suite completa, análisis y compilaciones release. Capturas de prueba y GIF en tmp/utilities-visual/. El diálogo de primer arranque requiere confirmación en un teléfono real.

Instalación: actualizar ambos equipos. Windows: bandeja > Salir, extraer todo el ZIP y ejecutar terax.exe. Android: instalar el APK como actualización. La vinculación se conserva.
