import 'package:cazino/domain/game/scoring.dart';
import 'package:cazino/domain/models/game_card.dart';
import 'package:test/test.dart';

void main() {
  test('official fixed cards total seven and majority categories total four', () {
    final fixed = <GameCard>[
      for (final suit in CardSuit.values) GameCard(1, suit),
      const GameCard(2, CardSuit.blackSpade),
      const GameCard(10, CardSuit.razer),
    ];
    final filler = const [GameCard(3, CardSuit.blackSpade), GameCard(4, CardSuit.blackSpade)];
    final result = const ScoringRules().score({'a': [...fixed, ...filler], 'b': const []});
    expect(result.breakdowns['a']!.aces, 4);
    expect(result.breakdowns['a']!.spyTwo, 1);
    expect(result.breakdowns['a']!.mummy, 2);
    expect(result.breakdowns['a']!.mostCards, 2);
    expect(result.breakdowns['a']!.mostSpades, 2);
    expect(result.points['a'], 11);
  });

  test('tie-breaker produces exactly one deterministic winner', () {
    final result = const ScoringRules().score({'z': const [], 'a': const []});
    expect(result.winnerId, 'a');
  });

  test('ties split most-cards and most-spades points one each', () {
    final result = const ScoringRules().score({
      'a': const [GameCard(3, CardSuit.blackSpade)],
      'b': const [GameCard(4, CardSuit.blackSpade)],
    });
    expect(result.breakdowns['a']!.mostCards, 1);
    expect(result.breakdowns['b']!.mostSpades, 1);
  });
}
