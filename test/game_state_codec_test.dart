import 'package:cazino/domain/game/game_engine.dart';
import 'package:cazino/domain/game/game_state_codec.dart';
import 'package:test/test.dart';
import 'dart:math';

void main() {
  test('online match snapshot round-trips all dealt cards and turn state', () {
    final original = GameEngine(random: Random(42))
        .start(challengerId: 'player-one', hostId: 'player-two');
    final restored = GameStateCodec.decode(GameStateCodec.encode(original));

    expect(restored.players, original.players);
    expect(restored.currentPlayerId, 'player-one');
    expect(restored.hands['player-one'], original.hands['player-one']);
    expect(restored.hands['player-two'], original.hands['player-two']);
    expect(restored.drawPile, original.drawPile);
    expect(restored.phase, original.phase);
  });
}
