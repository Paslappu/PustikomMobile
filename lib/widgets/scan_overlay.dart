import 'package:flutter/material.dart';

/// Square scan window, centred horizontally and slightly above the middle.
Rect scanWindowFor(Size size) {
  final side = (size.shortestSide * 0.7).clamp(220.0, 320.0).toDouble();
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.42),
    width: side,
    height: side,
  );
}

/// Dims everything outside [window] and draws four corner brackets on it.
class ScanWindowOverlay extends StatelessWidget {
  const ScanWindowOverlay({super.key, required this.window});

  final Rect window;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanWindowPainter(
          window: window,
          scrim: scheme.scrim.withValues(alpha: 0.55),
          bracket: scheme.onPrimary,
        ),
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter({
    required this.window,
    required this.scrim,
    required this.bracket,
  });

  final Rect window;
  final Color scrim;
  final Color bracket;

  static const double _radius = 20;
  static const double _stroke = 4;
  static const double _length = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(window, const Radius.circular(_radius)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      Paint()..color = scrim,
    );

    final paint = Paint()
      ..color = bracket
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    final l = window.left;
    final t = window.top;
    final r = window.right;
    final b = window.bottom;
    const rad = _radius;
    const len = _length;

    Path corner(Offset start, Offset apex, Offset end, Offset c1, Offset c2) {
      return Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(c1.dx, c1.dy)
        ..quadraticBezierTo(apex.dx, apex.dy, c2.dx, c2.dy)
        ..lineTo(end.dx, end.dy);
    }

    canvas.drawPath(
      corner(
        Offset(l, t + len),
        Offset(l, t),
        Offset(l + len, t),
        Offset(l, t + rad),
        Offset(l + rad, t),
      ),
      paint,
    );
    canvas.drawPath(
      corner(
        Offset(r - len, t),
        Offset(r, t),
        Offset(r, t + len),
        Offset(r - rad, t),
        Offset(r, t + rad),
      ),
      paint,
    );
    canvas.drawPath(
      corner(
        Offset(r, b - len),
        Offset(r, b),
        Offset(r - len, b),
        Offset(r, b - rad),
        Offset(r - rad, b),
      ),
      paint,
    );
    canvas.drawPath(
      corner(
        Offset(l + len, b),
        Offset(l, b),
        Offset(l, b - len),
        Offset(l + rad, b),
        Offset(l, b - rad),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter old) =>
      old.window != window || old.scrim != scrim || old.bracket != bracket;
}
