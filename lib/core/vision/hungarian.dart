/// Minimum-cost perfect matching on a square [cost] matrix (Hungarian
/// algorithm with potentials, O(n³)). Returns `result[row] = column`.
List<int> minCostAssignment(List<List<double>> cost) {
  final n = cost.length;
  final u = List.filled(n + 1, 0.0), v = List.filled(n + 1, 0.0);
  // p[column] = row matched to it (1-based; 0 = free).
  final p = List.filled(n + 1, 0), way = List.filled(n + 1, 0);
  for (var row = 1; row <= n; row++) {
    p[0] = row;
    var j0 = 0;
    final minv = List.filled(n + 1, double.infinity);
    final used = List.filled(n + 1, false);
    do {
      used[j0] = true;
      final i0 = p[j0];
      var delta = double.infinity;
      var j1 = 0;
      for (var j = 1; j <= n; j++) {
        if (used[j]) continue;
        final reduced = cost[i0 - 1][j - 1] - u[i0] - v[j];
        if (reduced < minv[j]) {
          minv[j] = reduced;
          way[j] = j0;
        }
        if (minv[j] < delta) {
          delta = minv[j];
          j1 = j;
        }
      }
      for (var j = 0; j <= n; j++) {
        if (used[j]) {
          u[p[j]] += delta;
          v[j] -= delta;
        } else {
          minv[j] -= delta;
        }
      }
      j0 = j1;
    } while (p[j0] != 0);
    do {
      final j1 = way[j0];
      p[j0] = p[j1];
      j0 = j1;
    } while (j0 != 0);
  }
  final result = List.filled(n, -1);
  for (var j = 1; j <= n; j++) {
    if (p[j] != 0) result[p[j] - 1] = j - 1;
  }
  return result;
}
