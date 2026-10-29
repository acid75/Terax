Terax pasa archivos entre un teléfono Android y una PC con Windows por la red local. La interfaz es oscura, tranquila y deja el protagonismo a los archivos; el turquesa y la menta marcan solo lo que se puede tocar o lo que está seleccionado.

El sistema tiene dos temas, uno por plataforma: **Windows** y **Android**. Comparten estructura, voz y componentes; cambian algunos tonos y los tamaños táctiles.

## Voz y texto

- Escribe la interfaz en español, de tú, en frases cortas y concretas: «Listo para recibir», «Agrega una carpeta una vez y explora sus archivos aquí.», «Mantén presionado y llévalo arriba, o toca para verlo.»
- Usa mayúscula solo al inicio de la frase («Enviar archivos», «Carpetas permitidas», «Código de este equipo»), nunca Title Case.
- Encadena estados con punto medio: «Está cerca · listo para recibir», «Android · Terax».
- Los estados en curso terminan en puntos suspensivos («Buscando automáticamente…», «Comprobando Bluetooth…») y siempre deben resolverse en un resultado o en una acción.
- Los subtítulos explican la consecuencia: «Desde tus equipos vinculados», «Después de verificar el archivo».
- Explica el comportamiento en una frase y sin jerga. Direcciones IP y detalles de red van solo como texto secundario (`caption`, `text-muted`).
- Sin emoji.

## Color

- Pinta la pantalla con `bg` y agrupa con `surface` (tarjeta de equipo, mosaicos, hojas). `surface` apenas se distingue de `bg`: los controles que deben leerse como campos llevan además borde `outline`.
- En Android, la cabecera va sobre `glow`, una luz gris que se desvanece hacia `bg`. Windows no la tiene.
- Texto principal en `text`; estado, ayudas, placeholder e iconos neutros en `text-muted`.
- `accent` (turquesa) solo para la opción seleccionada del control segmentado, con `on-accent`. En Android es más suave (`#62d7c5`) que en Windows (`#03dac6`).
- `mint` para acciones: botón principal (texto `on-mint`), interruptor encendido y acciones de texto («Recibidos», «Agregar carpeta», «Cargar más fotos», «Activar cercanía»).
- Icono del equipo: círculo `icon-container` con borde `icon-ring` y glifo `icon-on-container`.
- Bajo una hoja modal, cubre la pantalla con `scrim`.
- `danger` solo para lo destructivo o lo que falló: «Restablecer vínculos», «Error de integridad», «Conexión perdida». Rellena el botón de confirmación con `danger` y texto `on-danger`. Como tiene casi la misma luminosidad que `mint`, siempre va con icono y palabra.
- Nunca comuniques conexión, error o éxito solo con color: acompáñalo de texto o icono.
- Valores reales que no llegan a 3:1 y quedan anotados en su token: `outline` (≈2:1) y `control-off` (1.9:1).

## Tipografía

- `ui` es **Figtree** (variable, pesos 300–900), la misma en Windows y Android para que ambas apps se sientan una sola. `mono` es **Geist Mono**, solo para datos técnicos. Ambas tienen licencia OFL y sus archivos están en `fonts/`. En Flutter, regístralas como assets (Figtree se puede bajar en TTF desde Google Fonts) o usa el paquete `google_fonts`.
- `display` para el titular de una pantalla completa en Windows; `headline` para un estado vacío dentro de la biblioteca; ambos seguidos de `body-lg` en `text-muted`.
- `title` en hojas («Tus equipos»), `body` en filas de lista y en el buscador.
- `label` (600) para nombre de equipo, botones, pestañas y acciones; `label-sm` para encabezados de grupo y nombres bajo miniaturas (una línea con elipsis: «IMG-20261028-W…»); `caption` para estados, IP y subtítulos.
- `mono` para IP, nombres técnicos de equipo y tamaños; `code` para el código de conexión que hay que leer o copiar.
- `wordmark` es solo el respaldo en texto del logotipo; en pantalla va el archivo.

## Espaciado, forma y tamaño

