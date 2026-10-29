import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/theme/terax_theme.dart';
import 'package:terax/ui/components/terax_components.dart';

Widget host(
  Widget child, {
  TeraxPlatform platform = TeraxPlatform.android,
  double scale = 1,
  bool reduced = false,
}) => MaterialApp(
  theme: TeraxTheme.build(platform),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: Scaffold(body: SizedBox(width: 320, child: child)),
  ),
);
void main() {
  testWidgets('device status is readable at 200 percent in a narrow layout', (
    tester,
  ) async {
    for (final status in TeraxDeviceStatus.values) {
      await tester.pumpWidget(
        host(
          Center(
            child: TeraxDeviceBar(
              name:
                  'Computadora del trabajo con un nombre considerablemente largo',
              status: status,
              onTap: () {},
            ),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byIcon(switch (status) {
          TeraxDeviceStatus.unlinked => Icons.add_link_rounded,
          TeraxDeviceStatus.nearby => Icons.check_rounded,
          TeraxDeviceStatus.connected => Icons.wifi_rounded,
          TeraxDeviceStatus.reconnecting => Icons.sync_rounded,
          TeraxDeviceStatus.unavailable => Icons.wifi_off_rounded,
        }),
        findsOneWidget,
      );
    }
  });
  testWidgets('selection and search callbacks use caller state', (
    tester,
  ) async {
    var selected = 'photos';
    var query = '';
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              TeraxSegmentedControl<String>(
                segments: const [
                  TeraxSegment(
                    value: 'photos',
                    label: 'Fotos',
                    icon: Icons.photo_outlined,
                  ),
                  TeraxSegment(
                    value: 'docs',
                    label: 'Documentos',
                    icon: Icons.description_outlined,
                  ),
                ],
                selected: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
              TeraxSearchField(
                controller: search,
                hint: 'Buscar archivos',
                onChanged: (value) => query = value,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Documentos'));
    await tester.pump();
    expect(selected, 'docs');
    await tester.enterText(find.byType(TextField), 'factura');
    expect(query, 'factura');
    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pump();
    expect(query, isEmpty);
    expect(search.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('busy button cannot submit and reduced motion has no ticker', (
    tester,
  ) async {
    var submitted = 0;
    await tester.pumpWidget(
      host(
        Column(
          children: [
            TeraxPrimaryButton(
              label: 'Preparando',
              busy: true,
              onPressed: () => submitted++,
            ),
            const Expanded(
              child: TeraxEmptyState(
                title: 'Cargando biblioteca…',
                message: 'Un momento.',
                loading: true,
              ),
            ),
          ],
        ),
        reduced: true,
      ),
    );
    await tester.tap(find.text('Preparando'));
    await tester.pumpAndSettle();
    expect(submitted, 0);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('switch label toggles once and unavailable toggle is inert', (
    tester,
  ) async {
    var value = false;
    var calls = 0;
    Widget render() => host(
      TeraxSwitchRow(
        title: 'Permitir recepción',
        value: value,
        onChanged: (next) {
          value = next;
          calls++;
        },
      ),
    );
    await tester.pumpWidget(render());
    await tester.tap(find.text('Permitir recepción'));
    expect(value, isTrue);
    expect(calls, 1);
    await tester.pumpWidget(
      host(const TeraxSwitchRow(title: 'Permitir recepción', value: true)),
    );
    await tester.tap(find.text('Permitir recepción'));
    expect(calls, 1);
  });
  testWidgets(
    'confirmation cancels with Escape and only returns true explicitly',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTeraxConfirmation(
                  context,
                  title: '¿Restablecer vínculos?',
                  explanation: 'Tendrás que vincularlos otra vez.',
                  preservation: 'Los archivos recibidos no se borran.',
                  confirmLabel: 'Restablecer',
                );
              },
              child: const Text('Abrir diálogo'),
            ),
          ),
          platform: TeraxPlatform.windows,
        ),
      );
      await tester.tap(find.text('Abrir diálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Los archivos recibidos no se borran.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result, isFalse);
      await tester.tap(find.text('Abrir diálogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restablecer'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );
  testWidgets(
    'keyboard activates a primary action without adding wrapper focus stops',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          TeraxPrimaryButton(label: 'Enviar', onPressed: () => calls++),
          platform: TeraxPlatform.windows,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);
    },
  );
  testWidgets('device bar exposes its action to a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        host(
          TeraxDeviceBar(
            name: 'PC de casa',
            status: TeraxDeviceStatus.nearby,
            onTap: () {},
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(TeraxDeviceBar));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, contains('PC de casa'));
      expect(node.label, contains('Cerca'));
    } finally {
      semantics.dispose();
    }
  });
  testWidgets(
    'switch has one keyboard stop and then advances to the next action',
    (tester) async {
      var toggles = 0;
      var sends = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              TeraxSwitchRow(
                title: 'Permitir recepción',
                value: false,
                onChanged: (_) => toggles++,
              ),
              TeraxPrimaryButton(label: 'Enviar', onPressed: () => sends++),
            ],
          ),
          platform: TeraxPlatform.windows,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(toggles, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(sends, 1);
      expect(toggles, 1);
    },
  );
}
