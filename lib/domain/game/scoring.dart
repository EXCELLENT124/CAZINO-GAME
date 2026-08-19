import '../models/game_card.dart';

class ScoringConfig {
  const ScoringConfig(
      {this.mostCardsPoints = 2,
      this.mostSpadesPoints = 2,
      this.tieSharePoints = 1,
      this.spyTwoPoints = 1,
      this.mummyPoints = 2,
      this.acePoints = 1});
  final int mostCardsPoints, mostSpadesPoints, tieSharePoints;
  final int spyTwoPoints, mummyPoints, acePoints;
}

class ScoreBreakdown {
  const ScoreBreakdown(
      {required this.aces,
      required this.spyTwo,
      required this.mummy,
      required this.mostCards,
      required this.mostSpades});
  final int aces, spyTwo, mummy, mostCards, mostSpades;
  int get total => aces + spyTwo + mummy + mostCards + mostSpades;
}

class ScoreResult {
  const ScoreResult(this.points, this.winnerId, this.notes, this.breakdowns);
  final Map<String, int> points;
  final String winnerId;
  final List<String> notes;
  final Map<String, ScoreBreakdown> breakdowns;
}

/// Official two-player 11-point scoring from Khasino Rules v1.1.
class ScoringRules {
  const ScoringRules([this.config = const ScoringConfig()]);
  final ScoringConfig config;

  ScoreResult score(Map<String, List<GameCard>> packs) {
    final ids = packs.keys.toList();
    final cardCounts = {for (final id in ids) id: packs[id]!.length};
    final spadeCounts = {
      for (final id in ids)
        id: packs[id]!.where((c) => c.suit == CardSuit.blackSpade).length
    };
    final breakdowns = <String, ScoreBreakdown>{};
    for (final id in ids) {
      final cards = packs[id]!;
      breakdowns[id] = ScoreBreakdown(
        aces: cards.where((c) => c.rank == 1).length * config.acePoints,
        spyTwo: cards.contains(const GameCard(2, CardSuit.blackSpade))
            ? config.spyTwoPoints
            : 0,
        mummy: cards.contains(const GameCard(10, CardSuit.razer))
            ? config.mummyPoints
            : 0,
        mostCards: cardCounts[id]! >= 21
            ? config.mostCardsPoints
            : cardCounts[id] == 20
                ? config.tieSharePoints
                : 0,
        mostSpades: spadeCounts[id]! >= 6
            ? config.mostSpadesPoints
            : spadeCounts[id] == 5
                ? config.tieSharePoints
                : 0,
      );
    }
    final points = {for (final id in ids) id: breakdowns[id]!.total};
    ids.sort((a, b) {
      final byPoints = points[b]!.compareTo(points[a]!);
      if (byPoints != 0) return byPoints;
      final byCards = cardCounts[b]!.compareTo(cardCounts[a]!);
      return byCards != 0 ? byCards : a.compareTo(b);
    });
    return ScoreResult(
        points,
        ids.first,
        const [
          'Captured cards: 20 = 1 point; 21 or more = 2 points.',
          'Black spades: 5 = 1 point; 6 or more = 2 points.',
          'Deterministic demo tie-breaker: captured-card count, then player ID.',
        ],
        breakdowns);
  }
}
