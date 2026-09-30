import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android or iOS.
bool get isMobileOs => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Windows (not in a browser).
bool get isWindows => !kIsWeb && Platform.isWindows;

/// Camera scanning: from live frames on Android and iOS, from photos in a
/// browser and on Windows. Other desktops (no camera plugin) get manual
/// color entry.
final cameraScanSupportedProvider = Provider<bool>(
  (ref) => isMobileOs || kIsWeb || isWindows,
);

/// Orientation rules: phones are held upright; tablets and desktop windows
/// may rotate, split the screen or resize freely.
abstract final class AppOrientation {
  static const _tabletShortestSide = 600.0;

  /// Applies the app-wide rule for this device.
  static Future<void> applyDefault() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
    final isPhone = isMobileOs && shortestSide < _tabletShortestSide;
    return SystemChrome.setPreferredOrientations(
      isPhone ? const [DeviceOrientation.portraitUp] : const [],
    );
  }

  /// The scanner maps its on-screen grid to camera pixels assuming the
  /// device is upright.
  static Future<void> lockPortrait() => SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );
}
