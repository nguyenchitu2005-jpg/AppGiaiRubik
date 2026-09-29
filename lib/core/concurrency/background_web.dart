/// The web has no isolates (`Isolate.run` throws there), so [work] runs on
/// the UI thread, after a short pause that lets the loading indicator show.
Future<R> runInBackground<R>(R Function() work) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return work();
}
