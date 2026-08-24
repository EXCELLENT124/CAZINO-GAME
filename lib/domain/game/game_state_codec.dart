import '../models/game_card.dart';
import 'game_state.dart';

class GameStateCodec {
  static Map<String, dynamic> encode(GameState state) => {
        'players': state.players,
        'challenger_id': state.challengerId,
        'host_id': state.hostId,
        'hands': state.hands.map((id, cards) => MapEntry(id, cards.map(_card).toList())),
        'draw_pile': state.drawPile.map(_card).toList(),
        'captured': state.captured.map((id, cards) => MapEntry(id, cards.map(_card).toList())),
        'loose_table_cards': state.looseTableCards.map(_card).toList(),
        'builds': state.builds.map((b) => {
              'target': b.target,
              'cards': b.cards.map(_card).toList(),
              'owner_id': b.ownerId,
              'is_strong': b.isStrong,
              'is_locked': b.isLocked,
            }).toList(),
        'current_player_id': state.currentPlayerId,
        'last_round_winner_id': state.lastRoundWinnerId,
        'last_played_card': state.lastPlayedCard == null ? null : _card(state.lastPlayedCard!),
        'continuation_target': state.continuationTarget,
        'continuation_deadline': state.continuationDeadline?.toUtc().toIso8601String(),
        'commenced': state.commenced,
        'winner_id': state.winnerId,
        'forfeited_by_id': state.forfeitedById,
        'phase': state.phase.name,
      };

  static GameState decode(Map<String, dynamic> json) {
    final players = List<String>.from(json['players'] as List);
    final state = GameState(
      players: players,
      challengerId: json['challenger_id'] as String,
      hostId: json['host_id'] as String,
      hands: Map<String, dynamic>.from(json['hands'] as Map).map(
          (id, cards) => MapEntry(id, (cards as List).map(_decodeCard).toList())),
      drawPile: (json['draw_pile'] as List).map(_decodeCard).toList(),
      captured: Map<String, dynamic>.from(json['captured'] as Map).map(
          (id, cards) => MapEntry(id, (cards as List).map(_decodeCard).toList())),
      currentPlayerId: json['current_player_id'] as String,
      phase: GamePhase.values.byName(json['phase'] as String),
    );
    state.looseTableCards.addAll((json['loose_table_cards'] as List).map(_decodeCard));
    state.builds.addAll((json['builds'] as List).map((raw) {
      final b = Map<String, dynamic>.from(raw as Map);
      return TableBuild(target: b['target'] as int, cards: (b['cards'] as List).map(_decodeCard).toList(),
          ownerId: b['owner_id'] as String, isStrong: b['is_strong'] == true, isLocked: b['is_locked'] == true);
    }));
    state.lastRoundWinnerId = json['last_round_winner_id'] as String?;
    final last = json['last_played_card'];
    state.lastPlayedCard = last == null ? null : _decodeCard(last);
    state.continuationTarget = json['continuation_target'] as int?;
    state.continuationDeadline = DateTime.tryParse(
        json['continuation_deadline']?.toString() ?? '');
    state.commenced = json['commenced'] == true;
    state.winnerId = json['winner_id'] as String?;
    state.forfeitedById = json['forfeited_by_id'] as String?;
    return state;
  }

  static Map<String, dynamic> _card(GameCard card) => {'rank': card.rank, 'suit': card.suit.name};
  static GameCard _decodeCard(dynamic raw) {
    final card = Map<String, dynamic>.from(raw as Map);
    return GameCard(card['rank'] as int, CardSuit.values.byName(card['suit'] as String));
  }
}
