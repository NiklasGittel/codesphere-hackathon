String groupThousands(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (v < 0 ? '-' : '') + b.toString();
}

/// Formats a value for tooltips / labels based on its unit.
String formatValue(double v, String unit) {
  switch (unit) {
    case '€':
    case '\$':
      return '$unit${groupThousands(v)}';
    case 'ms':
      return v >= 1000
          ? '${(v / 1000).toStringAsFixed(2)} s'
          : '${v.round()} ms';
    case '%':
      return '${v.toStringAsFixed(1)}%';
    case '':
      return groupThousands(v);
    default:
      return '${groupThousands(v)} $unit';
  }
}

/// Compact axis labels.
String formatAxis(double v, String unit) {
  String compact(double x) => x >= 1000
      ? '${(x / 1000).toStringAsFixed(x % 1000 == 0 ? 0 : 1)}k'
      : (x < 10 && x != x.roundToDouble())
          ? x.toStringAsFixed(1)
          : x.round().toString();
  if (unit == 'ms') {
    return v >= 1000
        ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}s'
        : '${v.round()}';
  }
  if (unit == '€' || unit == '\$') return '$unit${compact(v)}';
  if (unit == '%') return '${compact(v)}%';
  return compact(v);
}

String formatDuration(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
