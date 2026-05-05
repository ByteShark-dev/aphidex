import '../models/enemy.dart';

final List<Enemy> enemyMock = [
  Enemy(
    id: 'aphid',
    speciesKey: 'aphid',
    name: const LocalizedText(es: 'Pulgón', en: 'Aphid', ru: 'Тля'),
    game: 'g1',
    order: 3,
    tier: 1,
    danger: 'baja',
    isBoss: false,
    weaknesses: ['slashing', 'spicy'],
    resistances: ['chopping'],
    defaultGold: false,
    cardNormal: 'assets/g1/creatures/cards/normal/Creaturecard_Aphid.webp',
    cardGold: 'assets/g1/creatures/cards/gold/Creaturecardgold_Aphid.webp',
    photo: 'assets/g1/creatures/photos/Aphid.webp',
  ),

  Enemy(
    id: 'wolf_spider',
    speciesKey: 'wolf_spider',
    name: const LocalizedText(
      es: 'Araña lobo',
      en: 'Wolf Spider',
      ru: 'Волчий паук',
    ),
    game: 'g1',
    order: 2,
    tier: 3,
    defaultGold: false,
    danger: 'muy_alta',
    isBoss: false,
    weaknesses: ['fresh', 'slashing'],
    resistances: ['stabbing', 'explosive'],
    cardNormal:
        'assets/g1/creatures/cards/normal/Creaturecard_Wolf_Spider.webp',
    cardGold:
        'assets/g1/creatures/cards/gold/Creaturecardgold_Wolf_Spider.webp',
    photo: 'assets/g1/creatures/photos/Wolf_Spider.webp',
  ),

  Enemy(
    id: 'antlion',
    speciesKey: 'antlion',
    name: const LocalizedText(
      es: 'Hormiga león',
      en: 'Antlion',
      ru: 'Муравьиный лев',
    ),
    game: 'g1',
    order: 1,
    tier: 2,
    danger: 'alta',
    isBoss: false,
    defaultGold: false,
    weaknesses: ['salty', 'busting'],
    resistances: ['slashing'],
    cardNormal: 'assets/g1/creatures/cards/normal/Creaturecard_Antlion.webp',
    cardGold: 'assets/g1/creatures/cards/gold/Creaturecardgold_Antlion.webp',
    photo: 'assets/g1/creatures/photos/Antlion.webp',
  ),
];
