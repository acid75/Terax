# Terax — fases 5, 6 y 7

Implementación de la UI del handoff. Fuente: `design/terax-handoff/SPEC.md`, pantallas 02/04/10/12/13/14 y sus HTML; revisión de las pantallas anteriores a 360/412 dp y Windows 1280×800.

## Resultado

- Nueve estados de presentación: preparar envío, preparar recepción, transferir, verificar, enviado, recibido, cancelado, fallo y error de integridad. Ni el 99 % ni una miniatura anuncian éxito. La recepción se confirma en `onReceived`; la salida, después de la respuesta verificada del cliente existente.
- Android conserva la biblioteca bajo la tarjeta superior y marca la celda que se envía. La tarjeta de éxito desaparece a los dos segundos. Los errores permanecen y ofrecen acciones reales.
- Windows conserva la navegación durante la llegada. Foto o documento, ondas, progreso, verificación, Abrir y Mostrar en carpeta. Al enviar y recibir simultáneamente, los descartes y la apertura pendiente son independientes.
- Arrastre con miniatura real, pulsación de 350 ms, elevación de 180 ms, escala 1.08, giro −3°, borde menta y retorno al cancelar. La biblioteca queda al 28 % de opacidad. Zona superior de 120 dp, luz radial sin panel opaco, píldora y vibración al entrar; no acepta destinos sin respuesta.
- Swipe de 35 % de la altura o 1000 dp/s, retorno físico y un único disparo. Llegada con miniatura de 420 ms y ondas de 900 ms, activada por el evento real. Sin bucles decorativos.
- Movimiento reducido: sin desplazamientos, giro ni ondas; fundido breve. El controlador omite la captura/distorsión nativa de escritorio cuando el sistema pide reducir movimiento.
- La apertura automática conserva las extensiones, cabeceras, tamaños y límites de píxeles originales. Se valida primero y se ofrece al menos 1200 ms para cancelar ese recibo mediante No abrir, conservando la preferencia global. Un fallo al abrir no quita el estado de archivo verificado.
- Una selección nueva borra el éxito y la selección anteriores antes de resolver el archivo, incluso si este desapareció. El destino de salida queda capturado al comenzar.

## Cobertura de los 20 casos del handoff

| Caso | Presentación y acción existente conectada |
|---|---|
| 1. Bluetooth apagado | Equipos: estado concreto, explicación de Wi-Fi y Activar Bluetooth. |
| 2. Sin Bluetooth compatible | Explicación de envío por Wi-Fi; no se ofrece una activación ficticia. |
| 3. Permiso de cercanía | Abrir permisos llama a los ajustes reales de cercanía. |
| 4. Cámara sin permiso | Pantalla de vinculación/cámara con permisos y alternativa de pegar código. |
| 5. QR ajeno a Terax | Error del escáner y posibilidad de volver a escanear. |
| 6. Código inválido | Mensaje de vinculación; el campo sigue disponible para corregir/pegar otro. |
| 7. Equipo sin respuesta | Barra del equipo y acceso a Equipos y ajustes; no se permite soltar para enviar. |
| 8. Reconectando | Estado del controlador existente, sin fingir una conexión. |
| 9. Fotos parciales | Aviso y Elegir más a través de PhotoManager. |
| 10. Carpeta sin permiso | Chip de la carpeta y volver a autorizar mediante el selector nativo. |
| 11. Archivo desaparecido | Mensaje y Actualizar la biblioteca; se limpia la selección anterior. |
| 12. Más de 1 GiB | Límite existente y mensajes; Windows deshabilita el envío. |
| 13. Receptor ocupado | Explicación y Reintentar usando el cliente existente. |
| 14. Recepción pausada | Explicación y ajustes; no se inventa una activación remota. |
| 15. Fallo de aplicación al abrir | Archivo sigue verificado, mensaje y Mostrar en carpeta. |
| 16. Onda no disponible | Aviso de recepción verificada como alternativa; Probar efecto en ajustes. |
| 17. Cierre a bandeja | Aviso nativo una vez por sesión; el menú Salir se conserva. |
| 18. No se abre automáticamente | Política existente; aviso y apertura manual explícita desde el recibo. |
| 19. Sin equipo vinculado | Vincular PC mediante QR o código existente. |
| 20. Búsqueda sin resultados | Mensaje sobre archivos cargados, Limpiar búsqueda y Cargar más si hay más fotos. |

