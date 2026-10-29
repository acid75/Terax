Quiero que rediseñes la interfaz y la experiencia de Terax, una aplicación existente para transferir archivos entre Android y Windows.

Necesito un diseño completo de producto para ambas plataformas: pantallas, navegación, componentes, estados, gestos y animaciones. Puedes reorganizar profundamente la interfaz, pero debes conservar las funciones y respetar las limitaciones que describo.

El resultado debe sentirse como una herramienta nativa, cuidada y fluida. No quiero una página web de presentación ni un dashboard administrativo.

1. Qué es Terax

Terax permite pasar fotos, documentos y otros archivos entre un teléfono Android y una computadora Windows conectados a la misma red local.

Su interacción principal es enviar un archivo hacia el otro dispositivo mediante un gesto:

- En el teléfono, mantienes presionado un archivo dentro de la biblioteca y lo arrastras hacia el borde superior para enviarlo.
- También puedes tocar el archivo, abrir su vista previa y deslizar hacia arriba.
- Existe un botón de enviar como alternativa al gesto.
- En Windows, el archivo debe sentirse como si entrara por el borde inferior de la pantalla.
- Una vez recibido y verificado, puede abrirse en la aplicación correspondiente.

La intención es generar una sensación de continuidad entre teléfono y computadora: que el archivo parezca salir de uno y llegar al otro.

La referencia conceptual de movimiento es NameDrop de iPhone, adaptada a transferencia de archivos entre Android y Windows. No estamos implementando protocolos de Apple.

2. Para quién está pensada

Para alguien que está trabajando en su computadora, tiene el teléfono a la mano y quiere pasar un archivo rápidamente.

Ejemplos:

- Tomar una foto de un documento y abrirla en la PC.
- Pasar una captura del teléfono a Windows.
- Enviar un PDF para revisarlo en la computadora.
- Mandar un documento de Windows al teléfono.
- Transferir un archivo sin enviárselo por WhatsApp, correo o una nube.

La persona quiere resolver una tarea en segundos. No debería necesitar entender redes, certificados, direcciones IP ni Bluetooth para usar las funciones principales.

3. Cómo se conectan los dispositivos

La vinculación inicial se realiza una sola vez:

- La PC muestra un código QR.
- Android lo escanea.
- También se puede copiar y pegar un código de conexión.
- Ambos dispositivos guardan el vínculo.
- Después se buscan y reconectan automáticamente al abrir Terax.
- El vínculo sobrevive al cierre de la aplicación.

El QR no debe dominar la pantalla principal después de vincular los equipos.

Hay que distinguir visualmente estos conceptos:

- Vinculado: el equipo fue autorizado anteriormente.
- Conectado: está disponible para transferir por la red.
- Cerca: Bluetooth detecta una señal suficientemente fuerte y estable.
- Desconectado: está autorizado, pero actualmente no responde.

Un equipo puede estar conectado por Wi-Fi sin que la cercanía Bluetooth esté disponible.

4. Qué hace Bluetooth y qué no hace

Bluetooth se utiliza para detectar aproximadamente la cercanía entre dispositivos conocidos.

Actualmente:

- Windows anuncia una identidad mediante Bluetooth LE.
- Android busca los anuncios de sus equipos vinculados.
- Se analiza la intensidad de señal para decidir si el equipo está cerca.
- El teléfono comunica ese estado a la PC mediante la conexión autenticada.

Es importante respetar estas limitaciones:

- Bluetooth no transporta los archivos; los archivos viajan por la red local.
- Acercarse no autoriza por sí solo a un dispositivo desconocido.
- No medimos centímetros.
- No detectamos la posición exacta de la punta del teléfono respecto del monitor.
- No utilizamos UWB ni NFC.
- No se debe enviar un archivo solamente por acercar el teléfono.
- La transferencia sigue siendo posible por Wi-Fi si Bluetooth falla.

La interfaz debe comunicar los errores de Bluetooth de manera comprensible y permitir reintentar. No debe quedarse mostrando indefinidamente “Preparando…” sin explicar qué pasa.

5. Pantalla principal de Android

Actualmente Android abre una biblioteca dentro de Terax.

Sus elementos funcionales son:

