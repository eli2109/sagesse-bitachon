import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_state.dart';

class PhraseService {
  static const _stateKey = 'reading_state';
  static const _welcomeKey = 'welcome_shown';

  final Random _random = Random();

  List<String> _phrases = [];
  ReadingState _state = const ReadingState(order: [], pos: 0);

  List<String> get phrases => List.unmodifiable(_phrases);
  ReadingState get state => _state;

  Future<void> initialize() async {
    _phrases = await _loadPhrases();
    _state = await _loadState() ?? _createNewState();
    _state = _normalizeState(_state);
    await _saveState();
  }

  String? get currentPhrase {
    final index = _state.currentIndex;
    if (index == null || index < 0 || index >= _phrases.length) {
      return null;
    }
    return _phrases[index];
  }

  int get displayPosition => _state.isEmpty ? 0 : _state.pos + 1;
  int get cycleLength => _state.cycleLength;

  Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_welcomeKey) ?? false);
  }

  Future<void> markWelcomeShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, true);
  }

  Future<ReadingState> nextPhrase() async {
    if (_state.isEmpty) {
      return _state;
    }

    var nextPos = _state.pos + 1;
    var nextOrder = _state.order;

    if (nextPos >= _state.order.length) {
      final lastIndex = _state.order.isNotEmpty ? _state.order.last : null;
      nextOrder = _shuffledIndices(_phrases.length, avoidFirst: lastIndex);
      nextPos = 0;
    }

    _state = ReadingState(order: nextOrder, pos: nextPos);
    await _saveState();
    return _state;
  }

  Future<ReadingState> startNewCycle() async {
    if (_phrases.isEmpty) {
      _state = const ReadingState(order: [], pos: 0);
    } else {
      final lastIndex =
          _state.currentIndex ?? (_state.order.isNotEmpty ? _state.order.last : null);
      final newOrder = _shuffledIndices(_phrases.length, avoidFirst: lastIndex);
      _state = ReadingState(order: newOrder, pos: 0);
    }
    await _saveState();
    return _state;
  }

  Future<void> resetState() async {
    _state = _createNewState();
    await _saveState();
  }

  Future<List<String>> _loadPhrases() async {
    try {
      final jsonString = await rootBundle.loadString('assets/phrases.json');
      final decoded = json.decode(jsonString);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .where((item) => item != null)
          .map((item) => item.toString().trim())
          .where((phrase) => phrase.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ReadingState?> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_stateKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return ReadingState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, json.encode(_state.toJson()));
  }

  ReadingState _createNewState() {
    if (_phrases.isEmpty) {
      return const ReadingState(order: [], pos: 0);
    }
    return ReadingState(
      order: _shuffledIndices(_phrases.length),
      pos: 0,
    );
  }

  ReadingState _normalizeState(ReadingState loaded) {
    if (_phrases.isEmpty) {
      return const ReadingState(order: [], pos: 0);
    }

    final phraseCount = _phrases.length;
    final validOrder = loaded.order
        .where((index) => index >= 0 && index < phraseCount)
        .toList();

    if (validOrder.isEmpty) {
      return _createNewState();
    }

    final uniqueOrder = <int>[];
    final seen = <int>{};
    for (final index in validOrder) {
      if (seen.add(index)) {
        uniqueOrder.add(index);
      }
    }

    if (uniqueOrder.length != phraseCount) {
      return _createNewState();
    }

    var pos = loaded.pos;
    if (pos < 0) {
      pos = 0;
    } else if (pos >= uniqueOrder.length) {
      pos = uniqueOrder.length - 1;
    }

    return ReadingState(order: uniqueOrder, pos: pos);
  }

  List<int> _shuffledIndices(int count, {int? avoidFirst}) {
    if (count <= 0) {
      return [];
    }

    if (count == 1) {
      return [0];
    }

    final indices = List<int>.generate(count, (index) => index);

    for (var i = indices.length - 1; i > 0; i--) {
      var j = _random.nextInt(i + 1);
      if (i == 0 && avoidFirst != null && indices[j] == avoidFirst) {
        j = (j + 1) % (i + 1);
      }
      final temp = indices[i];
      indices[i] = indices[j];
      indices[j] = temp;
    }

    if (avoidFirst != null && indices.first == avoidFirst) {
      final swapIndex = 1 + _random.nextInt(count - 1);
      final temp = indices[0];
      indices[0] = indices[swapIndex];
      indices[swapIndex] = temp;
    }

    return indices;
  }
}