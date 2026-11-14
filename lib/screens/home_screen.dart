import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../state/chat_controller.dart';
import '../theme.dart';
import '../widgets/composer.dart';
import '../widgets/message_view.dart';
import '../widgets/sidebar.dart';
import '../widgets/start_page.dart';
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
  String? _nav = NavIds.overview;

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

  void _open(String title, String actionId) {
    _forceScroll = true;
    c.send(title, actionId: actionId);
  }

  /// Card clicked on the start page.
  void _openFromStart(String title, String actionId) {
    setState(() => _nav = actionId.startsWith('incident') ? NavIds.incidents : NavIds.savings);
    _open(title, actionId);
  }

  void _newChat() {
    c.reset();
    setState(() => _nav = NavIds.overview);
  }

  /// Sidebar navigation. Every entry leads somewhere in the demo.
  void _navigate(String id) {
    const topics = {
      NavIds.services: ('Service map', 'nav_services'),
      NavIds.changes: ('What changed in production?', 'nav_changes'),
      NavIds.costs: ('Cost explorer', 'nav_costs'),
      'recent_checkout': ('Checkout is slow in West Europe', 'incident_checkout'),
      'recent_costs': ('November cost review', 'nav_costs'),
      'recent_changes': ('Production changes', 'nav_changes'),
    };
    if (id == NavIds.settings) {
      setState(() => _nav = id);
      return;
    }
    final topic = topics[id];
    if (topic == null) {
      // overview / incidents / savings live on the start page.
      if (!c.busy) c.reset();
      setState(() => _nav = id);
      return;
    }
    if (c.busy) return;
    c.reset();
    setState(() => _nav = id);
    _open(topic.$1, topic.$2);
  }

  String? get _topic {
    if (c.messages.isEmpty) return null;
    final parts = c.messages.first.parts;
    final first = parts.isEmpty ? null : parts.first;
    return first is TextPart ? first.text : null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        return Scaffold(
          body: Row(children: [
            if (wide)
              ListenableBuilder(
                listenable: c,
                builder: (context, _) =>
                    Sidebar(selected: _nav, onNavigate: _navigate, onNewChat: _newChat),
              ),
            if (wide) const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => Column(children: [
                  _TopBar(topic: _topic, onBack: _newChat),
                  Expanded(
                    child: c.messages.isEmpty ? StartPage(onOpen: _openFromStart) : _messages(),
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
                    key: ValueKey(m.id),
                    message: m,
                    onAction: (b, a) {
                      _forceScroll = true;
                      c.runAction(b, a);
                    },
                    onAsk: (b, q) {
                      _forceScroll = true;
                      c.ask(b, q);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.topic, required this.onBack});
  final String? topic;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          if (topic != null) ...[
            ShadButton(
              icon: Icons.arrow_back_rounded,
              variant: ButtonVariant.ghost,
              small: true,
              tooltip: 'Back to overview',
              onPressed: onBack,
            ),
            const SizedBox(width: 6),
            HoverBuilder(
              onTap: onBack,
              builder: (context, hovered) => Text('Overview',
                  style: TextStyle(
                      fontSize: 14,
                      color: hovered ? AppColors.foreground : AppColors.mutedForeground)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.borderStrong),
            ),
            Flexible(
              child: Text(topic!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ] else ...[
            const SizedBox(width: 4),
            const Text('Overview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            const ShadBadge(label: 'Production · 4 providers · 38 services'),
          ],
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
