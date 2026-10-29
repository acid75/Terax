# AGENTS.md — Rediseño de Terax

Copia este archivo a la raíz del repositorio (o agrega su contenido al AGENTS.md existente). El paquete de diseño vive en `design/terax-handoff/`.

## Contexto
Terax es una app Flutter/Dart (Android + Windows, con componentes nativos) para pasar archivos entre teléfono y PC por la red local. Estamos rehaciendo **solo la UI/UX**. El protocolo, el transporte HTTPS local, la vinculación, la detección por Bluetooth, el componente nativo de la onda de escritorio y la bandeja de Windows **ya existen y se conservan**.

## Fuentes de verdad (léelas antes de tocar UI)
1. `design/terax-handoff/SPEC.md`: navegación, pantallas, estados, límites y orden de trabajo.
2. `design/terax-handoff/screens/*.png`: cómo debe verse cada pantalla.
3. `design/terax-handoff/source/*.dc.html`: medidas y textos exactos.
4. `design/terax-handoff/flutter/terax_theme.dart`: colores, tipografía, espaciado, tamaños y movimiento.
5. `design/terax-handoff/design-system/Brief.md`: requisitos originales del producto.

## Reglas
- Usa `TeraxColors`, `TeraxText`, `TeraxSpace`, `TeraxRadius`, `TeraxSize` y `TeraxMotion`. No escribas colores ni tamaños de texto literales en los widgets.
- Los textos de la interfaz van en español, tal como aparecen en SPEC.md y en los PNG.
- No agregues funciones que la app no tiene (envío múltiple, cola, portapapeles, compartir desde otras apps, historial persistente, servicio en segundo plano en Android).
- Nunca muestres éxito antes de la verificación de integridad. Todo estado lleva icono + palabra.
- Respeta `MediaQuery.disableAnimations` y las áreas seguras de Android.
- Separa la UI de la lógica existente: los widgets nuevos consumen los servicios/estados que ya hay; si falta un estado (por ejemplo «Reconectando» o «Verificando»), exponlo desde la capa existente sin cambiar el protocolo.
- Trabaja por fases (SPEC.md § Orden de implementación) y deja la app compilando y usable al final de cada una.
- Al terminar cada pantalla, compárala con su PNG y anota diferencias intencionales en el PR.
