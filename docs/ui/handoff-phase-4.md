# Fase 4 — Windows

Implementación de `design/terax-handoff/SPEC.md`, pantallas 09 y 11 y ajustes de Windows. Se mantiene el flujo de transferencia actual hasta las fases 5/6.

## Interfaz y conexiones

- Menú lateral de 232px: Recibir, Enviar al teléfono, Carpeta Recibidos y Equipos y ajustes. En tamaños estrechos se convierte en menú desplegable, sin convertir Windows en la interfaz de Android.
- Recepción: equipo y estados reales, recepción activada/pausada, preferencia de apertura automática, ilustración, carpeta real abreviada y panel de sesión de 340px. Si no hay servidor no se afirma que esté listo. Activar recepción llama a `setAccepting`.
- Actividad: solo `controller.history.take(10)`, sin almacenamiento nuevo. Nombre, dirección de transferencia, tamaño y hora reales; Abrir usa `openFile(entry.file)`.
- Envío: tabla Nombre/Tipo/Tamaño/Modificado, carpetas de Documents/Downloads/Pictures y las agregadas durante esta sesión. Los nombres visibles se traducen, las rutas siguen siendo las del servicio. Carpeta inicial Documents cuando la biblioteca es propiedad de Home.
- Selección y teclado: flechas, Enter en carpetas, Ctrl+F desde el menú o el contenido y Ctrl+Enter para enviar. El foco y el navegador sobreviven al cambio de carpeta; búsqueda/selección se limpian al cambiar de ubicación. La selección al pulsar evita la espera del doble clic antes de Enter. Doble clic y botón Abrir carpeta siguen disponibles.
- Vista previa: imagen real o representación con extensión, nombre y metadatos. El botón consulta la selección actual; bloquea carpetas, archivos mayores que `maxFileBytes`, equipos sin conexión y controlador ocupado. El controlador conserva su propia validación del archivo real.
- Ajustes: diálogo con desplazamiento, equipos deduplicados, QR/código existentes, recepción, apertura automática, efecto de escritorio (activar/probar), cercanía, red y confirmación de restablecimiento. Las acciones siguen siendo los métodos existentes de AppController.

## Archivos y alcance

Nuevos: `lib/ui/windows_home.dart`, `windows_browser.dart`, `windows_parts.dart`, `windows_settings.dart`. `home.dart` despacha por plataforma y conserva su integración de TransferScene; `settings.dart` despacha al diálogo Windows o pantalla Android. Se retira la presentación Windows anterior.

`LibraryService` únicamente expone el getter de ubicación actual para esta fase. El componente base de interruptor añade una variante compacta; las dimensiones y colores adicionales viven en el tema.

No se modificaron AppController, lib/transfer, la validación de vinculación, el transporte HTTPS, discovery, BLE, la onda nativa ni la bandeja. No se introdujeron colas, envío múltiple, reanudación ni historial persistente.

## Comparación con el handoff

Capturas de widgets reales a 1280×800, con fuentes reales, en `tmp/handoff-phase-4/`: recibir, recepción pausada, enviar y ajustes. Se inspeccionaron frente a los PNG 09/11 y sus HTML. El juego de datos de prueba no se usa en producción.

Diferencias intencionales:

- El marco pertenece a Windows; no se dibuja una ventana falsa.
- Las carpetas y los metadatos provienen del sistema; no se copian los nombres, tamaños o el orden de los archivos ficticios del PNG. Las fechas se muestran numéricamente. Las carpetas sin fecha informada muestran un guion.
- La ruta central se abrevia a sus últimos tres segmentos; Carpeta Recibidos abre la ubicación efectiva. No se fuerza una ruta predeterminada si el sistema usa otra.
- Búsqueda y metadatos se adaptan al ancho/texto aumentado; columnas secundarias se ocultan en modo estrecho, con tamaño y nombre conservados. La vista previa pasa debajo de la tabla y se puede desplazar. El historial pasa debajo de la recepción.
- Las carpetas agregadas se conservan durante esta sesión, sin simular marcadores persistentes que el servicio no proporciona.
- Hay indicaciones adicionales de teclado y aclaración de que el documento es una representación. El error de imagen permite comprobar el archivo sin mostrar una foto ficticia.
- La luz inferior de espera es tenue y estática. Las tarjetas de transferencia, llegada, verificación, acciones de apertura y coreografía final mantienen sus fases 5/6; no se presenta una animación nueva como señal de éxito.

## Validación

- 78 pruebas aprobadas; flutter analyze sin problemas.
- Pruebas de Ctrl+F desde el menú, flechas, selección/enviar, bloqueo de archivo sobredimensionado, bloqueo durante picking, navegación en carpetas reales conservando teclado, recepción pausada/activación y apertura de la entrada correcta del historial.
- Recibir y enviar a 320dp con texto200; ajustes a 700dp/texto200 y QR a 320dp. Cuatro capturas a 1280×800.
- Revisión independiente, con corrección y regresión del atajo desde el menú.
- Compilaciones release Windows y Android ARM64.

Las pruebas de efecto usan un controlador de prueba para verificar la llamada, no validan la distorsión nativa. Falta comprobar el envío, la recepción, el efecto minimizado y TalkBack/Narrator entre equipos reales. El núcleo no cambió.
## Entregable

`dist/Terax-Windows-ui-fase4.zip`: distribución portable completa, verificada por CRC y presencia de ejecutable, flutter_windows.dll, ICU y manifiesto de fuentes. Incluye instrucciones de extracción y salida desde la bandeja para evitar abrir la instancia anterior. SHA-256 en el archivo `.sha256` contiguo. No se sustituyeron los paquetes anteriores.
