# Terax 0.5.0 (7)

## Uso

- **Archivos** abre el selector nativo de archivos individuales y permite seleccionar contenido de Descargas. Android 11+ no permite conceder la raíz de Descargas mediante el selector de carpetas; usa Archivos para esa ubicación.
- **Texto / enlaces** prepara un mensaje para la vista previa y el envío. Pegar y Copiar requieren una acción explícita. Los enlaces HTTP(S) recibidos se abren únicamente al tocar Abrir enlace.
- Android recibe Compartir de otras aplicaciones, con un archivo, varios archivos o texto. Si llegan archivos y texto juntos, puedes incluir ambos antes de confirmar la cola.
- La cola envía de forma secuencial, admite hasta 100 elementos y se pausa ante un fallo. Puedes reintentar, pausar después del elemento actual o cancelar. Su destino queda fijado; cambiar el equipo seleccionado no redirige los pendientes. La cola pendiente no sobrevive al cierre de la aplicación.
- El historial guarda hasta 50 transferencias verificadas entre sesiones. Borrarlo elimina el registro, conserva los archivos y restaura la lista si falla la escritura. Un archivo movido, borrado o limpiado por Android puede dejar de estar disponible aunque conserve su registro.
- El archivo sale por el borde superior del emisor y aparece por el borde inferior del receptor. Respeta movimiento reducido; no confirma éxito hasta que finaliza la verificación.
- Dos sonidos originales cortos comparten una nota de unión: salida de 240 ms y entrada de 280 ms. Funcionan en ambos sentidos y se silencian en Ajustes o Más. Siguen los eventos reales; la red y el tamaño del archivo pueden separar ambos sonidos. No hay sincronización de relojes entre equipos.

## Instalación

Actualiza Android y Windows para obtener la presentación de mensajes en ambos extremos. Un receptor antiguo guardará el mensaje como archivo JSON. Instalar la actualización conserva la vinculación existente.

En Windows, cierra la versión anterior mediante el icono de bandeja > Salir, extrae la carpeta completa del ZIP y abre terax.exe. Abrir otra copia mientras la anterior sigue ejecutándose puede activar la copia antigua.

## Validación

144 pruebas aprobadas, análisis sin incidencias y compilaciones release Android ARM64/Windows. Capturas verificadas en Android 360/412, texto ampliado, movimiento reducido y Windows 1280×800; vista previa de la salida y WAV originales disponibles en tmp/utilities-visual/. Versiones nativas verificadas: Android 0.5.0 código 7; Windows 0.5.0+7. Los hashes de los archivos preexistentes de transporte, protocolo, Bluetooth, descubrimiento y política de apertura coinciden con la referencia anterior.

La recepción desde proveedores Android reales, el sonido entre dos dispositivos, la transferencia física y el efecto de escritorio minimizado requieren comprobación en los equipos del usuario. Esta entrega no incorpora recepción Android como servicio en segundo plano, reanudación por fragmentos, sincronización automática del portapapeles ni transporte por internet.
