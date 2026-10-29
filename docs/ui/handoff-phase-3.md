# Fase 3 — Android

Implementación del handoff `design/terax-handoff/`, pantallas 01, 03, 05, 06, 07 y 08. Las fases 1 y 2 siguen documentadas en `handoff-phase-1-2.md`.

## Pantallas y conexiones

- Biblioteca: cuadrícula de tres columnas, miniaturas cuadradas, etiquetas de fecha reales, paginación al final y botón de respaldo, ayuda de gesto que se puede cerrar. El buscador ocupa la fila del segmentado y vuelve a la misma biblioteca al cerrarlo. El arrastre sigue llamando al mismo envío; lectores de pantalla tienen una acción de envío.
- Documentos: carpetas autorizadas en chips, selección activa, ruta de nombres y vuelta a la carpeta anterior, tipo/tamaño/fecha reales. No se inventan conteos de elementos. El error existente de permiso vencido se presenta con advertencia y acceso al selector para volver a autorizar.
- Vista previa: pantalla oscura con proporción de imagen real, metadatos de tamaño y dimensiones, panel inferior con destino, envío por botón y el mismo gesto existente. Los documentos se representan por su extensión, sin simular un lector.
- Equipos y ajustes: ruta completa en Android; equipos deduplicados por fingerprint, estado de la conexión actual, recepción, detalles de red desplegables, permisos y confirmación de restablecimiento. Conserva las acciones existentes del controlador.
- Vinculación inicial: nueva presentación de pantalla completa con visor de cámara y alternativa de código. Home la muestra una vez al iniciar sin vínculos. Cancelar deja explorar la biblioteca; no vuelve a abrirse repetidamente en la misma sesión. Los códigos siguen pasando por AppController.connect y su validación existente.
- Permisos: diferencia entre biblioteca vacía y acceso denegado; selección parcial solo cuando Android ofrece esa capacidad (API 34+), acción para ampliar selección, acceso a los ajustes del sistema y actualización al regresar tras cambiar permisos.

## Archivos y límite técnico

Presentación: `lib/ui/home.dart`, `library_browser.dart`, `settings.dart`, `pairing.dart`; nuevos `android_preview.dart`, `android_settings.dart`, `pairing_camera.dart`. Se ajustan tokens en `lib/theme/terax_theme.dart` y accesibilidad/layout en los componentes base.

`LibraryService` expone metadatos para permiso de fotos, capacidad del selector parcial, carpetas autorizadas y ruta visible. El mapeo de filas Android se reutiliza sin cambiar los métodos del canal nativo. Seleccionar un chip vuelve a la raíz correspondiente; no acumula una ruta ficticia entre carpetas distintas.

No se modificaron AppController, lib/transfer, la autorización de vinculación, el protocolo, HTTPS, discovery, BLE ni el código nativo de Android o Windows. El aviso tras cinco segundos de espera Bluetooth es exclusivamente de presentación: ofrece abrir permisos sin fabricar un resultado ni cancelar/modificar la operación.

## Comparación visual y decisiones intencionales

Se generaron e inspeccionaron 12 PNG de widgets reales (seis vistas a 360/412 dp) en `tmp/handoff-phase-3/`, con fuentes reales y archivos sintéticos locales. Se compararon estructura, jerarquía, formas y colores con los PNG/HTML del handoff. No son capturas de un teléfono físico ni contienen datos privados. La cámara en esos renders muestra el marco de referencia; el visor nativo se crea en Android.

Diferencias intencionales:

- SafeArea y barras del sistema son reales; no se dibuja una barra de estado ficticia para copiar el PNG.
- Ajustes permite desplazarse y conserva la opción existente de apertura automática e historial de sesión, además de las secciones del PNG. Un equipo sin respuesta usa estado explícito; no se afirma que todos los equipos vinculados estén conectados.
- La autorización nativa actual no entrega un estado individual de permiso por cada raíz; el chip puede marcar el permiso vencido cuando la lectura de esa raíz produce el error. No se fabrican errores en otras carpetas.
- El acceso parcial solo aparece si es compatible con el Android instalado. Al denegarse el permiso hay una acción adicional para ir a Ajustes, evitando un botón sin salida tras denegaciones repetidas.
- Se mantiene el buscador en estados vacíos para que el control conserve su lugar.
- El papel del documento limita la extensión a una línea; la aclaración de representación va en el panel inferior para admitir texto al 200%. El error de cámara y la confirmación pueden desplazarse.
- La tarjeta anclada durante transferencia, sus nueve estados y el retiro automático corresponden a fase 5. Umbral/velocidad de swipe y la coreografía final del arrastre, borde y llegada corresponden a fase 6; los gestos actuales siguen operativos.
- La estructura nueva de Windows es fase 4; en esta fase conserva su pantalla existente.

## Verificación

- 70 pruebas aprobadas y flutter analyze sin problemas.
- Cobertura de búsqueda/restauración, carpetas reales y migas, lectura semántica de miniatura ilegible, acceso a fotos al volver de Ajustes, deduplicación, espera de Bluetooth y código inválido sin autorizar equipo.
- Android: envío desde su nueva vista previa con el controlador existente, más regresiones de pulsación larga/arrastre y swipe. La prueba de UI impide mostrar éxito mientras el cliente sigue enviando; los tests existentes de transporte cubren la integridad.
- Layout a 320 dp con texto 200%; renders a 360/412 dp.
- Revisión independiente: dos problemas de escalado corregidos; prueba de documento al 200% reproducida antes y aprobada después.
- Compilaciones release Android ARM64 y Windows.

Pendiente de validación física: cámara/QR, concesión y revocación real de permisos Android, accesibilidad con TalkBack, gestos y envío entre dispositivos. Las compilaciones y los widget tests no sustituyen estas pruebas.
