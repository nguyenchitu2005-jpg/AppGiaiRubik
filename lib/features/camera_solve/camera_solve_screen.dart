import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cube/cube_state.dart';
import '../../core/cube/face.dart';
import '../../core/cube/move.dart';
import '../../core/cube/move_description.dart';
import '../../core/solver/kociemba_solver.dart';
import '../../core/timer/solve_times.dart';
import '../../core/vision/color_classifier.dart';
import '../../core/vision/color_math.dart';
import '../../core/vision/face_locator.dart';
import '../../core/vision/scan_assembler.dart';
import '../../core/vision/solve_tracker.dart';
import '../../shared/layout.dart';
import '../../shared/move_speaker.dart';
import '../../shared/platform_support.dart';
import '../../state/settings.dart';
import '../scanner/camera_feed.dart';
import '../scanner/scan_screen.dart';

/// Solves the scanned cube with the user: says each move of the shortest
/// solution (about 20 moves) out loud and shows it, watches the front face
/// through the camera to see it done, then goes on to the next one. A
/// wrong move is noticed and undone.
class CameraSolveScreen extends ConsumerStatefulWidget {
  const CameraSolveScreen({
    super.key,
    required this.start,
    this.scan,
    @visibleForTesting this.solution,
  });

  /// The cube as scanned (and maybe fixed by hand).
  final CubeState start;

  /// The scan: how this cube's colors look on this camera, and whether the
  /// camera mirrors.
  final ScanResult? scan;

  /// The moves to play, instead of solving [start] (for tests).
  final List<Move>? solution;

  @override
  ConsumerState<CameraSolveScreen> createState() => CameraSolveScreenState();
}

/// How many moves are said at once.
enum _ReadAhead {
  one(1, 'Từng nước'),
  three(3, '3 nước một lần');

  const _ReadAhead(this.moves, this.label);

  final int moves;
  final String label;
}

class CameraSolveScreenState extends ConsumerState<CameraSolveScreen> {
  /// A move the camera cannot see is taken as done after this long.
  static const unseenDelay = Duration(milliseconds: 2500);

  /// Colors come from photos here (see [CameraFeed]): compare every photo.
  static final bool _photos = kIsWeb || isWindows;

  final Stopwatch _clock = Stopwatch()..start();
  final Stopwatch _solveTime = Stopwatch();
  Timer? _ticker;
  Timer? _unseen;

  late final Face Function(Rgb) _classify;
  late final bool Function(Rgb) _isClear;

  /// This cube's scanned colors (null without a scan).
  late final StickerPalette? _scanPalette;

  /// The camera's last picture showed the front face (null before any).
  bool? _faceSeen;

  SolveTracker? _tracker;
  String? _error;
  List<Face>? _live;

  /// Moves said so far (the next ones are said when the user gets there).
  int _saidUpTo = 0;
  int _lastDone = 0;
  _ReadAhead _readAhead = _ReadAhead.one;
  bool _explain = false;

  /// What was said about the last wrong move, shown for a few seconds.
  String? _correction;
  Duration _correctionAt = Duration.zero;
  int _solutionLength = 0;

  @override
  void initState() {
    super.initState();
    AppOrientation.lockPortrait();
    final palette = _scanPalette = _palette();
    _classify = palette?.classify ?? LiveColorClassifier.classify;
    _isClear = palette?.isClear ?? LiveColorClassifier.isClear;
    _solve();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _unseen?.cancel();
    _tracker?.dispose();
    _speaker.stop();
    AppOrientation.applyDefault();
    super.dispose();
  }

  late final Speaker _speaker = ref.read(speakerProvider);

