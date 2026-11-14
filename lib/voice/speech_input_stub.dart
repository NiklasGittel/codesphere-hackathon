class SpeechInput {
  bool get supported => false;

  bool start({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onEnd,
    void Function(String error)? onError,
    String lang = 'en-US',
  }) =>
      false;

  void stop() {}
}
