import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseInviteStatus', () {
    expect(parseInviteStatus('pending'), InviteStatus.pending);
    expect(parseInviteStatus('accepted'), InviteStatus.accepted);
    expect(parseInviteStatus('declined'), InviteStatus.declined);
    expect(parseInviteStatus('other'), isNull);
  });

  test('only pending can accept or decline', () {
    expect(
      canTransitionInvite(InviteStatus.pending, InviteStatus.accepted),
      isTrue,
    );
    expect(
      canTransitionInvite(InviteStatus.pending, InviteStatus.declined),
      isTrue,
    );
    expect(
      canTransitionInvite(InviteStatus.accepted, InviteStatus.declined),
      isFalse,
    );
    expect(
      canTransitionInvite(InviteStatus.declined, InviteStatus.accepted),
      isFalse,
    );
  });

  test('lookup email is trimmed and lowercased', () {
    expect(normalizeInviteEmailForLookup('  Foo@Bar.COM '), 'foo@bar.com');
  });
}
