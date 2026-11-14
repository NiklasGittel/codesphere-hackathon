import 'package:flutter/material.dart';

import '../state/chat_controller.dart';
import '../theme.dart';
import '../widgets/composer.dart';
import '../widgets/empty_state.dart';
import '../widgets/message_view.dart';
import '../widgets/sidebar.dart';
import '../widgets/ui/primitives.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final ChatController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  bool _forceScroll = false;

  ChatController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final nearBottom = pos.maxScrollExtent - pos.pixels < 260;
      if (_forceScroll || nearBottom) {
        _forceScroll = false;
        _scroll.animateTo(pos.maxScrollExtent,
            duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
      }
    });
  }

  void _send(String text) {
    _forceScroll = true;
    c.send(text);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        return Scaffold(
          body: Row(children: [
            if (wide) Sidebar(onNewChat: c.reset),
            if (wide) const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => Column(children: [
                  const _TopBar(),
                  Expanded(
                    child: c.messages.isEmpty ? EmptyState(onPick: _send) : _messages(),
                  ),
                  Composer(busy: c.busy, onSend: _send, onStop: c.stop),
                ]),
              ),
            ),
          ]),
        );
      });

  Widget _messages() => Scrollbar(
        controller: _scroll,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          itemCount: c.messages.length,
          itemBuilder: (context, i) {
            final m = c.messages[i];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: MessageView(
                      key: ValueKey(m.id), message: m, onAction: (b, a) {
                    _forceScroll = true;
                    c.runAction(b, a);
                  }),
                ),
              ),
            );
          },
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          const Text('Production',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          const ShadBadge(label: '4 providers · 38 services'),
          const Spacer(),
          const Dot(color: AppColors.success, size: 7),
          const SizedBox(width: 8),
          const Text('Live · simulated', style: AppText.muted),
          const SizedBox(width: 16),
          ShadButton(
            label: 'Share',
            icon: Icons.ios_share_rounded,
            variant: ButtonVariant.outline,
            small: true,
            onPressed: () {},
          ),
        ]),
      );
}
