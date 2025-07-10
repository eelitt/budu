import 'package:cloud_firestore/cloud_firestore.dart';

/// Malli kutsulle Firestoresta.
class Invitation {
  final String id;
  final String sharedBudgetId;
  final String inviterId;
  final String inviteeEmail;
  final String status;
  final DateTime createdAt;

  Invitation({
    required this.id,
    required this.sharedBudgetId,
    required this.inviterId,
    required this.inviteeEmail,
    required this.status,
    required this.createdAt,
  });

  factory Invitation.fromMap(Map<String, dynamic> map, String id) {
    return Invitation(
      id: id,
      sharedBudgetId: map['sharedBudgetId'],
      inviterId: map['inviterId'],
      inviteeEmail: map['inviteeEmail'],
      status: map['status'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
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
}