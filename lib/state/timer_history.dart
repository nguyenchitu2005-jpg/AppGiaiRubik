import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/timer/solve_times.dart';

/// The timed solves, oldest first, kept on the device between sessions.
class TimerHistoryController extends Notifier<List<TimedSolve>> {
  static const _key = 'timer.solves';

  /// Saving waits for this, so it never overwrites solves not yet loaded.
  late Future<void> _loading;

  @override
  List<TimedSolve> build() {
    _loading = _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return;
      final loaded = [
        for (final item in jsonDecode(saved) as List<Object?>)
          TimedSolve.fromJson(item! as Map<String, Object?>),
      ];
      // Solves timed while loading come after the saved ones.
      state = [...loaded, ...state];
    } catch (error) {
      debugPrint('Không đọc được lịch sử hẹn giờ: $error');
    }
  }

  Future<void> _save() async {
    await _loading;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final s in state) s.toJson()]),
      );
    } catch (error) {
      debugPrint('Không lưu được lịch sử hẹn giờ: $error');
    }
  }

  void add(TimedSolve solve) {
    state = [...state, solve];
    _save();
  }

  void setPenalty(TimedSolve solve, Penalty penalty) {
    state = [
      for (final s in state) identical(s, solve) ? s.withPenalty(penalty) : s,
    ];
    _save();
  }

  void remove(TimedSolve solve) {
    state = [
      for (final s in state)
        if (!identical(s, solve)) s,
    ];
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }
}

final timerHistoryProvider =
    NotifierProvider<TimerHistoryController, List<TimedSolve>>(
      TimerHistoryController.new,
    );
