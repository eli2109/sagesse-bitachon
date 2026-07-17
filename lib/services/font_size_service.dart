import 'package:shared_preferences/shared_preferences.dart';

class FontSizeService {
  static const _fontSizeKey = 'font_size';
  static const double defaultSize = 26;
  static const double minSize = 18;
  static const double maxSize = 42;
  static const double step = 2;

  double _fontSize = defaultSize;

  double get fontSize => _fontSize;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_fontSizeKey) ?? defaultSize;
    _fontSize = _fontSize.clamp(minSize, maxSize);
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