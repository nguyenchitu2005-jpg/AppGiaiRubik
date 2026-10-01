import 'dart:js_interop';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_web/camera_web.dart';
// The plugin keeps each camera's device id here; filled in for the cameras
// listed below.
// ignore: implementation_imports
import 'package:camera_web/src/types/camera_metadata.dart';
import 'package:web/web.dart' as web;

/// The browser's cameras that start.
///
/// The camera plugin opens every camera to list it and gives up at the
/// first one that cannot start, e.g. a virtual camera whose program is
/// closed (OBS Virtual Camera): then no camera at all could be used. In
/// that case each camera is tried here and only those that start are kept.
Future<List<CameraDescription>> listCameras() async {
  try {
    return await availableCameras();
  } on CameraException catch (e) {
    final plugin = CameraPlatform.instance;
    if (_denied(e.code) || plugin is! CameraPlugin) rethrow;
    final cameras = await _startingCameras(plugin);
    if (cameras.isEmpty) rethrow;
    return cameras;
  }
}

bool _denied(String code) =>
    code.contains('ermission') ||
    code.contains('NotAllowed') ||
    code.contains('Access');

Future<List<CameraDescription>> _startingCameras(CameraPlugin plugin) async {
  final mediaDevices = web.window.navigator.mediaDevices;
  final devices = (await mediaDevices.enumerateDevices().toDart).toDart.where(
    (d) => d.kind == 'videoinput' && d.deviceId.isNotEmpty,
  );
  final cameras = <CameraDescription>[];
  for (final device in devices) {
    try {
      final stream = await mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: {
                'deviceId': {'exact': device.deviceId},
              }.jsify()!,
            ),
          )
          .toDart;
      final tracks = stream.getVideoTracks().toDart;
      final facing = tracks.isEmpty
          ? ''
          : tracks.first.getSettings().facingMode;
      for (final track in tracks) {
        track.stop();
      }
      final camera = CameraDescription(
        name: device.label,
        lensDirection: switch (facing) {
          'user' => CameraLensDirection.front,
          'environment' => CameraLensDirection.back,
          _ => CameraLensDirection.external,
        },
        sensorOrientation: 0,
      );
      // Where the plugin looks up each camera's device id when opening it.
      // ignore: invalid_use_of_visible_for_testing_member
      plugin.camerasMetadata[camera] = CameraMetadata(
        deviceId: device.deviceId,
        facingMode: facing.isEmpty ? null : facing,
      );
      cameras.add(camera);
    } catch (_) {
      // This camera does not start: leave it out.
    }
  }
  return cameras;
}
