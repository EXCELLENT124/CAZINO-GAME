import 'package:cazino/app/app_controller.dart';
import 'package:cazino/data/repositories.dart';
import 'package:test/test.dart';

void main() {
  test('computer makes one legal move and returns control to the human',
      () async {
    final repository = LocalDemoRepository();
    await repository.login('lebo_mokoena', 'password');
    final controller = AppController(repository)..startComputerGame();
    final humanId = repository.currentUser!.id;
    final computerHandBefore =
        controller.game!.hands[AppController.computerPlayerId]!.length;

    controller.throwCard(controller.game!.hands[humanId]!.first);
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(controller.game!.currentPlayerId, humanId);
    expect(controller.game!.hands[AppController.computerPlayerId]!.length,
        computerHandBefore - 1);
  });
}
