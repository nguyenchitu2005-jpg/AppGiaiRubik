import 'package:camera/camera.dart';

/// The device's cameras.
Future<List<CameraDescription>> listCameras() => availableCameras();
