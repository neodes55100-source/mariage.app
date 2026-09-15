import 'package:flutter/material.dart';

class WeddingDecor extends StatelessWidget {
  final Widget child;
  final bool bottom;
  const WeddingDecor({super.key, required this.child, this.bottom = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(child: Align(alignment: Alignment.topRight, child: Image.asset('assets/wedding/rose_top.webp', width: 115, fit: BoxFit.contain))),
        IgnorePointer(child: Align(alignment: Alignment.topLeft, child: Transform.flip(flipX: true, child: Image.asset('assets/wedding/rose_top.webp', width: 115, fit: BoxFit.contain)))),
        if (bottom) IgnorePointer(child: Align(alignment: Alignment.bottomLeft, child: Image.asset('assets/wedding/rose_bottom.webp', width: 82, fit: BoxFit.contain))),
        if (bottom) IgnorePointer(child: Align(alignment: Alignment.bottomRight, child: Transform.flip(flipX: true, child: Image.asset('assets/wedding/rose_bottom.webp', width: 82, fit: BoxFit.contain)))),
      ],
    );
  }
}

class SiteRings extends StatelessWidget {
  final double width;
  const SiteRings({super.key, this.width = 185});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://mariage.creemachanson.com/assets/img/rings-design2-final-20260914.png',
      width: width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox(height: 105),
    );
  }
}
