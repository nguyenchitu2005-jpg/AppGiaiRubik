import 'dart:isolate';

/// Runs [work] on a new isolate so the UI keeps animating.
Future<R> runInBackground<R>(R Function() work) => Isolate.run(work);
