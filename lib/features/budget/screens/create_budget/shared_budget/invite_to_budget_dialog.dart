import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/notification/data/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Dialogi kutsun lähettämiseen olemassa olevalle yhteistalousbudjetille.
/// Päivitetty: Käytä NotificationRepository:a notifikaation luonnissa (modulaarinen, batch atominen).
class InviteToExistingBudgetDialog extends StatefulWidget {
  final String sharedBudgetId; // Pakollinen budjetti-ID

  const InviteToExistingBudgetDialog({
    super.key,
    required this.sharedBudgetId,
  });

  @override
  State<InviteToExistingBudgetDialog> createState() => _InviteToExistingBudgetDialogState();
}

class _InviteToExistingBudgetDialogState extends State<InviteToExistingBudgetDialog> {
  final _inviteeEmailController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  final NotificationRepository _notificationRepository = NotificationRepository(); // Lisätty: Repository-instanssi

  @override
  void dispose() {
    _inviteeEmailController.dispose();
    super.dispose();
  }

  /// Hakee userId:n annetulla email:llä (optimoitu limit=1).
  Future<String?> _getUserIdByEmail(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to get userId by email: $email',
      );
      return null;
    }
  }

  /// Tarkistaa, onko sähköposti rekisteröity (olemassa oleva logiikka).
  Future<bool> _checkEmailExists(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to check email existence: $email',
      );
      return false;
    }
  }

  Future<void> _createInvitation(BuildContext context) async {
    final inviteeEmail = _inviteeEmailController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

    if (inviteeEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Syötä kutsuttavan sähköposti';
      });
      return;
    }

    // Tarkista, onko sähköposti rekisteröity
    final emailExists = await _checkEmailExists(inviteeEmail);
    if (!emailExists) {
      setState(() {
        _errorMessage = 'Sähköpostiosoitetta ei löydy sovelluksen käyttäjistä';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = authProvider.user!.uid;
      final inviteeUserId = await _getUserIdByEmail(inviteeEmail); // Hae kutsutun userId notifikaatiolle
      if (inviteeUserId == null) {
        throw Exception('Failed to retrieve invitee userId');
      }

      final invitationId = await sharedBudgetProvider.createInvitationForExistingBudget(
        sharedBudgetId: widget.sharedBudgetId,
        inviterId: userId,
        inviteeEmail: inviteeEmail,
      );

      // Luo in-app-notifikaatio kutsutulle repositoryn kautta (atominen batch)
      final batch = FirebaseFirestore.instance.batch();
      await _notificationRepository.createNotification(
        userId: inviteeUserId,
        type: 'invitation',
        message: 'Olet kutsuttu yhteistalousbudjettiin (ID: ${widget.sharedBudgetId}) käyttäjältä $userId',
        invitationId: invitationId,
        batch: batch,
      );
      await batch.commit(); // Committaa batch (atominen)

      await FirebaseCrashlytics.instance.log('InviteToExistingBudgetDialog: Kutsu ja notifikaatio lähetetty, sharedBudgetId: ${widget.sharedBudgetId}, inviteeEmail: $inviteeEmail');
      if (mounted) {
        Navigator.pop(context, inviteeEmail); // Palauta kutsuttu sähköposti
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to create invitation and notification for sharedBudgetId ${widget.sharedBudgetId}',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kutsun lähetys epäonnistui: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Kutsu yhteistalousbudjettiin'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _inviteeEmailController,
            decoration: const InputDecoration(
              labelText: 'Kutsuttavan sähköposti',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Peruuta'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _createInvitation(context),
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Lähetä kutsu'),
        ),
      ],
    );
  }
}