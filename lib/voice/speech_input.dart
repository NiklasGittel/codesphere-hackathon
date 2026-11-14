/// Browser speech-to-text. Uses the Web Speech API on web, no-op elsewhere.
export 'speech_input_stub.dart' if (dart.library.js_interop) 'speech_input_web.dart';