  /// Finds the front face anywhere in the picture. Made in a static
  /// function from plain data only, so that it can be sent to a background
  /// isolate.
  static FaceLocator _locatorFor(
    StickerPalette? palette,
    Face center,
    ExpectedFronts? expected,
  ) => FaceLocator(
    colorOf: palette?.pixelColor ?? LiveColorClassifier.pixelColor,
    centerOk: (c) => c == center,
    // The colors the solution expects beat a look-alike patch.
    bonus: expected == null
        ? null
        : (colors) => expected.matches(colors) ? 3 : 0,
  );

  /// The scanned colors of this very cube, when the scan can be matched to
  /// it (the user may have turned the cube while fixing colors).
  StickerPalette? _palette() {
    final scan = widget.scan;
    if (scan == null || scan.samples.length != 54) return null;
    final sameHold = Face.values.every(
      (f) => scan.state.center(f) == widget.start.center(f),
    );
    return StickerPalette.fromScan(
      sameHold ? widget.start : scan.state,
      scan.samples,
    );
  }

  Future<void> _solve() async {
    try {
      final solution =
          widget.solution ?? await KociembaSolver.solve(widget.start);
      if (!mounted) return;
      _solutionLength = solution.length;
      final tracker = SolveTracker(
        start: widget.start,
        solution: solution,
        preferMirrored: widget.scan?.mirrored ?? false,
        cameraTurns: widget.scan?.cameraTurns ?? 0,
        // A move is judged on a view seen twice (photos) or held 0.4 s
        // (live frames): one glimpse can be a blur or a misread.
        minFrames: _photos ? 2 : 3,
        stableFor: _photos ? Duration.zero : const Duration(milliseconds: 400),
        // After a wrong move, a new formula from where the cube is when it
        // is shorter than undoing (the solver's tables are loaded by now).
        resolve: _resolve,
      )..addListener(_onTracker);
      setState(() => _tracker = tracker);
    } on UnsolvableCubeException catch (e) {
      setState(() => _error = e.issues.first.message);
    } catch (e) {
      setState(() => _error = 'Không tìm được lời giải: $e');
    }
  }

  /// A new solution from [state], or null if none is found quickly.
  static List<Move>? _resolve(CubeState state) {
    try {
      return KociembaSolver.solveSync(state);
    } catch (_) {
      return null;
    }
  }

  /// Colors read by the camera.
  @visibleForTesting
  void addSamples(List<Rgb> samples, Duration time) {
    // Nothing to follow while the front face is not in the picture.
    if (_faceSeen == false) {
      _live = null;
      setState(() {});
      return;
    }
    final labels = [for (final s in samples) _classify(s)];
    final clear = samples.every(_isClear);
    _live = labels;
    final tracker = _tracker;
    if (tracker != null) {
      tracker.addFrame(labels, time, clear: clear);
    } else {
      setState(() {});
    }
  }

