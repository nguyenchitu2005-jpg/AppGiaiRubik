import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'features/input/net_editor_screen.dart';
import 'features/library/algorithm_library_screen.dart';
import 'features/notation/notation_screen.dart';
import 'features/scanner/scan_screen.dart';
import 'features/scrambles/scramble_screen.dart';
import 'features/timer/timer_screen.dart';

class RubikApp extends StatelessWidget {
  const RubikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rubik Solver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5FFF)),
        useMaterial3: true,
      ),
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        NetEditorScreen.routeName: (_) => const NetEditorScreen(),
        AlgorithmLibraryScreen.routeName: (_) => const AlgorithmLibraryScreen(),
        ScanScreen.routeName: (_) => const ScanScreen(),
        TimerScreen.routeName: (_) => const TimerScreen(),
        ScrambleScreen.routeName: (_) => const ScrambleScreen(),
        NotationScreen.routeName: (_) => const NotationScreen(),
      },
    );
  }
}
