enum CardSuit { redHeart, blackSpade, razer, tree }

class GameCard {
  const GameCard(this.rank, this.suit);

  final int rank;
  final CardSuit suit;

  String get id => '${suit.name}-$rank';
  String get rankLabel => rank == 1 ? 'A' : '$rank';
  String get suitSymbol => switch (suit) {
        CardSuit.redHeart => '♥',
        CardSuit.blackSpade => '♠',
        CardSuit.razer => '◆',
        CardSuit.tree => '♣',
      };
  bool get isRed => suit == CardSuit.redHeart || suit == CardSuit.razer;

  @override
  bool operator ==(Object other) =>
      other is GameCard && rank == other.rank && suit == other.suit;
  @override
  int get hashCode => Object.hash(rank, suit);
}