  void _onTracker() {
    final tracker = _tracker!;
    final news = tracker.takeNews();
    Speech? prefix;
    switch (news) {
      case TrackerStarted():
        _solveTime.start();
        _ticker = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) => setState(() {}),
        );
        prefix = const Speech('Bắt đầu.', 'Start.');
        _saidUpTo = 0;
      case TrackerAdvanced():
        HapticFeedback.selectionClick();
      case TrackerCorrected(:final wrong, :final fix, :final replanned):
        HapticFeedback.heavyImpact();
        final fixVi = fix.map((m) => Speech.move(m).vi).join(', ');
        final fixEn = fix.map((m) => Speech.move(m).en).join(', ');
        prefix = replanned
            ? Speech(
                'Sai rồi, bạn vừa xoay ${Speech.move(wrong).vi}. '
                    'Đã đổi công thức.',
                'Oops, that was ${Speech.move(wrong).en}. New moves.',
              )
            : Speech(
                'Sai rồi, bạn vừa xoay ${Speech.move(wrong).vi}. '
                    'Xoay $fixVi để sửa.',
                'Oops, that was ${Speech.move(wrong).en}. '
                    'Do $fixEn to fix it.',
              );
        _correction =
            'Bạn vừa xoay nhầm ${wrong.notation}: '
            '${replanned ? 'đã đổi sang công thức mới.' : 'xoay ${Move.format(fix)} để sửa, công thức đã cập nhật.'}';
        _correctionAt = _clock.elapsed;
        // The fix is said now; the moves after it once it is done.
        _saidUpTo = tracker.done + fix.length;
      case TrackerLost():
        HapticFeedback.heavyImpact();
        prefix = const Speech(
          'Camera chưa nhận ra khối. Kiểm tra nước vừa xoay.',
          'The camera lost track. Check your last move.',
        );
      case TrackerSolved():
        _solveTime.stop();
        _ticker?.cancel();
        HapticFeedback.heavyImpact();
        final seconds = (_solveTime.elapsedMilliseconds / 1000).round();
        final (vi, en) = seconds < 60
            ? ('$seconds giây', '$seconds seconds')
            : (
                '${seconds ~/ 60} phút ${seconds % 60} giây',
                '${seconds ~/ 60} minutes ${seconds % 60} seconds',
              );
        _say(Speech('Xong! Giải trong $vi.', 'Solved in $en!'));
      case TrackerWentBack() || null:
        break;
    }
    // A move undone (or stepped back): say it again.
    if (tracker.done < _lastDone) _saidUpTo = tracker.done;
    _lastDone = tracker.done;
    _sayNext(prefix: prefix);
    _watchUnseen();
    setState(() {});
  }

  void _say(Speech speech) {
    if (ref.read(voiceGuideProvider)) _speaker.say(speech);
  }

  /// The moves to say from [from] (one, or a few when reading ahead).
  List<Speech> _movesFrom(int from) {
    final plan = _tracker!.plan;
    final to = (from + _readAhead.moves).clamp(0, plan.length);
    return [
      for (var i = from; i < to; i++)
        Speech.move(plan[i], explain: _explain && _readAhead.moves == 1),
    ];
  }

  /// Says [prefix], then the move to make now (and a few more when reading
  /// ahead) unless already said.
  void _sayNext({Speech? prefix}) {
    final tracker = _tracker!;
    if (tracker.phase != TrackerPhase.solving) return;
    final moves = <Speech>[];
    if (tracker.done >= _saidUpTo) {
      moves.addAll(_movesFrom(tracker.done));
      _saidUpTo = tracker.done + moves.length;
    }
    if (prefix == null && moves.isEmpty) return;
    String join(String? first, Iterable<String> rest) =>
        [?first, if (rest.isNotEmpty) rest.join(', ')].join(' ');
    _say(
      Speech(
        join(prefix?.vi, moves.map((m) => m.vi)),
        join(prefix?.en, moves.map((m) => m.en)),
      ),
    );
  }

  void _repeat() {
    final tracker = _tracker;
    if (tracker == null || tracker.phase != TrackerPhase.solving) return;
    final moves = _movesFrom(tracker.done);
    _say(
      Speech(
        moves.map((m) => m.vi).join(', '),
        moves.map((m) => m.en).join(', '),
      ),
    );
  }

  /// A move the camera cannot see is taken as done after [unseenDelay]
  /// (the next move the camera sees confirms it).
  void _watchUnseen() {
    final tracker = _tracker!;
    final key = (tracker.phase, tracker.done, tracker.plan.length);
    if (key == _unseenKey) return;
    _unseenKey = key;
    _unseen?.cancel();
    if (tracker.phase != TrackerPhase.solving || tracker.currentIsVisible) {
      return;
    }
    _unseenSince = _clock.elapsed;
    final done = tracker.done;
    _unseen = Timer(unseenDelay, () {
      if (mounted && tracker.done == done) tracker.confirmByUser();
    });
  }

  Object? _unseenKey;
  Duration _unseenSince = Duration.zero;

  @override
  Widget build(BuildContext context) {
    final tracker = _tracker;
    final voice = ref.watch(voiceGuideProvider);
    final camera = CameraFeed(
      clock: _clock,
      preferFront: true,
      active: tracker?.phase != TrackerPhase.solved,
      live: tracker?.phase == TrackerPhase.solved ? null : _live,
      stable: tracker != null && tracker.phase != TrackerPhase.aligning,
      onSamples: addSamples,
      locator: () => _locatorFor(
        _scanPalette,
        widget.start.center(Face.f),
        _tracker?.expectedFronts,
      ),
      onLocated: (grid) => _faceSeen = grid != null,
      maxHeight: MediaQuery.sizeOf(context).height * (_photos ? 0.5 : 0.4),
    );
    final panel = _panel(context, tracker);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _confirm,
        const SingleActivator(LogicalKeyboardKey.enter): _confirm,
        const SingleActivator(LogicalKeyboardKey.backspace): _back,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Giải cùng camera'),
            actions: [
              IconButton(
                tooltip: voice ? 'Tắt giọng đọc' : 'Bật giọng đọc',
                icon: Icon(voice ? Icons.volume_up : Icons.volume_off),
                onPressed: () {
                  if (voice) _speaker.stop();
                  ref.read(voiceGuideProvider.notifier).toggle();
                },
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (isWideLayout(constraints.maxWidth)) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: camera,
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: panel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [camera, const SizedBox(height: 12), ...panel],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _confirm() => _tracker?.confirmByUser();

  void _back() => _tracker?.back();

  List<Widget> _panel(BuildContext context, SolveTracker? tracker) {
    final theme = Theme.of(context);
    if (_error != null) {
      return [
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Khối quét được chưa giải được: $_error\n'
              'Hãy quét lại, hoặc sửa màu cho đúng với khối thật.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _scanAgain,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Quét lại'),
        ),
      ];
    }
    if (tracker == null) {
      return const [
        SizedBox(height: 24),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 12),
        Center(child: Text('Đang tìm lời giải ngắn nhất…')),
      ];
    }
    return switch (tracker.phase) {
      TrackerPhase.aligning => _aligning(theme, tracker),
      TrackerPhase.solving => _solving(theme, tracker),
      TrackerPhase.solved => _solved(theme, tracker),
    };
  }

  List<Widget> _aligning(ThemeData theme, SolveTracker tracker) {
    final up = widget.start.center(Face.u).colorName.toLowerCase();
    final front = widget.start.center(Face.f).colorName.toLowerCase();
    return [
      Text(
        'Lời giải có ${tracker.plan.length} nước',
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Cầm khối như lúc quét mặt đầu tiên: tâm $up ở trên, tâm $front '
        'hướng vào camera, cho mặt đó vừa lưới. Giữ nguyên cách cầm này '
        'suốt lúc giải. Khi camera nhận ra khối, app sẽ bắt đầu đọc.',
      ),
      if (tracker.isLost) ...[
        const SizedBox(height: 8),
        Text(
          'Mặt tâm $front đang thấy chưa khớp với khối đã quét: kiểm tra '
          'hướng cầm (tâm $up ở trên), hoặc quét lại.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
      const SizedBox(height: 12),
      _Formula(tracker: tracker),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: tracker.startAnyway,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Bắt đầu luôn'),
      ),
      const SizedBox(height: 8),
      _options(theme),
    ];
  }

  List<Widget> _solving(ThemeData theme, SolveTracker tracker) {
    final move = tracker.current!;
    final front = widget.start.center(Face.f).colorName.toLowerCase();
    final unseen = !tracker.currentIsVisible;
    final waited = _clock.elapsed - _unseenSince;
    return [
      Row(
        children: [
          Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            SolveStats.format(_solveTime.elapsedMilliseconds),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            'Nước ${tracker.done + 1}/${tracker.plan.length}',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Card(
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _repeat,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                Text(
                  move.notation,
                  key: const ValueKey('current-move'),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  move.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (tracker.isLost) ...[
        Text(
          'Camera chưa biết bạn vừa xoay gì. Xoay ngược lại các nước vừa '
          'xoay nhầm, bấm "Lùi lại" / "Đã xoay" cho đúng nước đang làm, hoặc '
          'quét lại để có công thức mới cho đúng khối.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        TextButton.icon(
          onPressed: _scanAgain,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Quét lại để tính công thức mới'),
        ),
      ] else if (_correction != null &&
          _clock.elapsed - _correctionAt < const Duration(seconds: 6))
        Text(
          _correction!,
          style: TextStyle(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        )
      else if (_faceSeen == false || tracker.wrongFace)
        Text(
          'Đưa mặt tâm $front về phía camera (gần hay xa đều được, không '
          'cần khớp ô vuông).',
          style: TextStyle(color: theme.colorScheme.error),
        )
      else if (unseen) ...[
        Text(
          'Camera không thấy được nước này (mặt sau không đổi mặt trước). '
          'Xoay xong, app tự sang nước tiếp; nước sau sẽ kiểm tra lại.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (waited.inMilliseconds / unseenDelay.inMilliseconds).clamp(
            0.0,
            1.0,
          ),
        ),
      ] else
        Text(
          'Cứ xoay, camera tự nhận ra nước vừa xong và đọc nước tiếp.',
          style: theme.textTheme.bodySmall,
        ),
      const SizedBox(height: 12),
      _Formula(tracker: tracker),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: tracker.done == 0 ? null : tracker.back,
              icon: const Icon(Icons.undo),
              label: const Text('Lùi lại'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _repeat,
              icon: const Icon(Icons.replay),
              label: const Text('Đọc lại'),
            ),
          ),
          const SizedBox(width: 8),
          // Only when the camera misses a move: it follows them itself.
          Expanded(
            child: OutlinedButton.icon(
              onPressed: tracker.confirmByUser,
              icon: const Icon(Icons.skip_next),
              label: const Text('Đã xoay'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _options(theme),
    ];
  }

  List<Widget> _solved(ThemeData theme, SolveTracker tracker) {
    final mistakes = tracker.mistakes.length;
    return [
      Icon(Icons.emoji_events, size: 64, color: theme.colorScheme.primary),
      Text(
        'Đã giải xong!',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        '${SolveStats.format(_solveTime.elapsedMilliseconds)} · '
        '$_solutionLength nước'
        '${mistakes > 0 ? ' · sửa $mistakes lần xoay nhầm' : ''}',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      _Formula(tracker: tracker),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _scanAgain,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Quét và giải khối khác'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Về trang chủ'),
      ),
    ];
  }

  Widget _options(ThemeData theme) => Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('Đọc:', style: theme.textTheme.bodySmall),
      for (final option in _ReadAhead.values)
        ChoiceChip(
          label: Text(option.label),
          selected: _readAhead == option,
          onSelected: (_) => setState(() {
            _readAhead = option;
            _saidUpTo = _tracker?.done ?? 0;
          }),
        ),
      FilterChip(
        label: const Text('Kèm cách xoay'),
        selected: _explain,
        onSelected: (value) => setState(() => _explain = value),
      ),
    ],
  );

  void _scanAgain() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const ScanScreen(solveAfter: true)),
  );
}

/// The whole solution, the moves done faded, the current one highlighted,
/// wrong moves in red.
class _Formula extends StatelessWidget {
  const _Formula({required this.tracker});

  final SolveTracker tracker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = tracker.plan;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < plan.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tracker.mistakes.contains(i)
                  ? theme.colorScheme.errorContainer
                  : i == tracker.done && tracker.phase == TrackerPhase.solving
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              plan[i].notation,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: tracker.mistakes.contains(i)
                    ? TextDecoration.lineThrough
                    : null,
                color:
                    i == tracker.done && tracker.phase == TrackerPhase.solving
                    ? theme.colorScheme.onPrimary
                    : i < tracker.done
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
