import 'dart:js_interop';
import 'package:web/web.dart' as web;

class LessonUnloadGuard {
  bool _active = false;
  final JSFunction _listener = ((web.Event event) {
    event.preventDefault();
    (event as web.BeforeUnloadEvent).returnValue = '';
  }).toJS;

  void update(bool unsaved) {
    if (_active == unsaved) return;
    _active = unsaved;
    if (_active) {
      web.window.addEventListener('beforeunload', _listener);
    } else {
      web.window.removeEventListener('beforeunload', _listener);
    }
  }

  void dispose() => update(false);
}
