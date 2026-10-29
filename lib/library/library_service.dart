// ignore_for_file: prefer_initializing_formals
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

enum LibraryKind { photo, document }

@immutable
class LibraryItem {
  // Public callback names keep callers independent of implementation details.
  const LibraryItem({
    required this.id,
    required this.name,
    required this.isDirectory,
    required this.isImage,
    required this.size,
    required this.modified,
    this.localFile,
    this.location,
    Future<File> Function()? resolver,
    Future<Uint8List?> Function(int)? thumbnailLoader,
  }) : _resolver = resolver,
       _thumbnailLoader = thumbnailLoader;
  final String id, name;
  final bool isDirectory, isImage;
  final int size;
  final DateTime modified;
  final File? localFile;
  final String? location;
  final Future<File> Function()? _resolver;
  final Future<Uint8List?> Function(int)? _thumbnailLoader;
  Future<Uint8List?> thumbnail({int size = 320}) async =>
      _thumbnailLoader?.call(size);
  Future<File> resolve() async {
    if (isDirectory) throw StateError('Selecciona un archivo.');
    final file = localFile ?? await _resolver?.call();
    if (file == null || !await file.exists()) {
      throw StateError('El archivo ya no está disponible.');
    }
    if (await file.length() > 1073741824) {
      throw StateError('El archivo supera el límite de 1 GB.');
    }
    return file;
  }
}

