# Verificación de Terax 0.4.0 — 2026-10-27

## Validación automatizada

- `flutter analyze`: sin problemas.
- `flutter test --no-pub`: 52 pruebas aprobadas.
- Incluye HTTPS real en loopback, integridad SHA-256, confianza persistente, reservas de oferta, cancelación y expiración, y aviso autenticado de cercanía antes de ofrecer un archivo.
- Ambos gestos integrados pasan: vista previa y swipe arriba; pulsación larga y arrastre al borde superior. Se comprueban biblioteca, búsqueda, permisos representados, layouts estrechos y movimiento reducido.
- Política de apertura de fotos y documentos probada; ejecutables y documentos con macros no se abren automáticamente.

## Corrección BLE y hardware

El publicador WinRT anterior usaba un campo Service UUID no admitido. Se sustituyó por un anuncio manufacturer de 20 bytes (identificador experimental 0xffff, marca TRX, versión 2 y prefijo de huella), validado contra equipos autorizados. Android filtra el contenido y aplica suavizado RSSI, histéresis y caducidad. Los errores nativos se presentan sin quedarse reintentando indefinidamente.

Un diagnóstico C++ con el mismo constructor de anuncio confirmó en esta PC: LE supported=1, peripheral supported=1, Radio state=On, Publisher=starting y Publisher=ready. Se detuvo después del diagnóstico sin cambiar ajustes del adaptador. El teléfono comunica el estado de cercanía a Windows por HTTPS autenticado; el aviso caduca si deja de llegar.

No había Android conectado por ADB. Sigue pendiente comprobar físicamente permisos, selección de carpeta, RSSI/distancia, animación entre ambos equipos y apertura en las aplicaciones instaladas. RSSI no permite identificar la punta del teléfono ni medir centímetros.

## Experiencia nueva

Biblioteca propia para fotos y documentos. Android necesita permiso de fotos y autorización de cada carpeta de documentos una vez; después navega dentro de Terax. La oferta autenticada activa la recepción antes del hash y de los bytes; la entrega solo se confirma tras verificar integridad. Las animaciones conservan tiempo visible incluso para archivos pequeños.

El QR autoriza el vínculo inicialmente y se conserva en almacenamiento protegido. Actualizar ambas aplicaciones mantiene los vínculos existentes. La versión 0.2 cambia el anuncio BLE: ambos extremos necesitan actualizarse.

Windows y Android se compilan en release. El APK ARM64 usa firma de desarrollo para esta entrega de pruebas. Los artefactos y SHA-256 están en `dist/`. La compilación no sustituye la validación física pendiente.

## Movimiento 0.3

Referencia Figma NameDrop suministrada por el usuario: bV9QctUEetDsPgfPnN5x5z. Se leyeron diseño y transiciones de prototipo; get_motion_context no devolvió pistas. Se exportaron las capas de luz, gradiente y onda a archivos locales y se rasterizaron conservando filtros SVG. No se incluye contenido del teléfono de ejemplo.

Se eliminó el óvalo pintado. El borde emite una onda de 1800ms de una sola ejecución; las etiquetas aparecen después de la entrada del archivo. El movimiento reducido omite la onda. La recepción en Windows solicita restaurar/activar la ventana y espera respuesta nativa antes de iniciar la escena; Windows puede limitar el cambio de foco y entonces se solicita atención en la barra de tareas. La apertura automática espera al menos 2450ms desde el comienzo de llegada.

Prueba nueva de recepción ya completada: la geometría permanece quieta hasta habilitar la presentación y después cambia durante la entrada. Capturas deterministas a 390x844 y 1200x720, 37 fotogramas por tamaño; vista animada en tmp/motion/Terax-motion-preview.gif. No sustituye la comprobación entre teléfono y PC físicos.

Comprobación adicional de la app Windows 0.3 abierta: la interfaz informó “Visible por Bluetooth”, “Tu teléfono, conectado” y “Está cerca · listo para recibir”. Se observó el lienzo sin el óvalo anterior. Se corrigió la etiqueta de cercanía para separarla de la tarjeta del equipo; las pruebas de layout se volvieron a ejecutar (3 aprobadas). La transferencia con la animación de las dos versiones nuevas sigue pendiente de comprobación física conjunta.