`ui_issue.dart` centraliza textos de presentación. Los errores no reconocidos conservan su detalle original; no se reemplazan por una explicación de red inexacta.

## Comparación visual y diferencias intencionales

Capturas regenerables en `tmp/ui-final/`, `tmp/handoff-phase-3/` y `tmp/handoff-phase-4/`. Se inspeccionaron la biblioteca, vista previa, documentos, vinculación, equipos y permisos en 360/412, y recepción, envío, ajustes y llegada en 1280×800. Las capturas finales incluyen arrastre, envío, error, texto al 200 %, verificación y movimiento reducido. Los archivos/imágenes usados son fixtures locales, no transferencias ni capturas de hardware.

- 02: el área superior está dentro de SafeArea; no invade la barra del sistema. La ayuda de biblioteca se oculta durante el gesto para no mezclarse con la cancelación.
- 04: la tarjeta se adapta al texto y ancho, en lugar de conservar posiciones absolutas del HTML. Se mantiene el nombre con elipsis y una insignia de estado sobre su miniatura. Las celdas conservan sus nombres reales.
- 10: marco de foto 264×352, tarjeta de hasta 520 y separación del borde inferior de 56, según el HTML. Se conserva una acción para volver a recibir. Los datos provienen de los archivos/estados reales.
- 10: el canal existente no devuelve el nombre de la aplicación predeterminada; se usa «Se abre en N s». No se inventa «Fotos» o «Word».
- 10: el transporte no identifica el remitente por oferta. Con varios equipos vinculados se muestra «Recibiendo archivo» y se omite un origen específico; con uno solo, su nombre es inequívoco. No se cambia el protocolo para añadir identidad.
- 12: se reutiliza la notificación balloon de la bandeja Win32. **No incluye miniatura ni botones**: un clic restaura Terax y allí aparecen Abrir/Mostrar en carpeta. El aviso de primer cierre tampoco incorpora un botón Entendido; usa el cierre del aviso del sistema. Es una diferencia respecto al PNG, para conservar el componente y ciclo de vida existentes. Windows puede suprimir estos avisos según sus preferencias.
- 13/14: son catálogos de referencia; no se agregaron pantallas de demostración a la app. Cada variante aparece con su evento/permiso correspondiente. En texto al 200 %, las tarjetas largas pueden desplazarse; no se recortan mediante alturas fijas de texto.

## Validación y alcance

- `flutter test --no-pub`: 101 pruebas pasan, incluyendo transporte existente, IDs de oferta, verificación, gestos, permisos, autoapertura, selección fallida y transferencias simultáneas.
- `flutter analyze --no-pub`: sin problemas.
- `flutter build windows --release --no-pub` y APK Android arm64 release.
- Capturas por `TERAX_CAPTURE_FINAL=1`, `TERAX_CAPTURE_ANDROID=1` y `TERAX_CAPTURE_WINDOWS=1` con los tests visuales correspondientes. Las capturas son verificaciones de disposición y contenido, no goldens automáticos ni pruebas físicas.
- Comparación SHA-256 antes/después de todos los archivos de `lib/transfer/`: sin cambios en protocolo, HTTPS, descubrimiento, Bluetooth, política de apertura ni componentes de transporte. El renderer nativo de la onda no se modificó.
- La única ampliación nativa en esta fase es la presentación de avisos en `flutter_window`: recepción verificada, primer cierre y restauración al pulsar el aviso. Se conserva la bandeja, sus menús y el cierre explícito.
- Revisión independiente de estado y nativo: se detectó y corrigió el descarte cruzado en envío/recepción simultáneos. Verificación posterior sin hallazgos nuevos.
- Pendiente de hardware: transferencia entre teléfono/PC reales, recepción minimizada, políticas de notificación de Windows y comportamiento del controlador Bluetooth real. No se afirma que estas pruebas físicas se hayan ejecutado.

## Entrega

`dist/terax-android-arm64-ui-final.apk` y `dist/Terax-Windows-ui-final.zip`. El ZIP contiene la carpeta completa del release. En Windows, salir de Terax desde su icono de bandeja antes de ejecutar esta versión; la instancia anterior puede seguir abierta aunque se cierre su ventana.
