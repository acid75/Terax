import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/ui/swipe_card.dart';
import 'package:terax/library/library_service.dart';
import 'package:terax/ui/edge_drop_zone.dart';
import 'package:terax/ui/edge_motion.dart';
import 'package:terax/theme/terax_theme.dart';

void main() {
  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
    theme: TeraxTheme.build(TeraxPlatform.android),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('swipe uses rendered height and sends only once', (tester) async {
    var sends = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 200,
          height: 400,
          child: SwipeCard(
            enabled: true,
            sending: false,
            onSend: () => sends++,
            child: const ColoredBox(color: TeraxColors.previewBackground),
          ),
        ),
      ),
    );
    // Slow movement avoids the independent velocity trigger.
    await tester.timedDrag(
      find.byType(SwipeCard),
      const Offset(0, -100),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(sends, 0);
    await tester.timedDrag(
      find.byType(SwipeCard),
      const Offset(0, -180),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(sends, 1);
    await tester.dragFrom(const Offset(400, 300), const Offset(0, -180));
    expect(sends, 1);
  });

  testWidgets(
    'velocity trigger works below distance threshold with reduced motion',
    (tester) async {
      var sends = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 200,
            height: 400,
            child: SwipeCard(
              enabled: true,
              sending: false,
              onSend: () => sends++,
              child: const ColoredBox(color: TeraxColors.previewBackground),
            ),
          ),
          reduced: true,
        ),
      );
      await tester.fling(find.byType(SwipeCard), const Offset(0, -90), 1500);
      await tester.pumpAndSettle();
      expect(sends, 1);
      await tester.fling(find.byType(SwipeCard), const Offset(0, -90), 1500);
      expect(sends, 1);
      expect(tester.getTopLeft(find.byType(ColoredBox).last).dy, 100);
    },
  );

  testWidgets('disabled swipe cannot send', (tester) async {
    var sends = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 200,
          height: 400,
          child: SwipeCard(
            enabled: false,
            sending: false,
            onSend: () => sends++,
            child: const ColoredBox(color: TeraxColors.previewBackground),
          ),
        ),
      ),
    );
    await tester.fling(find.byType(SwipeCard), const Offset(0, -200), 1500);
    expect(sends, 0);
  });

  testWidgets(
    'unavailable target communicates destination and has 120 dp strip',
    (tester) async {
      await tester.pumpWidget(
        host(
          EdgeDropZone(
            canAccept: false,
            destination: 'PC de casa',
            onDrop: (_) => fail('Unavailable target accepted'),
          ),
        ),
      );
      expect(find.text('PC de casa no responde'), findsOneWidget);
      expect(tester.getSize(find.byType(DragTarget<LibraryItem>)).height, 120);
    },
  );

  testWidgets('drop sends only when destination is available', (tester) async {
    final item = LibraryItem(
      id: 'one',
      name: 'foto.jpg',
      isDirectory: false,
      isImage: true,
      size: 40,
      modified: DateTime(2026),
    );
    var drops = 0;
    Future<void> exercise(bool available) async {
      await tester.pumpWidget(
        host(
          Stack(
            children: [
              Positioned(
                left: 100,
                top: 300,
                child: Draggable<LibraryItem>(
                  data: item,
                  feedback: const SizedBox(width: 40, height: 40),
                  child: const SizedBox(
                    key: ValueKey('drag'),
                    width: 50,
                    height: 50,
                    child: ColoredBox(color: TeraxColors.previewBackground),
                  ),
                ),
              ),
              Positioned.fill(
                child: EdgeDropZone(
                  canAccept: available,
                  destination: 'PC de casa',
                  onDrop: (_) => drops++,
                ),
              ),
            ],
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('drag'))),
      );
      await gesture.moveTo(const Offset(130, 30));
      await tester.pump(TeraxMotion.zoneHover);
      if (available) {
        expect(find.text('Suelta para enviar a PC de casa'), findsOneWidget);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await exercise(false);
    expect(drops, 0);
    await exercise(true);
    expect(drops, 1);
  });
  testWidgets('passive edge effect schedules no repeating animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const EdgeMotion(top: false, timeline: AlwaysStoppedAnimation(.5)),
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(IgnorePointer), findsWidgets);
  });
}
