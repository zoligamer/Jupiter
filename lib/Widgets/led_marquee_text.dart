import 'dart:async';
import 'package:flutter/material.dart';

class LedMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final Duration velocity;
  final Duration pauseDuration;

  const LedMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.onLongPress,
    this.onTap,
    this.velocity = const Duration(seconds: 4),
    this.pauseDuration = const Duration(milliseconds: 1400),
  });

  @override
  State<LedMarqueeText> createState() => _LedMarqueeTextState();
}

class _LedMarqueeTextState extends State<LedMarqueeText> {
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void didUpdateWidget(covariant LedMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
    }
  }

  void _checkAndStartScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 2.0 && !_isScrolling) {
      _startMarquee();
    }
  }

  void _startMarquee() {
    _timer?.cancel();
    _isScrolling = true;
    _timer = Timer(widget.pauseDuration, () async {
      if (!mounted || !_scrollController.hasClients) return;
      try {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll <= 2.0) {
          _isScrolling = false;
          return;
        }
        await _scrollController.animateTo(
          maxScroll,
          duration: widget.velocity,
          curve: Curves.linear,
        );
        await Future.delayed(widget.pauseDuration);
        if (!mounted || !_scrollController.hasClients) return;
        await _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
        _startMarquee();
      } catch (_) {
        _isScrolling = false;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );

    if (widget.onLongPress != null || widget.onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      );
    }

    return child;
  }
}
