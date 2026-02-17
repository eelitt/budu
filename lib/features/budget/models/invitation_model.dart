import 'package:cloud_firestore/cloud_firestore.dart';

/// Malli kutsulle Firestoresta.
class Invitation {
  final String id;
  final String sharedBudgetId;
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
      sharedBudgetId: map['sharedBudgetId'],
      inviterId: map['inviterId'],
      inviteeEmail: map['inviteeEmail'],
      status: map['status'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      inviterDisplayName: map['inviterDisplayName'] as String?,
      inviterEmail: map['inviterEmail'] as String?,
      sharedBudgetName: map['sharedBudgetName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sharedBudgetId': sharedBudgetId,
      'inviterId': inviterId,
      'inviteeEmail': inviteeEmail,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
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
      inviterId: inviterId,
      inviteeEmail: inviteeEmail,
      status: status,
      createdAt: createdAt,
      inviterEmail: inviterEmail ?? this.inviterEmail,
      sharedBudgetName: sharedBudgetName ?? this.sharedBudgetName,
    );
  }
}