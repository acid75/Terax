import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/ui/components/terax_components.dart';

void main() {
  if (Platform.environment['TERAX_CAPTURE_COMPONENTS'] != '1') return;
  for (final entry in [
    (TeraxPlatform.android, 360.0),
    (TeraxPlatform.android, 412.0),
    (TeraxPlatform.windows, 1280.0),
  ]) {
    testWidgets('visual component board ${entry.$1.name} ${entry.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(entry.$2, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final font in {
          'Figtree': 'assets/fonts/Figtree-VariableFont_wght.ttf',
          'GeistMono': 'assets/fonts/GeistMono-Regular.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(font.key);
          loader.addFont(rootBundle.load(font.value));
          await loader.load();
        }
      });
      final key = GlobalKey();
      final search = TextEditingController();
      addTearDown(search.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(entry.$1),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final c = TeraxColors.of(context);
                  final controls = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: TeraxBrand(),
                      ),
                      const SizedBox(height: 24),
                      TeraxDeviceBar(
                        name: 'PC de casa',
                        status: TeraxDeviceStatus.nearby,
                        onTap: () {},
                      ),
                      const SizedBox(height: 18),
                      TeraxSegmentedControl<String>(
                        segments: const [
                          TeraxSegment(
                            value: 'p',
                            label: 'Fotos',
                            icon: Icons.photo_outlined,
                          ),
                          TeraxSegment(
                            value: 'd',
                            label: 'Documentos',
                            icon: Icons.description_outlined,
                          ),
                        ],
                        selected: 'p',
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 12),
                      TeraxSearchField(
                        controller: search,
                        hint: 'Buscar fotos',
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(
                            'Hoy',
                            style: TeraxText.label.copyWith(color: c.text),
                          ),
                          const Spacer(),
                          Text(
                            'Recientes primero',
                            style: TeraxText.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 136,
                        child: Row(
                          children: [
                            Expanded(
                              child: TeraxLibraryTile(
                                name: 'IMG_20261028.jpg',
                                thumbnail: ColoredBox(color: c.iconContainer),
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TeraxLibraryTile(
                                name: 'Documento.jpg',
                                state: TeraxTileState.loading,
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TeraxLibraryTile(
                                name: 'Ilegible.jpg',
                                state: TeraxTileState.unreadable,
                                onTap: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TeraxPrimaryButton(
                        label: 'Enviar a PC de casa',
                        icon: Icons.north_east,
                        onPressed: () {},
                      ),
                      const SizedBox(height: 12),
                      TeraxSwitchRow(
                        title: 'Permitir recepción',
                        subtitle: 'Desde tus equipos vinculados',
                        value: true,
                        onChanged: (_) {},
                      ),
                      TeraxSwitchRow(
                        title: 'Abrir al recibir',
                        subtitle: 'Después de verificar el archivo',
                        value: false,
                        onChanged: (_) {},
                      ),
                    ],
                  );
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: entry.$1 == TeraxPlatform.windows
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 420, child: controls),
                              const SizedBox(width: 48),
                              Expanded(
                                child: TeraxEmptyState(
                                  large: true,
                                  title: 'Listo para recibir',
                                  message: 'Vincula tu teléfono una vez.',
                                  icon: Icons.devices_outlined,
                                  actionLabel: 'Conectar equipo',
                                  onAction: () {},
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(child: controls),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('tmp/handoff-phase-1-2').create(recursive: true);
        await File(
          'tmp/handoff-phase-1-2/${entry.$1.name}-${entry.$2.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
  testWidgets('visual confirmation at 412dp', (tester) async {
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: TeraxTheme.build(TeraxPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTeraxConfirmation(
                  context,
                  title: '¿Restablecer vínculos?',
                  explanation:
                      'Tus equipos dejarán de estar autorizados y tendrás que vincularlos otra vez con el código QR.',
                  preservation: 'Los archivos recibidos no se borran.',
                  confirmLabel: 'Restablecer',
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'tmp/handoff-phase-1-2/confirmation-412.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
