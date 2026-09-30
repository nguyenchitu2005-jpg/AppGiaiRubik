import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/cube/face.dart';
import '../../core/vision/scan_assembler.dart';
import '../../core/vision/yuv_image.dart';
import '../../shared/cube_palette.dart';
import '../../shared/platform_support.dart';
import '../input/net_editor_screen.dart';
import 'scan_controller.dart';

/// Scans the six faces with the back camera, then opens the color editor
/// with the result so the user can check and fix it.
///
/// On phones the colors are read live from the camera's frames. In a
/// browser and on Windows the camera plugin has no live frames: the user
/// takes a photo of each face instead.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  static const routeName = '/scan';

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  /// The grid is a square this wide (fraction of the preview width).
  static const _gridWidth = 0.7;

  /// Give up opening the camera after this long (camera services can hang).
  static const _openTimeout = Duration(seconds: 5);

  /// Frames are analyzed at most this often.
  static const _analyzeEvery = Duration(milliseconds: 100);

  final ScanController _scan = ScanController();
  final Stopwatch _clock = Stopwatch()..start();
  CameraController? _camera;
  String? _error;

  /// Faces are photographed (no live frames on this platform).
  bool _photoMode = false;

  /// A photo is being taken and read.
  bool _busy = false;
  Duration _lastAnalyzed = -_analyzeEvery;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    AppOrientation.lockPortrait();
    WidgetsBinding.instance.addObserver(this);
    _scan.addListener(_onScanChanged);
    _openCamera();
  }

  @override
  void dispose() {
    AppOrientation.applyDefault();
    WidgetsBinding.instance.removeObserver(this);
    _scan
      ..removeListener(_onScanChanged)
      ..dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      _camera = null;
      camera.dispose();
      setState(() {});
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _openCamera();
    }
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras().timeout(_openTimeout);
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await camera.initialize().timeout(_openTimeout);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      final photoMode = !camera.supportsImageStreaming();
      if (!photoMode) await camera.startImageStream(_onImage);
      setState(() {
        _camera = camera;
        _photoMode = photoMode;
        _error = null;
      });
    } on CameraException catch (e) {
      final denied =
          e.code.contains('Access') ||
          e.code.contains('ermission') ||
          e.code.contains('NotAllowed');
      setState(
        () => _error = !denied
            ? 'Không mở được camera (${e.code}).'
            : kIsWeb
            ? 'Trình duyệt chưa được cấp quyền camera. Hãy bấm biểu tượng '
                  'camera trên thanh địa chỉ, chọn Cho phép, rồi thử lại.'
            : isWindows
            ? 'Windows đang chặn camera. Hãy bật trong Cài đặt > Quyền riêng '
                  'tư & bảo mật > Camera, rồi thử lại.'
            : 'Ứng dụng chưa được cấp quyền camera. Hãy cho phép trong Cài '
                  'đặt > Ứng dụng > Rubik Solver > Quyền.',
      );
    } catch (_) {
      setState(() => _error = 'Không tìm thấy camera trên thiết bị này.');
    }
  }

  void _onImage(CameraImage image) {
    final now = _clock.elapsed;
    final camera = _camera;
    if (_analyzing || camera == null || now - _lastAnalyzed < _analyzeEvery) {
      return;
    }
    _analyzing = true;
    _lastAnalyzed = now;
    try {
      final samples = GridSampler.sample(
        _toYuv(image),
        grid: _gridRect(camera),
        rotation: camera.description.sensorOrientation,
      );
      _scan.addFrame(samples, now);
    } finally {
      _analyzing = false;
    }
  }

  /// Takes a photo of the face in the grid and reads its 9 colors.
  Future<void> _capturePhoto() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() => _busy = true);
    try {
      final photo = await camera.takePicture();
      final codec = await ui.instantiateImageCodec(await photo.readAsBytes());
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final samples = GridSampler.sample(
        RgbaImage(
          width: image.width,
          height: image.height,
          bytes: data!.buffer.asUint8List(),
        ),
        grid: _gridRect(camera),
        rotation: 0,
        // Windows shows the webcam mirrored but takes photos unmirrored.
        mirrored: isWindows,
      );
      image.dispose();
      _scan.captureSamples(samples);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không chụp được ảnh: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The grid square, in normalized coordinates of the upright preview.
  Rect _gridRect(CameraController camera) {
    if (_photoMode) {
      // The preview is shown as the camera gives it, aspectRatio wide.
      final aspect = camera.value.aspectRatio;
      final (width, height) = aspect >= 1
          ? (_gridWidth / aspect, _gridWidth)
          : (_gridWidth, _gridWidth * aspect);
      return Rect.fromLTWH((1 - width) / 2, (1 - height) / 2, width, height);
    }
    // The sensor is landscape; upright, the preview is 1/aspectRatio wide.
    final widthOverHeight = 1 / camera.value.aspectRatio;
    final height = _gridWidth * widthOverHeight;
    return Rect.fromLTWH(
      (1 - _gridWidth) / 2,
      (1 - height) / 2,
      _gridWidth,
      height,
    );
  }

  static YuvImage _toYuv(CameraImage image) => YuvImage(
    width: image.width,
    height: image.height,
    y: image.planes[0].bytes,
    yRowStride: image.planes[0].bytesPerRow,
    u: image.planes[1].bytes,
    v: image.planes[2].bytes,
    uvRowStride: image.planes[1].bytesPerRow,
    uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
  );

  void _onScanChanged() {
    if (!mounted) return;
    if (_scan.isComplete) {
      _finish(_scan.assemble());
    } else {
      setState(() {});
    }
  }

  void _finish(ScanResult result) {
    _camera?.stopImageStream().ignore();
    final turned = result.rotatedFaces.keys
        .map((f) => 'tâm ${f.colorName.toLowerCase()}')
        .join(', ');
    final notice = [
      if (result.rotatedFaces.isNotEmpty)
        'Đã tự xoay lại mặt $turned vì có vẻ bạn cầm lệch hướng.',
      if (!result.validation.isValid)
        'Kết quả quét chưa hợp lệ: '
            '${result.validation.issues.first.message} '
            'Hãy so với khối thật và sửa các ô sai.',
      if (result.validation.isValid)
        'Hãy so với khối thật; nếu có ô sai, chọn màu đúng và chạm vào ô đó.',
    ].join('\n');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NetEditorScreen(
          initial: result.state,
          title: 'Kiểm tra kết quả quét',
          notice: notice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _scan.step;
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Quét khối bằng camera')),
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
                _FaceProgress(scan: _scan),
                const SizedBox(height: 12),
                if (step != null)
                  Text(
                    'Mặt ${_scan.stepIndex + 1}/6: ${step.instruction}',
                    style: theme.textTheme.titleSmall,
                  ),
                const SizedBox(height: 12),
                if (_error != null)
                  _CameraError(message: _error!, onRetry: _openCamera)
                else if (camera == null || !camera.value.isInitialized)
                  const AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  // On a computer screen keep the capture button in view:
                  // the preview gets the height the rest leaves.
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: _photoMode
                            ? max(
                                200.0,
                                MediaQuery.sizeOf(context).height - 360,
                              )
                            : double.infinity,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          // Phones: the landscape sensor shown upright. Browser and
                          // Windows: the picture as the camera gives it.
                          aspectRatio: _photoMode
                              ? camera.value.aspectRatio
                              : 1 / camera.value.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_photoMode)
                                camera.buildPreview()
                              else
                                CameraPreview(camera),
                              CustomPaint(
                                painter: _GridOverlay(
                                  grid: _gridRect(camera),
                                  live: _scan.live,
                                  stable: _scan.isStable,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                  _photoMode
                      ? 'Căn mặt khối cho vừa lưới, giữ yên rồi bấm "Chụp mặt này".'
                      : _scan.isStable
                      ? 'Màu đã ổn định, có thể chụp.'
                      : 'Giữ yên khối trong khung…',
                  style: theme.textTheme.bodySmall,
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
                            ? (camera == null || _busy ? null : _capturePhoto)
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

class _GridOverlay extends CustomPainter {
  _GridOverlay({required this.grid, required this.live, required this.stable});

  final Rect grid;
  final List<Face>? live;
  final bool stable;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      grid.left * size.width,
      grid.top * size.height,
      grid.width * size.width,
      grid.height * size.height,
    );
    final cell = rect.width / 3;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = stable ? Colors.greenAccent : Colors.white;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final cellRect = Rect.fromLTWH(
          rect.left + col * cell,
          rect.top + row * cell,
          cell,
          cell,
        ).deflate(4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect, const Radius.circular(10)),
          border,
        );
        final guess = live?[row * 3 + col];
        if (guess != null) {
          final dot = Rect.fromCenter(
            center: cellRect.center,
            width: cell * 0.28,
            height: cell * 0.28,
          );
          canvas
            ..drawRRect(
              RRect.fromRectAndRadius(dot, const Radius.circular(6)),
              Paint()..color = CubePalette.of(guess),
            )
            ..drawRRect(
              RRect.fromRectAndRadius(dot, const Radius.circular(6)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = Colors.black54,
            );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridOverlay old) =>
      old.grid != grid || old.live != live || old.stable != stable;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.no_photography,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
