import 'dart:math';
import 'package:cazino/domain/game/game_engine.dart';
import 'package:cazino/domain/game/game_state.dart';
import 'package:cazino/domain/models/game_card.dart';
import 'package:test/test.dart';

void main() {
  late GameEngine engine;
  setUp(() => engine = GameEngine(random: Random(7)));

  test('deck contains 40 unique cards, ranks 1 through 10 in four suits', () {
    final deck = engine.createDeck();
    expect(deck, hasLength(40));
    expect(deck.map((c) => c.id).toSet(), hasLength(40));
    for (final suit in CardSuit.values) {
      expect(deck.where((c) => c.suit == suit).map((c) => c.rank).toSet(),
          equals({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}));
    }
  });

  test('start shuffles and deals 10 per player with 20 remaining', () {
    final state = engine.start(challengerId: 'challenger', hostId: 'host');
    expect(state.hands['challenger'], hasLength(10));
    expect(state.hands['host'], hasLength(10));
    expect(state.drawPile, hasLength(20));
    expect(state.currentPlayerId, 'challenger');
  });

  test('player view hides opponent hand but exposes ordered taken-card packs',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.captured['b']!.addAll(state.drawPile.take(2));
    final view = engine.viewFor(state, 'a');
    expect(view.hand, state.hands['a']);
    expect(view.capturedCounts['b'], 2);
    expect(view.capturedPacks['b'], hasLength(2));
    expect(view.hand.any(state.hands['b']!.contains), isFalse);
  });

  test('take-off captures hand card and every visible rank match', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final card = state.hands['a']!.first;
    state.looseTableCards.addAll([
      GameCard(card.rank, CardSuit.tree),
      const GameCard(9, CardSuit.razer)
    ]);
    engine.takeOff(state, 'a', card);
    expect(state.captured['a'], hasLength(2));
    expect(state.captured['a']!.last, card);
    expect(state.looseTableCards.single.rank, 9);
  });

  test('normal throw automatically takes off opponent latest matching rank',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final first = state.hands['a']!.first;
    engine.throwCard(state, 'a', first);
    final matching = GameCard(
        first.rank, CardSuit.values.firstWhere((suit) => suit != first.suit));
    state.hands['b']!
      ..clear()
      ..add(matching);
    engine.throwCard(state, 'b', matching);
    expect(state.looseTableCards, isEmpty);
    expect(state.captured['b'], hasLength(2));
    expect(state.captured['b']!.last, matching);
  });

  test('take-off accepts selected table cards whose ranks total the hand card',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..add(const GameCard(5, CardSuit.redHeart));
    state.looseTableCards.addAll(const [
      GameCard(2, CardSuit.tree),
      GameCard(3, CardSuit.razer),
      GameCard(8, CardSuit.blackSpade),
    ]);
    final takingCard = state.hands['a']!.single;
    engine.takeOff(state, 'a', takingCard,
        [state.looseTableCards[0], state.looseTableCards[1]]);
    expect(state.captured['a']!.map((c) => c.rank), equals([3, 2, 5]));
    expect(state.captured['a']!.last, takingCard);
    expect(state.looseTableCards.single.rank, 8);
  });

  test('construct requires retained target card and emits exact error', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..addAll(
          const [GameCard(2, CardSuit.tree), GameCard(7, CardSuit.redHeart)]);
    state.looseTableCards.add(const GameCard(3, CardSuit.razer));
    expect(
        () => engine.construct(state, 'a', state.hands['a']!.first,
            [state.looseTableCards.first], 5),
        throwsA(predicate((e) => '$e' == 'Card in construct not available')));
  });

  test('legal simple build consumes only selected visible table cards', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..addAll(
          const [GameCard(2, CardSuit.tree), GameCard(5, CardSuit.redHeart)]);
    state.looseTableCards.addAll(const [
      GameCard(3, CardSuit.razer),
      GameCard(3, CardSuit.blackSpade),
      GameCard(9, CardSuit.tree)
    ]);
    engine.construct(
        state, 'a', state.hands['a']!.first, [state.looseTableCards.first], 5);
    expect(state.builds.single.cards, hasLength(2));
    expect(state.looseTableCards.map((c) => c.rank), containsAll([3, 9]));
    expect(state.hands['a']!.single.rank, 5);
  });

  test('matching hand and table cards may build their sum instead of chow', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(4, CardSuit.redHeart),
        GameCard(8, CardSuit.razer),
      ]);
    state.looseTableCards.add(const GameCard(4, CardSuit.blackSpade));
    engine.construct(
        state, 'a', state.hands['a']!.first, [state.looseTableCards.first], 8);
    expect(state.builds.single.target, 8);
    expect(state.builds.single.isStrong, isFalse);
    expect(state.builds.single.cards.map((card) => card.rank), equals([4, 4]));
    expect(state.hands['a']!.single.rank, 8);
  });

  test(
      'table target card plus matching combination creates locked strong build',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(6, CardSuit.tree),
        GameCard(9, CardSuit.redHeart),
      ]);
    state.looseTableCards.addAll(const [
      GameCard(9, CardSuit.blackSpade),
      GameCard(3, CardSuit.razer),
    ]);
    engine.construct(
        state, 'a', state.hands['a']!.first, List.of(state.looseTableCards), 9);
    expect(state.builds.single.target, 9);
    expect(state.builds.single.isStrong, isTrue);
  });

  test('strong build cannot be extended into another number', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final locked = TableBuild(
        target: 9,
        cards: const [
          GameCard(9, CardSuit.blackSpade),
          GameCard(6, CardSuit.tree),
          GameCard(3, CardSuit.razer),
        ],
        ownerId: 'a',
        isStrong: true);
    state.builds.add(locked);
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(1, CardSuit.tree),
        GameCard(10, CardSuit.redHeart),
      ]);
    final handCard = state.hands['a']!.first;
    expect(
        () => engine.construct(state, 'a', handCard, const [], 10, [locked]),
        throwsA(predicate((error) =>
            '$error' == 'Unable to construct a number: number is strong')));
  });

  test('only owner can add a complete group to their strong build', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final build =
        TableBuild(target: 9, ownerId: 'a', isStrong: true, cards: const [
      GameCard(9, CardSuit.blackSpade),
      GameCard(9, CardSuit.razer),
    ]);
    state.builds.add(build);
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(1, CardSuit.tree),
        GameCard(9, CardSuit.redHeart),
      ]);
    state.looseTableCards.add(const GameCard(8, CardSuit.blackSpade));
    engine.construct(state, 'a', state.hands['a']!.first,
        [state.looseTableCards.first], 9, [build]);
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.cards.map((card) => card.rank),
        equals([9, 9, 8, 1]));
  });

  test('opponent cannot raise a strong build and may only chow it', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final build =
        TableBuild(target: 8, ownerId: 'b', isStrong: true, cards: const [
      GameCard(6, CardSuit.tree),
      GameCard(2, CardSuit.razer),
    ]);
    state.builds.add(build);
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(1, CardSuit.tree),
        GameCard(9, CardSuit.redHeart),
      ]);
    expect(
        () => engine.construct(
            state, 'a', state.hands['a']!.first, const [], 9, [build]),
        throwsA(predicate((error) =>
            '$error' == 'Unable to construct a number: number is strong')));
  });

  test('either player can raise an opponent simple build to a higher target',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const two = GameCard(2, CardSuit.blackSpade);
    const nine = GameCard(9, CardSuit.tree);
    state.hands['a']!
      ..clear()
      ..addAll(const [two, nine]);
    const simpleSeven = TableBuild(target: 7, ownerId: 'b', cards: [
      GameCard(4, CardSuit.tree),
      GameCard(3, CardSuit.blackSpade),
    ]);
    state.builds.add(simpleSeven);

    engine.construct(state, 'a', two, const [], 9, const [simpleSeven]);

    expect(state.builds.single.target, 9);
    expect(state.builds.single.ownerId, 'a');
    expect(
        state.builds.single.cards.map((card) => card.rank), equals([4, 3, 2]));
    expect(state.builds.single.isStrong, isFalse);
    expect(state.hands['a'], equals(const [nine]));
  });

  test('opponent raises simple 7 with hand 2 and loose 9 into strong 9', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const two = GameCard(2, CardSuit.blackSpade);
    const retainedNine = GameCard(9, CardSuit.tree);
    const looseNine = GameCard(9, CardSuit.redHeart);
    state.hands['a']!
      ..clear()
      ..addAll(const [two, retainedNine]);
    const simpleSeven = TableBuild(target: 7, ownerId: 'b', cards: [
      GameCard(4, CardSuit.tree),
      GameCard(3, CardSuit.blackSpade),
    ]);
    state.builds.add(simpleSeven);
    state.looseTableCards.add(looseNine);

    engine.construct(
        state, 'a', two, const [looseNine], 9, const [simpleSeven]);

    final strongNine = state.builds.single;
    expect(strongNine.target, 9);
    expect(strongNine.ownerId, 'a');
    expect(strongNine.isStrong, isTrue);
    expect(strongNine.cards.take(2).map((card) => card.rank), equals([4, 3]));
    expect(strongNine.cards.map((card) => card.rank), equals([4, 3, 9, 2]));
    expect(state.hands['a'], equals(const [retainedNine]));
  });

  test('current build owner cannot raise their own simple build', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const two = GameCard(2, CardSuit.blackSpade);
    const nine = GameCard(9, CardSuit.tree);
    state.hands['a']!
      ..clear()
      ..addAll(const [two, nine]);
    const ownSeven = TableBuild(target: 7, ownerId: 'a', cards: [
      GameCard(4, CardSuit.tree),
      GameCard(3, CardSuit.blackSpade),
    ]);
    state.builds.add(ownSeven);

    expect(
        () => engine.construct(state, 'a', two, const [], 9, const [ownSeven]),
        throwsA(predicate((error) =>
            '$error' == 'Only the opponent may edit this constructed number')));
  });

  test('original constructor may edit after opponent takes ownership', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const one = GameCard(1, CardSuit.redHeart);
    const eight = GameCard(8, CardSuit.razer);
    state.hands['b']!
      ..clear()
      ..addAll(const [one, eight]);
    const seven = TableBuild(target: 7, ownerId: 'a', cards: [
      GameCard(4, CardSuit.tree),
      GameCard(3, CardSuit.blackSpade),
    ]);
    state.builds.add(seven);
    state.currentPlayerId = 'b';
    engine.construct(state, 'b', one, const [], 8, const [seven]);

    const secondOne = GameCard(1, CardSuit.tree);
    const nine = GameCard(9, CardSuit.redHeart);
    state.hands['a']!
      ..clear()
      ..addAll(const [secondOne, nine]);
    final editedEight = state.builds.single;
    engine.construct(state, 'a', secondOne, const [], 9, [editedEight]);

    expect(state.builds.single.target, 9);
    expect(state.builds.single.ownerId, 'a');
    expect(state.builds.single.isStrong, isFalse);
  });

  test('opponent top captured card can complete a locked strong table build',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const opponentTop = GameCard(2, CardSuit.tree);
    state.captured['b']!.add(opponentTop);
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(5, CardSuit.redHeart),
        GameCard(7, CardSuit.razer),
      ]);
    state.looseTableCards.add(const GameCard(7, CardSuit.blackSpade));
    engine.construct(state, 'a', state.hands['a']!.first,
        [state.looseTableCards.first], 7, const [], [opponentTop]);
    expect(state.captured['b'], isEmpty);
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
    expect(
        state.builds.single.cards.map((card) => card.rank), equals([7, 5, 2]));
  });

  test('hand Ace plus opponent top 5 joins table 6 as a locked strong 6', () {
    final state = engine.start(challengerId: 'lebo', hostId: 'amina');
    const ace = GameCard(1, CardSuit.tree);
    const retainedSix = GameCard(6, CardSuit.tree);
    const opponentFive = GameCard(5, CardSuit.redHeart);
    const tableSix = GameCard(6, CardSuit.blackSpade);
    state.hands['lebo']!
      ..clear()
      ..addAll(const [retainedSix, ace]);
    state.captured['amina']!.add(opponentFive);
    state.looseTableCards.add(tableSix);

    engine.construct(state, 'lebo', ace, const [tableSix], 6, const [],
        const [opponentFive]);

    expect(state.captured['amina'], isEmpty);
    expect(state.hands['lebo'], equals(const [retainedSix]));
    expect(state.looseTableCards, isEmpty);
    expect(state.builds.single.target, 6);
    expect(state.builds.single.ownerId, 'lebo');
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
    expect(
        state.builds.single.cards.map((card) => card.rank), equals([6, 5, 1]));
  });

  test(
      'new construction combination is descending regardless of selection order',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const four = GameCard(4, CardSuit.tree);
    const retainedNine = GameCard(9, CardSuit.redHeart);
    const two = GameCard(2, CardSuit.blackSpade);
    const three = GameCard(3, CardSuit.razer);
    state.hands['a']!
      ..clear()
      ..addAll(const [four, retainedNine]);
    state.looseTableCards.addAll(const [two, three]);

    engine.construct(state, 'a', four, const [two, three], 9);

    expect(
        state.builds.single.cards.map((card) => card.rank), equals([4, 3, 2]));
  });

  test(
      'matching opponent top target is automatic and sits above constructing cards',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.captured['b']!.addAll(const [
      GameCard(2, CardSuit.tree),
      GameCard(7, CardSuit.razer),
    ]);
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(3, CardSuit.redHeart),
        GameCard(7, CardSuit.blackSpade),
      ]);
    state.looseTableCards.add(const GameCard(4, CardSuit.tree));
    engine.construct(
        state, 'a', state.hands['a']!.first, [state.looseTableCards.first], 7);
    expect(state.captured['b']!.single.rank, 2);
    expect(state.builds.single.isLocked, isTrue);
    expect(
        state.builds.single.cards.map((card) => card.rank), equals([4, 3, 7]));
  });

  test('locked strong build owner can add another complete target group', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final locked = TableBuild(
        target: 7,
        ownerId: 'a',
        isStrong: true,
        isLocked: true,
        cards: const [
          GameCard(7, CardSuit.razer),
          GameCard(5, CardSuit.redHeart),
          GameCard(2, CardSuit.tree)
        ]);
    state.builds.add(locked);
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(3, CardSuit.tree),
        GameCard(7, CardSuit.redHeart),
      ]);
    state.looseTableCards.add(const GameCard(4, CardSuit.blackSpade));
    engine.construct(state, 'a', state.hands['a']!.first,
        [state.looseTableCards.first], 7, [locked]);
    expect(state.builds.single.target, 7);
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
  });

  test('owner adds hand 7 and opponent top 3 to their locked strong 10', () {
    final state = engine.start(challengerId: 'thabo', hostId: 'lebo');
    const seven = GameCard(7, CardSuit.tree);
    const retainedTen = GameCard(10, CardSuit.redHeart);
    const opponentThree = GameCard(3, CardSuit.blackSpade);
    state.hands['thabo']!
      ..clear()
      ..addAll(const [seven, retainedTen]);
    state.captured['lebo']!.add(opponentThree);
    const lockedTen = TableBuild(
        target: 10,
        ownerId: 'thabo',
        isStrong: true,
        isLocked: true,
        cards: [
          GameCard(6, CardSuit.razer),
          GameCard(4, CardSuit.redHeart),
          GameCard(10, CardSuit.blackSpade),
        ]);
    state.builds.add(lockedTen);

    engine.construct(state, 'thabo', seven, const [], 10, const [lockedTen],
        const [opponentThree]);

    expect(state.captured['lebo'], isEmpty);
    expect(state.hands['thabo'], equals(const [retainedTen]));
    expect(state.builds.single.target, 10);
    expect(state.builds.single.ownerId, 'thabo');
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
    expect(state.builds.single.cards.map((card) => card.rank),
        equals([6, 4, 10, 7, 3]));
  });

  test('owner continues strong 10 with loose 8 and opponent top 2', () {
    final state = engine.start(challengerId: 'lebo', hostId: 'amina');
    const retainedTen = GameCard(10, CardSuit.tree);
    const looseEight = GameCard(8, CardSuit.blackSpade);
    const opponentTwo = GameCard(2, CardSuit.razer);
    state.hands['lebo']!
      ..clear()
      ..add(retainedTen);
    state.looseTableCards.add(looseEight);
    state.captured['amina']!.add(opponentTwo);
    const strongTen = TableBuild(
        target: 10,
        ownerId: 'lebo',
        isStrong: true,
        isLocked: true,
        cards: [
          GameCard(6, CardSuit.tree),
          GameCard(4, CardSuit.redHeart),
          GameCard(10, CardSuit.blackSpade),
        ]);
    state.builds.add(strongTen);

    expect(engine.hasVisibleBuildContinuation(state, 'lebo', 10), isTrue);
    engine.continueBuild(
        state, 'lebo', strongTen, const [looseEight], const [opponentTwo]);

    expect(state.looseTableCards, isEmpty);
    expect(state.captured['amina'], isEmpty);
    expect(state.builds.single.cards.map((card) => card.rank),
        equals([6, 4, 10, 8, 2]));
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
  });

  test('owner continues build with a private 6 and opponent top 2', () {
    final state = engine.start(challengerId: 'lebo', hostId: 'amina');
    const handSix = GameCard(6, CardSuit.tree);
    const retainedEight = GameCard(8, CardSuit.redHeart);
    const opponentTwo = GameCard(2, CardSuit.razer);
    state.hands['lebo']!
      ..clear()
      ..addAll(const [handSix, retainedEight]);
    state.captured['amina']!.add(opponentTwo);
    const strongEight = TableBuild(
        target: 8,
        ownerId: 'lebo',
        isStrong: true,
        cards: [
          GameCard(5, CardSuit.tree),
          GameCard(3, CardSuit.blackSpade),
          GameCard(8, CardSuit.redHeart),
        ]);
    state.builds.add(strongEight);

    expect(engine.hasVisibleBuildContinuation(state, 'lebo', 8), isTrue);
    engine.continueBuild(state, 'lebo', strongEight, const [],
        const [opponentTwo], handSix);

    expect(state.hands['lebo'], equals(const [retainedEight]));
    expect(state.captured['amina'], isEmpty);
    expect(state.builds.single.cards.map((card) => card.rank),
        equals([5, 3, 8, 6, 2]));
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
  });

  test('owner continues strong 7 with loose 4 and 3', () {
    final state = engine.start(challengerId: 'lebo', hostId: 'amina');
    const retainedSeven = GameCard(7, CardSuit.tree);
    const looseFour = GameCard(4, CardSuit.redHeart);
    const looseThree = GameCard(3, CardSuit.blackSpade);
    state.hands['lebo']!
      ..clear()
      ..add(retainedSeven);
    state.looseTableCards.addAll(const [looseFour, looseThree]);
    const strongSeven = TableBuild(
        target: 7,
        ownerId: 'lebo',
        isStrong: true,
        cards: [
          GameCard(5, CardSuit.razer),
          GameCard(2, CardSuit.redHeart),
          GameCard(7, CardSuit.blackSpade),
        ]);
    state.builds.add(strongSeven);

    engine.continueBuild(
        state, 'lebo', strongSeven, const [looseFour, looseThree]);

    expect(state.looseTableCards, isEmpty);
    expect(state.builds.single.cards.map((card) => card.rank),
        equals([5, 2, 7, 4, 3]));
  });

  test('player cannot own two separate constructed numbers', () {
    final state = engine.start(challengerId: 'lebo', hostId: 'amina');
    const handThree = GameCard(3, CardSuit.tree);
    const retainedFive = GameCard(5, CardSuit.redHeart);
    const looseTwo = GameCard(2, CardSuit.blackSpade);
    state.hands['lebo']!
      ..clear()
      ..addAll(const [handThree, retainedFive]);
    state.looseTableCards.add(looseTwo);
    state.builds.add(const TableBuild(
        target: 7,
        ownerId: 'lebo',
        cards: [
          GameCard(4, CardSuit.razer),
          GameCard(3, CardSuit.redHeart),
        ]));

    expect(
        () => engine.construct(
            state, 'lebo', handThree, const [looseTwo], 5),
        throwsA(isA<GameRuleException>()));
  });

  test('strong 5 may use a loose 5 with hand 3 and opponent top 2', () {
    final state = engine.start(challengerId: 'lebo', hostId: 'amina');
    const handThree = GameCard(3, CardSuit.tree);
    const retainedFive = GameCard(5, CardSuit.redHeart);
    const looseFive = GameCard(5, CardSuit.blackSpade);
    const opponentTwo = GameCard(2, CardSuit.razer);
    state.hands['lebo']!
      ..clear()
      ..addAll(const [handThree, retainedFive]);
    state.looseTableCards.add(looseFive);
    state.captured['amina']!.add(opponentTwo);

    engine.construct(state, 'lebo', handThree, const [looseFive], 5,
        const [], const [opponentTwo]);

    expect(state.hands['lebo'], equals(const [retainedFive]));
    expect(state.looseTableCards, isEmpty);
    expect(state.captured['amina'], isEmpty);
    expect(state.builds.single.target, 5);
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
    expect(state.builds.single.cards.map((card) => card.rank),
        equals([5, 3, 2]));
  });

  test('new construction group is descending regardless of selection source',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const handFour = GameCard(4, CardSuit.tree);
    const retainedNine = GameCard(9, CardSuit.redHeart);
    const tableTwo = GameCard(2, CardSuit.blackSpade);
    const opponentThree = GameCard(3, CardSuit.razer);
    state.hands['a']!
      ..clear()
      ..addAll(const [handFour, retainedNine]);
    state.looseTableCards.add(tableTwo);
    state.captured['b']!.add(opponentThree);
    const existingNine =
        TableBuild(target: 9, ownerId: 'a', isStrong: true, cards: [
      GameCard(6, CardSuit.redHeart),
      GameCard(3, CardSuit.blackSpade),
    ]);
    state.builds.add(existingNine);

    engine.construct(state, 'a', handFour, const [tableTwo], 9,
        const [existingNine], const [opponentThree]);

    expect(state.builds.single.cards.take(2).map((card) => card.rank),
        equals([6, 3]));
    expect(state.builds.single.cards.skip(2).map((card) => card.rank),
        equals([4, 3, 2]));
  });

  test(
      'multiple opponent cards are taken top-first and each needs its own group',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const lowerFour = GameCard(4, CardSuit.tree);
    const topFour = GameCard(4, CardSuit.razer);
    state.captured['b']!.addAll(const [lowerFour, topFour]);
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(4, CardSuit.redHeart),
        GameCard(8, CardSuit.blackSpade),
      ]);
    state.looseTableCards.addAll(const [
      GameCard(8, CardSuit.redHeart),
      GameCard(4, CardSuit.blackSpade),
    ]);
    engine.construct(
        state,
        'a',
        state.hands['a']!.first,
        List.of(state.looseTableCards),
        8,
        const [],
        const [topFour, lowerFour]);
    expect(state.captured['b'], isEmpty);
    expect(state.builds.single.isLocked, isTrue);
    expect(state.builds.single.cards.where((card) => card.rank == 4),
        hasLength(4));
  });

  test('build value cannot exceed ten', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..addAll(
          const [GameCard(6, CardSuit.tree), GameCard(10, CardSuit.redHeart)]);
    state.looseTableCards.add(const GameCard(5, CardSuit.razer));
    expect(
        () => engine.construct(state, 'a', state.hands['a']!.first,
            [state.looseTableCards.first], 11),
        throwsA(predicate((e) => '$e' == 'The maximum build is 10')));
  });

  test('existing loose target card is automatically merged into a strong build',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..addAll(const [
        GameCard(1, CardSuit.tree),
        GameCard(3, CardSuit.redHeart),
      ]);
    state.looseTableCards.addAll(const [
      GameCard(2, CardSuit.blackSpade),
      GameCard(3, CardSuit.razer),
    ]);
    engine.construct(
        state, 'a', state.hands['a']!.first, [state.looseTableCards.first], 3);
    expect(state.looseTableCards, isEmpty);
    expect(state.builds.single.isStrong, isTrue);
    expect(
        state.builds.single.cards.map((card) => card.rank), equals([3, 2, 1]));
  });

  test('matching hand card captures selected build regardless of owner', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..add(const GameCard(6, CardSuit.tree));
    final build = TableBuild(target: 6, ownerId: 'b', cards: const [
      GameCard(4, CardSuit.redHeart),
      GameCard(2, CardSuit.razer),
    ]);
    state.builds.add(build);
    engine.takeOff(state, 'a', state.hands['a']!.single, const [], [build]);
    expect(state.builds, isEmpty);
    expect(state.captured['a'], hasLength(3));
  });

  test('normal play automatically chows matching builds without selecting them',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..add(const GameCard(8, CardSuit.razer));
    state.builds.add(const TableBuild(target: 8, ownerId: 'b', cards: [
      GameCard(6, CardSuit.blackSpade),
      GameCard(2, CardSuit.redHeart),
    ]));
    engine.throwCard(state, 'a', state.hands['a']!.single);
    expect(state.builds, isEmpty);
    expect(state.captured['a']!.map((card) => card.rank), equals([6, 2, 8]));
  });

  test('build owner can drift a matching card when another chow card remains',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const firstTen = GameCard(10, CardSuit.razer);
    const secondTen = GameCard(10, CardSuit.tree);
    state.hands['a']!
      ..clear()
      ..addAll(const [firstTen, secondTen]);
    const build = TableBuild(target: 10, ownerId: 'a', cards: [
      GameCard(7, CardSuit.blackSpade),
      GameCard(3, CardSuit.redHeart),
    ]);
    state.builds.add(build);

    engine.stashBuild(state, 'a', firstTen, build);

    expect(state.hands['a'], equals(const [secondTen]));
    expect(
        state.builds.single.cards.map((card) => card.rank), equals([7, 3, 10]));
    expect(state.builds.single.isStrong, isTrue);
    expect(state.builds.single.isLocked, isTrue);
    expect(state.currentPlayerId, 'b');
  });

  test('drift onto build requires another matching chow card', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const ten = GameCard(10, CardSuit.razer);
    state.hands['a']!
      ..clear()
      ..add(ten);
    const build = TableBuild(target: 10, ownerId: 'a', cards: [
      GameCard(7, CardSuit.blackSpade),
      GameCard(3, CardSuit.redHeart),
    ]);
    state.builds.add(build);

    expect(
        () => engine.stashBuild(state, 'a', ten, build),
        throwsA(predicate(
            (e) => '$e' == 'Another matching card is required to stash')));
  });

  test('opponent can chow a build made strong by a matching drift', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const ownerTen = GameCard(10, CardSuit.razer);
    const retainedTen = GameCard(10, CardSuit.tree);
    const opponentTen = GameCard(10, CardSuit.redHeart);
    state.hands['a']!
      ..clear()
      ..addAll(const [ownerTen, retainedTen]);
    state.hands['b']!
      ..clear()
      ..add(opponentTen);
    const build = TableBuild(target: 10, ownerId: 'a', cards: [
      GameCard(6, CardSuit.blackSpade),
      GameCard(4, CardSuit.tree),
    ]);
    state.builds.add(build);

    engine.stashBuild(state, 'a', ownerTen, build);
    engine.throwCard(state, 'b', opponentTen);

    expect(state.builds, isEmpty);
    expect(
        state.captured['b']!.map((card) => card.rank), equals([10, 6, 4, 10]));
  });

  test('one card captures multiple selected sets of the same value', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..add(const GameCard(6, CardSuit.tree));
    state.looseTableCards.addAll(const [
      GameCard(6, CardSuit.redHeart),
      GameCard(4, CardSuit.razer),
      GameCard(2, CardSuit.blackSpade),
    ]);
    engine.takeOff(
        state, 'a', state.hands['a']!.single, List.of(state.looseTableCards));
    expect(state.captured['a'], hasLength(4));
  });

  test('later chow packets are appended without rearranging earlier packets',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    const firstNine = GameCard(9, CardSuit.tree);
    const secondNine = GameCard(9, CardSuit.redHeart);
    const six = GameCard(6, CardSuit.blackSpade);
    const three = GameCard(3, CardSuit.razer);
    const five = GameCard(5, CardSuit.tree);
    const four = GameCard(4, CardSuit.redHeart);
    state.hands['a']!
      ..clear()
      ..addAll(const [firstNine, secondNine]);

    state.looseTableCards.addAll(const [six, three]);
    engine.takeOff(state, 'a', firstNine, const [six, three]);
    expect(state.captured['a']!.map((card) => card.rank), equals([6, 3, 9]));

    state.currentPlayerId = 'a';
    state.looseTableCards.addAll(const [five, four]);
    engine.takeOff(state, 'a', secondNine, const [five, four]);

    expect(state.captured['a']!.map((card) => card.rank),
        equals([6, 3, 9, 5, 4, 9]));
  });

  test('packet-preserving chow order applies to every rank Ace through 10', () {
    for (var target = 1; target <= 10; target++) {
      final state = engine.start(challengerId: 'a', hostId: 'b');
      final firstTakingCard = GameCard(target, CardSuit.tree);
      final secondTakingCard = GameCard(target, CardSuit.redHeart);
      state.hands['a']!
        ..clear()
        ..addAll([firstTakingCard, secondTakingCard]);

      final firstPacket = target == 1
          ? const [GameCard(1, CardSuit.blackSpade)]
          : [
              GameCard(target - 1, CardSuit.blackSpade),
              const GameCard(1, CardSuit.razer),
            ];
      state.looseTableCards.addAll(firstPacket);
      engine.takeOff(state, 'a', firstTakingCard, firstPacket);
      final preservedFirstPacket = List<GameCard>.of(state.captured['a']!);

      state.currentPlayerId = 'a';
      final secondPacket = target == 1
          ? const [GameCard(1, CardSuit.razer)]
          : [
              GameCard(target - 1, CardSuit.razer),
              const GameCard(1, CardSuit.blackSpade),
            ];
      state.looseTableCards.addAll(secondPacket);
      engine.takeOff(state, 'a', secondTakingCard, secondPacket);

      expect(state.captured['a']!.take(preservedFirstPacket.length),
          orderedEquals(preservedFirstPacket),
          reason: 'Earlier packet changed when chowing rank $target');
      expect(state.captured['a']!.last, secondTakingCard,
          reason: 'Taking rank $target must top its newest packet');
    }
  });

  test('chow also takes every consecutive matching opponent top card', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.hands['a']!
      ..clear()
      ..add(const GameCard(7, CardSuit.tree));
    state.looseTableCards.addAll(const [
      GameCard(6, CardSuit.blackSpade),
      GameCard(1, CardSuit.razer),
    ]);
    state.captured['b']!.addAll(const [
      GameCard(3, CardSuit.tree),
      GameCard(7, CardSuit.redHeart),
      GameCard(7, CardSuit.razer),
    ]);
    engine.takeOff(
        state, 'a', state.hands['a']!.single, List.of(state.looseTableCards));
    expect(state.captured['b']!.single.rank, 3);
    expect(state.captured['a'], hasLength(5));
    expect(state.captured['a']!.last.rank, 7);
  });

  test('owner cannot drift while their build remains in round one', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.builds.add(const TableBuild(target: 5, ownerId: 'a', cards: [
      GameCard(3, CardSuit.tree),
      GameCard(2, CardSuit.razer),
    ]));
    expect(
        () => engine.throwCard(state, 'a', state.hands['a']!.first),
        throwsA(predicate(
            (e) => '$e' == 'Capture your build before drifting in round 1')));
  });

  test('last capturer receives all table leftovers at game end', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    state.phase = GamePhase.roundTwo;
    state.drawPile.clear();
    final finalCard = state.hands['a']!.first;
    state.hands['a']!
      ..clear()
      ..add(finalCard);
    state.hands['b']!.clear();
    state.lastPlayedCard = null;
    state.lastRoundWinnerId = 'b';
    final leftoverRank = finalCard.rank == 10 ? 1 : finalCard.rank + 1;
    state.looseTableCards.add(GameCard(leftoverRank, CardSuit.tree));
    engine.throwCard(state, 'a', finalCard);
    expect(state.phase, GamePhase.finished);
    expect(state.looseTableCards, isEmpty);
    expect(state.captured['b']!.map((c) => c.rank),
        containsAll([leftoverRank, finalCard.rank]));
  });

  test('round two deals remaining cards and winner/host plays second', () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final lastA = state.hands['a']!.first;
    state.hands['a']!
      ..clear()
      ..add(lastA);
    state.hands['b']!.clear();
    state.lastRoundWinnerId = 'b';
    engine.throwCard(state, 'a', lastA);
    expect(state.phase, GamePhase.roundTwo);
    expect(state.hands['a'], hasLength(10));
    expect(state.hands['b'], hasLength(10));
    expect(state.currentPlayerId, 'a');
  });

  test('round one opening player starts round two even after winning round one',
      () {
    final state = engine.start(challengerId: 'a', hostId: 'b');
    final lastA = state.hands['a']!.first;
    state.hands['a']!
      ..clear()
      ..add(lastA);
    state.hands['b']!.clear();
    state.lastRoundWinnerId = 'a';

    engine.throwCard(state, 'a', lastA);

    expect(state.phase, GamePhase.roundTwo);
    expect(state.currentPlayerId, 'a');
  });
}
