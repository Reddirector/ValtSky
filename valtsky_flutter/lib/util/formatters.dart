/// Centralized formatters for ValtSky editorial design
class ValtSkyFormatters {
  /// Formats image and video counts across all dashboards, activities,
  /// stat tabs, and sheets.
  /// If the count is over 999, returns "999+" rather than the exact number.
  static String formatMediaCount(int count) {
    if (count > 999) return '999+';
    if (count < 0) return '0';
    return '$count';
  }

  /// Parses and formats a dynamic or string count. If over 999, returns "999+".
  static String formatDynamicCount(dynamic value) {
    if (value is int) return formatMediaCount(value);
    final parsed = int.tryParse('$value');
    if (parsed != null) return formatMediaCount(parsed);
    return '$value';
  }

  /// Formats byte sizes into elegant human-readable strings (e.g. 1.2 GB, 450 MB, 0 B).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }
}
