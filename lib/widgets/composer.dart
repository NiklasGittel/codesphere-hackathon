import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../gemini/gemini_client.dart';
import '../theme.dart';
import '../voice/audio_recorder.dart';
import '../voice/speech_input.dart';
import 'ui/primitives.dart';

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.busy,
    required this.onSend,
    required this.onStop,
    this.onMicToggle,
  });
  final bool busy;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  /// Hook for voice input (Gemini Live). Called with the new listening state.
  final ValueChanged<bool>? onMicToggle;

  @override
  State<Composer> createState() => _ComposerState();
}

enum _Voice { idle, recording, transcribing }

class _ComposerState extends State<Composer> {
  final _ctrl = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  final _speech = SpeechInput();
  final _recorder = AudioRecorder();
  final _gemini = GeminiClient();
  _Voice _voice = _Voice.idle;
  double _level = 0;
  bool _heardSpeech = false;
  DateTime _lastLoud = DateTime.now();
  DateTime _recordStarted = DateTime.now();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _speech.stop();
    _recorder.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || widget.busy) return;
    widget.onSend(text);
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.text.trim().isEmpty) _ctrl.clear();
    });
  }

  // ------------------------------------------------------------ voice ----

  Future<void> _toggleMic() async {
    switch (_voice) {
      case _Voice.transcribing:
        return;
      case _Voice.recording:
        await _finishRecording();
      case _Voice.idle:
        if (widget.busy) return;
        if (GeminiClient.configured && _recorder.supported) {
          await _startRecording();
        } else {
          _startBrowserSpeech();
        }
    }
  }

  Future<void> _startRecording() async {
    _heardSpeech = false;
    _lastLoud = DateTime.now();
    _recordStarted = DateTime.now();
    try {
      await _recorder.start(onLevel: _onLevel);
    } catch (e) {
      _toast('Microphone access is blocked. Allow it via the icon in the address bar.');
      return;
    }
    _ctrl.clear();
    setState(() => _voice = _Voice.recording);
    widget.onMicToggle?.call(true);
  }

  /// Auto-stop after ~1.4 s of silence once speech was heard (max 20 s).
  void _onLevel(double level) {
    if (_voice != _Voice.recording) return;
    final now = DateTime.now();
    if (level > 0.025) {
      _heardSpeech = true;
      _lastLoud = now;
    }
    final silent = now.difference(_lastLoud).inMilliseconds > 1400;
    final tooLong = now.difference(_recordStarted).inSeconds >= 20;
    if ((_heardSpeech && silent) || tooLong) _finishRecording();
    final smoothed = (_level * 0.6 + math.min(1.0, level * 8) * 0.4);
    if ((smoothed - _level).abs() > 0.04) setState(() => _level = smoothed);
  }

  Future<void> _finishRecording() async {
    if (_voice != _Voice.recording) return;
    setState(() {
      _voice = _Voice.transcribing;
      _level = 0;
    });
    widget.onMicToggle?.call(false);
    try {
      final wav = await _recorder.stop();
      if (wav == null || !_heardSpeech) {
        _toast("Didn't catch that. Tap the mic and try again.");
        return;
      }
      final text = await _gemini.transcribe(wav);
      if (!mounted) return;
      if (text.isEmpty) {
        _toast("Didn't catch that. Tap the mic and try again.");
        return;
      }
      _ctrl.value =
          TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      setState(() => _voice = _Voice.idle);
      _submit();
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted && _voice == _Voice.transcribing) setState(() => _voice = _Voice.idle);
    }
  }

  /// Fallback when no Gemini key is configured: the browser's speech API.
  void _startBrowserSpeech() {
    if (!GeminiClient.configured) {
      _toast('No GEMINI_API_KEY set, using browser speech recognition instead.');
    }
    final started = _speech.start(
      onResult: (text, isFinal) {
        if (!mounted) return;
        _ctrl.value =
            TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
        if (isFinal) {
          _speech.stop();
          setState(() => _voice = _Voice.idle);
          if (text.trim().isNotEmpty) _submit();
        }
      },
      onEnd: () {
        if (mounted && _voice == _Voice.recording) setState(() => _voice = _Voice.idle);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _voice = _Voice.idle);
        _toast(error == 'not-allowed'
            ? 'Microphone access is blocked. Allow it via the icon in the address bar.'
            : 'Voice input error: $error');
      },
    );
    if (!started) {
      _toast('Voice input is not supported in this browser.');
      return;
    }
    _ctrl.clear();
    setState(() => _voice = _Voice.recording);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      width: 460,
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _focused ? AppColors.borderStrong : AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0x0F000000),
                      blurRadius: _focused ? 16 : 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(children: [
                TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 6,
                  style: AppText.body,
                  decoration: InputDecoration(
                    hintText: switch (_voice) {
                      _Voice.recording => 'Listening… pause or tap stop when you are done',
                      _Voice.transcribing => 'Transcribing with Gemini…',
                      _Voice.idle => 'Ask about performance, costs or incidents…',
                    },
                    hintStyle: AppText.body.copyWith(color: AppColors.mutedForeground),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  child: Row(children: [
                    const _ScopeChip(icon: Icons.layers_outlined, label: 'All providers'),
                    const SizedBox(width: 6),
                    const _ScopeChip(icon: Icons.public_rounded, label: 'Production'),
                    const Spacer(),
                    _MicButton(state: _voice, level: _level, onTap: _toggleMic),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _ctrl,
                      builder: (context, value, _) => ShadButton(
                        icon: widget.busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                        small: true,
                        tooltip: widget.busy ? 'Stop' : 'Send',
                        onPressed: widget.busy
                            ? widget.onStop
                            : (value.text.trim().isEmpty ? null : _submit),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Text('Simulated cloud data for demo purposes · Powered by Gemini',
                style: AppText.small),
          ]),
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: () {},
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hovered ? AppColors.muted : AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: AppColors.mutedForeground),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground)),
          ]),
        ),
      );
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.state, required this.level, required this.onTap});
  final _Voice state;
  final double level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recording = state == _Voice.recording;
    final transcribing = state == _Voice.transcribing;
    return Tooltip(
      message: recording
          ? 'Stop and transcribe'
          : (transcribing ? 'Transcribing with Gemini…' : 'Voice input (Gemini)'),
      child: HoverBuilder(
        onTap: transcribing ? null : onTap,
        builder: (context, hovered) => Stack(alignment: Alignment.center, children: [
          // Pulsing ring that follows the input level.
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: recording ? 32 + 14 * level : 32,
            height: recording ? 32 + 14 * level : 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording ? AppColors.destructive.withAlpha(40) : Colors.transparent,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: recording
                  ? AppColors.destructive
                  : (hovered ? AppColors.muted : AppColors.background),
              borderRadius: BorderRadius.circular(recording ? 16 : AppRadius.md),
              border: Border.all(color: recording ? AppColors.destructive : AppColors.border),
            ),
            child: transcribing
                ? const Center(child: Spinner(size: 13))
                : Icon(recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                    size: 16, color: recording ? Colors.white : AppColors.foreground),
          ),
        ]),
      ),
    );
  }
}
