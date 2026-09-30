/// Windows at least this wide (logical pixels) get two-column layouts:
/// computers, tablets and wide web browsers. Phones keep one column.
const double wideLayoutWidth = 840;

bool isWideLayout(double width) => width >= wideLayoutWidth;
