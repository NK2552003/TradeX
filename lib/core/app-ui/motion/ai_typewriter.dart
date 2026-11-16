import 'dart:async';

import 'package:flutter/widgets.dart';

/// Tune the reveal cadence here. API chunks never restart this queue.
const aiTypingCharacterInterval = Duration(milliseconds: 25);

class AiTypewriter extends ChangeNotifier {
  AiTypewriter({this.interval = aiTypingCharacterInterval});
  final Duration interval;
  Timer? _timer;
  String _target = '';
  final List<String> _queue = [];
  int _shown = 0;
  int _visibleUnits = 0;
  bool _skipped = false;
  bool _reducedMotion = false;

  String get visibleText => _target.substring(0, _visibleUnits);
  bool get isTyping => _shown < _queue.length;
  bool get skipped => _skipped;

  set reducedMotion(bool value) {
    _reducedMotion = value;
    if (value) _revealAll();
  }

  void reset(String text, {required bool animate}) {
    _timer?.cancel();
    _timer = null;
    _skipped = false;
    _target = '';
    _queue.clear();
    _shown = 0;
    _visibleUnits = 0;
    update(text, animate: animate);
  }

  void update(String text, {bool animate = true}) {
    if (text == _target) return;
    if (text.startsWith(_target)) {
      // Re-segment the tail to keep emoji/combining marks intact across chunks.
      final tail = _target.isEmpty ? 0 : _target.length - _queue.last.length;
      if (_queue.isNotEmpty) _queue.removeLast();
      _queue.addAll(text.substring(tail).characters);
    } else {
      _queue
        ..clear()
        ..addAll(text.characters);
      _shown = 0;
      _visibleUnits = 0;
    }
    _target = text;
    if (!animate || _skipped || _reducedMotion) {
      _revealAll();
      return;
    }
    // A chunk may extend the final grapheme that is already visible.
    _shown = _shown.clamp(0, _queue.length);
    _visibleUnits = _queue.take(_shown).fold(0, (n, c) => n + c.length);
    _timer ??= Timer.periodic(interval, (_) {
      if (!isTyping) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      _visibleUnits += _queue[_shown++].length;
      notifyListeners();
      if (!isTyping) {
        _timer?.cancel();
        _timer = null;
      }
    });
    notifyListeners();
  }

  void skip() {
    _skipped = true;
    _revealAll();
  }

  void _revealAll() {
    _timer?.cancel();
    _timer = null;
    _shown = _queue.length;
    _visibleUnits = _target.length;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
