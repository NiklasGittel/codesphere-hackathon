import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Thin wrapper around the browser's (webkit)SpeechRecognition.
class SpeechInput {
  JSObject? _rec;

  String? get _ctorName => globalContext.has('SpeechRecognition')
      ? 'SpeechRecognition'
      : (globalContext.has('webkitSpeechRecognition') ? 'webkitSpeechRecognition' : null);

  bool get supported => _ctorName != null;

  bool start({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onEnd,
    void Function(String error)? onError,
    String lang = 'en-US',
  }) {
    final name = _ctorName;
    if (name == null) return false;
    stop();
    final ctor = globalContext[name] as JSFunction;
    final rec = ctor.callAsConstructor<JSObject>();
    rec['lang'] = lang.toJS;
    rec['interimResults'] = true.toJS;
    rec['continuous'] = false.toJS;
    rec['maxAlternatives'] = 1.toJS;

    rec['onresult'] = ((JSObject event) {
      final results = event['results'] as JSObject;
      final length = (results['length'] as JSNumber).toDartInt;
      final text = StringBuffer();
      var isFinal = length > 0;
      for (var i = 0; i < length; i++) {
        final result = results.callMethod<JSObject>('item'.toJS, i.toJS);
        final alt = result.callMethod<JSObject>('item'.toJS, 0.toJS);
        text.write((alt['transcript'] as JSString).toDart);
        if (!(result['isFinal'] as JSBoolean).toDart) isFinal = false;
      }
      onResult(text.toString(), isFinal);
    }).toJS;

    rec['onerror'] = ((JSObject event) {
      final error = event['error'];
      onError?.call(error == null ? 'unknown' : (error as JSString).toDart);
    }).toJS;

    rec['onend'] = ((JSAny? _) => onEnd()).toJS;

    rec.callMethod<JSAny?>('start'.toJS);
    _rec = rec;
    return true;
  }

  void stop() {
    final rec = _rec;
    _rec = null;
    if (rec != null) {
      rec['onend'] = null;
      rec['onresult'] = null;
      rec.callMethod<JSAny?>('stop'.toJS);
    }
  }
}
