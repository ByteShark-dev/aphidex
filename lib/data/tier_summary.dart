String romanTierLabel(int tier) => switch (tier) {
  1 => 'I',
  2 => 'II',
  3 => 'III',
  4 => 'IV',
  5 => 'V',
  _ => tier.toString(),
};

String formatTierSummaryLabel({
  required int tier,
  required bool isBoss,
  required String bossLabel,
}) {
  final roman = romanTierLabel(tier);
  return isBoss ? '$roman - $bossLabel' : roman;
}
