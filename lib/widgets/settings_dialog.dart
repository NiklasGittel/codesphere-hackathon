import 'package:flutter/material.dart';

import '../gemini/decisions_client.dart';
import '../gemini/gemini_client.dart';
import '../live/live_client.dart';
import '../theme.dart';
import 'ui/primitives.dart';

/// Settings popup. The demo reset sits in a collapsed "Advanced" section.
/// Returns 'reset' when the demo was reset.
Future<String?> showSettingsDialog(BuildContext context, {required Future<void> Function() onReset}) =>
    showDialog<String>(
      context: context,
      barrierColor: const Color(0x55000000),
      builder: (_) => _SettingsDialog(onReset: onReset),
    );

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.onReset});
  final Future<void> Function() onReset;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  bool _advanced = false;
  bool _resetting = false;
  String? _error;

  Future<void> _reset() async {
    setState(() {
      _resetting = true;
      _error = null;
    });
    try {
      await widget.onReset();
      if (mounted) Navigator.of(context).pop('reset');
    } catch (e) {
      if (mounted) {
        setState(() {
          _resetting = false;
          _error = 'App reset, but the live reset failed: $e';
        });
      }
    }
  }

  Widget _row(String label, String value, {bool on = true}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: AppText.muted)),
          Dot(color: on ? AppColors.success : AppColors.borderStrong, size: 6),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                ShadButton(
                  icon: Icons.close_rounded,
                  variant: ButtonVariant.ghost,
                  small: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const Text('Acme Shop · Production workspace', style: AppText.muted),
              const SizedBox(height: 14),
              _row('Agent', GeminiClient.configured ? 'Gemini · ${GeminiClient.model}' : 'Offline playbook',
                  on: GeminiClient.configured),
              _row('Policy checks', 'Gemini Decisions · ${DecisionsClient.model}', on: GeminiClient.configured),
              _row('Live resource', LiveClient.configured ? 'payment-svc · Google Cloud Run' : 'Off (simulation only)',
                  on: LiveClient.configured),
              _row('Providers', 'AWS · Google Cloud · Azure · codesphere'),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 6),
              HoverBuilder(
                onTap: () => setState(() => _advanced = !_advanced),
                builder: (context, hovered) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Text('Advanced',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: hovered ? AppColors.foreground : AppColors.mutedForeground)),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _advanced ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.mutedForeground),
                    ),
                  ]),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_advanced
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.subtle,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Reset demo', style: AppText.title),
                          const SizedBox(height: 4),
                          Text(
                            LiveClient.configured
                                ? 'Routes payment-svc back to the faulty revision, clears the live latency history, '
                                    'all chats and the simulated state. The live chart needs ~30 s to show the incident again.'
                                : 'Clears all chats and restores the simulated incident.',
                            style: AppText.muted,
                          ),
                          const SizedBox(height: 12),
                          ShadButton(
                            label: _resetting ? 'Resetting…' : 'Reset demo',
                            icon: Icons.restart_alt_rounded,
                            variant: ButtonVariant.destructive,
                            small: true,
                            onPressed: _resetting ? null : _reset,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: AppText.small.copyWith(color: AppColors.destructive)),
                          ],
                        ]),
                      ),
              ),
            ]),
          ),
        ),
      );
}
