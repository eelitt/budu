import 'package:budu/features/budget/domain/chatbot_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly unchanged', () {
    expect(scaleChatbotAmount(value: 120), 120);
  });

  test('biweekly halves', () {
    expect(scaleChatbotAmount(value: 120, isBiweekly: true), 60);
  });

  test('yearly /12', () {
    expect(scaleChatbotAmount(value: 120, isYearly: true), 10);
  });

  test('biweekly then yearly matches processor ( /2 then /12 )', () {
    expect(
      scaleChatbotAmount(value: 120, isBiweekly: true, isYearly: true),
      5,
    );
  });
}
