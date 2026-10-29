import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terax/ui/transfer_wave.dart';
import 'package:terax/theme/terax_theme.dart';

void main() {
  testWidgets(
    'receiver front enters from bottom and sender front retreats to top in live app pixels',
    (tester) async {
      final key = GlobalKey();
      Future<({double energy, double y})> sample(
        bool incoming,
        double p,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: TeraxTheme.build(TeraxPlatform.windows),
            home: RepaintBoundary(
              key: key,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  TransferWave(
                    incoming: incoming,
                    timeline: AlwaysStoppedAnimation(p),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        late ui.Image bitmap;
        late ByteData pixels;
        await tester.runAsync(() async {
          bitmap =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          pixels = (await bitmap.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
        });
        double energy = 0, weighted = 0;
        for (var y = 0; y < bitmap.height; y += 4) {
          for (var x = 0; x < bitmap.width; x += 4) {
            final brightness = pixels.getUint8((y * bitmap.width + x) * 4 + 1);
            energy += brightness;
            weighted += brightness * y;
          }
        }
        bitmap.dispose();
        return (energy: energy, y: weighted / math.max(energy, 1));
      }

      final enter = await sample(true, .3), retreat = await sample(false, .7);
      expect(enter.energy, greaterThan(1000));
      expect(retreat.energy, greaterThan(1000));
      expect(enter.y, greaterThan(400));
      expect(retreat.y, lessThan(200));
      expect((await sample(true, 0)).energy, 0);
      expect((await sample(false, 1)).energy, 0);
    },
  );
}