- Margen lateral: `space-48` en Windows, `space-20` en Android. Relleno interior de tarjeta y filas `space-16`; entre controles apilados `space-12` (`space-18` tras la tarjeta de equipo en Windows); entre mosaicos `space-6`.
- Esquinas: `radius-sm` en mosaicos y buscador, `radius-md` en el control segmentado de Windows, `radius-lg` en tarjeta y botón, `radius-sheet` en las esquinas superiores de las hojas, `radius-full` en interruptores, en el control segmentado de Android y en el círculo del icono.
- Los tokens `size-*` son los de Windows. En Android los controles crecen para el dedo; `components/bundle.css` los aplica bajo el tema Android:

| Elemento | Windows | Android (≈dp) |
| --- | --- | --- |
| Control segmentado | 32 | 40, píldora |
| Buscador | 48 | 56 |
| Botón principal | 42 | 52 |
| Tarjeta de equipo | 60 | 70 |
| Cuadrícula de fotos | columnas de 140 | 3 columnas |

- Sin sombras: la profundidad se marca con `surface`, `glow` y `scrim`.
- Respeta las barras del sistema de Android: el contenido no debe quedar detrás de la barra de navegación.

## Componentes

`Header`, `DeviceCard`, `SegmentedControl`, `SearchField`, `LibraryGrid`, `Button`, `Switch`, `Sheet`, `ConfirmDialog`, `EmptyState` y `BottomBar` (solo en Windows). Son HTML con las clases `tx-*` de `components/bundle.css`; envuelve cada pantalla en `.tx` y fija `data-theme="windows"` o `data-theme="android"` en la raíz.

Pantalla de biblioteca en Android, de arriba abajo: `Header` sobre `glow` → `DeviceCard` → `SegmentedControl` → `SearchField` → encabezado de sección → `LibraryGrid` (o `EmptyState`) → ayuda de gesto.

## Iconografía

- Material Icons de Flutter, en variante de contorno (fuente «Material Icons Outlined»): `tune`, `desktop_windows`, `devices`, `image`, `description`, `search`, `folder`, `create_new_folder`, `bluetooth`, `settings`, `add`, `close`, `expand_more`. `check_circle` va relleno.
- La dirección se representa con flechas diagonales: `north_east` (↗) enviar, `south_west` (↙) recibir. La misma ↗ acompaña al nombre en la cabecera.
- Iconos de acción en `mint`, neutros en `text-muted`, de error en `danger` (`link_off`, `error`, `warning`), a 20–24px; 48px en estados vacíos.
- La flecha de la marca (`terax-symbol.svg`) no sustituye a `north_east` en la interfaz: es la marca, no un icono de acción.

## Logotipo

La marca es la flecha ↗: un archivo que sale de un equipo hacia el otro. El grupo *Logos* tiene todas las versiones.

- **Wordmark** (`terax-wordmark.svg`): flecha `mint` y «terax» en Figtree Bold convertido a trazos, en `text`. Va en la cabecera de ambas apps, sobre `bg` o `glow`.
- **Monocromos**: `terax-wordmark-mono-light.svg` (todo `text`) sobre fondos oscuros que no sean del sistema; `terax-wordmark-mono-dark.svg` (todo `bg`) sobre fondos claros.
- **Ícono de app** (`terax-icon.svg`, PNG de 512 y 1024): cuadrado redondeado `mint` con la flecha en `on-mint` y dos ondas que nacen de la esquina inferior: la luz que sale del borde. Para el instalador de Windows, el launcher de Android y la tienda.
- **Ícono pequeño** (`terax-icon-small.svg`): sin ondas, para 24px o menos (bandeja del sistema, barra de título, favicon).
- **Ícono oscuro** (`terax-icon-dark.svg`): flecha y ondas `mint` sobre `surface`, para fondos claros o el icono monocromo de Android 13.
- **Símbolo** (`terax-symbol.svg`): solo la flecha en `mint`, para notificaciones y el efecto de escritorio.
- Deja alrededor un margen libre igual a la altura de la «x». No cambies los colores, no gires la flecha ni la separes del nombre en el wordmark.

## Capturas de referencia

El grupo *Other* tiene la app de Windows (biblioteca, «Listo para recibir», hoja «Tus equipos»). El grupo *Android* tiene la app del teléfono (Documentos vacío, biblioteca de fotos, hoja «Tus equipos»). Los valores de Android salen de capturas JPEG, así que son aproximados en ±2 de cada canal.
