import 'package:flutter/foundation.dart';
import '../data/repositories.dart';
import '../domain/game/game_engine.dart';
import '../domain/game/game_state.dart';
import '../domain/models/account.dart';
import '../domain/models/game_card.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final LocalDemoRepository repository;
  final GameEngine engine = GameEngine();
  GameState? game;
  String? demoActivePlayerId;
  final Map<String, String> demoPlayerNames = {};
  PlayerAccount? get user => repository.currentUser;
  String get gamePlayerId => demoActivePlayerId ?? user!.id;

  Future<void> login(String email, String password) async {
    await repository.login(email, password);
    notifyListeners();
  }

  Future<void> register(PlayerAccount account, String password) async {
    await repository.register(account, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await repository.logout();
    game = null;
    notifyListeners();
  }

  Future<void> challenge(String otherId) async {
    await repository.challenge(user!.id, otherId);
    notifyListeners();
  }

  void startDemoGame(String otherId) {
    game = engine.start(challengerId: user!.id, hostId: otherId);
    demoActivePlayerId = user!.id;
    demoPlayerNames[user!.id] = user!.displayName;
    demoPlayerNames[otherId] = repository.players
        .firstWhere((player) => player.id == otherId)
        .displayName;
    notifyListeners();
  }

  String playerName(String id) => demoPlayerNames[id] ?? 'Player';
  void setDemoPlayerNames(String playerOne, String playerTwo) {
    if (game == null) return;
    demoPlayerNames[game!.challengerId] =
        playerOne.trim().isEmpty ? 'Player 1' : playerOne.trim();
    demoPlayerNames[game!.hostId] =
        playerTwo.trim().isEmpty ? 'Player 2' : playerTwo.trim();
    notifyListeners();
  }

  void switchDemoPlayer() {
    if (game == null) return;
    demoActivePlayerId = game!.opponentOf(gamePlayerId);
    notifyListeners();
  }

  void throwCard(GameCard card) {
    engine.throwCard(game!, gamePlayerId, card);
    _followTurn();
  }

  void takeOff(GameCard card,
      [List<GameCard> tableCards = const [],
      List<TableBuild> builds = const []]) {
    engine.takeOff(game!, gamePlayerId, card, tableCards, builds);
    _followTurn();
  }

  void construct(GameCard card, List<GameCard> table, int target,
      [List<TableBuild> builds = const [],
      List<GameCard> opponentTopCards = const []]) {
    engine.construct(
        game!, gamePlayerId, card, table, target, builds, opponentTopCards);
    _followTurn();
  }

  void stashBuild(GameCard card, TableBuild build) {
    engine.stashBuild(game!, gamePlayerId, card, build);
    _followTurn();
  }

  void _followTurn() {
    if (game!.phase != GamePhase.finished) {
      demoActivePlayerId = game!.currentPlayerId;
    }
    notifyListeners();
  }
}
