# ConfirmDialog

Confirmación antes de una acción que no se puede deshacer, como «Restablecer vínculos».

## Uso
- Centrado sobre `scrim`, en `surface` con `radius-sheet`. Icono de la acción en `danger`, título en pregunta («¿Restablecer vínculos?»), explicación en `text-muted` que dice qué pasa y qué **no** se pierde, en `text` y negrita.
- Acciones abajo a la derecha: «Cancelar» (`tx-link neutral`, recibe el foco al abrir) y la acción con su verbo (`tx-btn danger`).
- Escape y tocar fuera equivalen a Cancelar.

## Lo que aporta quien lo usa
Icono, título, explicación y el verbo de la acción. Usa `role="alertdialog"` con título y descripción enlazados.

## No
- No uses «Aceptar» o «Sí» como verbo.
