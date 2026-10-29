# Terax — Especificación del rediseño (UI/UX)

Este paquete describe el rediseño de Terax para Android y Windows. La app ya existe en **Flutter/Dart** con componentes nativos; el objetivo es **rehacer la interfaz y la experiencia sin cambiar el protocolo, el transporte ni las funciones**.

## Contenido del paquete

| Carpeta | Qué es | Cómo usarlo |
| --- | --- | --- |
| `screens/` | PNG de las 14 pantallas y tableros (a 2×) | Referencia visual exacta. Compara tu implementación contra ellas. |
| `source/` | HTML fuente de cada pantalla (`*.dc.html`) + `terax.css` | Medidas, textos y colores exactos. Las etiquetas `sc-for`/`sc-if` son plantillas; los datos están en `renderVals()` al final de cada archivo. |
| `flutter/terax_theme.dart` | Tema listo: colores por plataforma, tipografía, espaciado, radios, tamaños y movimiento | Cópialo a `lib/theme/`. Es la única fuente de valores en Dart. |
| `design-system/` | Tokens (`tokens.json`), guía de marca (`README.md`), guías por componente, fuentes `.woff2` y el brief original (`Brief.md`) | Reglas de uso. `Brief.md` es el requerimiento original del producto. |
| `logos/` | Wordmark, íconos de app (SVG y PNG 512/1024), símbolo | Para la cabecera, el launcher de Android, el `.ico` de Windows y la bandeja. |

## Principios

1. **La biblioteca manda** (Android). Nada técnico ocupa más de una línea arriba.
2. **Recibir sin buscar la ventana** (Windows). El archivo entra por el borde inferior y el resultado se entiende de un vistazo.
3. **Cada animación sigue un evento real.** Nunca mostrar éxito antes de verificar. Ningún error queda tapado por una animación.
4. **Estado = icono + palabra.** Nunca solo color (accesibilidad y daltonismo).
5. **Lo técnico existe, pero en segundo plano**: IP, interfaces de red y Bluetooth viven en *Equipos y ajustes*, en `TeraxText.monoSm`.

## Límites que NO se deben romper (del brief)

- Un archivo por envío; máximo 1 GiB; una recepción simultánea; sin cola; sin reanudación.
- Bluetooth solo estima cercanía. **Nunca** se envía un archivo solo por acercar el teléfono. Los archivos viajan por la red local (HTTPS local). Si Bluetooth falla, todo sigue funcionando por Wi-Fi.
- Android necesita Terax abierto durante la transferencia: no diseñar un servicio en segundo plano.
- El historial es de la sesión: 50 entradas en memoria, se muestran 10, se pierde al salir. No presentarlo como biblioteca permanente.
- La vista previa de documentos es una **representación** (extensión + nombre), no un lector.
- Windows: cerrar la ventana deja Terax en la bandeja; salir es explícito; una instancia; sin autoinicio.
- Apertura automática solo después de verificar. Fotos PNG/JPG/WebP/GIF/BMP ≤ 32 MiB y 40 MP; documentos PDF/DOCX/XLSX/PPTX/ODT/ODS/ODP/TXT/CSV/MD/RTF ≤ 64 MiB. Nunca ejecutables ni archivos con macros.
- Las funciones de la sección 21 del brief (compartir desde otras apps, envío múltiple, cola, portapapeles, etc.) **no se implementan**.

## Navegación

### Android
```
Vinculación (primera vez, sin equipos)
  └─ Biblioteca  [Fotos | Documentos]  ← pantalla principal
        ├─ Vista previa (tocar un elemento)
        ├─ Arrastre al borde superior (pulsación larga) → envío
        ├─ Buscador por nombre (icono lupa: se expande en la misma fila)
        └─ Equipos y ajustes (tocar la barra del equipo o el icono de ajustes)
              ├─ Vincular otro equipo → Vinculación
              ├─ Detalles de red
              ├─ Permisos de Terax en Android (abre ajustes del sistema)
              └─ Restablecer vínculos → diálogo de confirmación
```
La tarjeta de envío en curso aparece **sobre** la biblioteca, anclada arriba; no es una pantalla nueva.

