# SearchField

Buscador por nombre dentro de la biblioteca cargada.

## Uso
- Bajo el control segmentado, a `space-12`. Borde `outline`, que pasa a `mint` al enfocar. Texto en `body`; placeholder en `text-muted`.
- Windows: alto `size-input`, `radius-sm`. Android: ≈56dp, `radius-lg`.
- El placeholder dice qué se busca: «Buscar fotos», «Buscar archivos». La búsqueda es por nombre: no prometas búsqueda por contenido.

## Lo que aporta quien la usa
El placeholder y el manejo del texto. Sin resultados, muestra un `EmptyState`.
