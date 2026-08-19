import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/account.dart';
import '../domain/game/game_state.dart';
import '../domain/game/game_state_codec.dart';
import 'repositories.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get configured => url.isNotEmpty && key.isNotEmpty;
}

/// Online adapter. Sensitive identity/address rows are kept in private_profiles;
/// public lobby queries only read profiles and presence.
class SupabaseRepository implements AppRepository {
  SupabaseRepository(this.client);
  final SupabaseClient client;
  final List<PlayerAccount> _players = [];
  final List<Challenge> _challenges = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Set<String> _friends = {};
  PlayerAccount? _current;
  int _coins = 0;
  RealtimeChannel? _matchChannel;
  RealtimeChannel? _challengeChannel;

  @override
  bool get isOnlineBackend => true;
  @override
  PlayerAccount? get currentUser => _current;
  @override
  List<PlayerAccount> get players => List.unmodifiable(_players);
  @override
  int get coinBalance => _coins;

  @override
  Future<PlayerAccount> register(PlayerAccount account, String password) async {
    final username = account.username.trim().toLowerCase();
    final availability = await client.functions.invoke('username-login',
        body: {'action': 'availability', 'username': username});
    final availableData = Map<String, dynamic>.from(availability.data as Map);
    if (availability.status >= 400 || availableData['available'] != true) {
      throw Exception(
          'That username is already assigned. Choose another username.');
    }
    final response = await client.auth.signUp(
      email: account.email,
      password: password,
      data: {
        'first_name': account.firstName,
        'last_name': account.lastName,
        'username': username
      },
    );
    final id = response.user?.id;
    if (id == null)
      throw Exception('Check your email to confirm registration.');
    await client.from('private_profiles').upsert({
      'user_id': id,
      'phone': account.phone,
      'id_number': account.idNumber,
      'date_of_birth': account.dateOfBirth.toIso8601String().substring(0, 10),
      'address_line_1': account.address.line1,
      'address_line_2': account.address.line2,
      'city': account.address.city,
      'province': account.address.province,
      'postal_code': account.address.postalCode,
      'country': account.address.country,
    });
    await _loadCurrent();
    await setPresence(true);
    await claimDailyCoins();
    await refreshSocial();
    return _current!;
  }

