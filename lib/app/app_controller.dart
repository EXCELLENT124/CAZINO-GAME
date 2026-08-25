import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repositories.dart';
import '../domain/game/game_engine.dart';
import '../domain/game/game_state.dart';
import '../domain/models/account.dart';
import '../domain/models/game_card.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final AppRepository repository;
  final GameEngine engine = GameEngine();
  GameState? game;
  String? demoActivePlayerId;
  final Map<String, String> demoPlayerNames = {};
  Timer? _buildGraceTimer;
  Timer? _computerTurnTimer;
  static const computerPlayerId = 'cazino-computer';
  bool isComputerMatch = false;
  bool computerThinking = false;
  bool buildGraceActive = false;
  int buildGraceSeconds = 0;
  String? _pendingNextPlayerId;
  String? onlineGameId;
  int onlineGameVersion = 0;
  String? onlineSyncError;
  bool onlineMovePending = false;
  bool get isOnlineMatch => onlineGameId != null;
  PlayerAccount? get user => repository.currentUser;
  // An online client must always render and act as its authenticated user.
  // demoActivePlayerId is only for the single-device offline demo where one
  // person deliberately switches between both players.
  String get gamePlayerId => isOnlineMatch || isComputerMatch
      ? user!.id
      : demoActivePlayerId ?? user!.id;

  Future<void> login(String email, String password) async {
    await repository.login(email, password);
    notifyListeners();
  }

  Future<void> register(PlayerAccount account, String password) async {
    await repository.register(account, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await repository.stopWatchingMatch();
    await repository.logout();
    _computerTurnTimer?.cancel();
    isComputerMatch = false;
    game = null;
    notifyListeners();
  }

  Future<void> acceptOnlineChallenge(Challenge challenge) async {
    final gameId = await repository.acceptChallenge(challenge.id);
    await _openOnlineGame(challenge, gameId);
  }

  Future<void> joinOnlineChallenge(Challenge challenge) async {
    final gameId = await repository.gameForChallenge(challenge.id);
    await _openOnlineGame(challenge, gameId);
  }

  Future<void> _openOnlineGame(Challenge challenge, String gameId) async {
    final proposed = engine.start(
        challengerId: challenge.fromPlayerId, hostId: challenge.toPlayerId);
    final loaded = await repository.initializeOrLoadMatch(gameId, proposed);
    game = loaded.state;
    isComputerMatch = false;
    onlineGameId = gameId;
    onlineGameVersion = loaded.version;
    demoActivePlayerId = user!.id;
    for (final id in [challenge.fromPlayerId, challenge.toPlayerId]) {
      demoPlayerNames[id] = id == user!.id
          ? user!.displayName
          : repository.players.where((p) => p.id == id)
              .map((p) => p.displayName).firstOrNull ?? 'Opponent';
    }
    await repository.watchMatch(gameId, (state, version) {
      if (version <= onlineGameVersion) return;
      game = state;
      onlineGameVersion = version;
      onlineSyncError = null;
      if (state.phase == GamePhase.finished) {
        _cancelBuildGrace();
      } else {
        _restoreBuildGraceFromState();
      }
      notifyListeners();
    });
    _restoreBuildGraceFromState();
    notifyListeners();
  }

  static const allowedStakes = [100, 150, 200, 250, 300, 350, 400, 500];
  int get coinBalance => repository.coinBalance;
  Future<void> challenge(String otherId, {int stake = 100}) async {
    await repository.challenge(user!.id, otherId, stake: stake);
    notifyListeners();
  }

  Future<void> addFriend(String otherId) async {
    await repository.addFriend(otherId);
    notifyListeners();
  }

  Future<void> refreshOnlinePlayers() async {
    await repository.refreshSocial();
    notifyListeners();
  }

  Future<void> watchChallenges() => repository.watchChallenges(notifyListeners);

  Future<String?> quitOnlineMatch() async {
    final id = onlineGameId;
    if (id == null || game == null || game!.phase == GamePhase.finished) {
      return null;
    }
    final winner = await repository.forfeitMatch(id);
    await repository.stopWatchingMatch();
    _cancelBuildGrace();
    onlineGameId = null;
    game = null;
    notifyListeners();
    return winner;
  }

  Future<void> leaveCompletedMatch() async {
    if (game?.phase != GamePhase.finished) return;
    await repository.stopWatchingMatch();
    _cancelBuildGrace();
    onlineGameId = null;
    game = null;
    notifyListeners();
  }

  Future<void> claimDailyCoins() async {
    await repository.claimDailyCoins();
    notifyListeners();
  }

  void startDemoGame(String otherId) {
    _computerTurnTimer?.cancel();
    isComputerMatch = false;
    onlineGameId = null;
    game = engine.start(challengerId: user!.id, hostId: otherId);
    demoActivePlayerId = user!.id;
    demoPlayerNames[user!.id] = user!.displayName;
    demoPlayerNames[otherId] = repository.players
        .firstWhere((player) => player.id == otherId)
        .displayName;
    notifyListeners();
  }

  void startComputerGame() {
    _computerTurnTimer?.cancel();
    onlineGameId = null;
    isComputerMatch = true;
    computerThinking = false;
    game = engine.start(
        challengerId: user!.id, hostId: computerPlayerId);
    demoActivePlayerId = user!.id;
    demoPlayerNames[user!.id] = user!.displayName;
    demoPlayerNames[computerPlayerId] = 'CAZINO Computer';
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
    if (game == null || isComputerMatch) return;
    _cancelBuildGrace();
    demoActivePlayerId = game!.opponentOf(gamePlayerId);
    notifyListeners();
  }

  void throwCard(GameCard card) {
    _ensureOnlineMoveReady();
    engine.throwCard(game!, gamePlayerId, card);
    _followTurn();
    _publishOnlineMove();
  }

  void takeOff(GameCard card,
      [List<GameCard> tableCards = const [],
      List<TableBuild> builds = const []]) {
    _ensureOnlineMoveReady();
    engine.takeOff(game!, gamePlayerId, card, tableCards, builds);
    _followTurn();
    _publishOnlineMove();
  }

  void construct(GameCard card, List<GameCard> table, int target,
      [List<TableBuild> builds = const [],
      List<GameCard> opponentTopCards = const []]) {
    _ensureOnlineMoveReady();
    final actingPlayer = gamePlayerId;
    engine.construct(
        game!, actingPlayer, card, table, target, builds, opponentTopCards);
    _followTurnWithBuildGrace(actingPlayer, target);
    _publishOnlineMove();
  }

  void continueBuild(
      TableBuild build,
      List<GameCard> table,
      List<GameCard> opponentTopCards,
      GameCard? handCard) {
    _ensureOnlineMoveReady();
    if (!buildGraceActive) {
      throw const GameRuleException('Construction continuation window ended');
    }
    engine.continueBuild(
        game!, gamePlayerId, build, table, opponentTopCards, handCard);
    final target = game!.continuationTarget;
    if (target == null) {
      _completeBuildContinuation();
    } else {
      final now = DateTime.now().toUtc();
      // Only a successful continuation grants one fresh 10-second window.
      game!.continuationDeadline = now.add(const Duration(seconds: 10));
      _restoreBuildGraceFromState();
    }
    _publishOnlineMove();
  }

  void stashBuild(GameCard card, TableBuild build) {
    _ensureOnlineMoveReady();
    engine.stashBuild(game!, gamePlayerId, card, build);
    _followTurn();
    _publishOnlineMove();
  }

  Future<void> _publishOnlineMove() async {
    final id = onlineGameId;
    if (id == null || game == null) return;
    final expected = onlineGameVersion;
    onlineMovePending = true;
    try {
      onlineGameVersion =
          await repository.publishMatchState(id, game!, expected);
      onlineSyncError = null;
    } catch (error) {
      onlineSyncError = 'Move was not synchronized: $error';
    }
    onlineMovePending = false;
    notifyListeners();
  }

  void _ensureOnlineMoveReady() {
    if (isOnlineMatch && onlineMovePending) {
      throw const GameRuleException('Please wait for the previous move to synchronize');
    }
  }

  void _followTurn() {
    _cancelBuildGrace();
    if (!isOnlineMatch && !isComputerMatch && game!.phase != GamePhase.finished) {
      demoActivePlayerId = game!.currentPlayerId;
    }
    notifyListeners();
    _scheduleComputerTurn();
  }

  void _followTurnWithBuildGrace(String playerId, int target) {
    if (game!.phase != GamePhase.finished) {
      _pendingNextPlayerId = game!.currentPlayerId;
      game!.currentPlayerId = playerId;
      if (!isOnlineMatch && !isComputerMatch) demoActivePlayerId = playerId;
      game!.continuationTarget = target;
      final now = DateTime.now().toUtc();
      game!.continuationDeadline = now.add(const Duration(seconds: 10));
      _restoreBuildGraceFromState();
    } else {
      _followTurn();
    }
    notifyListeners();
  }

  void _cancelBuildGrace() {
    _buildGraceTimer?.cancel();
    _buildGraceTimer = null;
    buildGraceActive = false;
    buildGraceSeconds = 0;
    _pendingNextPlayerId = null;
  }

  void commenceGame() {
    if (game == null || game!.commenced) return;
    game!.commenced = true;
    notifyListeners();
    _publishOnlineMove();
  }

  void endBuildContinuation() {
    if (!buildGraceActive ||
        game == null ||
        game!.currentPlayerId != gamePlayerId) {
      return;
    }
    if (isOnlineMatch && onlineMovePending) return;
    _completeBuildContinuation();
    notifyListeners();
    _publishOnlineMove();
  }

  void _restoreBuildGraceFromState() {
    _buildGraceTimer?.cancel();
    final state = game;
    final deadline = state?.continuationDeadline;
    final target = state?.continuationTarget;
    if (state == null || deadline == null || target == null) {
      _cancelBuildGrace();
      return;
    }
    _pendingNextPlayerId = state.opponentOf(state.currentPlayerId);
    buildGraceActive = true;
    void tick(Timer timer) {
      final remaining = deadline.difference(DateTime.now().toUtc()).inSeconds + 1;
      buildGraceSeconds = remaining.clamp(0, 10).toInt();
      if (remaining <= 0) {
        timer.cancel();
        if (state.currentPlayerId == gamePlayerId) {
          // An unused window expires once and immediately passes the turn.
          _completeBuildContinuation();
          _publishOnlineMove();
        } else {
          buildGraceActive = false;
        }
      }
      notifyListeners();
    }
    _buildGraceTimer = Timer.periodic(const Duration(seconds: 1), tick);
    tick(_buildGraceTimer!);
  }

  void _completeBuildContinuation() {
    final state = game!;
    final next = _pendingNextPlayerId ?? state.opponentOf(state.currentPlayerId);
    _cancelBuildGrace();
    state.continuationTarget = null;
    state.continuationDeadline = null;
    state.currentPlayerId = next;
    if (!isOnlineMatch && !isComputerMatch) demoActivePlayerId = next;
    _scheduleComputerTurn();
  }

  void _scheduleComputerTurn() {
    _computerTurnTimer?.cancel();
    final state = game;
    if (!isComputerMatch ||
        state == null ||
        state.phase == GamePhase.finished ||
        state.currentPlayerId != computerPlayerId) {
      computerThinking = false;
      return;
    }
    computerThinking = true;
    notifyListeners();
    _computerTurnTimer = Timer(const Duration(milliseconds: 900), () {
      final current = game;
      if (!isComputerMatch ||
          current == null ||
          current.currentPlayerId != computerPlayerId ||
          current.phase == GamePhase.finished) return;
      _playComputerMove(current);
      computerThinking = false;
      notifyListeners();
    });
  }

  void _playComputerMove(GameState state) {
    final hand = List<GameCard>.from(state.hands[computerPlayerId]!)
      ..sort((a, b) => b.rank.compareTo(a.rank));

    // Prefer any direct chow; throwCard automatically takes matching loose
    // cards and constructed numbers using the normal engine rules.
    for (final card in hand) {
      if (state.looseTableCards.any((table) => table.rank == card.rank) ||
          state.builds.any((build) => build.target == card.rank)) {
        engine.throwCard(state, computerPlayerId, card);
        return;
      }
    }

    // Then look for a visible combination whose total matches a hand card.
    for (final card in hand) {
      final combination = _subsetForTarget(state.looseTableCards, card.rank);
      if (combination.isNotEmpty) {
        engine.takeOff(state, computerPlayerId, card, combination);
        return;
      }
    }

    // With no capture available, drift the lowest card to preserve stronger
    // cards for later captures.
    hand.sort((a, b) => a.rank.compareTo(b.rank));
    engine.throwCard(state, computerPlayerId, hand.first);
  }

  List<GameCard> _subsetForTarget(List<GameCard> cards, int target) {
    List<GameCard>? result;
    void search(int index, int total, List<GameCard> picked) {
      if (result != null || total > target) return;
      if (total == target && picked.isNotEmpty) {
        result = List<GameCard>.from(picked);
        return;
      }
      for (var i = index; i < cards.length; i++) {
        search(i + 1, total + cards[i].rank, [...picked, cards[i]]);
      }
    }

    search(0, 0, const []);
    return result ?? const [];
  }
}
