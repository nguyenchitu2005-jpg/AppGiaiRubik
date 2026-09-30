import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/cube/face.dart';
import '../../core/vision/color_math.dart';
import '../../core/vision/yuv_image.dart';
import '../../shared/cube_palette.dart';
import '../../shared/platform_support.dart';

/// The camera with a 3×3 grid drawn over its preview. Reports the 9 colors
/// inside the grid: from live frames on phones (about ten a second), from a
/// photo every 0.7 s in a browser and on Windows (no live frames there).
class CameraFeed extends StatefulWidget {
  const CameraFeed({
    super.key,
    required this.clock,
    required this.onSamples,
    this.live,
    this.stable = false,
    this.active = true,
    this.preferFront = false,
    this.maxHeight = double.infinity,
    this.onReady,
  });

  /// Times the samples.
  final Stopwatch clock;

  final void Function(List<Rgb> samples, Duration time) onSamples;

  /// Colors to draw as dots in the grid (as read, row by row).
  final List<Face>? live;

  /// Draw the grid green (the colors hold still).
  final bool stable;

  /// Read colors at all (stop when there is nothing left to read).
  final bool active;

  /// Use the camera on the screen's side (to watch the user while they
  /// look at the screen), when there is one.
  final bool preferFront;

  final double maxHeight;

  /// The camera opened; true when colors come from photos.
  final ValueChanged<bool>? onReady;

  @override
  State<CameraFeed> createState() => CameraFeedState();
}

class CameraFeedState extends State<CameraFeed> with WidgetsBindingObserver {
  /// The grid is a square this wide (fraction of the preview width).
  static const _gridWidth = 0.7;

  /// Give up opening the camera after this long (camera services can hang).
  static const _openTimeout = Duration(seconds: 5);

  /// Frames are analyzed at most this often.
  static const _analyzeEvery = Duration(milliseconds: 100);

  /// Where frames cannot be streamed, a photo is taken this often.
  static const _photoEvery = Duration(milliseconds: 700);

  CameraController? _camera;
  String? _error;
  bool _photoMode = false;
  Timer? _poll;
  bool _polling = false;
  Duration _lastAnalyzed = -_analyzeEvery;
  bool _analyzing = false;

  /// Colors come from photos (no live frames on this platform).
  bool get photoMode => _photoMode;

  bool get isReady => _camera?.value.isInitialized ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      _poll?.cancel();
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
      final wanted = widget.preferFront
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final chosen = cameras.firstWhere(
        (c) => c.lensDirection == wanted,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        chosen,
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
      if (photoMode) {
        _poll?.cancel();
        _poll = Timer.periodic(_photoEvery, (_) => _pollPhoto());
      }
      widget.onReady?.call(photoMode);
    } on CameraException catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _error = 'Không tìm thấy camera trên thiết bị này.');
    }
  }

  void _onImage(CameraImage image) {
    final now = widget.clock.elapsed;
    final camera = _camera;
    if (!widget.active ||
        _analyzing ||
        camera == null ||
        now - _lastAnalyzed < _analyzeEvery) {
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
      widget.onSamples(samples, now);
    } finally {
      _analyzing = false;
    }
  }

  /// Takes a photo and reads the 9 colors inside the grid (waiting for a
  /// photo being taken for the live colors to finish).
  Future<List<Rgb>> takePhoto() async {
    while (_polling) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final camera = _camera;
    if (camera == null) throw StateError('Camera chưa sẵn sàng');
    return _readPhoto(camera);
  }

  Future<List<Rgb>> _readPhoto(CameraController camera) async {
    final photo = await camera.takePicture();
    final bytes = await photo.readAsBytes();
    // Windows saves each photo to a file: do not let them pile up.
    if (!kIsWeb) File(photo.path).delete().ignore();
    final codec = await ui.instantiateImageCodec(bytes);
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
    return samples;
  }

  /// A photo read like a streamed frame.
  Future<void> _pollPhoto() async {
    final camera = _camera;
    if (camera == null || _polling || !widget.active) return;
    _polling = true;
    try {
      final samples = await _readPhoto(camera);
      if (mounted && _camera == camera && widget.active) {
        widget.onSamples(samples, widget.clock.elapsed);
      }
    } catch (_) {
      // A missed photo is simply skipped.
    } finally {
      _polling = false;
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

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    if (_error != null) {
      return _CameraError(message: _error!, onRetry: _openCamera);
    }
    if (camera == null || !camera.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 3 / 4,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
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
                    live: widget.live,
                    stable: widget.stable,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
