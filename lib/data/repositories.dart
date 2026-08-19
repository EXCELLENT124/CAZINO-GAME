import '../domain/models/account.dart';
import '../domain/game/game_state.dart';

abstract interface class AuthRepository {
  PlayerAccount? get currentUser;
  Future<PlayerAccount> login(String email, String password);
  Future<PlayerAccount> register(PlayerAccount account, String password);
  Future<void> logout();
}

abstract interface class SocialRepository {
  List<PlayerAccount> get players;
  List<Challenge> challengesFor(String playerId);
  Future<Challenge> challenge(String from, String to, {required int stake});
  Future<void> addFriend(String playerId);
  bool isFriend(String playerId);
  Future<void> refreshSocial();
  List<ChatMessage> messages(String roomId);
  Future<ChatMessage> sendMessage(String roomId, String senderId, String text);
}

abstract interface class WalletRepository {
  int get coinBalance;
  Future<int> claimDailyCoins();
}

abstract interface class AppRepository
    implements
        AuthRepository,
        SocialRepository,
        KycRepository,
        WalletRepository {
  bool get isOnlineBackend;
  Future<void> setPresence(bool online);
  Future<String> acceptChallenge(String challengeId);
  Future<String> gameForChallenge(String challengeId);
  Future<({GameState state, int version})> initializeOrLoadMatch(
      String gameId, GameState proposedState);
  Future<int> publishMatchState(
      String gameId, GameState state, int expectedVersion);
  Future<void> watchMatch(
      String gameId, void Function(GameState state, int version) onState);
  Future<void> stopWatchingMatch();
  Future<void> watchChallenges(void Function() onChanged);
}

abstract interface class KycRepository {
  Future<FicaDocument> stageDocument(String type, String fileName);
}

/// Memory-only demo adapter. Replace these interfaces with Supabase/Firebase
/// adapters; never place identity documents or passwords in app logs/storage.
class LocalDemoRepository implements AppRepository {
  LocalDemoRepository() {
    _players.addAll([
      _demo('demo-1', 'Lebo', 'Mokoena', 'lebo@cazino.demo'),
      _demo('demo-2', 'Amina', 'Khan', 'amina@cazino.demo'),
      _demo('demo-3', 'Thabo', 'Dlamini', 'thabo@cazino.demo'),
    ]);
  }
  final List<PlayerAccount> _players = [];
  final List<Challenge> _challenges = [];
  final Map<String, List<ChatMessage>> _messages = {};
  PlayerAccount? _current;
  final Set<String> _friends = {};
  int _coins = 500;
  DateTime? _lastClaim;

  static PlayerAccount _demo(
          String id, String first, String last, String email) =>
      PlayerAccount(
          id: id,
          firstName: first,
          lastName: last,
          username: '${first.toLowerCase()}_${last.toLowerCase()}',
          email: email,
          phone: '000 000 0000',
          idNumber: 'DEMO-HIDDEN',
          dateOfBirth: DateTime(1990),
          address: const Address(
              line1: 'Demo address',
              city: 'Johannesburg',
              province: 'Gauteng',
              postalCode: '2000',
              country: 'South Africa'));

  @override
  PlayerAccount? get currentUser => _current;
  @override
  List<PlayerAccount> get players => List.unmodifiable(_players);
  @override
  Future<PlayerAccount> login(String email, String password) async {
    final identifier = email.trim().toLowerCase();
    if (identifier.isEmpty || password.isEmpty)
      throw Exception('Enter username or email and password');
    _current = _players.firstWhere(
        (p) =>
            p.email.toLowerCase() == identifier ||
            p.username.toLowerCase() == identifier,
        orElse: () => _demo('local-user', 'Demo', 'Player', email));
    if (!_players.contains(_current)) _players.add(_current!);
    return _current!;
  }

  @override
  Future<PlayerAccount> register(PlayerAccount account, String password) async {
    final username = account.username.toLowerCase();
    if (_players.any((p) => p.username.toLowerCase() == username)) {
      throw Exception('That username is already assigned to another player');
    }
    _players.add(account);
    _current = account;
    return account;
  }

  @override
  Future<void> logout() async => _current = null;
  @override
  List<Challenge> challengesFor(String id) => _challenges
      .where((c) => c.fromPlayerId == id || c.toPlayerId == id)
      .toList();
  @override
  Future<Challenge> challenge(String from, String to,
      {required int stake}) async {
    final item = Challenge(
        id: 'challenge-${_challenges.length + 1}',
        fromPlayerId: from,
        toPlayerId: to,
        stake: stake);
    _challenges.add(item);
    return item;
  }

  @override
  List<ChatMessage> messages(String roomId) =>
      List.unmodifiable(_messages[roomId] ?? []);
  @override
  Future<ChatMessage> sendMessage(
      String roomId, String senderId, String text) async {
    final item = ChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        senderId: senderId,
        text: text,
        sentAt: DateTime.now());
    (_messages[roomId] ??= []).add(item);
    return item;
  }

  @override
  Future<FicaDocument> stageDocument(String type, String fileName) async =>
      FicaDocument(type: type, fileName: fileName, uploadedAt: DateTime.now());
  @override
  bool get isOnlineBackend => false;
  @override
  int get coinBalance => _coins;
  @override
  Future<int> claimDailyCoins() async {
    final now = DateTime.now();
    if (_lastClaim == null || now.difference(_lastClaim!).inDays >= 1) {
      _coins += 500;
      _lastClaim = now;
    }
    return _coins;
  }

  @override
  Future<void> addFriend(String playerId) async => _friends.add(playerId);
  @override
  bool isFriend(String playerId) => _friends.contains(playerId);
  @override
  Future<void> refreshSocial() async {}
  @override
  Future<void> setPresence(bool online) async {}
  @override
  Future<String> acceptChallenge(String challengeId) async => challengeId;
  @override
  Future<String> gameForChallenge(String challengeId) async => challengeId;
  @override
  Future<({GameState state, int version})> initializeOrLoadMatch(
          String gameId, GameState proposedState) async =>
      (state: proposedState, version: 0);
  @override
  Future<int> publishMatchState(
          String gameId, GameState state, int expectedVersion) async =>
      expectedVersion + 1;
  @override
  Future<void> watchMatch(String gameId,
      void Function(GameState state, int version) onState) async {}
  @override
  Future<void> stopWatchingMatch() async {}
  @override
  Future<void> watchChallenges(void Function() onChanged) async {}
}
