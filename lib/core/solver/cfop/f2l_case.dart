/// Where the pair's corner and edge are before the F2L algorithm.
enum F2lCategory {
  bothTop('Cả góc và cạnh ở tầng trên'),
  cornerInSlot('Góc đã ở trong khe, cạnh ở tầng trên'),
  edgeInSlot('Cạnh đã ở trong khe, góc ở tầng trên'),
  bothInSlot('Cả hai ở trong khe nhưng sai hướng');

  const F2lCategory(this.label);

  final String label;
}

/// An F2L algorithm for the front-right slot.
class F2lCase {
  const F2lCase(this.category, this.notation);

  final F2lCategory category;
  final String notation;
}
