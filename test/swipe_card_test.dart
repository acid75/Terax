import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/ui/swipe_card.dart';

void main() {
  testWidgets('short swipe cancels, upward swipe sends once, disabled blocks', (
    tester,
  ) async {
    var sent = 0;
    Future<void> mount(bool enabled) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SwipeCard(
              enabled: enabled,
              sending: false,
              onSend: () => sent++,
              child: const SizedBox(
                width: 250,
                height: 250,
                child: Text('foto.png'),
              ),
            ),
          ),
        ),
      ),
    );
    await mount(true);
    await tester.drag(find.text('foto.png'), const Offset(0, -30));
    await tester.pumpAndSettle();
    expect(sent, 0);
    await tester.drag(find.text('foto.png'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(sent, 1);
    await mount(false);
    await tester.drag(find.text('foto.png'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(sent, 1);
  });
}
