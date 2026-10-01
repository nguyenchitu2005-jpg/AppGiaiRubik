import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../../core/concurrency/background.dart';
import '../../core/cube/face.dart';
import '../../core/vision/color_math.dart';
import '../../core/vision/face_locator.dart';
import '../../core/vision/yuv_image.dart';
import '../../shared/cube_palette.dart';
import '../../shared/platform_support.dart';
import 'camera_list.dart';

/// The camera with a 3×3 grid drawn over its preview. Reports the 9 colors
/// inside the grid: from live frames on phones (about ten a second), from a
/// photo every half second or so in a browser and on Windows (no live
/// frames there).
///
/// With a [locator], the cube face is looked for anywhere in the picture
/// (near or far) and the grid follows it; the fixed grid in the middle is
/// only a fallback.
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
    this.locator,
    this.onLocated,
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

  /// Makes a face finder for each picture, to find the face anywhere in
  /// it. The finder may run on a background isolate: it must hold only
  /// plain data (not the screen's state).
  final FaceLocator Function()? locator;

  /// After each picture: where [locator] found the face (null: nowhere),
  /// in normalized coordinates of the preview.
  final ValueChanged<Rect?>? onLocated;

  @override
  State<CameraFeed> createState() => CameraFeedState();
}

class CameraFeedState extends State<CameraFeed> with WidgetsBindingObserver {
  /// The grid is a square this wide (fraction of the preview width).
  static const _gridWidth = 0.7;

  /// Give up opening the camera after this long (camera services can hang).
  static const _openTimeout = Duration(seconds: 5);

  /// Listing the cameras may open each of them (in a browser).
  static const _listTimeout = Duration(seconds: 12);

  /// Frames are analyzed at most this often.
  static const _analyzeEvery = Duration(milliseconds: 100);

  /// Where frames cannot be streamed, a photo is taken this often (a
  /// browser takes them quickly; Windows saves each to a file).
  static final _photoEvery = Duration(milliseconds: kIsWeb ? 450 : 700);

  /// Where [CameraFeed.locator] last found the face.
  Rect? _found;

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

  /// The camera the user last switched to, kept for the next page.
  static String? _chosenName;

  /// Cameras that can be tried, best first.
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _opening = false;

  /// Names of virtual cameras (programs that pretend to be a webcam): they
  /// show nothing, or fail, while their program is closed.
  static final _virtual = RegExp(
    r'virtual|obs|droidcam|manycam|xsplit|snap camera|broadcast|iriun|epoccam',
    caseSensitive: false,
  );

  /// Best first: the one chosen before, real cameras before virtual ones,
  /// the side asked for ([CameraFeed.preferFront]) before the other.
  List<CameraDescription> _ordered(List<CameraDescription> cameras) {
    final wanted = widget.preferFront
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    int rank(CameraDescription c) =>
        (c.name == _chosenName ? 0 : 4) +
        (_virtual.hasMatch(c.name) ? 2 : 0) +
        (c.lensDirection == wanted ? 0 : 1);
    final indexed = [for (var i = 0; i < cameras.length; i++) (i, cameras[i])];
    indexed.sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
    return [for (final (_, c) in indexed) c];
  }