- Identidad de la aplicación.
- Acceso a ajustes y equipos.
- Nombre del dispositivo de destino.
- Estado de conexión y cercanía.
- Acceso a vincular un equipo si hace falta.
- Sección de fotos.
- Sección de documentos.
- Buscador.
- Contenido de la biblioteca.
- Una explicación breve de los gestos, cuando resulte necesaria.

Puedes cambiar la composición, la jerarquía y la navegación. No tienes que conservar las tarjetas, pestañas ni tamaños actuales.

La biblioteca debe ocupar el protagonismo. No quiero que media pantalla se desperdicie con información técnica o una tarjeta enorme del dispositivo.

6. Biblioteca de fotos

La sección de fotos utiliza imágenes reales del teléfono.

Tiene:

- Miniaturas.
- Cuadrícula adaptable.
- Nombre del archivo.
- Fotos ordenadas con las recientes primero.
- Carga por páginas.
- Acción para cargar más fotos.
- Búsqueda por nombre entre los elementos cargados.
- Acceso a vista previa.
- Pulsación larga para arrastrar.

Hay que resolver bien:

- Fotografías verticales y horizontales.
- Capturas de pantalla.
- Nombres largos.
- Miniaturas que tardan en cargar.
- Imágenes que no se pueden leer.
- Biblioteca vacía.
- Permiso de fotos todavía no concedido.
- Acceso limitado a determinadas fotos.
- Búsqueda sin resultados.

La búsqueda actual es por nombre, no por reconocimiento del contenido de la imagen.

7. Biblioteca de documentos

Los documentos también se navegan dentro de Terax.

En Android:

- El usuario autoriza una carpeta mediante el selector del sistema.
- Esa autorización puede conservarse.
- Después navega por esa carpeta y sus subcarpetas dentro de Terax.
- Puede agregar otras carpetas.
- Puede volver a la carpeta anterior.

El selector nativo es necesario para conceder acceso a una carpeta, pero no debe aparecer cada vez que se quiere enviar un archivo.

En Windows se utilizan carpetas locales, como Documentos y Descargas, y se pueden agregar otras.

Cada elemento necesita representar claramente:

- Nombre.
- Tipo de archivo.
- Tamaño cuando esté disponible.
- Si es un archivo o una carpeta.
- Acción principal.
- Disponibilidad o problema de acceso.

La vista previa actual de documentos es una representación del archivo con su extensión y nombre. No existe todavía un lector completo integrado de PDF, Word o Excel.

Si propones una vista previa más avanzada, identifícala como una ampliación funcional.

8. Primer gesto: arrastrar al borde superior

El flujo debe ser:

1. Mantengo presionado un archivo.
2. El archivo se desprende visualmente de la biblioteca.
3. Aparece una indicación discreta de que puedo llevarlo hacia arriba.
4. Arrastro el archivo al borde superior.
5. La zona responde cuando el archivo entra.
6. La indicación cambia a “Suelta para enviar”.
7. Al soltarlo, comienza el envío.

La zona de recepción del gesto no debe parecer un formulario, un cuadro de carga o un panel pegado encima de la pantalla.

Problemas que quiero evitar:

- Un rectángulo grande y opaco en la parte superior.
- Un brillo que termina con un corte horizontal evidente.
- Una franja blanca que tape la interfaz.
- Óvalos o círculos decorativos sin una función clara.
- Texto blanco ilegible sobre un resplandor blanco.

Busco una integración orgánica con el borde: luz suave, desvanecimiento progresivo y una indicación pequeña y legible.

El área donde se puede soltar el archivo debe ser fácil de alcanzar y reconocer, aunque su representación visual sea discreta.

9. Segundo gesto: vista previa y swipe hacia arriba

El flujo alternativo es:

1. Toco una foto o un documento.
2. Se abre una vista previa amplia.
3. Puedo identificar claramente lo que estoy enviando.
4. Deslizo el objeto hacia arriba.
5. Si el gesto es suficiente, se envía.
6. Si es demasiado corto, vuelve suavemente a su posición.

La vista previa debe mostrar:

- El archivo como elemento principal.
- Nombre.
- Tamaño.
- Destino.
- Estado de disponibilidad del destino.
- Volver a la biblioteca.
- Botón alternativo para enviar.

En fotos, debe respetarse la proporción de la imagen.

