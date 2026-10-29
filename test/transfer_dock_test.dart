import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/app_controller.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/ui/home.dart';
import 'package:terax/ui/transfer_scene.dart';

void main() {
  for (final platform in TeraxPlatform.values) {
    testWidgets('transfer stays below library and header on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = Size(
        platform == TeraxPlatform.android ? 390 : 1280,
        800,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController()
        ..starting = false
        ..selectedName = 'Contrato.pdf'
        ..selectedSize = 500
        ..state = SendState.sending
        ..outgoingId = 'sending'
        ..progress = .4;
      final library = LibraryService()..items = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: TeraxTheme.build(platform),
          home: Home(controller: c, library: library),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final dock = find.byKey(const ValueKey('transfer-dock'));
      expect(dock, findsOneWidget);
      expect(tester.getTopLeft(dock).dy, greaterThan(400));
      expect(tester.getBottomRight(dock).dy, lessThanOrEqualTo(800));
      expect(
        tester.widget<TransferScene>(find.byType(TransferScene)).docked,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      library.dispose();
    });
  }
}
