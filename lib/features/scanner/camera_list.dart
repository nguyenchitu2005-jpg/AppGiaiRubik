/// The cameras that can be opened (see [listCameras]).
library;

export 'camera_list_io.dart'
    if (dart.library.js_interop) 'camera_list_web.dart';
