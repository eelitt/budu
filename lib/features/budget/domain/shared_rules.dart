enum InviteStatus { pending, accepted, declined }

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