## Entrega 0.4: Bluetooth y escritorio

- `flutter analyze --no-pub`: sin problemas. Suite completa: 52 pruebas aprobadas.
- Nueva regresión Android: authorize() devuelve true sin actualizar estado cached unauthorized en bluetooth_low_energy_android 6.2.1. Antes se impedía escanear; ahora se respeta ese resultado y el escáner nativo verifica disponibilidad. Se prueban denegación, fallo nativo y reintento.
- Recuperación Windows: el publicador se reinicia con un intervalo mínimo de 10 segundos cuando aborta/se detiene, y se limpia el error anterior al recuperar estado Started/Waiting. No se oculta el código de fallo.
- Diagnóstico nativo recompilado: LE supported=1, peripheral supported=1, Radio state=On, Publisher=starting → ready. Publicidad detenida al terminar; no se cambiaron ajustes del sistema. El error 1 reportado no se reprodujo de forma continua.
- Renderer de escritorio: Direct3D11 + DirectComposition, textura DXGI (fallback GDI) capturada antes de mostrar la capa, shader de desplazamiento radial, ventana topmost no activable, duración 1.8s, memoria liberada después. Hardware o WARP. La imagen es un fotograma fijo durante el efecto, no vídeo continuo.
- Probe nativo compilado con MSVC /W4 /WX. Ejecución normal y movimiento reducido: setup GPU/composición correcto, finalización sin error, foco y posición del cursor conservados. Esto no confirma por sí solo la apariencia ni el click-through bajo todas las aplicaciones.
- La inspección visual del overlay se interrumpió con Escape. Sigue pendiente validar su apariencia durante la transferencia física Android-PC. Android no está conectado por ADB; no se declaran probados permisos/escaneo en el teléfono del usuario.
- Se añadieron bandeja con Salir y exclusión de instancias duplicadas, preferencia del efecto y botón de prueba. La recepción minimizada no necesita restaurar la ventana cuando el overlay se inicia correctamente.

## Corrección Windows 0.4.1

Se reprodujo un fallo real de render: tras el primer Present del swapchain FLIP_SEQUENTIAL, el render target quedaba desvinculado. La ejecución diagnóstica anterior al arreglo terminó con `Frame has no render target after Present` en ~254ms. Esto explica que el setup GPU/composición fuera exitoso pero no aparecieran los fotogramas del efecto.

Se vuelve a enlazar el render target antes de CADA Draw. Además de comprobar ese enlace, a los 200ms se verifica el canal alfa de un único píxel del backbuffer, sin leer ni guardar colores del escritorio; un frame transparente produce un error. La prueba nativa corregida termina sin error tanto en modo normal (~2083ms) como reducido (~2075ms), conservando foco y posición del cursor. Build MSVC /W4 /WX y Windows release aprobados. Android no cambia respecto de 0.4.

Contrato de DXGI confirmado en documentación oficial: https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgiswapchain-present

La herramienta de inspección no enumeró la ventana transitoria del efecto en dos intentos. La prueba de píxeles verifica salida de render; la apariencia final sobre otras aplicaciones sigue requiriendo comprobación visual en uso.

## Android 0.4.2: zona de arrastre

La luz del borde se dibuja sobre el lienzo completo con una máscara vertical suave, separada del área táctil superior de 135px. Se elimina el panel opaco que recortaba el brillo y generaba una franja rectangular. Durante el arrastre se oculta el halo de cercanía para no sumar ambos brillos. La indicación tiene fondo oscuro redondeado y sigue cambiando al entrar en la zona de envío.

Verificación: analyze sin problemas, prueba de swipe y arrastre integrado aprobadas y layout estrecho aprobado (3 pruebas dirigidas). Captura sintética a 390x844 en tmp/motion/drag-edge-soft.png: sin límite rectangular inferior; no contiene fotografías del usuario. Android 0.4.2 reemplaza el APK; Windows 0.4.1 conserva su arreglo nativo.
