import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'asset/images/ung_logo.png',
      width: size,
      height: size,
      semanticLabel: 'Logo Universitas Negeri Gorontalo',
    );
  }
}
