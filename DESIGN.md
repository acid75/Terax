# Terax Design System

## Fuente vigente: handoff 2026-10-28

`design/terax-handoff/SPEC.md`, sus PNG/HTML y `lib/theme/terax_theme.dart` tienen prioridad sobre las notas históricas siguientes. Figtree para la interfaz; Geist Mono para metadatos. Las fases 1/2 y 3 se describen en `docs/ui/handoff-phase-1-2.md` y `docs/ui/handoff-phase-3.md`. La estructura Windows está implementada en la fase 4 (`docs/ui/handoff-phase-4.md`). Los estados y la coreografía de transferencias mantienen sus fases 5/6.

## Notas históricas — 0.2

Biblioteca dentro de la aplicación, fotos en cuadrícula y documentos en lista. Mantener presionado permite llevar el archivo al borde superior; tocar abre la vista previa con swipe arriba. La PC recibe desde el borde inferior sobre un lienzo amplio. QR y opciones técnicas viven en Ajustes.

Fondo #0B1016, superficie #141D27, tinta #F3F6FA, secundaria #ABB8CB, acento #9BE9DD, contorno #344556. Fuente del sistema, contraste claro, ancho máximo 1240. Pantallas estrechas desde 320 px con texto aumentado.

La oferta autenticada inicia la escena de llegada antes de subir bytes. El archivo despega y se contrae; en recepción asciende desde abajo. Los archivos pequeños conservan tiempo de animación; la confirmación depende de integridad verificada. Halo solo durante cercanía real, arrastre o transferencia. Movimiento reducido sin desplazamientos ni ticker decorativo; botón de enviar como alternativa al gesto.

## Revisión 0.3: efecto NameDrop

La referencia del usuario aporta tres capas locales: luz blanca difusa, bloom y onda circular expansiva. Sustituye el contorno ovalado. Una sola onda recorre la pantalla al detectar cercanía o confirmar una oferta; no hay pulsación perpetua. En recepción aparece el archivo desde abajo, y las etiquetas entran después para no cruzarse con él. Windows solicita restaurar la ventana antes de iniciar el movimiento. El APK y Windows deben actualizarse juntos.
