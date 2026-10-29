# DeviceCard

Tarjeta del equipo de destino: icono en círculo, nombre, estado de conexión y cercanía, e indicador a la derecha.

## Uso
- Una sola tarjeta, arriba de la biblioteca, sobre `surface` con `radius-lg`. Nombre en `label`, estado en `caption` / `text-muted`.
- El estado siempre se dice con palabras, con el formato «cercanía · conexión»: «Está cerca · listo para recibir», «Conectado por Wi-Fi», «Buscando automáticamente…». El icono de la derecha (`check_circle` cuando hay conexión, `add_link` cuando falta vincular) acompaña, no sustituye.
- Círculo del icono: `icon-container`, borde `icon-ring`, glifo `icon-on-container` (blanco en Windows, menta en Android).

## Lo que aporta quien la usa
Nombre del equipo, texto de estado y la acción de la derecha (indicador o botón con `aria-label`).

## No
- No la agrandes con datos técnicos: la IP va en la hoja *Tus equipos*.
