/// Friendly UI copy; transport messages remain unchanged.
enum UiIssueKind {
  bluetoothOff,
  bluetoothUnavailable,
  nearbyPermission,
  cameraPermission,
  foreignQr,
  invalidCode,
  unreachable,
  reconnecting,
  partialPhotos,
  folderPermission,
  missingFile,
  oversize,
  busy,
  paused,
  noViewer,
  effectUnavailable,
  tray,
  automaticSkipped,
  unlinked,
  noResults,
  connection,
}

class UiIssue {
  const UiIssue(this.kind, this.title, this.body, this.action);
  final UiIssueKind kind;
  final String title, body;
  final String? action;
  static UiIssue describe(UiIssueKind kind) => switch (kind) {
    UiIssueKind.bluetoothOff => const UiIssue(
      UiIssueKind.bluetoothOff,
      'Bluetooth apagado',
      'Puedes seguir enviando por Wi-Fi. Actívalo para saber cuándo tu PC está cerca.',
      'Activar Bluetooth',
    ),
    UiIssueKind.bluetoothUnavailable => const UiIssue(
      UiIssueKind.bluetoothUnavailable,
      'Sin Bluetooth en este equipo',
      'Terax funciona igual por Wi-Fi; solo no sabremos si están cerca.',
      null,
    ),
    UiIssueKind.nearbyPermission => const UiIssue(
      UiIssueKind.nearbyPermission,
      'Sin permiso de dispositivos cercanos',
      'Sin él no podemos detectar si tu PC está cerca.',
      'Abrir permisos',
    ),
    UiIssueKind.cameraPermission => const UiIssue(
      UiIssueKind.cameraPermission,
      'Cámara sin permiso',
      'La necesitamos solo para escanear el código QR de tu PC.',
      'Abrir permisos',
    ),
    UiIssueKind.foreignQr => const UiIssue(
      UiIssueKind.foreignQr,
      'Ese QR no es de Terax',
      'Escanea el código que aparece en Terax, en tu PC.',
      'Volver a escanear',
    ),
    UiIssueKind.invalidCode => const UiIssue(
      UiIssueKind.invalidCode,
      'Código de conexión inválido',
      'Está incompleto o ya venció. Copia uno nuevo desde tu PC.',
      'Pegar otro código',
    ),
    UiIssueKind.unreachable => const UiIssue(
      UiIssueKind.unreachable,
      'Tu equipo no responde',
      'Sigue vinculado. ¿Está encendido, con Terax abierto y en la misma red?',
      'Equipos y ajustes',
    ),
    UiIssueKind.reconnecting => const UiIssue(
      UiIssueKind.reconnecting,
      'Reconectando…',
      'Buscando tu equipo en la red. Esto suele tardar unos segundos.',
      null,
    ),
    UiIssueKind.partialPhotos => const UiIssue(
      UiIssueKind.partialPhotos,
      'Acceso parcial a fotos',
      'Solo ves las fotos que elegiste.',
      'Elegir más fotos',
    ),
    UiIssueKind.folderPermission => const UiIssue(
      UiIssueKind.folderPermission,
      'Carpeta sin permiso',
      'Android retiró el acceso. Autorízala otra vez.',
      'Volver a autorizar',
    ),
    UiIssueKind.missingFile => const UiIssue(
      UiIssueKind.missingFile,
      'El archivo ya no existe',
      'Se movió o se borró desde que abriste la biblioteca.',
      'Actualizar',
    ),
    UiIssueKind.oversize => const UiIssue(
      UiIssueKind.oversize,
      'Archivo demasiado grande',
      'El máximo por archivo es 1 GB.',
      null,
    ),
    UiIssueKind.busy => const UiIssue(
      UiIssueKind.busy,
      'Tu equipo está ocupado',
      'Está recibiendo otro archivo. Inténtalo cuando termine.',
      'Reintentar',
    ),
    UiIssueKind.paused => const UiIssue(
      UiIssueKind.paused,
      'Recepción pausada',
      'El equipo receptor no está aceptando archivos ahora. Activa la recepción allí.',
      'Equipos y ajustes',
    ),
    UiIssueKind.noViewer => const UiIssue(
      UiIssueKind.noViewer,
      'No se pudo abrir el archivo',
      'Se guardó bien. Comprueba que tienes una aplicación compatible.',
      'Mostrar en carpeta',
    ),
    UiIssueKind.effectUnavailable => const UiIssue(
      UiIssueKind.effectUnavailable,
      'Efecto de escritorio no disponible',
      'No se pudo mostrar la onda. La recepción sigue disponible.',
      'Probar efecto',
    ),
    UiIssueKind.tray => const UiIssue(
      UiIssueKind.tray,
      'Terax sigue en la bandeja',
      'Para cerrarlo del todo, usa Salir desde su icono.',
      'Entendido',
    ),
    UiIssueKind.automaticSkipped => const UiIssue(
      UiIssueKind.automaticSkipped,
      'No se abrió automáticamente',
      'Los ejecutables y archivos con macros nunca se abren solos.',
      'Mostrar en carpeta',
    ),
    UiIssueKind.unlinked => const UiIssue(
      UiIssueKind.unlinked,
      'Ningún equipo vinculado',
      'Vincula tu PC una vez y después se reconectan solos.',
      'Vincular PC',
    ),
    UiIssueKind.noResults => const UiIssue(
      UiIssueKind.noResults,
      'Búsqueda sin resultados',
      'Ningún archivo cargado coincide. Se busca por nombre.',
      null,
    ),
    UiIssueKind.connection => const UiIssue(
      UiIssueKind.connection,
      'Revisa la conexión',
      'Comprueba que ambos equipos estén en la misma red y con Terax abierto.',
      'Equipos y ajustes',
    ),
  };
  static UiIssue fromMessage(String message) {
    final s = message.toLowerCase();
    return describe(
      s.contains('integridad')
          ? UiIssueKind.connection
          : s.contains('pausada')
          ? UiIssueKind.paused
          : s.contains('recibiendo un archivo') || s.contains('ocupad')
          ? UiIssueKind.busy
          : s.contains('permiso') && s.contains('carpeta')
          ? UiIssueKind.folderPermission
          : s.contains('no está disponible') || s.contains('ya no')
          ? UiIssueKind.missingFile
          : s.contains('1 gib') || s.contains('1 gb') || s.contains('límite')
          ? UiIssueKind.oversize
          : s.contains('código')
          ? UiIssueKind.invalidCode
          : s.contains('abrir el archivo')
          ? UiIssueKind.noViewer
          : s.contains('no responde')
          ? UiIssueKind.unreachable
          : UiIssueKind.connection,
    );
  }
}
