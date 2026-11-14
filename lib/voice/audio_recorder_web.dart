import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

/// Records raw PCM through the Web Audio API and encodes it as WAV,
/// a format Gemini accepts directly.
class AudioRecorder {
  JSObject? _ctx;
  JSObject? _stream;
  JSObject? _source;
  JSObject? _processor;
  final List<Float32List> _chunks = [];
  double _sampleRate = 48000;

  bool get supported {
    final nav = globalContext['navigator'] as JSObject?;
    return globalContext.has('AudioContext') && nav != null && nav.has('mediaDevices');
  }

  Future<void> start({void Function(double level)? onLevel}) async {
    cancel();
    final nav = globalContext['navigator'] as JSObject;
    final devices = nav['mediaDevices'] as JSObject;
    final constraints = {
      'audio': {'channelCount': 1, 'echoCancellation': true, 'noiseSuppression': true},
    }.jsify();
    final stream =
        await devices.callMethod<JSPromise<JSObject>>('getUserMedia'.toJS, constraints).toDart;
    final ctx = (globalContext['AudioContext'] as JSFunction).callAsConstructor<JSObject>();
    _sampleRate = (ctx['sampleRate'] as JSNumber).toDartDouble;
    final source = ctx.callMethod<JSObject>('createMediaStreamSource'.toJS, stream);
    final processor =
        ctx.callMethod<JSObject>('createScriptProcessor'.toJS, 4096.toJS, 1.toJS, 1.toJS);

    processor['onaudioprocess'] = ((JSObject event) {
      final buffer = event['inputBuffer'] as JSObject;
      final data = buffer.callMethod<JSFloat32Array>('getChannelData'.toJS, 0.toJS).toDart;
      _chunks.add(Float32List.fromList(data));
      if (onLevel != null) {
        var sum = 0.0;
        for (final s in data) {
          sum += s * s;
        }
        onLevel(math.sqrt(sum / math.max(1, data.length)));
      }
    }).toJS;

    source.callMethod<JSAny?>('connect'.toJS, processor);
    processor.callMethod<JSAny?>('connect'.toJS, ctx['destination']);
    _ctx = ctx;
    _stream = stream;
    _source = source;
    _processor = processor;
  }

  /// Stops recording and returns the WAV bytes (null if nothing was recorded).
  Future<Uint8List?> stop() async {
    final samples = _flatten();
    _teardown();
    if (samples.length < _sampleRate * 0.3) return null;
    return _encodeWav(_downsample(samples, _sampleRate, 16000), 16000);
  }

  void cancel() {
    _teardown();
    _chunks.clear();
  }

  Float32List _flatten() {
    final total = _chunks.fold<int>(0, (n, c) => n + c.length);
    final out = Float32List(total);
    var offset = 0;
    for (final c in _chunks) {
      out.setAll(offset, c);
      offset += c.length;
    }
    _chunks.clear();
    return out;
  }

  void _teardown() {
    final processor = _processor;
    if (processor != null) {
      processor['onaudioprocess'] = null;
      processor.callMethod<JSAny?>('disconnect'.toJS);
    }
    _source?.callMethod<JSAny?>('disconnect'.toJS);
    final stream = _stream;
    if (stream != null) {
      final tracks = stream.callMethod<JSArray<JSObject>>('getTracks'.toJS).toDart;
      for (final t in tracks) {
        t.callMethod<JSAny?>('stop'.toJS);
      }
    }
    _ctx?.callMethod<JSAny?>('close'.toJS);
    _ctx = null;
    _stream = null;
    _source = null;
    _processor = null;
  }

  static Float32List _downsample(Float32List input, double from, double to) {
    if (from <= to) return input;
    final ratio = from / to;
    final length = (input.length / ratio).floor();
    final out = Float32List(length);
    for (var i = 0; i < length; i++) {
      final start = (i * ratio).floor();
      final end = math.min(input.length, ((i + 1) * ratio).floor());
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += input[j];
      }
      out[i] = end > start ? sum / (end - start) : 0;
    }
    return out;
  }

  static Uint8List _encodeWav(Float32List samples, int sampleRate) {
    final dataLength = samples.length * 2;
    final bytes = ByteData(44 + dataLength);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i].clamp(-1.0, 1.0);
      bytes.setInt16(44 + i * 2, (s < 0 ? s * 0x8000 : s * 0x7FFF).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
