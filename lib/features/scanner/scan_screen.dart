import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cube/face.dart';
import '../../core/vision/scan_assembler.dart';
import '../../shared/cube_palette.dart';
import '../../shared/platform_support.dart';
import '../camera_solve/camera_solve_screen.dart';
import '../input/net_editor_screen.dart';
import 'camera_feed.dart';
import 'scan_controller.dart';

/// Scans the six faces, then opens the color editor with the result so the
/// user can check and fix it; or, with [solveAfter], goes on to solving the
/// cube along with the camera.
///
/// On phones the colors are read live from the camera's frames. In a
/// browser and on Windows the camera plugin has no live frames: photos are
/// taken instead.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.solveAfter = false});

  /// Scan to solve along with the camera (the camera facing the user).
  final bool solveAfter;

  static const routeName = '/scan';

  /// Scanning, then solving along with the camera.
  static const solveRouteName = '/camera-solve';

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ScanController _scan = ScanController();
  final Stopwatch _clock = Stopwatch()..start();
  final GlobalKey<CameraFeedState> _feed = GlobalKey();

  /// Faces are photographed (no live frames on this platform).
  bool _photoMode = false;
  bool _cameraReady = false;

  /// A photo is being taken and read.
  bool _busy = false;

  /// Faces captured so far, to notice each new one.
  int _capturedCount = 0;

  @override
  void initState() {
    super.initState();
    AppOrientation.lockPortrait();
    _scan.addListener(_onScanChanged);
  }

  @override
  void dispose() {
    AppOrientation.applyDefault();
    _scan
      ..removeListener(_onScanChanged)
      ..dispose();
    super.dispose();
  }

  /// Takes a photo of the face in the grid and captures its 9 colors.
  Future<void> _capturePhoto() async {
    final feed = _feed.currentState;
    if (feed == null || _busy) return;
    setState(() => _busy = true);
    try {
      _scan.captureSamples(await feed.takePhoto());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không chụp được ảnh: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onScanChanged() {
    if (!mounted) return;
    if (_scan.stepIndex > _capturedCount) {
      // A face was just captured (maybe by itself): say which one.
      final face = ScanController.steps[_scan.stepIndex - 1].face;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text(
              'Đã chụp mặt tâm ${face.colorName.toLowerCase()} '
              '(${_scan.stepIndex}/6)',
            ),
          ),
        );
    }
    _capturedCount = _scan.stepIndex;
    if (_scan.isComplete) {
      _finish(_scan.assemble());
    } else {
      setState(() {});
    }
  }

  void _finish(ScanResult result) {
    final navigator = Navigator.of(context);
    // Solving along: a valid scan goes straight to it.
    if (widget.solveAfter && result.validation.isValid) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CameraSolveScreen(start: result.state, scan: result),
        ),
      );
      return;
    }
    final turned = result.rotatedFaces.keys
        .map((f) => 'tâm ${f.colorName.toLowerCase()}')
        .join(', ');
    final notice = [
      if (result.rotatedFaces.isNotEmpty && result.cameraTurns == 0)
        'Đã tự xoay lại mặt $turned vì có vẻ bạn cầm lệch hướng.',
      if (!result.validation.isValid)
        'Kết quả quét chưa hợp lệ: '
            '${result.validation.issues.first.message} '
            'Hãy so với khối thật và sửa các ô sai.',
      if (result.validation.isValid)
        'Hãy so với khối thật; nếu có ô sai, chọn màu đúng và chạm vào ô đó.',
    ].join('\n');
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NetEditorScreen(
          initial: result.state,
          title: 'Kiểm tra kết quả quét',
          notice: notice,
          doneLabel: widget.solveAfter ? 'Giải cùng camera' : null,
          onDone: widget.solveAfter
              ? (context, cube) => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CameraSolveScreen(start: cube, scan: result),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _scan.step;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.solveAfter
              ? 'Quét để giải cùng camera'
              : 'Quét khối bằng camera',
        ),
      ),
      body: SafeArea(
        // Keep the end of the page clear of the system navigation bar
        // (Android draws edge to edge).
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.solveAfter) ...[
                  Text(
                    'Quét 6 mặt, rồi app đọc từng nước giải và nhìn khối qua '
                    'camera để biết bạn đã xoay đúng chưa. Nên dựng máy trước '
                    'mặt, camera hướng về phía bạn.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
                _FaceProgress(scan: _scan),
                const SizedBox(height: 12),
                if (step != null)
                  Text(
                    'Mặt ${_scan.stepIndex + 1}/6: ${step.instruction}',
                    style: theme.textTheme.titleSmall,
                  ),
                const SizedBox(height: 12),
                CameraFeed(
                  key: _feed,
                  clock: _clock,
                  preferFront: widget.solveAfter,
                  active: !_scan.isComplete && !_busy,
                  live: _scan.live,
                  stable: _scan.isStable,
                  onSamples: _scan.addFrame,
                  onReady: (photoMode) => setState(() {
                    _photoMode = photoMode;
                    _cameraReady = true;
                  }),
                  // On a computer screen keep the capture button in view:
                  // the preview gets the height the rest leaves.
                  maxHeight: _photoMode
                      ? max(200.0, MediaQuery.sizeOf(context).height - 360)
                      : double.infinity,
                ),
                const SizedBox(height: 8),
                if (step != null && !_scan.centerMatches)
                  Text(
                    'Tâm đang thấy không giống màu '
                    '${step.face.colorName.toLowerCase()}: hãy kiểm tra lại mặt '
                    'đang quét.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                Text(
                  _scan.live == null
                      ? 'Căn mặt khối cho vừa lưới và giữ yên.'
                      : !_scan.isClear
                      ? 'Đưa cả mặt vào lưới, đủ sáng, để thấy rõ màu từng ô.'
                      : _scan.autoCapture && _scan.centerMatches
                      ? 'Giữ yên, app sẽ tự chụp khi màu ổn định…'
                      : _scan.isStable
                      ? 'Màu đã ổn định, có thể chụp.'
                      : 'Giữ yên khối trong khung…',
                  style: theme.textTheme.bodySmall,
                ),
                if (_scan.autoCapture) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    key: const ValueKey('auto-capture-progress'),
                    value: _scan.autoProgress(_clock.elapsed),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Tự động chụp khi nhận rõ màu'),
                  value: _scan.autoCapture,
                  onChanged: (value) =>
                      setState(() => _scan.autoCapture = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scan.stepIndex == 0
                            ? null
                            : _scan.retakePrevious,
                        icon: const Icon(Icons.undo),
                        label: const Text('Chụp lại mặt trước'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _photoMode
                            ? (!_cameraReady || _busy ? null : _capturePhoto)
                            : (_scan.isStable ? _scan.capture : null),
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.camera),
                        label: const Text('Chụp mặt này'),
                      ),
                    ),
                  ],
                ),
                if (!widget.solveAfter)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushReplacementNamed(NetEditorScreen.routeName),
                    child: const Text('Không quét được? Nhập màu bằng tay'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Six small tiles, one per face, filled in as faces are captured.
class _FaceProgress extends StatelessWidget {
  const _FaceProgress({required this.scan});

  final ScanController scan;

  @override
  Widget build(BuildContext context) {
    final captured = scan.capturedPreview;
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < ScanController.steps.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: CubePalette.body,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: i == scan.stepIndex
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _MiniFace(
                    colors: captured[ScanController.steps[i].face],
                    center: ScanController.steps[i].face,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniFace extends StatelessWidget {
  const _MiniFace({required this.colors, required this.center});

  final List<Face>? colors;
  final Face center;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 1.5,
      crossAxisSpacing: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 9; i++)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: colors != null
                  ? CubePalette.of(colors![i])
                  : i == 4
                  ? CubePalette.of(center)
                  : Colors.grey.shade800,
            ),
          ),
      ],
    );
  }
}
