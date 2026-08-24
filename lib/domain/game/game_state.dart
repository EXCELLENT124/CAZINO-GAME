import '../models/game_card.dart';

enum GamePhase { roundOne, roundTwo, finished }

class TableBuild {
  const TableBuild({required this.target, required this.cards,
    required this.ownerId, this.isStrong = false, this.isLocked = false});
  final int target;
  final List<GameCard> cards;
  final String ownerId;
  final bool isStrong;
  final bool isLocked;
}

class GameState {
  GameState({required this.players, required this.challengerId,
    required this.hostId, required this.hands, required this.drawPile,
    required this.currentPlayerId, this.phase = GamePhase.roundOne,
    Map<String, List<GameCard>>? captured})
      : captured = captured ?? {for (final id in players) id: []};

  final List<String> players;
  final String challengerId, hostId;
  final Map<String, List<GameCard>> hands;
  final List<GameCard> drawPile;
  final Map<String, List<GameCard>> captured;
  final List<GameCard> looseTableCards = [];
  final List<TableBuild> builds = [];
  String currentPlayerId;
  String? lastRoundWinnerId;
  GameCard? lastPlayedCard;
  int? continuationTarget;
  DateTime? continuationDeadline;
  DateTime? continuationLimitDeadline;
  bool commenced = false;
  GamePhase phase;

  String opponentOf(String id) => players.firstWhere((player) => player != id);
}

class PlayerGameView {
  const PlayerGameView({required this.hand, required this.tableCards,
    required this.builds, required this.capturedCounts,
    required this.capturedTopCards,
    required this.capturedPacks,
    required this.currentPlayerId, required this.phase});
  final List<GameCard> hand, tableCards;
  final List<TableBuild> builds;
  final Map<String, int> capturedCounts;
  final Map<String, GameCard?> capturedTopCards;
  final Map<String, List<GameCard>> capturedPacks;
  final String currentPlayerId;
  final GamePhase phase;
}

class GameRuleException implements Exception {
  const GameRuleException(this.message);
  final String message;
  @override
  String toString() => message;
}
