# Terax: fases 1 y 2 del handoff

## Alcance

Referencia original: `dist/Design/terax-handoff/terax-handoff/`. Copia canónica en `design/terax-handoff/`; instrucciones copiadas a `AGENTS.md` en la raíz. Se revisaron los 14 PNG, SPEC y los README de los ocho componentes.

Tema aplicado desde `lib/theme/terax_theme.dart` a MaterialApp. Se conservaron los valores entregados y se añadieron tokens locales para los elementos faltantes (nombre de mosaico de 11dp, dimensiones de iconos, separación y foco). Los componentes nuevos no declaran colores ni tamaños de texto propios.

Figtree variable y Geist Mono Regular/Medium locales en TTF, con OFL y registro de licencias Flutter. Origen oficial y derivación en `assets/fonts/README.md`. Wordmark SVG sin sustituir su dibujo. Launcher Android en 48/72/96/144/192px. ICO Windows en 16/20/24/32/48/64/128/256px; los tamaños pequeños usan la variante simplificada. El icono de bandeja ya comparte ese recurso, sin cambiar código nativo.

## Componentes y conexión

- `device_bar.dart`: nombre, estado y callback. Home deriva el estado de peer/peerOnline/nearbyFingerprint/starting/connecting. Sin inferir cercanía ni crear nuevos estados de red.
- `library_controls.dart`: segmentado genérico y buscador controlado por el padre. LibraryBrowser conserva kind/load y filtro por nombre.
- `library_tile.dart`: mosaico y miniatura con variantes lista/cargando/ilegible. Los archivos siguen viniendo de LibraryItem; la pulsación larga y callbacks de selección no se sustituyeron.
- `foundation.dart`: marca, botón principal, interruptor, diálogo y estado vacío. Ajustes conserva setAccepting/setAutoOpen/setDesktopEffects/resetLinks; el diálogo solo devuelve bool.
- `focus_ring.dart`: borde visible al navegar con teclado, sin agregar otra parada. Semantics explicita estado y acción.

No se editaron AppController, LibraryService, lib/transfer, la vinculación, la implementación Bluetooth, la onda nativa ni el comportamiento de la bandeja.

## Comparación visual y diferencias intencionales

Capturas sintéticas en `tmp/handoff-phase-1-2/`: Android 360 y 412dp, Windows 1280x800 y confirmación. Se compararon contra los tokens, las guías de componentes y los PNG 01, 07, 08, 09, 11 y 13. No contienen fotografías de usuarios.

Estas capturas son tableros de componentes, no pantallas finales. La búsqueda todavía se muestra debajo del segmentado en la pantalla existente; el componente ya admite cerrarse para integrarlo en la fila durante la fase 3. Tampoco se implementaron todavía agrupación por día, nuevo panel de equipos Android, sidebar Windows, tablas de envío, nuevas tarjetas de transferencia ni la coreografía de la fase 6. Se preservó el flujo usable actual.

Los nombres y estados reales vienen de los servicios. No se usan los nombres de ejemplo de los PNG como datos de producción. Las miniaturas de muestra de la galería de pruebas representan estados, no contenido estático para la app.

## Validación

- Flutter analyze sin problemas.
- Suite completa: 60 pruebas, incluidas regresiones del flujo de envío existente y ocho pruebas de los componentes.
- Se comprobaron nombres largos a 320dp y texto al 200%, confirmación con Escape, estado ocupado, movimiento reducido, acciones semánticas y orden de foco del interruptor.
- Compilaciones release de Android ARM64 y Windows correctas tras la integración.
- Inspección de activos: TTF locales presentes, cinco densidades Android y ocho tamaños ICO.

La advertencia futura de compatibilidad Kotlin de los plugins Bluetooth/photo_manager ya existía; las compilaciones actuales terminan correctamente. No se cambió su versión ni su implementación.

Las capturas son renders de widget tests. Falta comprobar el launcher en un teléfono físico y el icono de bandeja con la caché real de Windows; la inspección del recurso ICO no sustituye esa prueba.
