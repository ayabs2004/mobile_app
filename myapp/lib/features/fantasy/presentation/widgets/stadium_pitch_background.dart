import 'package:flutter/material.dart';

/// Fond réaliste de terrain de football (vu du dessus, à la verticale),
/// utilisé pour simuler un "stade" derrière la composition d'équipe.
///
/// Dessine :
/// - des bandes de tonte alternées (façon pelouse entretenue)
/// - la ligne médiane + le rond central
/// - les surfaces de réparation (petite + grande) en haut et en bas
/// - les arcs de coin
class StadiumPitchBackground extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const StadiumPitchBackground({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambiance "nocturne de stade" : la pelouse s'assombrit vers le bas.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1D7A3E),
                  Color(0xFF166030),
                  Color(0xFF0F4924),
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _PitchPainter(),
            size: Size.infinite,
          ),
          // Léger vignettage pour un rendu plus "premium" / stade éclairé.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [
                  Colors.white10,
                  Colors.transparent,
                ],
                stops: [0.0, 0.7],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _paintMowStripes(canvas, size);
    _paintLines(canvas, size);
  }

  void _paintMowStripes(Canvas canvas, Size size) {
    const stripeCount = 10;
    final stripeHeight = size.height / stripeCount;
    final darkStripe = Paint()..color = Colors.black.withValues(alpha: 0.06);
    for (var i = 0; i < stripeCount; i++) {
      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, stripeHeight * i, size.width, stripeHeight),
          darkStripe,
        );
      }
    }
  }

  void _paintLines(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final margin = size.width * 0.05;
    final fieldRect = Rect.fromLTWH(
      margin,
      size.height * 0.02,
      size.width - margin * 2,
      size.height * 0.96,
    );

    // Pourtour du terrain.
    canvas.drawRect(fieldRect, line);

    // Ligne médiane.
    final midY = fieldRect.top + fieldRect.height / 2;
    canvas.drawLine(
      Offset(fieldRect.left, midY),
      Offset(fieldRect.right, midY),
      line,
    );

    // Rond central + point central.
    final centerRadius = fieldRect.width * 0.16;
    canvas.drawCircle(Offset(fieldRect.center.dx, midY), centerRadius, line);
    canvas.drawCircle(
      Offset(fieldRect.center.dx, midY),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // Surfaces de réparation (haut = but adverse, bas = but du gardien).
    _paintPenaltyArea(canvas, fieldRect, line, atTop: true);
    _paintPenaltyArea(canvas, fieldRect, line, atTop: false);

    // Arcs de coin.
    final cornerRadius = fieldRect.width * 0.035;
    final corners = [
      fieldRect.topLeft,
      fieldRect.topRight,
      fieldRect.bottomLeft,
      fieldRect.bottomRight,
    ];
    for (final c in corners) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: cornerRadius),
        0,
        6.28,
        false,
        line,
      );
    }
  }

  void _paintPenaltyArea(Canvas canvas, Rect fieldRect, Paint line,
      {required bool atTop}) {
    final boxWidth = fieldRect.width * 0.62;
    final boxHeight = fieldRect.height * 0.16;
    final smallBoxWidth = fieldRect.width * 0.32;
    final smallBoxHeight = fieldRect.height * 0.07;

    final boxLeft = fieldRect.center.dx - boxWidth / 2;
    final smallBoxLeft = fieldRect.center.dx - smallBoxWidth / 2;

    final boxTop = atTop ? fieldRect.top : fieldRect.bottom - boxHeight;
    final smallBoxTop =
        atTop ? fieldRect.top : fieldRect.bottom - smallBoxHeight;

    canvas.drawRect(
      Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(smallBoxLeft, smallBoxTop, smallBoxWidth, smallBoxHeight),
      line,
    );

    // Arc de la surface (demi-cercle du point de penalty).
    final penaltySpotY =
        atTop ? fieldRect.top + boxHeight * 0.62 : fieldRect.bottom - boxHeight * 0.62;
    final arcRadius = fieldRect.width * 0.13;
    final rect = Rect.fromCircle(
      center: Offset(fieldRect.center.dx, penaltySpotY),
      radius: arcRadius,
    );
    canvas.drawArc(
      rect,
      atTop ? 0.5 : 3.65,
      2.15,
      false,
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}