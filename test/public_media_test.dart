import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/transfer/history_store.dart';
import 'package:terax/transfer/identity.dart';
import 'package:terax/transfer/protocol.dart';
import 'package:terax/transfer/transport.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/ui/home.dart';

class _History implements TransferHistoryStore {
  @override
  Future<List<HistoryEntry>> load() async => [];
  @override
  Future<void> save(List<HistoryEntry> rows) async {}
}

void main() {
  if (Platform.environment['TERAX_PUBLIC_MEDIA'] != '1') return;
  testWidgets(
    'capture current app with non-personal public demonstration data',
    (tester) async {
      for (final font in {
        'Figtree': 'assets/fonts/Figtree-VariableFont_wght.ttf',
        'GeistMono': 'assets/fonts/GeistMono-Regular.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(font.key)
          ..addFont(rootBundle.load(font.value));
        await loader.load();
      }
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late ServerIdentity identity;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('terax-public-');
        identity = await ServerIdentity.generate();
      });
      final c =
          AppController(
              documentsDirectory: () async => root,
              historyStore: _History(),
            )
            ..starting = false
            ..peerOnline = true
            ..peer = PairingInfo(
              host: '192.168.1.2',
              port: 4040,
              token: 'a' * 64,
              fingerprint: 'b' * 64,
              name: 'Mi PC',
            );
      c.server = TransferServer(
        directory: Directory("${root.path}/Documentos/Terax/Recibidos"),
        identity: identity,
        name: 'Terax',
        token: 'a' * 64,
      );
      final library = LibraryService(android: false)
        ..kind = LibraryKind.photo
        ..locationLabel = 'Tus fotos'
        ..photoAccess = PermissionState.authorized;
      final names = [
        'Brisa',
        'Costa',
        'Horizonte',
        'Bosque',
        'Aurora',
        'Arena',
      ];
      library.items = [
        for (var i = 0; i < 6; i++)
          LibraryItem(
            id: 'public-$i',
            name: '${names[i]}.jpg',
            isDirectory: false,
            isImage: true,
            size: 24000 + i * 1024,
            modified: DateTime.now(),
            localFile: File('test/fixtures/public_media/wallpaper-$i.jpg'),
          ),
      ];
      final key = GlobalKey();
      Future<void> warm() async {
        for (var i = 0; i < 7; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
        }
      }

      Future<void> shot(String name) async {
        await warm();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'docs/media/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> mount(TeraxPlatform platform, Size size) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: TeraxTheme.build(platform),
              home: Home(controller: c, library: library),
            ),
          ),
        );
        await warm();
      }

      await mount(TeraxPlatform.android, const Size(412, 892));
      await tester.pump(const Duration(milliseconds: 1200));
      await shot('android-library');
      await tester.tap(find.text('Costa.jpg'));
      await warm();
      await shot('android-preview');
      await tester.pumpWidget(const SizedBox());
      c.peer = PairingInfo(
        host: '192.168.1.2',
        port: 4040,
        token: 'a' * 64,
        fingerprint: 'b' * 64,
        name: 'Mi Android',
      );
      c.history.addAll([
        for (var i = 0; i < 3; i++)
          HistoryEntry(
            name: ['Costa.jpg', 'Propuesta.pdf', 'Notas.txt'][i],
            size: [2516582, 786432, 8192][i],
            incoming: true,
            file: library.items[i].localFile!,
            time: DateTime.now().subtract(Duration(minutes: i * 3)),
          ),
      ]);
      await mount(TeraxPlatform.windows, const Size(1280, 800));
      await tester.pump(const Duration(milliseconds: 1100));
      await shot('windows-receiver');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      library.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
