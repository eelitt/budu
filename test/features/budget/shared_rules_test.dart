import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:budu/features/budget/models/invitation_model.dart';
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

  test('invitation toMap writes normalized email', () {
    final invite = Invitation(
      id: 'i1',
      sharedBudgetId: 's1',
      inviterId: 'u1',
      inviteeEmail: '  Foo@Bar.COM ',
      status: 'pending',
      createdAt: DateTime(2025, 1, 1),
    );
    expect(invite.toMap()['inviteeEmail'], 'foo@bar.com');
  });

  test('householdUsersForNewPeriod always includes creator and copies others', () {
    expect(
      householdUsersForNewPeriod(creatorId: 'a', previousUsers: null),
      ['a'],
    );
    expect(
      householdUsersForNewPeriod(
        creatorId: 'a',
        previousUsers: ['b', 'a', 'c'],
      ),
      containsAll(['a', 'b', 'c']),
    );
  });

  test('validateInvite rejects empty, self, missing user, member, duplicate', () {
    expect(
      validateInvite(
        inviteeEmail: '  ',
        inviterEmail: 'me@x.fi',
        inviteeUid: 'u2',
        memberUids: ['u1'],
        pendingEmails: const [],
      ),
      InviteValidation.emptyEmail,
    );
    expect(
      validateInvite(
        inviteeEmail: ' Me@X.FI ',
        inviterEmail: 'me@x.fi',
        inviteeUid: 'u1',
        memberUids: const [],
        pendingEmails: const [],
      ),
      InviteValidation.self,
    );
    expect(
      validateInvite(
        inviteeEmail: 'you@x.fi',
        inviterEmail: 'me@x.fi',
        inviteeUid: null,
        memberUids: const [],
        pendingEmails: const [],
      ),
      InviteValidation.userNotFound,
    );
    expect(
      validateInvite(
        inviteeEmail: 'you@x.fi',
        inviterEmail: 'me@x.fi',
        inviteeUid: 'u2',
        memberUids: ['u2'],
        pendingEmails: const [],
      ),
      InviteValidation.alreadyMember,
    );
    expect(
      validateInvite(
        inviteeEmail: 'you@x.fi',
        inviterEmail: 'me@x.fi',
        inviteeUid: 'u2',
        memberUids: ['u1'],
        pendingEmails: ['  YOU@x.fi '],
      ),
      InviteValidation.duplicatePending,
    );
    expect(
      validateInvite(
        inviteeEmail: 'you@x.fi',
        inviterEmail: 'me@x.fi',
        inviteeUid: 'u2',
        memberUids: ['u1'],
        pendingEmails: const [],
      ),
      InviteValidation.ok,
    );
  });
}
