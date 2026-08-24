import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:budu/features/budget/models/budget_model.dart';

/// Malli kutsulle Firestoresta.
class Invitation {
  final String id;
  final String sharedBudgetId;
  final String? householdId;
  final String inviterId;
  final String inviteeEmail;
  final String status;
  final DateTime createdAt;
  String? inviterDisplayName; // e.g., "Anna" from users doc
  String? inviterEmail;       // Fallback if no displayName
  String? sharedBudgetName;   // e.g., "Perhebudjetti"

  Invitation({
    required this.id,
    required this.sharedBudgetId,
    this.householdId,
    required this.inviterId,
    required this.inviteeEmail,
    required this.status,
    required this.createdAt,
    this.inviterDisplayName,
    this.inviterEmail,
    this.sharedBudgetName,
  });

  factory Invitation.fromMap(Map<String, dynamic> map, String id) {
    return Invitation(
      id: id,
      sharedBudgetId: map['sharedBudgetId'] as String? ?? '',
      householdId: map['householdId'] as String?,
      inviterId: map['inviterId'],
      inviteeEmail: map['inviteeEmail'],
      status: map['status'],
      createdAt: BudgetModel.parseDate(map['createdAt']) ?? DateTime.now(),
      inviterDisplayName: map['inviterDisplayName'] as String?,
      inviterEmail: map['inviterEmail'] as String?,
      sharedBudgetName: map['sharedBudgetName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sharedBudgetId': sharedBudgetId,
      if (householdId != null) 'householdId': householdId,
      'inviterId': inviterId,
      'inviteeEmail': normalizeInviteEmailForLookup(inviteeEmail),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  // Optional: copyWith for enrichment
  Invitation copyWith({
    String? inviterEmail,
    String? sharedBudgetName,
  }) {
    return Invitation(
      id: id,
      sharedBudgetId: sharedBudgetId,
      householdId: householdId,
      inviterId: inviterId,
      inviteeEmail: inviteeEmail,
      status: status,
      createdAt: createdAt,
      inviterEmail: inviterEmail ?? this.inviterEmail,
      sharedBudgetName: sharedBudgetName ?? this.sharedBudgetName,
    );
  }
}