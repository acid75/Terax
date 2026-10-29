import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../theme/terax_theme.dart';
import 'android_settings.dart';
import 'windows_settings.dart';

Future<void> showTeraxSettings(BuildContext context, AppController controller) {
  if (TeraxPlatform.of(context) == TeraxPlatform.android) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AndroidSettings(controller: controller),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(TeraxSpace.s24),
      child: SizedBox(
        width: TeraxSize.settingsWidth,
        child: WindowsSettings(controller: controller),
      ),
    ),
  );
}
