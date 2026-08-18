import '../domain/models/account.dart';

abstract interface class AuthRepository {
  PlayerAccount? get currentUser;
  Future<PlayerAccount> login(String email, String password);
  Future<PlayerAccount> register(PlayerAccount account, String password);
  Future<void> logout();
}

abstract interface class SocialRepository {
  List<PlayerAccount> get players;
  List<Challenge> challengesFor(String playerId);
  Future<Challenge> challenge(String from, String to);
  List<ChatMessage> messages(String roomId);
  Future<ChatMessage> sendMessage(String roomId, String senderId, String text);
}

abstract interface class KycRepository {
  Future<FicaDocument> stageDocument(String type, String fileName);
}

/// Memory-only demo adapter. Replace these interfaces with Supabase/Firebase
/// adapters; never place identity documents or passwords in app logs/storage.
class LocalDemoRepository implements AuthRepository, SocialRepository, KycRepository {
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

  static PlayerAccount _demo(String id, String first, String last, String email) =>
      PlayerAccount(id: id, firstName: first, lastName: last, email: email,
        phone: '000 000 0000', idNumber: 'DEMO-HIDDEN', dateOfBirth: DateTime(1990),
        address: const Address(line1: 'Demo address', city: 'Johannesburg',
          province: 'Gauteng', postalCode: '2000', country: 'South Africa'));

  @override PlayerAccount? get currentUser => _current;
  @override List<PlayerAccount> get players => List.unmodifiable(_players);
  @override Future<PlayerAccount> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) throw Exception('Enter email and password');
    _current = _players.firstWhere((p) => p.email == email,
      orElse: () => _demo('local-user', 'Demo', 'Player', email));
    if (!_players.contains(_current)) _players.add(_current!);
    return _current!;
  }
  @override Future<PlayerAccount> register(PlayerAccount account, String password) async {
    _players.add(account); _current = account; return account;
  }
  @override Future<void> logout() async => _current = null;
  @override List<Challenge> challengesFor(String id) =>
      _challenges.where((c) => c.fromPlayerId == id || c.toPlayerId == id).toList();
  @override Future<Challenge> challenge(String from, String to) async {
    final item = Challenge(id: 'challenge-${_challenges.length + 1}', fromPlayerId: from, toPlayerId: to);
    _challenges.add(item); return item;
  }
  @override List<ChatMessage> messages(String roomId) => List.unmodifiable(_messages[roomId] ?? []);
  @override Future<ChatMessage> sendMessage(String roomId, String senderId, String text) async {
    final item = ChatMessage(id: '${DateTime.now().microsecondsSinceEpoch}', senderId: senderId,
      text: text, sentAt: DateTime.now());
    (_messages[roomId] ??= []).add(item); return item;
  }
  @override Future<FicaDocument> stageDocument(String type, String fileName) async =>
      FicaDocument(type: type, fileName: fileName, uploadedAt: DateTime.now());
}