  /// Opens the best camera that starts (from [first] in the list, going
  /// round): a camera can fail to start (in use by another program, a
  /// virtual camera whose program is closed), and another may still work.
  Future<void> _openCamera({int? first}) async {
    if (_opening) return;
    _opening = true;
    try {
      if (_cameras.isEmpty || first == null) {
        _cameras = _ordered(await listCameras().timeout(_listTimeout));
      }
      if (_cameras.isEmpty) {
        throw CameraException('notFound', 'Không có camera');
      }
      CameraException? failure;
      for (var step = 0; step < _cameras.length; step++) {
        final index = ((first ?? 0) + step) % _cameras.length;
        final camera = CameraController(
          _cameras[index],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        try {
          await camera.initialize().timeout(_openTimeout);
        } on CameraException catch (e) {
          await camera.dispose();
          if (_denied(e.code)) rethrow;
          failure = e;
          continue;
        } on TimeoutException {
          camera.dispose().ignore();
          failure = CameraException('timeout', 'Camera không phản hồi');
          continue;
        }
        if (!mounted) {
          await camera.dispose();
          return;
        }
        await _use(camera, index);
        return;
      }
      throw failure!;
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = _denied(e.code)
            ? kIsWeb
                  ? 'Trình duyệt chưa được cấp quyền camera. Hãy bấm biểu '
                        'tượng camera trên thanh địa chỉ, chọn Cho phép, rồi '
                        'thử lại.'
                  : isWindows
                  ? 'Windows đang chặn camera. Hãy bật trong Cài đặt > Quyền '
                        'riêng tư & bảo mật > Camera, rồi thử lại.'
                  : 'Ứng dụng chưa được cấp quyền camera. Hãy cho phép trong '
                        'Cài đặt > Ứng dụng > Rubik Solver > Quyền.'
            : e.code == 'notFound'
            ? 'Không tìm thấy camera trên thiết bị này.'
            : 'Không mở được camera (${e.code}). Có thể camera đang được '
                  'ứng dụng khác dùng (Zalo, Zoom, Camera, OBS…): hãy đóng '
                  'ứng dụng đó rồi bấm Thử lại.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tìm thấy camera trên thiết bị này.');
    } finally {
      _opening = false;
    }
  }

  static bool _denied(String code) =>
      code.contains('Access') ||
      code.contains('ermission') ||
      code.contains('NotAllowed');

  Future<void> _use(CameraController camera, int index) async {
    final photoMode = !camera.supportsImageStreaming();
    if (!photoMode) await camera.startImageStream(_onImage);
    setState(() {
      _camera = camera;
      _cameraIndex = index;
      _photoMode = photoMode;
      _error = null;
    });
    if (photoMode) {
      _poll?.cancel();
      _poll = Timer.periodic(_photoEvery, (_) => _pollPhoto());
    }
    widget.onReady?.call(photoMode);
  }

  /// Switches to the next camera (front and back, or another webcam).
  Future<void> _switchCamera() async {
    final current = _camera;
    if (current == null || _cameras.length < 2 || _opening) return;
    _poll?.cancel();
    setState(() => _camera = null);
    while (_polling || _analyzing) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await current.dispose();
    final next = (_cameraIndex + 1) % _cameras.length;
    _chosenName = _cameras[next].name;
    await _openCamera(first: next);
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
    // The camera reuses its buffers: the frame is copied before being read
    // in the background. Frames arriving meanwhile are skipped.
    _read(
          _toYuv(image),
          camera,
          rotation: camera.description.sensorOrientation,
          // The sensor is landscape; upright, the preview is turned.
          aspect: 1 / camera.value.aspectRatio,
        )
        .then((samples) {
          if (samples != null && mounted && widget.active) {
            widget.onSamples(samples, now);
          }
        })
        .catchError((Object error) {
          // A frame that cannot be read is skipped (but said, in case it
          // is every frame).
          debugPrint('Không đọc được khung hình: $error');
        })
        .whenComplete(() => _analyzing = false);
  }

  /// Takes a photo and reads the 9 colors inside the grid (waiting for a
  /// photo being taken for the live colors to finish).
  Future<List<Rgb>> takePhoto() async {
    while (_polling) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final camera = _camera;
    if (camera == null) throw StateError('Camera chưa sẵn sàng');
    return (await _readPhoto(camera, fallback: true))!;
  }

  Future<List<Rgb>?> _readPhoto(
    CameraController camera, {
    bool fallback = false,
  }) async {
    final photo = await camera.takePicture();
    final bytes = await photo.readAsBytes();
    // Windows saves each photo to a file: do not let them pile up.
    if (!kIsWeb) File(photo.path).delete().ignore();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = RgbaImage(
      width: image.width,
      height: image.height,
      bytes: data!.buffer.asUint8List(),
    );
    image.dispose();
    return _read(
      pixels,
      camera,
      rotation: 0,
      aspect: pixels.width / pixels.height,
      // Windows shows the webcam mirrored but takes photos unmirrored.
      mirrored: isWindows,
      fallback: fallback,
    );
  }

