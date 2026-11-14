import 'dart:async';

import 'package:flutter/material.dart';

import '../../live/live_blocks.dart';
import '../../live/live_client.dart';
import '../../models/ui_block.dart';
import '../../theme.dart';
import '../ui/primitives.dart';

/// Keeps a live block up to date by re-fetching the backend every [interval]
/// and re-rendering it. Shows a pulsing LIVE marker in the top-right corner.
class LiveBlock extends StatefulWidget {
  const LiveBlock({
    super.key,
    required this.kind,
    required this.initial,
    required this.render,
    this.interval = const Duration(seconds: 3),
  });
  final String kind;
  final UiBlock initial;
  final Widget Function(UiBlock block) render;
  final Duration interval;

  @override
  State<LiveBlock> createState() => _LiveBlockState();
}

class _LiveBlockState extends State<LiveBlock> {
  static final _client = LiveClient();
  late UiBlock _block = widget.initial;
  Timer? _timer;
  bool _fetching = false;
  bool _stale = false;
  DateTime _updated = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (LiveClient.configured) {
      _timer = Timer.periodic(widget.interval, (_) => _refresh());
    }
  }

  Future<void> _refresh({bool manual = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (manual && mounted) setState(() {});
    try {
      final data = await _client.paymentSvc(fresh: manual);
      final json = liveBlockJson(widget.kind, data);
      if (json != null && mounted) {
        setState(() {
          _block = UiBlock.fromJson(json);
          _stale = false;
          _updated = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted && !_stale) setState(() => _stale = true);
    } finally {
      _fetching = false;
      if (manual && mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _time =>
      '${_updated.hour.toString().padLeft(2, '0')}:${_updated.minute.toString().padLeft(2, '0')}:${_updated.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final active = LiveClient.configured && !_stale;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _LiveMarker(active: active),
          const SizedBox(width: 4),
          Text(
            active ? 'Live · updated $_time' : (LiveClient.configured ? 'Live data unavailable' : 'Live mode off'),
            style: AppText.small.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Refresh now',
            child: HoverBuilder(
              onTap: LiveClient.configured && !_fetching ? () => _refresh(manual: true) : null,
              builder: (context, hovered) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: hovered ? AppColors.muted : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: _fetching
                      ? const Spinner(size: 11, color: AppColors.mutedForeground)
                      : const Icon(Icons.refresh_rounded, size: 15, color: AppColors.mutedForeground),
                ),
              ),
            ),
          ),
        ]),
      ),
      widget.render(_block),
    ]);
  }
}

class _LiveMarker extends StatefulWidget {
  const _LiveMarker({required this.active});
  final bool active;

  @override
  State<_LiveMarker> createState() => _LiveMarkerState();
}

class _LiveMarkerState extends State<_LiveMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.destructive : AppColors.borderStrong;
    return Tooltip(
      message: widget.active ? 'Live · refreshes every 3 s' : 'Live data unavailable',
      child: SizedBox(
        width: 14,
        height: 14,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Stack(alignment: Alignment.center, children: [
            if (widget.active)
              Container(
                width: 6 + 8 * _pulse.value,
                height: 6 + 8 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(((1 - _pulse.value) * 90).round()),
                ),
              ),
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          ]),
        ),
      ),
    );
  }
}
