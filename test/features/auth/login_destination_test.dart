import 'package:budu/features/auth/domain/login_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no personal and no shared budgets -> chatbot', () {
    expect(
      decideLoginDestination(
        hasPersonalBudgets: false,
        hasSharedBudgets: false,
      ),
      LoginDestination.chatbot,
    );
  });

  test('shared only -> mainShared', () {
    expect(
      decideLoginDestination(
        hasPersonalBudgets: false,
        hasSharedBudgets: true,
      ),
      LoginDestination.mainShared,
    );
  });

  test('personal only -> mainPersonal', () {
    expect(
      decideLoginDestination(
        hasPersonalBudgets: true,
        hasSharedBudgets: false,
      ),
      LoginDestination.mainPersonal,
    );
  });

  test('personal and shared -> mainPersonal', () {
    expect(
      decideLoginDestination(
        hasPersonalBudgets: true,
        hasSharedBudgets: true,
      ),
      LoginDestination.mainPersonal,
    );
  });
}
