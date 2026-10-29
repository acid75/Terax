# Terax 0.5.2 (9)

## Interacción y presentación

El archivo sale por el borde superior del móvil y entra desde el borde inferior de Windows. La llegada usa el overlay raíz, recorre una etapa central contenida de hasta 160 dp y termina en la miniatura de una franja inferior. Esa franja muestra nombre, estado, progreso y las acciones correspondientes. Se mantiene la biblioteca y la navegación; desaparecen el panel superior de progreso y la foto permanente de gran tamaño. El texto ampliado adapta los controles a otra línea y respeta movimiento reducido y áreas seguras.

Causa corregida: la recepción activaba una captura de escritorio de 1,8 s que tapaba la animación Flutter completa. Ahora una oferta real presenta la ventana, detiene cualquier demostración de escritorio activa y después habilita la llegada. Con Terax minimizado, la recepción vuelve a mostrar su ventana. La onda nativa se conserva para la prueba manual de Ajustes; no cubre la entrada de archivos. El glow ambiental de conexión se mantiene independiente.

Los estados de éxito y las acciones de apertura siguen dependiendo de la verificación real de integridad. No se modifican protocolo, transporte, vinculación ni Bluetooth.

## Terax Air

Firma original en la dirección elegida por el usuario: impulso suave y envolvente, sin campanas ni secuencia de notas. Dos mitades complementarias con textura de aire filtrado: salida de 260 ms y llegada de 380 ms en el máster. Se distribuyen únicamente MP3 mono de 48 kHz a 320 kbps; el caché v5 sustituye los sonidos anteriores al actualizar. Los másteres de autoría quedan fuera del paquete.

Windows usa reproducción nativa de MP3 mediante MCI con argumentos estructurados para conservar rutas Unicode. La notificación de bandeja es silenciosa para no superponer un sonido del sistema a la firma de Terax. Android conserva SoundPool con volumen multimedia; ambos respetan el interruptor de sonidos y el volumen del sistema. El intervalo entre mitades depende de la red y los eventos reales, no de relojes sincronizados.

## Verificación y límites

152 pruebas aprobadas y análisis sin incidencias. Se comprueba recepción real en el controlador sin activar la captura de escritorio, trayectoria desde el borde físico inferior, tamaño acotado, franja inferior en Android/Windows, texto al 200 % y acceso a acciones solo después de verificar. Capturas y GIF de fotogramas Flutter disponibles en tmp/utilities-visual/. La prueba nativa local confirmó la reproducción MP3 de ambas mitades. El timbre percibido y la transferencia entre teléfono y PC requieren comprobación en los dispositivos del usuario.

## Instalar

Actualiza ambos dispositivos. En Windows: bandeja > Salir para cerrar la versión anterior; extrae el ZIP completo y ejecuta terax.exe conservando las DLL y la carpeta data. Android: instala el APK como actualización. Se conserva la vinculación existente.
