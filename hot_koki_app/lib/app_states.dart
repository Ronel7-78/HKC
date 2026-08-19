import 'dart:async';

import 'package:flutter/material.dart';

const _leaf900 = Color(0xFF1F3524);
const _cream = Color(0xFFFFF8EE);
const _flame600 = Color(0xFFC9491E);
const _inkSoft = Color(0xFF6B5F4E);

/// Évite le flash d'un indicateur quand une requête répond presque aussitôt.
class AppLoadingState extends StatefulWidget {
  const AppLoadingState({
    super.key,
    this.label = 'Préparation en cours…',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  State<AppLoadingState> createState() => _AppLoadingStateState();
}

class _AppLoadingStateState extends State<AppLoadingState> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _visible ? 1 : 0,
    duration: const Duration(milliseconds: 180),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _KokiLoader(),
            const SizedBox(height: 14),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _KokiLoader extends StatefulWidget {
  const _KokiLoader();

  @override
  State<_KokiLoader> createState() => _KokiLoaderState();
}

class _KokiLoaderState extends State<_KokiLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _cream,
        shape: BoxShape.circle,
        border: Border.all(color: _flame600, width: 3),
      ),
      child: const Icon(Icons.restaurant_rounded, color: _flame600, size: 21),
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: _cream,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _flame600, size: 42),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _leaf900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _inkSoft),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Impossible de charger cette page',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: _flame600, size: 48),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _leaf900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _inkSoft),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

class AppButtonLoading extends StatelessWidget {
  const AppButtonLoading({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Text(label),
    ],
  );
}

class AppCardSkeleton extends StatefulWidget {
  const AppCardSkeleton({super.key, this.count = 3});
  final int count;

  @override
  State<AppCardSkeleton> createState() => _AppCardSkeletonState();
}

class _AppCardSkeletonState extends State<AppCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: .45,
    upperBound: .9,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: Column(
      children: List.generate(
        widget.count,
        (_) => Container(
          height: 104,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFECE7DA),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
  );
}