### Windows
Menú lateral fijo de 232 px: **Recibir** (inicio) · **Enviar al teléfono** · abajo *Carpeta Recibidos* y *Equipos y ajustes*. Ajustes se abre como panel/diálogo con las mismas secciones que en Android, más *Efecto de escritorio* (activar / probar) y *Abrir al recibir*.

## Pantallas

Cada pantalla tiene su PNG en `screens/` y su fuente en `source/`.

### 01 · Android · Biblioteca de fotos (`01-Main.png`)
- Respeta las áreas seguras (`SafeArea`); no dibujar la barra de estado.
- **Cabecera** 56 dp sobre un degradado radial `glow → bg` (solo arriba, se desvanece antes de la cuadrícula): wordmark 26 dp de alto a la izquierda, botón de ajustes 48×48 a la derecha.
- **Barra del equipo** (60 dp, `surface`, radio 18): ícono del equipo en círculo · «Enviar a» (caption) + nombre (label) · píldora de cercanía con borde `mint`: «✓ Cerca». Estados de la píldora: `Cerca` (mint) · `Conectado` (sin cercanía; texto muted) · `Reconectando…` · `Sin respuesta` (borde outline). Tocar abre *Equipos y ajustes*.
- **Fila de control**: segmentado tipo píldora 44 dp (`Fotos` / `Documentos`, activo en `accent` con `onAccent`) + botón de búsqueda 44×44. La búsqueda reemplaza al segmentado por un campo mientras está activa.
- **Cuadrícula**: 3 columnas, separación 4 dp, miniaturas cuadradas con recorte centrado, radio 10; nombre debajo en 11 dp, una línea con elipsis. Encabezado de sección por día («Hoy», «Ayer», fecha). Paginación: carga al llegar al final + «Cargar más fotos» como respaldo.
- **Ayuda de gesto** (solo las primeras veces o hasta que la cierren): tarjeta flotante abajo «Mantén presionada una foto y llévala arriba. O tócala para verla.» con botón cerrar.
- Estados de miniatura: cargando (superficie estática, sin brillo si hay movimiento reducido), ilegible (icono imagen rota + «No se puede leer»).

### 02 · Android · Suelta para enviar (`02-AndroidArrastre.png`)
- Pulsación larga 350 ms → la miniatura se despega (escala 1.08, borde `mint` 2 dp, rotación −3°) y sigue el dedo con su nombre debajo.
- El resto de la UI baja a 28 % de opacidad.
- **Zona de envío**: los 120 dp superiores. Luz radial `mint` que nace del borde, sin bordes duros (degradado a transparente), más una línea de 3 dp en el borde. Nunca un rectángulo opaco ni texto sobre la luz.
- Píldora (40 dp, fondo `bg`, borde `mint`): «Lleva aquí para enviar» → al entrar en la zona: «Suelta para enviar a {equipo}» + vibración ligera.
- Abajo: «Suelta lejos del borde para cancelar».
- Si el destino no está disponible, la píldora dice «PC de casa no responde» y soltar no envía.

### 03 · Android · Vista previa (`03-AndroidVistaPrevia.png`)
- Fondo casi negro `#07090C`. Barra superior: volver + nombre del archivo.
- La foto respeta su proporción, centrada, radio 16. Encima, doble chevron `mint` como pista de deslizar.
- Panel inferior (`surface`, radio superior 28): nombre, «4.8 MB · 3000 × 4000» en mono, tarjeta del destino con su estado, botón principal «Enviar a {equipo}», texto «O desliza la foto hacia arriba».
- Deslizar: umbral 35 % de la altura o 1000 dp/s. Si no llega, vuelve con resorte.
- Documentos: en lugar de la foto, la representación del archivo (hoja con la extensión), igual que en `11-WindowsEnviar.png`.