class LibraryService extends ChangeNotifier {
  LibraryService({bool? android, Map<LibraryKind, List<Directory>>? roots})
    : _android = android ?? Platform.isAndroid,
      _roots = roots;
  static const _channel = MethodChannel('terax/library');
  static const photoPermission = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );
  final bool _android;
  final Map<LibraryKind, List<Directory>>? _roots;
  List<LibraryItem> items = [];
  bool loading = false;
  String? error;
  String locationLabel = 'Biblioteca';
  bool hasMore = false;
  PermissionState? photoAccess;
  bool canChoosePhotos = false;
  List<LibraryItem> _authorizedFolders = [];
  final List<String> _folderTrail = [];
  List<LibraryItem> get authorizedFolders =>
      List.unmodifiable(_authorizedFolders);
  List<String> get folderTrail => List.unmodifiable(_folderTrail);
  bool get photosLimited => photoAccess == PermissionState.limited;
  bool get photosDenied => photoAccess != null && !photoAccess!.hasAccess;
  Future<void> chooseMorePhotos() async {
    if (!_android || loading || !canChoosePhotos) return;
    final generation = _generation;
    try {
      await PhotoManager.presentLimited(type: RequestType.image);
      if (!_disposed &&
          generation == _generation &&
          kind == LibraryKind.photo) {
        await load(LibraryKind.photo);
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error =
            'No se pudo abrir la selección de fotos. Revisa los permisos de Terax.';
        _notify();
      }
    }
  }

  Future<void> openPhotoSettings() => PhotoManager.openSetting();
  LibraryKind kind = LibraryKind.photo;
  final List<String> _history = [];
  String? _location;
  AssetPathEntity? _album;
  int _page = 0;
  bool _disposed = false;
  int _generation = 0;
  bool get canGoBack => _history.isNotEmpty;
  String? get currentLocation => _location;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load(LibraryKind kind, {bool requestPermission = false}) async {
    this.kind = kind;
    _history.clear();
    _folderTrail.clear();
    _location = null;
    _album = null;
    _page = 0;
    await _read(requestPermission: requestPermission);
  }

  Future<void> _read({
    bool requestPermission = false,
    bool append = false,
  }) async {
    final generation = ++_generation;
    final currentKind = kind;
    var location = _location;
    var album = _album;
    final page = append ? _page + 1 : 0;
    var more = false;
    var label = locationLabel;
    loading = true;
    error = null;
    _notify();
    try {
      List<LibraryItem> result;
      more = false;
      if (_android && currentKind == LibraryKind.photo) {
        final api = int.tryParse(await PhotoManager.systemVersion()) ?? 0;
        if (generation == _generation) canChoosePhotos = api >= 34;
        final permission = requestPermission
            ? await PhotoManager.requestPermissionExtend(
                requestOption: photoPermission,
              )
            : await PhotoManager.getPermissionState(
                requestOption: photoPermission,
              );
        if (generation == _generation) photoAccess = permission;
        if (!permission.hasAccess) {
          throw StateError('Permite acceso a tus fotos para verlas aquí.');
        }
        album ??= (await PhotoManager.getAssetPathList(
          type: RequestType.image,
          onlyAll: true,
          filterOption: FilterOptionGroup(
            orders: const [
              OrderOption(type: OrderOptionType.updateDate),
              OrderOption(type: OrderOptionType.createDate),
            ],
          ),
        )).firstOrNull;
        final assets =
            await album?.getAssetListPaged(page: page, size: 80) ??
            <AssetEntity>[];
        more = assets.length == 80;
        label = 'Tus fotos';
        result = assets
            .map(
              (asset) => LibraryItem(
                id: asset.id,
                name: asset.title ?? 'Foto',
                isDirectory: false,
                isImage: true,
                size: 0,
                modified: asset.modifiedDateTime,
                resolver: () async {
                  final f = await asset.originFile;
                  if (f == null) throw StateError('No se pudo abrir la foto.');
                  return f;
                },
                thumbnailLoader: (size) =>
                    asset.thumbnailDataWithSize(ThumbnailSize(size, size)),
              ),
            )
            .toList();
      } else if (_android) {
        final data = await _channel.invokeListMethod<dynamic>('list', {
          'location': location,
        });
        label = location == null
            ? 'Carpetas permitidas'
            : (Uri.tryParse(location)?.pathSegments.lastOrNull ?? 'Carpeta');
        result = (data ?? []).map(_androidRow).toList();
      } else {
        final profile =
            Platform.environment['USERPROFILE'] ??
            Platform.environment['HOME'] ??
            '.';
        final roots =
            _roots?[currentKind] ??
            [
              Directory(
                p.join(
                  profile,
                  currentKind == LibraryKind.photo ? 'Pictures' : 'Documents',
                ),
              ),
              if (currentKind == LibraryKind.document)
                Directory(p.join(profile, 'Downloads')),
            ];
        if (currentKind == LibraryKind.document) {
          _authorizedFolders = roots.map((r) => _directory(r.path)).toList();
        }
        if (location == null && roots.length == 1) {
          location = roots.single.path;
        }
        if (location == null) {
          result = [
            for (final root in roots)
              if (await root.exists()) _directory(root.path),
          ];
          label = currentKind == LibraryKind.photo ? 'Fotos' : 'Documentos';
        } else {
          final entries = await Directory(
            location,
          ).list(followLinks: false).toList();
          result = [];
          for (final entry in entries) {
            if (entry is Directory) {
              result.add(_directory(entry.path));
            } else if (entry is File) {
              final image = _image(entry.path);
              if (currentKind == LibraryKind.photo && !image) continue;
              final stat = await entry.stat();
              result.add(
                LibraryItem(
                  id: entry.path,
                  name: p.basename(entry.path),
                  isDirectory: false,
                  isImage: image,
                  size: stat.size,
                  modified: stat.modified,
                  localFile: entry,
                ),
              );
            }
          }
          label = p.basename(location);
        }
      }
      // Android pages retain the provider's explicit ordering; local photos
      // use modification time with an ID tie breaker.
      if (!(_android && currentKind == LibraryKind.photo)) {
        result.sort((a, b) {
          if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
          if (currentKind == LibraryKind.photo && !a.isDirectory) {
            final date = b.modified.compareTo(a.modified);
            return date != 0 ? date : a.id.compareTo(b.id);
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }
      if (generation == _generation) {
        if (currentKind == LibraryKind.document && location == null) {
          _authorizedFolders = result
              .where((item) => item.isDirectory)
              .toList();
        }
        _location = location;
        _album = album;
        _page = page;
        hasMore = more;
        locationLabel = label;
        final combined = append ? [...items, ...result] : result;
        final seen = <String>{};
        items = List.unmodifiable(combined.where((item) => seen.add(item.id)));
      }
    } catch (e) {
      if (generation == _generation) {
        error = e is PlatformException
            ? (e.message ?? 'No se pudo acceder a la carpeta.')
            : e.toString().replaceFirst('Bad state: ', '');
        if (!append) items = [];
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  LibraryItem _androidRow(dynamic raw) {
    final row = Map<String, dynamic>.from(raw as Map);
    final uri = row['id'] as String;
    return LibraryItem(
      id: uri,
      name: row['name'] as String,
      isDirectory: row['directory'] == true,
      isImage: (row['mime'] as String? ?? '').startsWith('image/'),
      size: (row['size'] as num?)?.toInt() ?? 0,
      modified: DateTime.fromMillisecondsSinceEpoch(
        (row['modified'] as num?)?.toInt() ?? 0,
      ),
      location: uri,
      resolver: () async => File(
        (await _channel.invokeMethod<String>('materialize', {
          'uri': uri,
          'name': row['name'],
        }))!,
      ),
    );
  }

  static bool _image(String path) => [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.avif',
  ].contains(p.extension(path).toLowerCase());
  static LibraryItem _directory(String path) => LibraryItem(
    id: path,
    name: p.basename(path),
    isDirectory: true,
    isImage: false,
    size: 0,
    modified: DateTime.fromMillisecondsSinceEpoch(0),
    location: path,
  );
  bool isRootActive(LibraryItem root) =>
      (_history.length > 1 ? _history[1] : _location) ==
      (root.location ?? root.id);
  Future<void> openAuthorizedFolder(LibraryItem root) async {
    if (loading) return;
    _history.clear();
    _folderTrail.clear();
    _location = null;
    await openFolder(root);
  }

  Future<void> openFolder(LibraryItem item) async {
    if (!item.isDirectory || loading) return;
    _history.add(_location ?? '');
    _folderTrail.add(item.name);
    _location = item.location ?? item.id;
    await _read();
  }

  Future<void> goBack() async {
    if (!canGoBack || loading) return;
    final previous = _history.removeLast();
    if (_folderTrail.isNotEmpty) _folderTrail.removeLast();
    _location = previous.isEmpty ? null : previous;
    await _read();
  }

  Future<void> addFolder() async {
    if (loading) return;
    if (_android && kind == LibraryKind.photo) {
      await load(kind, requestPermission: true);
      return;
    }
    final generation = _generation;
    final currentKind = kind;
    try {
      final folder = _android
          ? await _channel.invokeMethod<String>('chooseFolder')
          : await FilePicker.getDirectoryPath();
      if (_disposed || generation != _generation || currentKind != kind) return;
      if (folder != null) {
        var chosenLocation = folder;
        _history.clear();
        _folderTrail.clear();
        _location = null;
        _history.add('');
        _folderTrail.add(
          Uri.tryParse(
                folder,
              )?.pathSegments.lastOrNull?.split('/').last.split(':').last ??
              p.basename(folder),
        );
        if (_android) {
          try {
            final roots = await _channel.invokeListMethod<dynamic>('list', {
              'location': null,
            });
            if (_disposed || generation != _generation || currentKind != kind) {
              return;
            }
            _authorizedFolders = (roots ?? []).map(_androidRow).toList();
            final chosen = _authorizedFolders
                .where(
                  (r) =>
                      Uri.tryParse(r.id)?.pathSegments.contains(
                        Uri.tryParse(folder)?.pathSegments.last,
                      ) ==
                      true,
                )
                .firstOrNull;
            if (chosen != null) {
              _folderTrail[_folderTrail.length - 1] = chosen.name;
              chosenLocation = chosen.location ?? chosen.id;
            }
          } catch (_) {
            /* Directory read below retains the original permission error. */
          }
        }
        _location = chosenLocation;
        await _read();
      }
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e is PlatformException ? e.message : e.toString();
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    await _read(append: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
