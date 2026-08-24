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

  test('online snapshot preserves a synchronized build continuation window', () {
    final original = GameEngine(random: Random(7))
        .start(challengerId: 'player-one', hostId: 'player-two');
    original.continuationTarget = 8;
    original.continuationDeadline = DateTime.utc(2026, 8, 24, 12, 0);
    original.continuationLimitDeadline = DateTime.utc(2026, 8, 24, 12, 10);
    original.commenced = true;

    final restored = GameStateCodec.decode(GameStateCodec.encode(original));

    expect(restored.continuationTarget, 8);
    expect(restored.continuationDeadline, DateTime.utc(2026, 8, 24, 12, 0));
    expect(restored.continuationLimitDeadline,
        DateTime.utc(2026, 8, 24, 12, 10));
    expect(restored.commenced, isTrue);
  });
}
