import 'package:cazino/domain/game/scoring.dart';
import 'package:cazino/domain/models/game_card.dart';
import 'package:test/test.dart';

void main() {
  test('fixed cards total seven and threshold categories complete 11', () {
    final fixed = <GameCard>[
      for (final suit in CardSuit.values) GameCard(1, suit),
      const GameCard(2, CardSuit.blackSpade),
      const GameCard(10, CardSuit.razer),
    ];
    final sixSpades = const [
      GameCard(3, CardSuit.blackSpade),
      GameCard(4, CardSuit.blackSpade),
      GameCard(5, CardSuit.blackSpade),
      GameCard(6, CardSuit.blackSpade),
    ];
    final filler =
        List.generate(11, (_) => const GameCard(3, CardSuit.redHeart));
    final result = const ScoringRules().score({
      'a': [...fixed, ...sixSpades, ...filler],
      'b': const []
    });
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

  test('exactly 20 cards and exactly 5 spades award one point each', () {
    final pack = <GameCard>[
      for (var rank = 1; rank <= 5; rank++) GameCard(rank, CardSuit.blackSpade),
      ...List.generate(15, (_) => const GameCard(3, CardSuit.redHeart)),
    ];
    final result = const ScoringRules().score({'a': pack, 'b': const []});
    expect(result.breakdowns['a']!.mostCards, 1);
    expect(result.breakdowns['a']!.mostSpades, 1);
  });
}
