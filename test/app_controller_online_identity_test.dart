import 'package:cazino/app/app_controller.dart';
import 'package:cazino/data/repositories.dart';
import 'package:test/test.dart';

class _SignedInDemoRepository extends LocalDemoRepository {
  Future<void> signIn() => login('lebo_mokoena', 'password');
}

void main() {
  test('online match screen identity never follows the current turn', () async {
    final repository = _SignedInDemoRepository();
    await repository.signIn();
    final controller = AppController(repository);
    final me = repository.currentUser!.id;

    // Simulate an opened online match and a turn belonging to the opponent.
    controller.onlineGameId = 'online-game';
    controller.demoActivePlayerId = 'opponent';

    expect(controller.gamePlayerId, me);
  });
}
