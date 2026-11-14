import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../state/chat_controller.dart';
import '../theme.dart';
import '../widgets/composer.dart';
import '../widgets/message_view.dart';
import '../live/live_client.dart';
import '../widgets/pages.dart';
import '../widgets/settings_dialog.dart';
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

  /// Page to return to when leaving a conversation.
  String _returnNav = NavIds.overview;

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

  /// Opens (or re-opens) the conversation for a topic. The action id doubles
  /// as conversation id, so each card / nav entry has exactly one chat.
  void _open(String title, String actionId) {
    _forceScroll = true;
    c.open(actionId, title, actionId: actionId);
  }

  /// Card clicked on the start page.
  void _openFromStart(String title, String actionId) {
    final page = _nav ?? NavIds.overview;
    setState(() {
      _returnNav = const {NavIds.overview, NavIds.incidents, NavIds.savings}.contains(page) ? page : NavIds.overview;
      _nav = actionId.startsWith('incident') || actionId.startsWith('resolved') ? NavIds.incidents : NavIds.savings;
    });
    _open(title, actionId);
  }

  void _newChat() {
    c.showOverview();
    setState(() {
      _nav = NavIds.overview;
      _returnNav = NavIds.overview;
    });
  }

  Future<void> _openSettings() async {
    final result = await showSettingsDialog(context, onReset: _resetDemo);
    if (result == 'reset' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Demo reset. Back to the open incident.'),
        behavior: SnackBarBehavior.floating,
        width: 420,
        backgroundColor: AppColors.primary,
      ));
    }
  }

  /// Full demo reset: live Cloud Run state (if connected), chats, simulation.
  Future<void> _resetDemo() async {
    Object? liveError;
    if (LiveClient.configured) {
      try {
        await LiveClient().reset();
      } catch (e) {
        liveError = e;
      }
    }
    c.clearAll();
    setState(() {
      _nav = NavIds.overview;
      _returnNav = NavIds.overview;
    });
    if (liveError != null) throw liveError;
  }

  /// Back from a conversation to the page it was opened from.
  void _back() {
    c.showOverview();
    setState(() => _nav = _returnNav);
  }

  Widget _page() => switch (_nav) {
        NavIds.incidents => IncidentsPage(onOpen: _openFromStart),
        NavIds.savings => SavingsPage(onOpen: _openFromStart),
        _ => StartPage(onOpen: _openFromStart),
      };

  String get _pageTitle => switch (c.current == null ? _nav : _returnNav) {
        NavIds.incidents => 'Incidents',
        NavIds.savings => 'Savings',
        _ => 'Overview',
      };

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
      _openSettings();
      return;
    }
    if (id.startsWith('chat:')) {
      _forceScroll = true;
      c.open(id.substring(5), '');
      setState(() => _nav = null);
      return;
    }
    final topic = topics[id];
    if (topic == null) {
      // overview / incidents / savings live on the start page.
      c.showOverview();
      setState(() => _nav = id);
      return;
    }
    setState(() => _nav = id);
    _open(topic.$1, topic.$2);
  }

  String? get _topic => c.current?.title;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        return Scaffold(
          body: Row(children: [
            if (wide)
              ListenableBuilder(
                listenable: c,
                builder: (context, _) =>
                    Sidebar(
                  selected: _nav,
                  onNavigate: _navigate,
                  onNewChat: _newChat,
                  conversations: [
                    for (final conv in c.conversations)
                      RecentChat(
                        id: conv.id,
                        title: conv.title,
                        updatedAt: conv.updatedAt,
                        running: c.runningId == conv.id,
                        open: c.current?.id == conv.id,
                      ),
                  ],
                ),
              ),
            if (wide) const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => Column(children: [
                  _TopBar(topic: _topic, onBack: _back, page: _pageTitle),
                  Expanded(
                    child: c.current == null ? _page() : _messages(),
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
  const _TopBar({required this.topic, required this.onBack, required this.page});
  final String? topic;
  final VoidCallback onBack;
  final String page;

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
              tooltip: 'Back to $page',
              onPressed: onBack,
            ),
            const SizedBox(width: 6),
            HoverBuilder(
              onTap: onBack,
              builder: (context, hovered) => Text(page,
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
            Text(page, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
