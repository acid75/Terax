# Terax 0.5.1 (8): glow de conexión y sonido

El borde superior de Android y Windows muestra un resplandor ambiental tenue que aumenta y baja lentamente mientras hay un equipo conectado. No es una onda expansiva, no presenta archivos y no reproduce sonidos de transferencia. Se oculta durante un envío/recepción activo y desaparece al desconectar. Con movimiento reducido permanece estático. La cercanía ya no dispara la onda grande de escritorio; esta se conserva para la recepción real y su prueba en Ajustes.

El sonido anterior se sustituye por dos pequeñas notas de cristal, con una nota compartida entre salida y llegada. Salida: 300 ms; llegada: 420 ms. PCM mono de 44,1 kHz, ataque y cierre suaves, pico de -4,7 dBFS y margen sin recorte. La versión de caché cambia a v2 para que la actualización no siga reproduciendo los archivos anteriores. Android usa el volumen multimedia, respetando el nivel del sistema y el interruptor de sonidos de Terax. Los tiempos dependen de los eventos reales de transferencia, sin sincronización de relojes entre equipos.

Se corrige además la confirmación del renderizador de escritorio: informa éxito después de presentar un fotograma comprobado, en vez de informar éxito antes de dibujarlo. Prueba nativa local: fotograma visible presentado correctamente. El glow de conexión dentro de la app no necesita captura del escritorio ni el renderizador nativo.

Validación: 148 pruebas aprobadas, análisis limpio; capturas del glow en ambos extremos del fade en Android 360/412 y Windows; muestras WAV reales con nivel y transitorios comprobados. La reproducción y el volumen percibido deben confirmarse en los altavoces del usuario. No se modifican el protocolo, el transporte, la vinculación ni Bluetooth.

## Instalar

Actualiza ambos equipos. En Windows: bandeja > Salir para cerrar Terax anterior, extrae el ZIP completo y ejecuta terax.exe. El ejecutable necesita la carpeta data y las DLL incluidas. Android: instala el APK como actualización. Se conserva la vinculación.
