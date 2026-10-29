# Terax: biblioteca y transferencia continua

## Alcance aprobado
El usuario pide reemplazar la selección nativa por una biblioteca dentro de Terax, eliminar el cuadro de envío, coordinar animaciones en emisor y receptor, inspirarse en acercar el borde superior del teléfono a la parte inferior de la PC, abrir documentos y corregir cercanía. Confirmó **ambas formas**: arrastrar desde la biblioteca y swipe desde vista previa.

## Diseño
Android abre una biblioteca de fotos/archivos en la propia app, con búsqueda y vista previa amplia. Mantener presionado permite arrastrar al borde superior, o abrir y deslizar el archivo hacia arriba. No hay tarjeta de preparación separada. Un borde luminoso representa el destino y responde a cercanía verificada por BLE y conexión TLS. El gesto emite una oferta autenticada de transferencia antes de calcular el hash; el receptor reconoce el archivo y comienza su animación de llegada desde el borde inferior. El emisor inicia el lanzamiento tras recibir la confirmación. La llegada y el progreso corresponden a estados reales, no a un temporizador de éxito.

Windows prioriza un lienzo de recepción con la entrada desde abajo, nombre/tipo del archivo y progreso. La configuración de vínculos/QR queda en ajustes. La apertura automática opcional admite fotos y documentos comunes con la aplicación asociada, después de verificar el archivo y terminar el aterrizaje visual. El botón Abrir sigue disponible.

## Arquitectura
Oferta con ID y reserva temporal de receptor, confirmación de disponibilidad, upload vinculado a la oferta, cancelación y expiración. Se conserva streaming, SHA-256, token persistente y fijación TLS. Android obtiene fotos con permisos de biblioteca; documentos mediante una carpeta autorizada una vez (SAF), navegada internamente después. No solicita acceso total al almacenamiento.

## Bluetooth
El publicador Windows no admite Service UUIDs en anuncios arbitrarios. Se sustituye por datos de fabricante con marcador/version e identificador del equipo; Android filtra el marcador de equipos autorizados. El error real del publicador debe ser visible, con comprobación nativa del anuncio. BLE aporta cercanía aproximada y selección, no autorización ni ubicación exacta de la punta del teléfono respecto al monitor.

## Alternativas y decisiones
Mantener el selector nativo con cambios cosméticos no cumple la solicitud. Una biblioteca propia con dos gestos fue la recomendación y la elección del usuario. Acceso SAF por carpeta evita permisos generales y permite documentos fuera de la galería. Animaciones de borde coordinadas por protocolo permiten empezar en ambos equipos aunque el archivo todavía se esté preparando.

## Verificación y límites
Pruebas reales de oferta/transferencia TLS, cancelación, reserva y limpieza; pruebas de gestos, biblioteca, políticas de apertura y layouts. Compilar Windows y APK actualizado, comprobar el anuncio con el adaptador real de la PC y revisar visualmente ambos tamaños. Sin teléfono conectado, la detección entre dos dispositivos físicos debe quedar señalada como pendiente, con diagnóstico concreto.
