import 'dart:math';
import '../models/game_card.dart';
import 'game_state.dart';

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random.secure();
  final Random _random;

  List<GameCard> createDeck() => [
        for (final suit in CardSuit.values)
          for (var rank = 1; rank <= 10; rank++) GameCard(rank, suit),
      ];

  GameState start({required String challengerId, required String hostId}) {
    final deck = createDeck()..shuffle(_random);
    return GameState(
      players: [challengerId, hostId],
      challengerId: challengerId,
      hostId: hostId,
      hands: {challengerId: deck.sublist(0, 10), hostId: deck.sublist(10, 20)},
      drawPile: deck.sublist(20),
      currentPlayerId: challengerId,
    );
  }

  PlayerGameView viewFor(GameState state, String playerId) => PlayerGameView(
        hand: List.unmodifiable(state.hands[playerId]!),
        tableCards: List.unmodifiable(state.looseTableCards),
        builds: List.unmodifiable(state.builds),
        capturedCounts: {
          for (final e in state.captured.entries) e.key: e.value.length
        },
        capturedTopCards: {
          for (final e in state.captured.entries)
            e.key: e.value.isEmpty ? null : e.value.last
        },
        capturedPacks: {
          for (final e in state.captured.entries)
            e.key: List.unmodifiable(e.value)
        },
        currentPlayerId: state.currentPlayerId,
        phase: state.phase,
      );

  void throwCard(GameState state, String playerId, GameCard card) {
    _validateTurnAndCard(state, playerId, card);
    final matchingLooseCards = state.looseTableCards
        .where((tableCard) => tableCard.rank == card.rank)
        .toList();
    final matchingBuilds =
        state.builds.where((build) => build.target == card.rank).toList();
    if (matchingLooseCards.isNotEmpty || matchingBuilds.isNotEmpty) {
      // A normal play defaults to chow every directly matching single and
      // every build of this value, regardless of build ownership.
      takeOff(state, playerId, card, matchingLooseCards, matchingBuilds);
      return;
    }
    if (state.phase == GamePhase.roundOne &&
        state.builds.any((build) => build.ownerId == playerId)) {
      throw const GameRuleException(
          'Capture your build before drifting in round 1');
    }
    state.hands[playerId]!.remove(card);
    state.looseTableCards.add(card);
    state.lastPlayedCard = card;
    _endTurn(state, playerId);
  }

  void takeOff(GameState state, String playerId, GameCard handCard,
      [List<GameCard> selectedVisibleCards = const [],
      List<TableBuild> selectedBuilds = const []]) {
    _validateTurnAndCard(state, playerId, handCard);
    final matches = selectedVisibleCards.isEmpty
        ? state.looseTableCards.where((c) => c.rank == handCard.rank).toList()
        : List<GameCard>.from(selectedVisibleCards);
    final selectionIsVisible =
        matches.isNotEmpty && matches.every(state.looseTableCards.contains);
    final buildsAreCapturable = selectedBuilds.isNotEmpty &&
        selectedBuilds.every((build) =>
            state.builds.contains(build) && build.target == handCard.rank);
    if ((!selectionIsVisible && !buildsAreCapturable) ||
        (matches.isNotEmpty &&
            !_canPartitionIntoTargetGroups(matches, handCard.rank)) ||
        (selectedBuilds.isNotEmpty && !buildsAreCapturable)) {
      throw const GameRuleException(
          'Selected table cards do not match the taking-off card');
    }
    state.hands[playerId]!.remove(handCard);
    for (final card in matches) {
      state.looseTableCards.remove(card);
    }
    final buildCards = <GameCard>[
      for (final build in selectedBuilds) ...build.cards
    ];
    state.builds.removeWhere(selectedBuilds.contains);
    final opponentPack = state.captured[state.opponentOf(playerId)]!;
    final matchingOpponentTopCards = <GameCard>[];
    while (opponentPack.isNotEmpty && opponentPack.last.rank == handCard.rank) {
      matchingOpponentTopCards.add(opponentPack.removeLast());
    }
    // Captured cards go underneath; the card just played remains face-up on top.
    final capturedCards = [
      ...matches,
      ...buildCards,
      ...matchingOpponentTopCards
    ]..sort((a, b) => b.rank.compareTo(a.rank));
    state.captured[playerId]!.addAll([...capturedCards, handCard]);
    state.lastRoundWinnerId = playerId;
    _endTurn(state, playerId);
  }

  void construct(GameState state, String playerId, GameCard handCard,
      List<GameCard> selectedVisibleCards, int target,
      [List<TableBuild> selectedBuilds = const [],
      List<GameCard> opponentTopCards = const []]) {
    _validateTurnAndCard(state, playerId, handCard);
    if (target > 10) throw const GameRuleException('The maximum build is 10');
    if (selectedBuilds.length > 1) {
      throw const GameRuleException(
          'Two builds cannot be combined into a higher build');
    }
    final buildsAreVisible = selectedBuilds.every(state.builds.contains);
    final opponentId = state.opponentOf(playerId);
    final opponentPack = state.captured[opponentId]!;
    final opponentTopIsValid = opponentTopCards.length <= opponentPack.length &&
        opponentTopCards.asMap().entries.every((entry) =>
            opponentPack[opponentPack.length - 1 - entry.key] == entry.value);
    if (!opponentTopIsValid) {
      throw const GameRuleException(
          'Only the current top opponent card can be used');
    }
    final effectiveOpponentCards = <GameCard>[...opponentTopCards];
    var opponentCursor =
        opponentPack.length - 1 - effectiveOpponentCards.length;
    while (opponentCursor >= 0 && opponentPack[opponentCursor].rank == target) {
      effectiveOpponentCards.add(opponentPack[opponentCursor]);
      opponentCursor--;
    }
    final strongAnchor = selectedVisibleCards.cast<GameCard?>().firstWhere(
          (anchor) =>
              anchor != null &&
              anchor.rank == target &&
              _canFormBuildGroups([
                handCard,
                ...selectedVisibleCards.where((card) => card != anchor)
              ], effectiveOpponentCards, anchor.rank),
          orElse: () => null,
        );
    final opponentTargetAnchor =
        effectiveOpponentCards.any((card) => card.rank == target);
    final createsCompound = (strongAnchor != null || opponentTargetAnchor) &&
        selectedBuilds.isEmpty;
    final selectedBuild = selectedBuilds.isEmpty ? null : selectedBuilds.single;
    final ownsAnotherBuild = state.builds.any((build) =>
        build.ownerId == playerId && !selectedBuilds.contains(build));
    if (ownsAnotherBuild) {
      throw const GameRuleException(
          'Complete or capture your existing build before starting another');
    }
    if (selectedBuild != null &&
        selectedBuild.ownerId == playerId &&
        !selectedBuild.isStrong &&
        target != selectedBuild.target) {
      throw const GameRuleException(
          'Only the opponent may edit this constructed number');
    }
    final addedValue = handCard.rank +
        selectedVisibleCards.fold<int>(0, (sum, card) => sum + card.rank) +
        effectiveOpponentCards.fold<int>(0, (sum, card) => sum + card.rank);
    final augmentingOwnBuild = selectedBuild != null &&
        selectedBuild.ownerId == playerId &&
        _canFormBuildGroups([handCard, ...selectedVisibleCards],
            effectiveOpponentCards, selectedBuild.target);
    final opponentBuildSelected =
        selectedBuild != null && selectedBuild.ownerId != playerId;
    final upgradingSimpleBuild = selectedBuild != null &&
        !selectedBuild.isStrong &&
        !selectedBuild.isLocked &&
        !augmentingOwnBuild;
    final upgradeAddedValue = handCard.rank +
        selectedVisibleCards
            .where((card) => card.rank != target)
            .fold<int>(0, (sum, card) => sum + card.rank) +
        effectiveOpponentCards.fold<int>(0, (sum, card) => sum + card.rank);
    final calculatedTarget = createsCompound
        ? target
        : augmentingOwnBuild
            ? selectedBuild.target
            : upgradingSimpleBuild
                ? selectedBuild.target + upgradeAddedValue
                : addedValue;
    final retainsTarget = state.hands[playerId]!
        .any((card) => card != handCard && card.rank == target);
    final validBuildAction =
        selectedBuild == null || augmentingOwnBuild || upgradingSimpleBuild;
    final duplicateTarget = state.builds.any(
        (build) => !selectedBuilds.contains(build) && build.target == target);
    if ((selectedVisibleCards.isEmpty && selectedBuilds.isEmpty) ||
        selectedVisibleCards.any((c) => !state.looseTableCards.contains(c)) ||
        !buildsAreVisible ||
        !validBuildAction ||
        duplicateTarget ||
        calculatedTarget != target ||
        !retainsTarget) {
      if (opponentBuildSelected && !upgradingSimpleBuild) {
        throw const GameRuleException(
            'Unable to construct a number: number is strong');
      }
      if (selectedBuild?.isLocked == true && !augmentingOwnBuild) {
        throw const GameRuleException(
            'Unable to construct a number: number is locked strong');
      }
      if (selectedBuild?.isStrong == true && !augmentingOwnBuild) {
        throw const GameRuleException(
            'Unable to construct a number: number is strong');
      }
      throw const GameRuleException('Card in construct not available');
    }
    final included = <GameCard>[...selectedVisibleCards];
    var automaticallyStrengthened = selectedBuild != null &&
        included.any((tableCard) => tableCard.rank == target);
    for (final tableCard in state.looseTableCards) {
      if (!included.contains(tableCard) && tableCard.rank == target) {
        included.add(tableCard);
        automaticallyStrengthened = true;
      }
    }
    state.hands[playerId]!.remove(handCard);
    for (var i = 0; i < effectiveOpponentCards.length; i++) {
      opponentPack.removeLast();
    }
    state.looseTableCards.removeWhere(included.contains);
    final previousBuildCards = <GameCard>[
      for (final build in selectedBuilds) ...build.cards,
    ];
    state.builds.removeWhere(selectedBuilds.contains);
    final thrownBaseCards =
        included.where((card) => card.rank == target).toList();
    final opponentTargetCards =
        effectiveOpponentCards.where((card) => card.rank == target).toList();
    final constructingCards = <GameCard>[
      handCard,
      ...included.where((card) => card.rank != target),
      ...effectiveOpponentCards.where((card) => card.rank != target),
    ]..sort((a, b) => b.rank.compareTo(a.rank));
    final buildCards = selectedBuild == null
        ? <GameCard>[
            ...thrownBaseCards,
            ...constructingCards,
            ...opponentTargetCards,
          ]
        : <GameCard>[
            ...previousBuildCards,
            ...thrownBaseCards,
            ...constructingCards,
            ...opponentTargetCards,
          ];
    state.builds.add(TableBuild(
        target: target,
        cards: buildCards,
        ownerId: playerId,
        isStrong:
            createsCompound || automaticallyStrengthened || augmentingOwnBuild,
        isLocked: selectedBuild?.isLocked == true ||
            effectiveOpponentCards.isNotEmpty));
    state.lastPlayedCard = handCard;
    _endTurn(state, playerId);
  }

  void stashBuild(
      GameState state, String playerId, GameCard handCard, TableBuild build) {
    _validateTurnAndCard(state, playerId, handCard);
    if (!state.builds.contains(build) ||
        build.ownerId != playerId ||
        build.target != handCard.rank) {
      throw const GameRuleException(
          'Only the owner can stash a matching card on their build');
    }
    if (build.isLocked) {
      throw const GameRuleException(
          'Unable to construct a number: number is locked strong');
    }
    final retainsAnotherChowCard = state.hands[playerId]!
        .any((card) => card != handCard && card.rank == build.target);
    if (!retainsAnotherChowCard) {
      throw const GameRuleException(
          'Another matching card is required to stash');
    }
    state.hands[playerId]!.remove(handCard);
    state.builds.remove(build);
    state.builds.add(TableBuild(
        target: build.target,
        cards: [...build.cards, handCard],
        ownerId: playerId,
        isStrong: true,
        isLocked: true));
    state.lastPlayedCard = handCard;
    _endTurn(state, playerId);
  }

  bool hasVisibleBuildContinuation(
      GameState state, String playerId, int target) {
    if (!state.builds.any(
            (build) => build.ownerId == playerId && build.target == target) ||
        !state.hands[playerId]!.any((card) => card.rank == target)) {
      return false;
    }
    final hand = state.hands[playerId]!;
    final opponentPack = state.captured[state.opponentOf(playerId)]!;
    for (final handCard in <GameCard?>[null, ...hand]) {
      if (handCard != null &&
          !hand.any((card) => card != handCard && card.rank == target)) {
        continue;
      }
      final handTotal = handCard?.rank ?? 0;
      for (var topCount = 0; topCount <= opponentPack.length; topCount++) {
        final topCards = topCount == 0
            ? <GameCard>[]
            : opponentPack.sublist(opponentPack.length - topCount);
        final topTotal = topCards.fold<int>(0, (sum, card) => sum + card.rank);
        final remainder = target - handTotal - topTotal;
        if (remainder < 0) break;
        if (_hasSubsetTotal(state.looseTableCards, remainder) &&
            (handCard != null || topCards.isNotEmpty || remainder > 0)) {
          return true;
        }
      }
    }
    return false;
  }

  void continueBuild(GameState state, String playerId, TableBuild build,
      List<GameCard> selectedVisibleCards,
      [List<GameCard> opponentTopCards = const [], GameCard? handCard]) {
    if (state.phase == GamePhase.finished) {
      throw const GameRuleException('Game has ended');
    }
    if (state.currentPlayerId != playerId) {
      throw const GameRuleException('Not your turn');
    }
    if (!state.builds.contains(build) || build.ownerId != playerId) {
      throw const GameRuleException('Only the build owner may continue it');
    }
    if (handCard != null && !state.hands[playerId]!.contains(handCard)) {
      throw const GameRuleException('Card is not in your hand');
    }
    if (!state.hands[playerId]!
        .any((card) => card != handCard && card.rank == build.target)) {
      throw const GameRuleException('Card in construct not available');
    }
    if (selectedVisibleCards
        .any((card) => !state.looseTableCards.contains(card))) {
      throw const GameRuleException(
          'Selected construction cards are not visible');
    }
    final opponentPack = state.captured[state.opponentOf(playerId)]!;
    final validTopSelection = opponentTopCards.length <= opponentPack.length &&
        opponentTopCards.asMap().entries.every((entry) =>
            opponentPack[opponentPack.length - 1 - entry.key] == entry.value);
    final cards = <GameCard>[
      if (handCard != null) handCard,
      ...selectedVisibleCards,
      ...opponentTopCards
    ];
    if (!validTopSelection ||
        cards.isEmpty ||
        cards.fold<int>(0, (sum, card) => sum + card.rank) != build.target) {
      throw const GameRuleException(
          'Selected cards do not complete the constructed number');
    }
    for (final card in selectedVisibleCards) {
      state.looseTableCards.remove(card);
    }
    if (handCard != null) state.hands[playerId]!.remove(handCard);
    for (var i = 0; i < opponentTopCards.length; i++) {
      opponentPack.removeLast();
    }
    cards.sort((a, b) => b.rank.compareTo(a.rank));
    state.builds.remove(build);
    state.builds.add(TableBuild(
        target: build.target,
        cards: [...build.cards, ...cards],
        ownerId: playerId,
        isStrong: true,
        isLocked: build.isLocked || opponentTopCards.isNotEmpty));
    if (handCard != null) state.lastPlayedCard = handCard;
  }

  bool _hasSubsetTotal(List<GameCard> cards, int target) {
    if (target == 0) return true;
    bool find(int index, int total) {
      if (total == target) return true;
      if (total > target) return false;
      for (var i = index; i < cards.length; i++) {
        if (find(i + 1, total + cards[i].rank)) return true;
      }
      return false;
    }

    return find(0, 0);
  }

  void _validateTurnAndCard(GameState state, String playerId, GameCard card) {
    if (state.phase == GamePhase.finished)
      throw const GameRuleException('Game has ended');
    if (state.currentPlayerId != playerId)
      throw const GameRuleException('Not your turn');
    if (!state.hands[playerId]!.contains(card))
      throw const GameRuleException('Card is not in your hand');
  }

  void _endTurn(GameState state, String playerId) {
    state.currentPlayerId = state.opponentOf(playerId);
    if (state.hands.values.every((hand) => hand.isEmpty))
      _transitionRound(state);
  }

  void _transitionRound(GameState state) {
    if (state.phase == GamePhase.roundOne) {
      for (final id in state.players) {
        state.hands[id]!.addAll(state.drawPile.take(10));
        state.drawPile.removeRange(0, 10);
      }
      state.phase = GamePhase.roundTwo;
      // The player who opened round one also opens round two.
      state.currentPlayerId = state.challengerId;
    } else {
      final lastCapturer = state.lastRoundWinnerId;
      if (lastCapturer != null) {
        final leftovers = <GameCard>[
          ...state.looseTableCards,
          for (final build in state.builds) ...build.cards,
        ];
        state.captured[lastCapturer]!.addAll(leftovers);
        state.looseTableCards.clear();
        state.builds.clear();
      }
      state.phase = GamePhase.finished;
    }
  }

  bool _canPartitionIntoTargetGroups(List<GameCard> cards, int target) {
    if (cards.isEmpty ||
        cards.fold<int>(0, (sum, c) => sum + c.rank) % target != 0)
      return false;
    bool solve(List<int> values) {
      if (values.isEmpty) return true;
      final first = values.first;
      bool findSubset(int index, int sum, List<int> picked) {
        if (sum == target) {
          final remaining = List<int>.from(values);
          for (final pickedIndex in picked.reversed) {
            remaining.removeAt(pickedIndex);
          }
          return solve(remaining);
        }
        if (sum > target) return false;
        for (var i = index; i < values.length; i++) {
          if (findSubset(i + 1, sum + values[i], [...picked, i])) return true;
        }
        return false;
      }

      return findSubset(1, first, [0]);
    }

    return solve(
        cards.map((c) => c.rank).toList()..sort((a, b) => b.compareTo(a)));
  }

  bool _canFormBuildGroups(
      List<GameCard> ownCards, List<GameCard> opponentCards, int target) {
    final tagged = <({int value, bool opponent})>[
      for (final card in ownCards) (value: card.rank, opponent: false),
      for (final card in opponentCards) (value: card.rank, opponent: true),
    ];
    final total = tagged.fold<int>(0, (sum, item) => sum + item.value);
    if (tagged.isEmpty || total % target != 0) return false;
    bool solve(List<({int value, bool opponent})> remaining) {
      if (remaining.isEmpty) return true;
      final first = remaining.first;
      bool subset(int index, int sum, int opponentCount, List<int> picked) {
        if (sum == target) {
          final opponentTargetAlone = picked.length == 1 &&
              remaining[picked.single].opponent &&
              remaining[picked.single].value == target;
          if (opponentCount > 1 ||
              (opponentCount == 1 &&
                  picked.every((i) => remaining[i].opponent) &&
                  !opponentTargetAlone)) {
            return false;
          }
          final next = List<({int value, bool opponent})>.from(remaining);
          for (final i in picked.reversed) next.removeAt(i);
          return solve(next);
        }
        if (sum > target || opponentCount > 1) return false;
        for (var i = index; i < remaining.length; i++) {
          final item = remaining[i];
          if (subset(
              i + 1,
              sum + item.value,
              opponentCount + (item.opponent ? 1 : 0),
              [...picked, i])) return true;
        }
        return false;
      }

      return subset(1, first.value, first.opponent ? 1 : 0, [0]);
    }

    return solve(tagged);
  }
}