No quiero una imagen metida dentro de otro cuadro genérico que diga “coloca aquí tu archivo”. El propio archivo debe ser el objeto que manipulo.

10. Animación de envío y recepción

La animación es parte central de la identidad de Terax.

Busco:

- Una reacción inmediata al gesto.
- Movimiento continuo y comprensible.
- Una luz que nace del borde.
- Una onda que se expande.
- Sensación de que el archivo atraviesa el límite entre dispositivos.
- Correspondencia visual entre lo que ocurre en Android y Windows.

En Android, el archivo sale hacia arriba.

En Windows, aparece desde abajo y se acomoda en una posición legible.

La animación debe coordinarse con acontecimientos reales:

- Antes de subir el archivo, el emisor anuncia al receptor lo que enviará.
- Cuando el receptor confirma que está listo, puede empezar la transición coordinada.
- La recepción puede mostrar una miniatura de la foto antes de tener el archivo completo.
- La confirmación de éxito solo aparece después de recibir y verificar el archivo.
- Un archivo muy pequeño también debe tener una transición perceptible.
- Un error no debe quedar oculto detrás de una animación de éxito.

Estados que necesitan tratamiento propio:

- Preparando envío.
- Preparando recepción.
- Enviando.
- Recibiendo.
- Verificando.
- Enviado.
- Recibido y verificado.
- Cancelado.
- Fallido.

Debe existir una alternativa con movimiento reducido. No dependas de animaciones para comunicar información esencial.

11. Aplicación de Windows

Windows tiene dos usos principales: recibir y enviar archivos.

La vista de recepción debería comunicar rápidamente:

- Terax está listo.
- Qué teléfono está conectado.
- Si el teléfono está cerca.
- Si la recepción está permitida.
- Qué está llegando.
- Dónde quedó guardado.
- Qué puedo hacer después.

Debe aprovechar el espacio de escritorio sin convertirse en un dashboard lleno de tarjetas vacías.

La vista de envío permite:

- Explorar la biblioteca local.
- Buscar archivos.
- Seleccionar un archivo.
- Ver una representación o vista previa.
- Enviarlo al teléfono conectado.

También existe acceso a la carpeta de archivos recibidos.

Puedes proponer una mejor navegación que las pestañas actuales, siempre que ambas tareas sigan siendo claras.

12. Efecto fuera de la ventana de Windows

Existe un componente nativo pensado para mostrar una onda sobre el escritorio, incluso si la ventana de Terax está minimizada u oculta en la bandeja.

Su intención es:

- La luz aparece desde el borde inferior del monitor.
- Una onda produce una ligera distorsión del contenido visible.
- Se percibe la llegada sin tener que abrir primero la ventana principal.
- El efecto desaparece y permite seguir trabajando.

La implementación actual:

- Captura un fotograma del monitor en memoria.
- Deforma esa imagen con la GPU.
- Lo muestra durante aproximadamente 1.8 segundos.
- Descarta la captura al terminar.
- No guarda ni envía capturas del escritorio.
- No es una captura de vídeo continua.

Por tanto, no diseñes una experiencia que dependa de deformar vídeo en tiempo real si eso requiere desarrollar otra implementación.

La capa está pensada para no robar el foco ni bloquear la interacción. Si no puede mostrarse, debe existir una alternativa dentro de la aplicación.

En ajustes hay:

- Activar o desactivar el efecto.
- Probar el efecto de escritorio.

Este componente ha requerido correcciones y su apariencia final necesita validación visual en dispositivos reales. No lo presentes como una capacidad universal e infalible.

13. Comportamiento de Windows en segundo plano

Terax dispone de un icono en la bandeja del sistema.

- Cerrar la ventana mantiene la aplicación funcionando.
- Desde la bandeja se puede volver a abrir.
- Existe una acción explícita para salir completamente.
- Solo se permite una instancia por sesión.
- No hay autoinicio configurado actualmente.

El diseño debe explicar este comportamiento de manera breve, especialmente la primera vez que el usuario cierra la ventana.

En Android, actualmente se necesita mantener Terax abierto y el teléfono activo durante la transferencia. No diseñes como existente un servicio de recepción permanente en segundo plano.

14. Qué ocurre cuando llega un archivo

Después de la recepción:

- Se verifica su integridad.
- Se guarda sin sobrescribir directamente otro archivo con el mismo nombre.
- Se muestra el resultado.
- Existe una acción para abrirlo.
- Se registra en la actividad de la sesión.

En Windows se puede activar la apertura automática de fotos y documentos compatibles.

La apertura automática debe suceder después de la verificación y de dejar percibir la llegada.

Formatos contemplados para apertura automática:

- Fotos: PNG, JPG/JPEG, WebP, GIF y BMP.
- Documentos: PDF, DOCX, XLSX, PPTX, ODT, ODS, ODP, TXT, CSV, Markdown y RTF.

Límites actuales de apertura automática:

- Fotos de hasta 32 MiB y 40 megapíxeles.
- Documentos de hasta 64 MiB.
- No se abren ejecutables ni archivos con macros automáticamente.
- Se utiliza la aplicación instalada que corresponda.
- Puede no existir una aplicación compatible; ese caso necesita un mensaje útil.

Estos límites son de apertura automática, no el límite general de transferencia.

15. Ajustes y equipos

Actualmente están disponibles estas funciones:

- Ver equipos vinculados.
- Conectar otro equipo.
- Mostrar el QR de este dispositivo.
- Copiar su código de conexión.
- Escanear un QR desde Android.
- Pegar un código.
- Consultar la dirección de red.
- Elegir una dirección si hay varias interfaces.
- Actualizar la información de red.
- Activar o reintentar cercanía Bluetooth.
- Ver el estado de Bluetooth.
- Abrir los permisos de Terax en Android.
- Permitir o pausar la recepción.
- Activar la apertura automática de archivos compatibles.
- Activar, desactivar y probar el efecto de escritorio en Windows.
- Restablecer los vínculos.
- Consultar la actividad de esta sesión.

Puedes separar ajustes, equipos y actividad en superficies distintas si mejora la experiencia.

Las direcciones IP y detalles técnicos deben quedar en un nivel secundario.

Restablecer vínculos es una acción delicada: invalida las autorizaciones anteriores y requiere vincular de nuevo. No borra los archivos recibidos. Debe explicarse antes de confirmarla.

16. Historial y almacenamiento

El historial actual:

- Es de la sesión.
- Mantiene hasta 50 entradas en memoria.
- La interfaz muestra las 10 más recientes.
- Incluye nombre, tamaño, dirección del envío y acceso al archivo.
- Se pierde al cerrar completamente la aplicación.
- Los archivos guardados no se borran por perder el historial.

En Windows, los recibidos se guardan en una carpeta Terax/Recibidos dentro de Documentos.

En Android se guardan en el espacio privado de la aplicación y se pueden abrir mediante una aplicación compatible.

No diseñes el historial actual como si fuera una biblioteca permanente sincronizada.

17. Límites funcionales que debes respetar

Actualmente:

- Un archivo por envío.
- Tamaño máximo de 1 GiB por archivo.
- Una recepción simultánea.
- Sin cola de múltiples archivos.
- Sin reanudación desde el punto de interrupción.
- Puede haber varios equipos guardados, pero eso no equivale a envío simultáneo a varios destinos.
- Ambos dispositivos necesitan conectividad por la red local.
- La proximidad Bluetooth es opcional.
- No requiere cuentas de usuario ni una nube.
- No hay integración con Raspberry Pi, NAS o discos remotos.

El transporte utiliza HTTPS local, autorización guardada y verificación de integridad. Eso debe traducirse en confianza y claridad, no en llenar la pantalla de términos criptográficos.

18. Estados vacíos, errores y permisos

Diseña explícitamente estas situaciones:

- Primera apertura.
- Ningún equipo vinculado.
- Equipo vinculado pero apagado.
- Reconectando.
- Conectado por Wi-Fi sin cercanía.
- Equipo cercano y conectado.
- Bluetooth apagado.
- Radio Bluetooth no disponible.
- Permiso de dispositivos cercanos denegado.
- Cámara sin permiso.
- QR incorrecto.
- Código de conexión inválido.
- Sin acceso a fotos.
- Acceso parcial a fotos.
- Carpeta todavía no autorizada.
- Permiso de carpeta vencido.
- Biblioteca vacía.
- Búsqueda sin resultados.
- Archivo que ya no existe o no se puede leer.
- Archivo demasiado grande.
- Destino ocupado.
- Recepción pausada.
- Conexión perdida durante el envío.
- Envío cancelado.
- Error de integridad.
- Archivo recibido sin aplicación para abrirlo.
- Efecto de escritorio no disponible.

