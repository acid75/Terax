import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/main.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/library/library_service.dart';

void main() {
  testWidgets(
    'mobile library and desktop receiver expose connection without overflow',
    (tester) async {
      final controller = AppController();
      final library = LibraryService()..items = [];
      addTearDown(library.dispose);
      addTearDown(controller.dispose);
      for (final width in [390.0, 1200.0]) {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        controller.starting = width < 850;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(width),
            theme: width < 850
                ? TeraxTheme.build(TeraxPlatform.android)
                : teraxTheme(),
            home: Home(controller: controller, library: library),
          ),
        );
        if (width < 850) {
          expect(find.text('Fotos'), findsOneWidget);
          expect(find.text('Documentos'), findsOneWidget);
        } else {
          expect(find.text('Conexión no disponible'), findsOneWidget);
        }
        expect(find.text('Conectar equipo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  test(
    'invalid pairing leaves no connected peer and exposes useful error',
    () async {
      final controller = AppController();
      expect(await controller.connect('incorrecto'), isFalse);
      expect(controller.peer, isNull);
      expect(controller.error, contains('código'));
      controller.dispose();
    },
  );
}