  /// The 9 colors of the face found in [image]; see [_ReadJob]. Done on a
  /// background isolate where there is one: looking for the face is heavy,
  /// and on a phone it would hold up the screen.
  Future<List<Rgb>?> _read(
    PixelSource image,
    CameraController camera, {
    required int rotation,
    required double aspect,
    bool mirrored = false,
    bool fallback = false,
  }) async {
    final job = _ReadJob(
      image: image,
      locator: widget.locator?.call(),
      guide: _gridRect(camera),
      rotation: rotation,
      aspect: aspect,
      mirrored: mirrored,
      fallback: fallback,
    );
    final (samples, found) = runsInBackground
        ? await runInBackground(job.run)
        : job.run();
    if (!mounted) return null;
    if (job.locator != null) widget.onLocated?.call(found);
    _found = found;
    return samples;
  }

  /// A photo read like a streamed frame.
  Future<void> _pollPhoto() async {
    final camera = _camera;
    if (camera == null || _polling || !widget.active) return;
    _polling = true;
    try {
      final samples = await _readPhoto(camera);
      if (samples != null && mounted && _camera == camera && widget.active) {
        widget.onSamples(samples, widget.clock.elapsed);
      }
    } catch (error) {
      // A missed photo is skipped (but said, in case it is every photo).
      debugPrint('Không đọc được ảnh: $error');
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
    y: Uint8List.fromList(image.planes[0].bytes),
    yRowStride: image.planes[0].bytesPerRow,
    u: Uint8List.fromList(image.planes[1].bytes),
    v: Uint8List.fromList(image.planes[2].bytes),
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
                    grid: (widget.active ? _found : null) ?? _gridRect(camera),
                    // Looking for the face (or done): the fixed grid is just
                    // a hint.
                    faint:
                        widget.locator != null &&
                        (_found == null || !widget.active),
                    live: widget.live,
                    stable: widget.stable,
                  ),
                ),
                if (_cameras.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip:
                          'Đổi camera (đang dùng: ${_cameras[_cameraIndex].name})',
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.cameraswitch_outlined),
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
  _GridOverlay({
    required this.grid,
    required this.live,
    required this.stable,
    this.faint = false,
  });

  final Rect grid;
  final bool faint;
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
      ..color = faint
          ? Colors.white38
          : stable
          ? Colors.greenAccent
          : Colors.white;
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
        final guess = faint ? null : live?[row * 3 + col];
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
      old.grid != grid ||
      old.live != live ||
      old.stable != stable ||
      old.faint != faint;
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

/// Reading one picture, made only of plain data so that it can run on a
/// background isolate.
class _ReadJob {
  const _ReadJob({
    required this.image,
    required this.locator,
    required this.guide,
    required this.rotation,
    required this.aspect,
    required this.mirrored,
    required this.fallback,
  });

  final PixelSource image;
  final FaceLocator? locator;

  /// The fixed grid in the middle of the preview.
  final Rect guide;
  final int rotation;
  final double aspect;
  final bool mirrored;

  /// Read the fixed grid when the locator finds no face.
  final bool fallback;

  /// Width of the small picture the face is looked for in.
  static const _searchWidth = 200;

  /// The 9 colors of the face found (or in the fixed grid without a
  /// locator), and where it was found. When the locator finds no face,
  /// no colors: the fixed grid would read whatever is behind it (a white
  /// wall is not the white face), unless [fallback].
  (List<Rgb>?, Rect?) run() {
    final locator = this.locator;
    Rect? found;
    if (locator != null) {
      found = locator.locate(
        GridSampler.downsample(
          image,
          width: _searchWidth,
          aspect: aspect,
          rotation: rotation,
          mirrored: mirrored,
        ),
      );
      if (found == null && !fallback) return (null, null);
    }
    final samples = GridSampler.sample(
      image,
      grid: found ?? guide,
      rotation: rotation,
      mirrored: mirrored,
    );
    return (samples, found);
  }
}
