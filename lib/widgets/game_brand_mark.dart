import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/game_pick.dart';

class GameBrandMark extends StatelessWidget {
  final GamePick gamePick;
  final double height;
  final bool useBlackAsset;

  const GameBrandMark({
    super.key,
    required this.gamePick,
    this.height = 30,
    this.useBlackAsset = false,
  });

  String get _assetName {
    final suffix = useBlackAsset ? '_black' : '';
    return switch (gamePick) {
      GamePick.g1 => 'assets/global/branding/Aphidex_internal_g1$suffix.svg',
      GamePick.g2 => 'assets/global/branding/Aphidex_internal_g2$suffix.svg',
      GamePick.all => 'assets/global/branding/Aphidex_internal_both$suffix.svg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aphidex',
      image: true,
      child: ExcludeSemantics(
        child: SvgPicture.asset(
          _assetName,
          key: ValueKey(
            'brand-mark-${gamePick.name}-${useBlackAsset ? 'dark' : 'light'}',
          ),
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
