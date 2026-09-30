/// Runs heavy work (the solvers) without freezing the UI where the platform
/// allows it: on a separate isolate natively, on the UI thread on the web.
library;

export 'background_io.dart' if (dart.library.js_interop) 'background_web.dart';
