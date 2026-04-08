import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// A utility class to provide platform-specific widgets (iOS/Swift-style vs Android/Material).
class PlatformAdaptive {
  
  /// Returns a platform-specific loading indicator.
  static Widget loader() {
    if (Platform.isIOS || Platform.isMacOS) {
      return const CupertinoActivityIndicator();
    }
    return const CircularProgressIndicator();
  }

  /// Returns a platform-specific back button icon.
  static IconData backIcon() {
    if (Platform.isIOS || Platform.isMacOS) {
      return Icons.arrow_back_ios_new_rounded;
    }
    return Icons.arrow_back_rounded;
  }

  /// Returns a platform-specific toggle/switch.
  static Widget platformSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    if (Platform.isIOS || Platform.isMacOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor,
    );
  }

  /// Shows a platform-specific alert dialog.
  static Future<void> showAlert({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    if (Platform.isIOS || Platform.isMacOS) {
      return showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