### 04 · Android · Enviando (`04-AndroidEnviando.png`)
- Tarjeta anclada arriba (`surface`, borde `outline`, radio 22): miniatura 48, «Enviando a {equipo}», nombre, botón «Cancelar», barra de progreso `mint` 6 dp, «3.0 de 4.8 MB» en mono, «Mantén Terax abierto hasta que termine».
- La celda de origen lleva una insignia ↗ mientras se envía.
- Secuencia de estados: ver `13-Estados.png`. Al terminar: «Enviado a {equipo}» con ✓ (solo tras la confirmación de verificación del receptor); la tarjeta se retira a los 2 s.

### 05 · Android · Documentos (`05-AndroidDocumentos.png`)
- Cabecera compacta: wordmark + píldora del equipo («● PC de casa · Cerca»).
- Fila de carpetas autorizadas como chips; la activa con borde y texto `mint`. Una carpeta con permiso vencido muestra ⚠ en `danger` + «volver a autorizar» y abre el selector del sistema.
- Migas: «‹ Trabajo › Facturas»; el botón ‹ vuelve a la carpeta anterior.
- Filas de 64 dp: insignia de tipo (DIR / PDF / DOC / XLS / MD…) en mono · nombre (elipsis) · «Tipo · tamaño · fecha». Carpetas con ›. Archivo inaccesible: nombre atenuado + «Ya no está en el teléfono» en `danger`.
- «Agregar carpeta» abre el selector nativo **solo** para conceder acceso.

### 06 · Android · Vinculación inicial (`06-AndroidVincular.png`)
- Título «Vincula tu PC», explicación, visor de cámara 280×280 con esquinas `mint`, dos pasos numerados y botón secundario «Pegar código de conexión».
- Errores: cámara sin permiso, QR que no es de Terax, código inválido (textos en `13-Estados.png`).

### 07 · Android · Equipos y ajustes (`07-AndroidEquipos.png`)
- Pantalla completa (no hoja). Secciones: **Tus equipos** (cada equipo con chips `✓ Conectado` y `Cerca`, o `Vinculada · sin respuesta`), «+ Vincular otro equipo», **Cercanía** (tarjeta de estado de Bluetooth con explicación y acción: Activar Bluetooth / Reintentar / Abrir permisos), **Recepción** (interruptor), *Detalles de red* (IP en mono, selector de interfaz, actualizar), *Permisos de Terax en Android*, y al final «Restablecer vínculos» en `danger`.
- Restablecer abre un diálogo: «¿Restablecer vínculos?» / «Tus equipos dejarán de estar autorizados y tendrás que vincularlos otra vez con el código QR. **Los archivos recibidos no se borran.**» / [Cancelar] [Restablecer]. Ver `design-system/components/ConfirmDialog/`.
- Nunca listar el mismo equipo dos veces (hoy pasa: deduplicar por identidad del equipo).
- Nunca quedarse en «Comprobando Bluetooth…»: tras ~5 s, mostrar un estado concreto y una acción.

### 08 · Android · Sin acceso a fotos (`08-AndroidPermiso.png`)
- Estado vacío centrado: ícono, «Terax necesita ver tus fotos», «Para mostrarlas aquí y enviar las que elijas. Ninguna sale del teléfono hasta que tú la envías.», [Permitir acceso a fotos], «Elegir solo algunas». Con acceso parcial: aviso fino arriba de la cuadrícula «Solo ves las fotos que elegiste · Elegir más».

### 09 · Windows · Listo para recibir (`09-WindowsRecibir.png`)
- Barra superior: teléfono conectado con chips de estado; a la derecha «Recepción activada» + interruptor y la línea «Abrir al recibir: fotos y documentos».
- Centro: ilustración de líneas, «Listo para recibir» (`display`), «En tu teléfono, mantén presionado un archivo y llévalo arriba. Llega por aquí abajo.», «Se guardan en Documentos › Terax › Recibidos». Brillo muy tenue en el borde inferior.
- Panel derecho 340 px «En esta sesión · Se borra al salir»: últimas 10 entradas (↙ recibido / ↗ enviado, tamaño, hora) con «Abrir».
- Recepción pausada: el título cambia a «Recepción pausada» y el botón principal es «Activar recepción».

