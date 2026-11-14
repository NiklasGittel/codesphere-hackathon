import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
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

class _ComposerState extends State<Composer> {
  final _ctrl = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  bool _listening = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
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

  void _toggleMic() {
    setState(() => _listening = !_listening);
    widget.onMicToggle?.call(_listening);
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
                    hintText: _listening
                        ? 'Listening…'
                        : 'Ask about performance, costs or incidents…',
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
                    _MicButton(listening: _listening, onTap: _toggleMic),
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
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: listening ? 'Stop listening' : 'Voice input',
        child: HoverBuilder(
          onTap: onTap,
          builder: (context, hovered) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: listening
                  ? AppColors.destructive.withAlpha(24)
                  : (hovered ? AppColors.muted : AppColors.background),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: listening ? AppColors.destructive.withAlpha(90) : AppColors.border),
            ),
            child: Icon(listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 16,
                color: listening ? AppColors.destructive : AppColors.foreground),
          ),
        ),
      );
}
