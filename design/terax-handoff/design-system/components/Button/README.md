# Button

Botón principal relleno de menta y acción de texto en menta.

## Uso
- **Principal** (`tx-btn`): relleno `mint`, texto `on-mint` en `label`, icono a la izquierda. Uno por pantalla, para la acción que desbloquea el estado actual («Conectar equipo», «Agregar carpeta»). Windows: alto `size-button`, `radius-lg`. Android: ≈52dp, esquinas de 16.
- **Acción de texto** (`tx-link`): texto e icono `mint`, sin fondo, mínimo 40px de alto. Para acciones secundarias: «Recibidos», «Reintentar Bluetooth», «Cargar más fotos».
- Foco: anillo `mint` sólido de 2px, separado 2px.

## Lo que aporta quien la usa
Texto en infinitivo o imperativo breve, icono opcional y la acción.

- **Destructiva**: `tx-link danger` para abrir la confirmación y `tx-btn danger` (relleno `danger`, texto `on-danger`) solo dentro de `ConfirmDialog`. Siempre con icono y un verbo que diga qué se pierde.

## No
- No uses `mint` para acciones destructivas, ni `danger` sin icono y palabra.
