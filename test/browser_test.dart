import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/ui/library_browser.dart';

void main() {
  testWidgets(
    'browser stays usable at 320 pixels and restores tabs after inline search',
    (tester) async {
      late Directory root;
      late LibraryService service;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('terax-browser-');
        await File('${root.path}/uno.txt').writeAsString('one');
        await File('${root.path}/dos.txt').writeAsString('two');
        service = LibraryService(
          android: false,
          roots: {
            LibraryKind.document: [root],
          },
        );
        await service.load(LibraryKind.document);
      });
      LibraryItem? preview;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 600,
              child: LibraryBrowser(
                service: service,
                onPreview: (item) => preview = item,
                canDrag: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('uno.txt'), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar archivos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'uno');
      await tester.pump();
      expect(find.text('dos.txt'), findsNothing);
      await tester.tap(find.text('uno.txt'));
      expect(preview?.name, 'uno.txt');
      expect(find.text('Fotos'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('Fotos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
