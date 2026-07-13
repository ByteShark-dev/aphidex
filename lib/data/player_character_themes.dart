import 'package:flutter/material.dart';

import '../models/player_character.dart';
import '../models/player_character_theme.dart';

class PlayerCharacterThemes {
  PlayerCharacterThemes._();

  static const empty = PlayerCharacterTheme(
    backgroundStart: Color(0xFF20252B),
    backgroundEnd: Color(0xFF3A4048),
    accent: Color(0xFFE5E7EB),
    foreground: Colors.white,
  );

  static const Map<String, PlayerCharacterTheme> _themes = {
    'g1_max': PlayerCharacterTheme(
      backgroundStart: Color(0xFF6B2E0D),
      backgroundEnd: Color(0xFFE78625),
      accent: Color(0xFFFFD17A),
      foreground: Colors.white,
    ),
    'g2_max': PlayerCharacterTheme(
      backgroundStart: Color(0xFF6B2E0D),
      backgroundEnd: Color(0xFFE78625),
      accent: Color(0xFFFFD17A),
      foreground: Colors.white,
    ),
    'g1_willow': PlayerCharacterTheme(
      backgroundStart: Color(0xFF063E49),
      backgroundEnd: Color(0xFF0C7A7A),
      accent: Color(0xFF6EE7D8),
      foreground: Colors.white,
    ),
    'g2_willow': PlayerCharacterTheme(
      backgroundStart: Color(0xFF063E49),
      backgroundEnd: Color(0xFF0C7A7A),
      accent: Color(0xFF6EE7D8),
      foreground: Colors.white,
    ),
    'g1_hoops': PlayerCharacterTheme(
      backgroundStart: Color(0xFF5C123B),
      backgroundEnd: Color(0xFFA72D68),
      accent: Color(0xFFFFB3D1),
      foreground: Colors.white,
    ),
    'g2_hoops': PlayerCharacterTheme(
      backgroundStart: Color(0xFF5C123B),
      backgroundEnd: Color(0xFFA72D68),
      accent: Color(0xFFFFB3D1),
      foreground: Colors.white,
    ),
    'g1_pete': PlayerCharacterTheme(
      backgroundStart: Color(0xFF123C79),
      backgroundEnd: Color(0xFF4EA0D8),
      accent: Color(0xFFBDEBFF),
      foreground: Colors.white,
    ),
    'g2_pete': PlayerCharacterTheme(
      backgroundStart: Color(0xFF123C79),
      backgroundEnd: Color(0xFF4EA0D8),
      accent: Color(0xFFBDEBFF),
      foreground: Colors.white,
    ),
    'g1_burgl': PlayerCharacterTheme(
      backgroundStart: Color(0xFF071B3B),
      backgroundEnd: Color(0xFF164F87),
      accent: Color(0xFF73C5FF),
      foreground: Colors.white,
    ),
    'g1_wendell': PlayerCharacterTheme(
      backgroundStart: Color(0xFF1D3821),
      backgroundEnd: Color(0xFF4B6630),
      accent: Color(0xFFD7C691),
      foreground: Colors.white,
    ),
    'g2_masked_stranger': PlayerCharacterTheme(
      backgroundStart: Color(0xFF31124A),
      backgroundEnd: Color(0xFF6D3A99),
      accent: Color(0xFFD6B7FF),
      foreground: Colors.white,
    ),
  };

  static PlayerCharacterTheme forCharacter(PlayerCharacter? character) =>
      character == null ? empty : _themes[character.id] ?? empty;
}
