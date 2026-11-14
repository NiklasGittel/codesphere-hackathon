import 'dart:typed_data';

class AudioRecorder {
  bool get supported => false;
  Future<void> start({void Function(double level)? onLevel}) async =>
      throw UnsupportedError('Recording is only supported on web');
  Future<Uint8List?> stop() async => null;
  void cancel() {}
}
