import 'package:flutter/material.dart';

/// Cadre partagé du logo : l'image d'origine reste intacte.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.width,
    required this.height,
    this.radius = 16,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x1FD94B16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Transform.scale(
          scale: 2.8,
          child: Image.asset(
            'assets/images/hot_koki_logo.jpeg',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Hot Koki Chaud',
          ),
        ),
      ),
    );
  }
}
