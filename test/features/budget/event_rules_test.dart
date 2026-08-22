import 'package:budu/features/budget/domain/event_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? validate({
    bool isExpense = true,
    String amountText = '10',
    String description = '',
    String? category = 'Ruoka',
    String? subcategory = 'Ruokakauppa',
    bool isLoggedIn = true,
    List<String> subs = const ['Ruokakauppa'],
  }) {
    return validateEvent(
      isExpense: isExpense,
      amountText: amountText,
      description: description,
      selectedCategory: category,
      selectedSubcategory: subcategory,
      isLoggedIn: isLoggedIn,
      subcategoryNamesForSelectedCategory: subs,
    );
  }

  test('valid expense', () => expect(validate(), isNull));

  test('non-number', () => expect(validate(amountText: 'abc'), isNotNull));
  test('empty amount', () => expect(validate(amountText: ''), isNotNull));
  test('negative', () => expect(validate(amountText: '-1'), isNotNull));
  test('zero allowed', () => expect(validate(amountText: '0'), isNull));
  test('99999 ok', () => expect(validate(amountText: '99999'), isNull));
  test('100000 rejected', () => expect(validate(amountText: '100000'), isNotNull));

  test('income skips category', () {
    expect(
      validate(isExpense: false, category: null, subcategory: null, subs: []),
      isNull,
    );
  });

  test('expense needs category', () {
    expect(validate(category: null), isNotNull);
  });

  test('subcategory required only if list non-empty', () {
    expect(validate(subcategory: null, subs: ['A']), isNotNull);
    expect(validate(subcategory: null, subs: []), isNull);
  });

  test('description 50 ok, 51 not', () {
    expect(validate(description: 'a' * 50), isNull);
    expect(
      validate(description: 'a' * 51),
      'Kuvaus voi olla enintään 50 merkkiä',
    );
    expect(
      eventValidationField('Kuvaus voi olla enintään 50 merkkiä'),
      EventValidationField.description,
    );
    expect(
      eventValidationField('Kuvaus voi olla enintään 75 merkkiä'),
      isNull,
    );
  });

  test('not logged in', () {
    expect(validate(isLoggedIn: false), 'Käyttäjä ei ole kirjautunut');
  });
}