### 10 · Windows · Llegada y verificación (`10-WindowsLlegada.png`)
- La miniatura (si el emisor la envía antes) sube desde el borde inferior; luz `mint` y dos ondas que se expanden.
- Tarjeta de estado: «Recibiendo de {teléfono} · 62 %» → «Verificando…» → «Recibido y verificado» con ✓, nombre, tamaño, origen, [Abrir] [Mostrar en carpeta] y, si aplica, «Se abre en {app} en 2 s · No abrir».
- Sin app compatible: «Se guardó, pero ninguna app abre archivos .{ext}» + [Mostrar en carpeta].

### 11 · Windows · Enviar al teléfono (`11-WindowsEnviar.png`)
- Carpetas en el menú lateral (Documentos, Descargas, Imágenes, + Agregar carpeta).
- Barra: búsqueda (Ctrl F) + píldora del teléfono.
- Tabla: Nombre · Tipo · Tamaño (mono) · Modificado; fila seleccionada con borde `mint`. Navegable con flechas, Enter abre carpeta, Ctrl+Enter envía.
- Panel derecho: vista previa (foto real o representación del documento), nombre, metadatos, [Enviar a {teléfono}], nota «Mantén la app abierta allá hasta que termine». Archivos > 1 GiB: botón deshabilitado + «Pesa 1.4 GB. El máximo es 1 GB.»

### 12 · Windows · Llegada con Terax minimizado (`12-WindowsEscritorio.png`)
- Usa el componente nativo existente (captura de un fotograma, ~1.8 s, sin foco). Encima o en su lugar: notificación de Terax con miniatura, «Recibido y verificado», [Abrir] [Mostrar en carpeta].
- Si el efecto no puede mostrarse, solo la notificación.
- Primer cierre de la ventana: aviso «Terax sigue en la bandeja. Para cerrarlo del todo, usa Salir desde su icono.» [Entendido].

### 13 · Estados y errores (`13-Estados.png`) · 14 · Movimiento (`14-Movimiento.png`)
Tablas completas con los textos finales, acciones, duraciones y curvas. Los valores también están en `TeraxMotion`.

## Accesibilidad
- Funciona desde 320 dp de ancho y con texto al 200 %: nada de alturas fijas en filas con texto.
- Toda acción por gesto tiene un botón visible (Enviar en la vista previa; en la biblioteca, menú de pulsación larga con «Enviar a…» para lectores de pantalla).
- `Semantics` en miniaturas (nombre del archivo), barra del equipo (estado completo en palabras) y progreso (porcentaje).
- Windows: todo navegable con teclado; foco visible (`mint`, 2 px).
- Movimiento reducido: `MediaQuery.disableAnimations` → columna «Movimiento reducido» de `14-Movimiento.png`.

## Orden de implementación sugerido
1. Tema (`terax_theme.dart`), fuentes TTF y logos (launcher Android, `.ico` Windows, bandeja).
2. Componentes base: barra del equipo, segmentado, buscador, mosaico, botón, interruptor, diálogo de confirmación, estado vacío.
3. Android: biblioteca de fotos → documentos → vista previa → equipos y ajustes → vinculación → permisos.
4. Windows: recibir → enviar → ajustes.
5. Flujo de transferencia con sus 9 estados y los errores de `13-Estados.png`.
6. Movimiento (arrastre, zona del borde, llegada) y la variante reducida.
7. Revisión contra los PNG a 360 dp, 412 dp y ventana de 1280×800.

## Criterios de aceptación
- Cada pantalla coincide con su PNG en estructura, jerarquía, textos y colores.
- Ningún color se usa fuera de `TeraxColors`; ningún tamaño de texto fuera de `TeraxText`.
- El éxito solo aparece tras la verificación; los errores muestran icono, texto y acción.
- Los 20 casos de error/permiso de `13-Estados.png` están cubiertos.
- Ninguna función nueva fuera del alcance del brief.
