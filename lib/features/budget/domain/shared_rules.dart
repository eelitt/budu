enum InviteStatus { pending, accepted, declined }

enum InviteValidation {
  ok,
  emptyEmail,
  self,
  userNotFound,
  alreadyMember,
  duplicatePending,
}

InviteStatus? parseInviteStatus(String status) {
  switch (status) {
    case 'pending':
      return InviteStatus.pending;
    case 'accepted':
      return InviteStatus.accepted;
    case 'declined':
      return InviteStatus.declined;
    default:
      return null;
  }
}

bool canTransitionInvite(InviteStatus from, InviteStatus to) {
  return from == InviteStatus.pending &&
      (to == InviteStatus.accepted || to == InviteStatus.declined);
}

String normalizeInviteEmailForLookup(String email) =>
    email.trim().toLowerCase();

/// Creator plus anyone already on the previous household period. No cap.
List<String> householdUsersForNewPeriod({
  required String creatorId,
  List<String>? previousUsers,
}) {
  final users = <String>{creatorId};
  if (previousUsers != null) {
    users.addAll(previousUsers.where((id) => id.isNotEmpty));
  }
  return users.toList();
}

InviteValidation validateInvite({
  required String inviteeEmail,
  required String inviterEmail,
  required String? inviteeUid,
  required List<String> memberUids,
  required Iterable<String> pendingEmails,
}) {
  final email = normalizeInviteEmailForLookup(inviteeEmail);
  if (email.isEmpty) return InviteValidation.emptyEmail;
  if (email == normalizeInviteEmailForLookup(inviterEmail)) {
    return InviteValidation.self;
  }
  if (inviteeUid == null || inviteeUid.isEmpty) {
    return InviteValidation.userNotFound;
  }
  if (memberUids.contains(inviteeUid)) return InviteValidation.alreadyMember;
  final pending = pendingEmails.map(normalizeInviteEmailForLookup).toSet();
  if (pending.contains(email)) return InviteValidation.duplicatePending;
  return InviteValidation.ok;
}

String inviteValidationMessage(InviteValidation result) {
  switch (result) {
    case InviteValidation.emptyEmail:
      return 'Syötä kutsuttavan sähköposti';
    case InviteValidation.self:
      return 'Et voi kutsua itseäsi';
    case InviteValidation.userNotFound:
      return 'Sähköpostiosoitetta ei löydy sovelluksen käyttäjistä';
    case InviteValidation.alreadyMember:
      return 'Käyttäjä on jo budjetissa';
    case InviteValidation.duplicatePending:
      return 'Kutsu on jo lähetetty';
    case InviteValidation.ok:
      return '';
  }
}
