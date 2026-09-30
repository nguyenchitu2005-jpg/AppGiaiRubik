/// A ZB algorithm: its subset (ZBLL: the corner case such as "T1"; ZBLS:
/// the F2L case number) and its number within the subset.
class ZbCase {
  const ZbCase(this.subset, this.number, this.notation);

  final String subset;
  final int number;
  final String notation;
}
