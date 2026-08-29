import 'package:flutter/material.dart';

import 'theme.dart';

class BrandAssets {
  static const logo = 'assets/brand/logo.png';
  static const mark = 'assets/brand/mark.png';
  static const mascotIdle = 'assets/brand/mascot_idle.png';
  static const mascotBle = 'assets/brand/mascot_ble.png';
  static const mascotPeek = 'assets/brand/mascot_peek.png';
  static const productFront = 'assets/brand/product_front.png';
  static const productStand = 'assets/brand/product_stand.png';
  static const productBack = 'assets/brand/product_back.png';
}

class HoloBackdrop extends StatelessWidget {
  const HoloBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: -80,
          top: 40,
          child: _glow(McColors.accent, 220, 0.16),
        ),
        Positioned(
          right: -90,
          top: 180,
          child: _glow(McColors.cyan, 260, 0.14),
        ),
        Positioned(
          left: 40,
          bottom: 80,
          child: _glow(McColors.violet, 180, 0.10),
        ),
        child,
      ],
    );
  }

  Widget _glow(Color color, double size, double opacity) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        BrandAssets.mark,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class Mascot extends StatelessWidget {
  const Mascot.idle({super.key, this.size = 168})
    : asset = BrandAssets.mascotIdle;
  const Mascot.ble({super.key, this.size = 168})
    : asset = BrandAssets.mascotBle;
  const Mascot.peek({super.key, this.size = 168})
    : asset = BrandAssets.mascotPeek;

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

class PassDevice extends StatelessWidget {
  const PassDevice({super.key, this.height = 236, this.online = false, this.screen});
  final double height;
  final bool online;
  final Widget? screen;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: online ? 1 : 0.92,
      child: Image.asset(
        BrandAssets.productFront,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class DeviceHero extends StatelessWidget {
  const DeviceHero({super.key, required this.online, this.mascot});
  final bool online;
  final Widget? mascot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PassDevice(height: 300, online: online),
          if (mascot != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 0, bottom: 0),
                child: mascot,
              ),
            ),
        ],
      ),
    );
  }
}

class ProductPair extends StatelessWidget {
  const ProductPair({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              BrandAssets.productStand,
              fit: BoxFit.contain,
              height: 180,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              BrandAssets.productBack,
              fit: BoxFit.contain,
              height: 180,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ],
    );
  }
}
