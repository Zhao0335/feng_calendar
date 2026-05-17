import 'dart:async';
import 'package:flutter/material.dart';

class FloatingChatButton extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingChatButton({super.key, required this.onTap});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with TickerProviderStateMixin {
  double _x = 0;
  double _y = 0;
  bool _initialized = false;
  bool _isDragging = false;
  bool _isAtLeftEdge = false;
  bool _isHiddenAtEdge = false; // faded-in-to-edge state

  // Pulse animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Slide animation (x position when hiding / showing)
  late final AnimationController _slideController;
  late Animation<double> _slideAnim;

  // Opacity animation
  late final AnimationController _opacityController;

  Timer? _hideTimer;

  static const double _size = 60.0;
  // How many px stay visible when hidden
  static const double _peekPx = 18.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = Tween<double>(begin: 0, end: 0).animate(_slideController);

    _opacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  void _initPosition(Size s) {
    if (_initialized) return;
    _x = s.width - 76;
    _y = s.height - 260;
    _initialized = true;
  }

  // ── Snap + hide flow ──────────────────────────────────────────────────────

  void _snapToEdge(Size s) {
    final center = _x + _size / 2;
    _isAtLeftEdge = center < s.width / 2;

    // 1. Snap to fully-visible edge position
    final double snapX = _isAtLeftEdge ? 16.0 : s.width - 76;
    _animateX(from: _x, to: snapX, onDone: () {
      // 2. After 800 ms of no dragging, slide into edge
      _hideTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && !_isDragging) _slideIntoEdge(s);
      });
    });
  }

  void _slideIntoEdge(Size s) {
    final double peekX = _isAtLeftEdge
        ? 0 - (_size - _peekPx) // show _peekPx on left edge
        : s.width - _peekPx;   // show _peekPx on right edge

    _animateX(from: _x, to: peekX, onDone: () {
      setState(() => _isHiddenAtEdge = true);
    });
  }

  void _slideOutFromEdge(Size s) {
    if (!_isHiddenAtEdge) return;
    setState(() => _isHiddenAtEdge = false);
    final double visibleX = _isAtLeftEdge ? 16.0 : s.width - 76;
    _animateX(from: _x, to: visibleX);
  }

  // ── Generic x-position animation ─────────────────────────────────────────

  void _animateX(
      {required double from, required double to, VoidCallback? onDone}) {
    _slideAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    )..addListener(() => setState(() => _x = _slideAnim.value));

    _slideController
      ..stop()
      ..forward(from: 0).then((_) => onDone?.call());
  }

  // ── Drag handlers ─────────────────────────────────────────────────────────

  void _onPanStart(Size s) {
    _hideTimer?.cancel();
    _slideController.stop();
    setState(() {
      _isDragging = true;
      _isHiddenAtEdge = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Size s) {
    setState(() {
      // Allow dragging slightly off-screen while dragging (feels natural)
      _x = (_x + d.delta.dx).clamp(-_size / 3, s.width - _size * 2 / 3);
      _y = (_y + d.delta.dy).clamp(0.0, s.height - _size);
    });
  }

  void _onPanEnd(Size s) {
    setState(() => _isDragging = false);
    _snapToEdge(s);
  }

  // ── Tap ───────────────────────────────────────────────────────────────────

  void _onTap(Size s) {
    if (_isHiddenAtEdge) {
      _slideOutFromEdge(s);
      // Small delay so user sees the slide-out before the screen changes
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) widget.onTap();
      });
    } else {
      widget.onTap();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    _initPosition(s);
    final cs = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none, // allow button to peek off-screen
        children: [
          Positioned(
            left: _x,
            top: _y,
            child: GestureDetector(
              onPanStart: (_) => _onPanStart(s),
              onPanUpdate: (d) => _onPanUpdate(d, s),
              onPanEnd: (_) => _onPanEnd(s),
              onTap: () => _onTap(s),
              child: MouseRegion(
                // Desktop: hovering the peeking button slides it out
                onEnter: (_) {
                  if (_isHiddenAtEdge) _slideOutFromEdge(s);
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: (_isDragging || _isHiddenAtEdge)
                        ? 1.0
                        : _pulseAnimation.value,
                    child: child,
                  ),
                  child: _ButtonBody(cs: cs, isHidden: _isHiddenAtEdge,
                      isAtLeftEdge: _isAtLeftEdge),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stateless body (avoids rebuilding parent on every frame) ─────────────────

class _ButtonBody extends StatelessWidget {
  final ColorScheme cs;
  final bool isHidden;
  final bool isAtLeftEdge;

  const _ButtonBody(
      {required this.cs,
      required this.isHidden,
      required this.isAtLeftEdge});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isHidden ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: isHidden ? 0.1 : 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(Icons.auto_awesome_rounded,
            color: cs.onPrimary, size: 28),
      ),
    );
  }
}
