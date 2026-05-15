import 'package:flutter/material.dart';

class FloatingChatButton extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingChatButton({super.key, required this.onTap});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  double _x = 0;
  double _y = 0;
  bool _initialized = false;
  bool _isDragging = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _initPosition(Size screenSize) {
    if (_initialized) return;
    _x = screenSize.width - 76;
    _y = screenSize.height - 160;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    _initPosition(screenSize);
    final cs = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: _x,
            top: _y,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  _x = (_x + details.delta.dx)
                      .clamp(0.0, screenSize.width - 60);
                  _y = (_y + details.delta.dy)
                      .clamp(0.0, screenSize.height - 60);
                });
              },
              onPanEnd: (_) {
                setState(() => _isDragging = false);
                _snapToEdge(screenSize);
              },
              onTap: _isDragging ? null : widget.onTap,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isDragging ? 1.0 : _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: cs.onPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snapToEdge(Size screenSize) {
    final center = _x + 30;
    final targetX =
        center < screenSize.width / 2 ? 16.0 : screenSize.width - 76;
    setState(() => _x = targetX);
  }
}
