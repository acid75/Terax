# LibraryGrid

Cuadrícula de miniaturas o carpetas con encabezado de sección; la miniatura manda.

## Uso
- Encabezado de sección en `label-sm` («Tus fotos», «Carpetas permitidas»), con una acción de texto opcional a la derecha.
- Mosaicos en `surface` con `radius-sm`, separados `space-6`. Windows: columnas de `size-tile`. Android: 3 columnas a lo ancho.
- La foto llena el mosaico (recorte centrado); el nombre va debajo en `label-sm`, una línea con elipsis.
- Estados: cargando (brillo suave; estático con movimiento reducido), ilegible (`broken_image` + «No se puede leer»), carpeta (`folder`).
- Al final, «Cargar más fotos» como acción de texto `mint`.

## Lo que aporta quien la usa
Elementos (miniatura o icono, nombre, estado), encabezado y acción.

## No
- No pongas tarjetas grandes alrededor de la cuadrícula: la biblioteca es la protagonista.
