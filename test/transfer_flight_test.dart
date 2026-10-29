import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/ui/transfer_flight.dart';
import 'package:terax/theme/terax_theme.dart';

void main() {
  Widget host({
    String? id = 'one',
    bool active = true,
    bool reduced = false,
    bool incoming = false,
    bool showcase = false,
    bool visible = true,
  }) => MaterialApp(
    theme: TeraxTheme.build(TeraxPlatform.android),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: visible
            ? Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 300,
                  height: 120,
                  child: SingleChildScrollView(
                    child: TransferFlight(
                      flightId: id,
                      active: active,
                      incoming: incoming,
                      showcase: showcase,
                      visual: const ColoredBox(
                        key: ValueKey('flying'),
                        color: TeraxColors.previewBackground,
                      ),
                      child: const SizedBox(width: 200, height: 100),
                    ),
                  ),
                ),
              )
            : const SizedBox(),
      ),
    ),
  );
  Future<void> launch(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  testWidgets('no acknowledged id means no flight', (tester) async {
    await launch(tester, host(id: null));
    expect(find.byKey(const ValueKey('flying')), findsNothing);
    await tester.pumpWidget(host(id: 'ready'));
    await tester.pump();
    expect(find.byKey(const ValueKey('flying')), findsOneWidget);
    await tester.pumpAndSettle();
  });
  testWidgets('root overlay escapes clipped source and launches once per id', (
    tester,
  ) async {
    await launch(tester, host());
    final start = tester.getTopLeft(find.byKey(const ValueKey('flying'))).dy;
    await tester.pump(const Duration(milliseconds: 160));
    final flying = find.byKey(const ValueKey('flying'));
    expect(tester.getTopLeft(flying).dy, lessThan(start));
    expect(tester.getTopLeft(flying).dy, lessThan(480));
    // Root Overlay is an ancestor, but source scroll viewport is not.
    expect(
      find.ancestor(of: flying, matching: find.byType(Overlay)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: flying, matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(flying, findsNothing);
    await tester.pumpWidget(host());
    await tester.pump();
    expect(flying, findsNothing);
    await tester.pumpWidget(host(id: 'two'));
    await tester.pump();
    expect(flying, findsOneWidget);
    await tester.pumpAndSettle();
    expect(flying, findsNothing);
  });
  testWidgets('failure and dispose immediately remove overlay and ticker', (
    tester,
  ) async {
    await launch(tester, host());
    await tester.pumpWidget(host(active: false));
    await tester.pump();
    expect(find.byKey(const ValueKey('flying')), findsNothing);
    await launch(tester, host(id: 'two'));
    expect(find.byKey(const ValueKey('flying')), findsOneWidget);
    await tester.pumpWidget(host(visible: false));
    await tester.pump();
    expect(find.byKey(const ValueKey('flying')), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced flight only fades at origin and cleans up in 150ms', (
    tester,
  ) async {
    await launch(tester, host(reduced: true));
    final initial = tester.getRect(find.byKey(const ValueKey('flying')));
    await tester.pump(const Duration(milliseconds: 75));
    expect(tester.getRect(find.byKey(const ValueKey('flying'))), initial);
    await tester.pumpAndSettle(const Duration(milliseconds: 75));
    expect(find.byKey(const ValueKey('flying')), findsNothing);
  });
  testWidgets('incoming starts below window and enters real card thumbnail', (
    tester,
  ) async {
    await launch(tester, host(incoming: true));
    final flying = find.byKey(const ValueKey('flying'));
    expect(tester.getTopLeft(flying).dy, 600);
    await tester.pump(const Duration(milliseconds: 210));
    expect(tester.getTopLeft(flying).dy, lessThan(600));
    expect(tester.getTopLeft(flying).dy, greaterThanOrEqualTo(480));
    await tester.pumpAndSettle();
    expect(flying, findsNothing);
  });
  testWidgets(
    'bounded arrival visibly rises from physical bottom before docking',
    (tester) async {
      await launch(tester, host(incoming: true, showcase: true));
      final flying = find.byKey(const ValueKey('flying'));
      expect(tester.getTopLeft(flying).dy, greaterThanOrEqualTo(600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getTopLeft(flying).dy, lessThan(400));
      expect(
        tester.getSize(flying).width,
        lessThanOrEqualTo(TeraxSize.handoffPreview),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getTopLeft(flying).dy, greaterThan(250));
      await tester.pumpAndSettle();
      expect(flying, findsNothing);
    },
  );
  for (final incoming in [false, true]) {
    testWidgets(
      'full-window wave survives the small file flight and runs once incoming=$incoming',
      (tester) async {
        await launch(tester, host(incoming: incoming));
        final wave = find.byKey(const ValueKey('transfer-wave-overlay'));
        expect(wave, findsOneWidget);
        expect(tester.getSize(wave), const Size(800, 600));
        expect(
          find.ancestor(of: wave, matching: find.byType(SingleChildScrollView)),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const ValueKey('flying')), findsNothing);
        expect(wave, findsOneWidget);
        await tester.pumpAndSettle();
        expect(wave, findsNothing);
        await tester.pumpWidget(host(incoming: incoming));
        await tester.pump();
        expect(wave, findsNothing);
        await tester.pumpWidget(host(id: 'next', incoming: incoming));
        await tester.pump();
        expect(wave, findsOneWidget);
        await tester.pumpWidget(
          host(id: 'next', active: false, incoming: incoming),
        );
        await tester.pump();
        expect(wave, findsNothing);
      },
    );
  }
  testWidgets('reduced motion never creates the transfer wave', (tester) async {
    await launch(tester, host(reduced: true));
    expect(find.byKey(const ValueKey('transfer-wave-overlay')), findsNothing);
    await tester.pumpAndSettle();
  });
}