Cada estado necesita una explicación breve y una acción pertinente cuando sea posible. Evita errores genéricos y controles que parecen no hacer nada.

19. Dirección visual buscada

Quiero una herramienta con personalidad, pero que se sienta sencilla.

Características deseadas:

- Tema oscuro cuidado.
- Buen contraste.
- Jerarquía clara.
- Tipografía legible.
- Miniaturas protagonistas.
- Espaciado consistente.
- Controles cómodos con una mano en Android.
- Uso natural de ratón y teclado en Windows.
- Movimiento fluido asociado a acciones concretas.
- Materiales y transparencias moderados.
- Información técnica accesible, pero secundaria.

El diseño actual utiliza un fondo oscuro azulado y acentos menta/turquesa. Puedes evolucionar esa identidad si tienes una propuesta mejor.

Cosas que rechazo:

- Paneles rectangulares superpuestos que se ven ajenos al resto.
- Brillos cortados por los límites de un contenedor.
- Óvalos decorativos flotando sin una función clara.
- Resplandores que impiden leer.
- Tarjetas gigantes con poco contenido.
- Controles genéricos sobredimensionados.
- Una interfaz que parezca un panel administrativo.
- Una copia superficial de iOS con una isla dinámica falsa.
- Animaciones espectaculares desconectadas del estado real.

La referencia de movimiento que proporcioné es:

https://www.figma.com/design/bV9QctUEetDsPgfPnN5x5z/Name-Drop--iOS-17--Free-Animation--Community-?node-id=0-1

Toma de ahí la continuidad, la luz y la expansión de la onda. No copies sus contactos, fondos ni pantalla de bloqueo.

20. Accesibilidad y adaptación

El diseño debe funcionar:

- Desde 320 px de ancho en Android.
- En teléfonos de distintos tamaños.
- Con texto aumentado.
- Con nombres largos.
- Con navegación por teclado en Windows.
- Con lector de pantalla.
- Con movimiento reducido.

Las acciones importantes deben tener una alternativa visible al gesto.

No comuniques conexión, error o éxito únicamente mediante color.

Respeta las barras del sistema y las áreas seguras de Android. No simules que la app controla toda la pantalla física del teléfono.

21. Funciones futuras, todavía no implementadas

Estas ideas pueden aparecer en una propuesta de evolución, pero deben quedar separadas del rediseño actual:

- Compartir hacia Terax desde otras aplicaciones de Android.
- Selección y envío múltiple.
- Cola de transferencias.
- Reanudación después de un corte.
- Portapapeles entre dispositivos.
- Enviar enlaces para abrirlos en el otro equipo.
- Arrastrar archivos desde el Explorador de Windows.
- Integración con el menú contextual de Windows.
- Historial persistente.
- Notificaciones con acciones y vista previa.

No conviertas estas ideas en funciones supuestamente existentes.

22. Qué necesito que entregues

Quiero que desarrolles una propuesta completa que incluya:

- Concepto visual y explicación de las decisiones principales.
- Arquitectura de navegación para Android y Windows.
- Pantallas principales de ambas plataformas.
- Vinculación inicial.
- Biblioteca de fotos.
- Biblioteca de documentos.
- Vista previa.
- Arrastre hacia el borde superior.
- Estado de “suelta para enviar”.
- Preparación, transferencia, verificación y resultado.
- Recepción en Windows.
- Experiencia con Windows minimizado.
- Ajustes, equipos y actividad.
- Estados vacíos, permisos y errores.
- Sistema de componentes y estilos.
- Especificación de las animaciones: disparador, recorrido, duración, finalización y alternativa con movimiento reducido.
- Textos de interfaz en español.

La aplicación está desarrollada en Flutter/Dart, con componentes nativos para algunas funciones de Windows y Android. La propuesta debe ser viable para trasladarla a ese entorno.

No te limites a embellecer las pantallas actuales. Reorganiza la experiencia para que conectar, encontrar un archivo, enviarlo y entender que llegó requieran la menor atención posible.
