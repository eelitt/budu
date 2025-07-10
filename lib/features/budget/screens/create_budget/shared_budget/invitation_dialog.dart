import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart'; // Lisätty: Batch-write notifikaatiolle
import 'package:budu/features/notification/data/notification_repository.dart'; // Lisätty: Käytä repositorya notifikaation luonnissa

/// Dialogi yhteistalousbudjetin nimen ja valinnaisen kutsun syöttämiseen.
/// Päivitetty: Käytä NotificationRepository:a notifikaation luonnissa (modulaarinen, batch atominen).
class InvitationDialog extends StatefulWidget {
  const InvitationDialog({super.key});

  @override
  State<InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<InvitationDialog> {
  final _budgetNameController = TextEditingController();
  final _inviteeEmailController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  bool _includeInvite = false;
  final NotificationRepository _notificationRepository = NotificationRepository(); // Lisätty: Repository-instanssi

  @override
  void dispose() {
    _budgetNameController.dispose();
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

  Future<void> _proceedToBudgetCreation(BuildContext context) async {
    final budgetName = _budgetNameController.text.trim();
    final inviteeEmail = _inviteeEmailController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null || FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _errorMessage = 'Käyttäjä ei ole kirjautunut';
      });
      showErrorSnackBar(context, 'Käyttäjä ei ole kirjautunut');
      await FirebaseCrashlytics.instance.log('InvitationDialog: Käyttäjä ei autentikoitu');
      return;
    }

    if (budgetName.isEmpty) {
      setState(() {
        _errorMessage = 'Syötä budjetin nimi';
      });
      return;
    }
    if (_includeInvite && inviteeEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Syötä kutsuttavan sähköposti';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = authProvider.user!.uid;
      final sharedBudgetId = Uuid().v4();
      print('InvitationDialog: Siirrytään budjetin luontiin, userId: $userId, sharedBudgetId: $sharedBudgetId, budgetName: $budgetName, includeInvite: $_includeInvite');
      await FirebaseCrashlytics.instance.log('InvitationDialog: Siirrytään budjetin luontiin, sharedBudgetId: $sharedBudgetId, invite: $_includeInvite');

      if (_includeInvite) {
        // Tarkista email ja hae userId
        final inviteeUserId = await _getUserIdByEmail(inviteeEmail);
        if (inviteeUserId == null) {
          throw Exception('Sähköpostiosoitetta ei löydy sovelluksen käyttäjistä');
        }

        // Luo invitation ja notifikaatio batch:lla (atominen)
        final batch = FirebaseFirestore.instance.batch();
        final invitationRef = FirebaseFirestore.instance.collection('invitations').doc();
        batch.set(invitationRef, {
          'sharedBudgetId': sharedBudgetId,
          'inviterId': userId,
          'inviteeEmail': inviteeEmail,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _notificationRepository.createNotification(
          userId: inviteeUserId,
          type: 'invitation',
          message: 'Olet kutsuttu uuteen yhteistalousbudjettiin "${budgetName}" käyttäjältä $userId',
          invitationId: invitationRef.id,
          batch: batch,
        );
        await batch.commit(); // Atominen write (optimoi kulut)
      }

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          AppRouter.sharedCreateBudgetRoute,
          arguments: {
            'sharedBudgetId': sharedBudgetId,
            'user1Id': userId,
            'user2Id': null,
            'budgetName': budgetName,
            'inviteeEmail': _includeInvite ? inviteeEmail : null,
            'isNew': true, // Lisätty: Kerro screen:lle, että uusi budjetti (skippaa haku)
          },
        );
      }
    } catch (e, stackTrace) {
      print('InvitationDialog: Virhe siirtymisessä budjetin luontiin: $e');
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to proceed to budget creation, userId: ${authProvider.user?.uid}',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'Siirtyminen budjetin luontiin epäonnistui: $e';
      });
      if (mounted) {
        showErrorSnackBar(context, _errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Luo yhteistalousbudjetti'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _budgetNameController,
            decoration: const InputDecoration(
              labelText: 'Budjetin nimi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Kutsu toinen käyttäjä'),
            value: _includeInvite,
            onChanged: (value) {
              setState(() {
                _includeInvite = value ?? false;
              });
            },
          ),
          if (_includeInvite)
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
          onPressed: _isLoading ? null : () => _proceedToBudgetCreation(context),
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Jatka'),
        ),
      ],
    );
  }
}