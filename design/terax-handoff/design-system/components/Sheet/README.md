# Sheet

Hoja modal «Tus equipos»: asa, título, cierre, filas con icono, separador e interruptores.

## Uso
- Se abre desde el botón de ajustes. Fondo `surface`, esquinas superiores `radius-sheet`, asa de 32×4 en `text-muted`, `scrim` detrás.
- Título en `title` con cierre (`close`) a la derecha. Filas de 56px como mínimo: icono `text-muted`, título `body`, subtítulo `caption`. Las IP van solo como subtítulo, en `mono`.
- «Restablecer vínculos» va al final, solo, como acción de texto `danger` con icono `link_off`, y siempre abre `ConfirmDialog`.
- Separa grupos (equipos / cercanía y recepción / restablecer) con `divider`.

## Lo que aporta quien la usa
Título, filas y acciones. Cada fila de equipo representa un equipo distinto.

## No
- No muestres el mismo equipo dos veces.
