import 'package:shared_preferences/shared_preferences.dart';

class FontSizeService {
  static const _fontSizeKey = 'font_size';
  static const double defaultSize = 34;
  static const double minSize = 24;
  static const double maxSize = 52;
  static const double step = 2;
  /// Previous default — migrate smaller saved sizes up for readability.
  static const double _legacyDefault = 26;

  double _fontSize = defaultSize;

  double get fontSize => _fontSize;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_fontSizeKey);
    if (stored == null || stored <= _legacyDefault) {
      _fontSize = defaultSize;
      await _save();
    } else {
      _fontSize = stored.clamp(minSize, maxSize);
    }
  }

  Future<double> increase() async {
    if (_fontSize >= maxSize) return _fontSize;
    _fontSize = (_fontSize + step).clamp(minSize, maxSize);
    await _save();
    return _fontSize;
  }

  Future<double> decrease() async {
    if (_fontSize <= minSize) return _fontSize;
    _fontSize = (_fontSize - step).clamp(minSize, maxSize);
    await _save();
    return _fontSize;
  }

  bool get canIncrease => _fontSize < maxSize;
  bool get canDecrease => _fontSize > minSize;

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
  }
}