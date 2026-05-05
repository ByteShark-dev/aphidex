enum GameVersion { g1, g2 }

enum EffectType {
  slashing,
  chopping,
  busting,
  stabbing,
  fresh,
  spicy,
  salty,
  explosive,
  sour,
  venom,
  poison,
  gas,
  bleed,
  shock,
  burning,
  infection,
}

enum WeakPointPart { back, eyes, gut, legs, rump }

enum SusceptibleDamageType {
  any,
  stabbingArrowsOnly, // para ojos (arcos/ballestas)
  stabbing,
  slashing,
  chopping,
  busting,
}
