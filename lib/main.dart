import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/platform_support.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppOrientation.applyDefault();
  runApp(const ProviderScope(child: RubikApp()));
}
