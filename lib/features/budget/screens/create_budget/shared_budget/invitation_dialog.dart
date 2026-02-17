import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budu/features/notification/data/notification_repository.dart';

/// Dialogi yhteistalousbudjetin nimen ja valinnaisen kutsun syöttämiseen.
/// Päivitetty: Normalisoi email lowercase:ksi queryä varten, lisätty tarkempi logging, parannettu virheenkäsittely indeksiongelmiin.
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
  final NotificationRepository _notificationRepository = NotificationRepository();

  @override
  void dispose() {
    _budgetNameController.dispose();
    _inviteeEmailController.dispose();
    super.dispose();
  }

  /// Hakee userId:n annetulla email:llä (optimoitu limit=1).
  /// Normalisoi email lowercase:ksi (case-insensitive haku).
  Future<String?> _getUserIdByEmail(String email) async {
    try {
      final normalizedEmail = email.toLowerCase(); // Normalisoi lowercase
      print('InvitationDialog: Haetaan userId email:llä $normalizedEmail');
      await FirebaseCrashlytics.instance.log('InvitationDialog: Haetaan userId email:llä $normalizedEmail');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final userId = snapshot.docs.first.id;
        final storedEmail = snapshot.docs.first.data()['email'] as String?;
        print('InvitationDialog: Löydetty userId: $userId, stored email: $storedEmail');
        await FirebaseCrashlytics.instance.log('InvitationDialog: Löydetty userId: $userId, stored email: $storedEmail');
        return userId;
      }
      print('InvitationDialog: Email $normalizedEmail ei löydy (snapshot size: ${snapshot.size})');
      await FirebaseCrashlytics.instance.log('InvitationDialog: Email $normalizedEmail ei löydy (snapshot size: ${snapshot.size})');
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await FirebaseCrashlytics.instance.log('Permission-denied email-haussa: $email - kohdellaan ei-löydettynä');
        print('InvitationDialog: Permission-denied email-haussa: $email');
        return null; // Handle as not found (turvallinen, ei heitä erroria)
      }
      if (e.code == 'failed-precondition') {
        await FirebaseCrashlytics.instance.log('Indeksi puuttuu email-haussa: $email - tarkista Firestore-konsoli');
        print('InvitationDialog: Indeksi puuttuu email-haussa: $email - tarkista Firestore-konsoli');
        return null; // Handle missing index
      }
      rethrow;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to get userId by email: $email',
      );
      print('InvitationDialog: Virhe userId:n haussa email:llä $email: $e');
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
          'inviteeEmail': inviteeEmail.toLowerCase(), // Normalisoi invitation-dokumenttiin
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
            'inviteeEmail': _includeInvite ? inviteeEmail.toLowerCase() : null, // Normalisoi myös tässä
            'isNew': true, // Kerro screen:lle, että uusi budjetti (skippaa haku)
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
    } finally {
      setState(() {
        _isLoading = false;
      });
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