  @override
  Future<PlayerAccount> login(String email, String password) async {
    final identifier = email.trim().toLowerCase();
    if (identifier.contains('@')) {
      await client.auth
          .signInWithPassword(email: identifier, password: password);
    } else {
      final response = await client.functions.invoke('username-login', body: {
        'action': 'login',
        'identifier': identifier,
        'password': password
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      if (response.status >= 400 || data['refresh_token'] == null) {
        throw Exception(data['error_description'] ??
            data['error'] ??
            'Invalid username or password');
      }
      await client.auth.setSession(data['refresh_token'] as String,
          accessToken: data['access_token'] as String?);
    }
    final account = await _loadCurrent();
    await setPresence(true);
    await claimDailyCoins();
    await refreshSocial();
    return account;
  }

  Future<PlayerAccount> _loadCurrent() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final pub =
        await client.from('profiles').select().eq('id', user.id).single();
    final priv = await client
        .from('private_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    final wallet = await client
        .from('wallets')
        .select('balance')
        .eq('user_id', user.id)
        .single();
    _coins = wallet['balance'] as int? ?? 0;
    return _current = _account(pub, priv, email: user.email ?? '');
  }

  PlayerAccount _account(Map<String, dynamic> pub, Map<String, dynamic>? priv,
      {String email = '', bool online = false, int balance = 0}) {
    return PlayerAccount(
      id: pub['id'] as String,
      firstName: pub['first_name'] as String? ?? 'Player',
      lastName: pub['last_name'] as String? ?? '',
      username: pub['username'] as String? ?? '',
      email: email,
      phone: priv?['phone'] as String? ?? '',
      idNumber: priv?['id_number'] as String? ?? '',
      dateOfBirth:
          DateTime.tryParse(priv?['date_of_birth']?.toString() ?? '') ??
              DateTime(1990),
      address: Address(
        line1: priv?['address_line_1'] as String? ?? '',
        line2: priv?['address_line_2'] as String? ?? '',
        city: priv?['city'] as String? ?? '',
        province: priv?['province'] as String? ?? '',
        postalCode: priv?['postal_code'] as String? ?? '',
        country: priv?['country'] as String? ?? '',
      ),
      isOnline: online,
      coinBalance: balance,
    );
  }

  @override
  Future<void> refreshSocial() async {
    final uid = client.auth.currentUser!.id;
    final rows = await client.from('online_players').select();
    _players
      ..clear()
      ..addAll((rows as List).where((r) => r['id'] != uid).map((r) => _account(
          Map<String, dynamic>.from(r), null,
          online: r['is_online'] == true, balance: r['balance'] as int? ?? 0)));
    final challengeRows = await client
        .from('challenges')
        .select()
        .or('from_player.eq.$uid,to_player.eq.$uid');
    _challenges
      ..clear()
      ..addAll((challengeRows as List).map((r) => Challenge(
          id: r['id'],
          fromPlayerId: r['from_player'],
          toPlayerId: r['to_player'],
          accepted: r['status'] == 'accepted',
          stake: r['stake'])));
    final friendRows = await client
        .from('friendships')
        .select('user_a,user_b')
        .or('user_a.eq.$uid,user_b.eq.$uid');
    _friends
      ..clear()
      ..addAll((friendRows as List).map((r) =>
          r['user_a'] == uid ? r['user_b'] as String : r['user_a'] as String));
  }

  @override
  List<Challenge> challengesFor(String id) => _challenges
      .where((c) => c.fromPlayerId == id || c.toPlayerId == id)
      .toList();

  @override
  Future<Challenge> challenge(String from, String to,
      {required int stake}) async {
    final row = await client.rpc('create_challenge',
        params: {'opponent_id': to, 'coin_stake': stake});
    await refreshSocial();
    return _challenges.firstWhere((c) => c.id == row.toString());
  }

  @override
  Future<String> acceptChallenge(String challengeId) async {
    final result = await client
        .rpc('accept_challenge', params: {'challenge': challengeId});
    await refreshSocial();
    return result as String;
  }

  @override
  Future<String> gameForChallenge(String challengeId) async => (await client
      .rpc('game_for_challenge', params: {'challenge': challengeId})) as String;

  @override
  Future<({GameState state, int version})> initializeOrLoadMatch(
      String gameId, GameState proposedState) async {
    final row = await client.rpc('initialize_or_load_game', params: {
      'game': gameId,
      'initial_state': GameStateCodec.encode(proposedState),
    });
    final data = Map<String, dynamic>.from(row as Map);
    return (
      state: GameStateCodec.decode(
          Map<String, dynamic>.from(data['state'] as Map)),
      version: data['version'] as int
    );
  }

  @override
  Future<int> publishMatchState(
      String gameId, GameState state, int expectedVersion) async {
    final result = await client.rpc('submit_game_state', params: {
      'game': gameId,
      'expected_version': expectedVersion,
      'next_state': GameStateCodec.encode(state),
    });
    return result as int;
  }

  @override
  Future<void> watchMatch(String gameId,
      void Function(GameState state, int version) onState) async {
    await stopWatchingMatch();
    _matchChannel = client.channel('game:$gameId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'game_sessions',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'id', value: gameId),
        callback: (payload) {
          final row = payload.newRecord;
          final raw = row['state'];
          if (raw is Map && raw.isNotEmpty) {
            onState(GameStateCodec.decode(Map<String, dynamic>.from(raw)),
                row['version'] as int);
          }
        },
      )
      ..subscribe();
  }

  @override
  Future<void> stopWatchingMatch() async {
    final channel = _matchChannel;
    _matchChannel = null;
    if (channel != null) await client.removeChannel(channel);
  }

  @override
  Future<void> watchChallenges(void Function() onChanged) async {
    final existing = _challengeChannel;
    if (existing != null) await client.removeChannel(existing);
    _challengeChannel = client.channel('my-challenges')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'challenges',
        callback: (_) async {
          await refreshSocial();
          onChanged();
        },
      )
      ..subscribe();
  }

  @override
  Future<void> addFriend(String playerId) async {
    await client.rpc('send_friend_request', params: {'other_user': playerId});
    await refreshSocial();
  }

  @override
  bool isFriend(String playerId) => _friends.contains(playerId);

  @override
  Future<int> claimDailyCoins() async {
    _coins = (await client.rpc('claim_daily_coins')) as int;
    return _coins;
  }

  @override
  Future<void> setPresence(bool online) async =>
      client.rpc('set_player_presence', params: {'online': online});

  @override
  Future<void> logout() async {
    await stopWatchingMatch();
    final challengeChannel = _challengeChannel;
    _challengeChannel = null;
    if (challengeChannel != null) await client.removeChannel(challengeChannel);
    await setPresence(false);
    await client.auth.signOut();
    _current = null;
    _players.clear();
  }

  @override
  List<ChatMessage> messages(String roomId) =>
      List.unmodifiable(_messages[roomId] ?? const []);
  @override
  Future<ChatMessage> sendMessage(
      String roomId, String senderId, String text) async {
    final row = await client
        .from('messages')
        .insert({'room_id': roomId, 'body': text.trim()})
        .select()
        .single();
    final message = ChatMessage(
        id: row['id'],
        senderId: row['sender_id'],
        text: row['body'],
        sentAt: DateTime.parse(row['created_at']));
    (_messages[roomId] ??= []).add(message);
    return message;
  }

  @override
  Future<FicaDocument> stageDocument(String type, String fileName) async {
    final row = await client
        .from('fica_documents')
        .insert({'document_type': type, 'file_name': fileName})
        .select()
        .single();
    return FicaDocument(
        type: type,
        fileName: fileName,
        uploadedAt: DateTime.parse(row['created_at']),
        remoteReference: row['id']);
  }
}
