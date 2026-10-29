# Header

Cabecera de pantalla: logotipo, estado de cercanía y botón de ajustes.

## Uso
- Arriba de toda pantalla principal. A la izquierda el logotipo `terax-wordmark.svg` (grupo Logos) a 28px de alto en Windows y 32dp en Android; a la derecha el botón de ajustes (`tune`, 40px, `text-muted`) que abre la hoja *Tus equipos*.
- El estado de cercanía («Visible por Bluetooth», icono `bluetooth` en `mint`, texto `caption`) aparece en Windows; en Android el estado vive en la tarjeta de equipo.
- En Android la cabecera va sobre `glow` (clase `tx-glow`), que se desvanece hacia `bg`.

## Lo que aporta quien la usa
El texto de estado y la acción del botón de ajustes. El botón necesita `aria-label`.

## No
- No escribas «terax» como texto en la cabecera ni recolorees el archivo: usa la versión monocroma si el fondo no es `bg`.
