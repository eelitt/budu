import 'package:budu/core/utils.dart'; // showSnackBar/showErrorSnackBar
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Dialogi useiden odottavien kutsujen hallintaan.
/// Näyttää listan kutsuja tai "Ei kutsuja" -viestin jos tyhjä.
/// Teema sopii sovelluksen muihin dialogeihin (valkoinen tausta, pyöristetyt kulmat).
class PendingInvitesDialog extends StatefulWidget {
  const PendingInvitesDialog({super.key});

  @override
  State<PendingInvitesDialog> createState() => _PendingInvitesDialogState();
}

class _PendingInvitesDialogState extends State<PendingInvitesDialog> {
  bool _isProcessing = false; // Estää tuplaklikkaukset

  @override
  Widget build(BuildContext context) {
    return Consumer<SharedBudgetProvider>(
      builder: (context, sharedProvider, child) {
        final authProvider = Provider.of<AuthProvider>(context);
        final pending = sharedProvider.pendingInvitations;

        // Jos tyhjä (debug tai kaikki käsitelty), näytä viesti – ei auto-closea
        if (pending.isEmpty) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: const Text('Odottavat kutsut'),
            content: const Text('Ei odottavia kutsuja.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Sulje'),
              ),
            ],
          );
        }

        // Normaali lista kun kutsuja on
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Odottavat kutsut'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final invite = pending[index];
                final budgetName = invite.sharedBudgetName ?? 'Nimetön budjetti';
                final inviterEmail = invite.inviterEmail ?? 'tuntematon@example.com';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Kutsu budjettiin "$budgetName" käyttäjältä $inviterEmail',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Column(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(80, 36),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    setState(() => _isProcessing = true);
                                    try {
                                      await sharedProvider.acceptInvitation(
                                        invitationId: invite.id,
                                        sharedBudgetId: invite.sharedBudgetId,
                                        userId: authProvider.user!.uid,
                                      );
                                      showSnackBar(context, 'Kutsu hyväksytty!', backgroundColor: Colors.green);

                                      // Reload – päivittää listan (voi mennä tyhjään viestiin)
                                      await sharedProvider.fetchPendingInvitations(authProvider.user!.email!);
                                    } catch (e) {
                                      showErrorSnackBar(context, 'Hyväksyminen epäonnistui');
                                    } finally {
                                      if (mounted) setState(() => _isProcessing = false);
                                    }
                                  },
                            child: const Text('Hyväksy', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    setState(() => _isProcessing = true);
                                    try {
                                      await sharedProvider.declineInvitation(invite.id);
                                      showSnackBar(context, 'Kutsu hylätty');

                                      // Reload – päivittää listan
                                      await sharedProvider.fetchPendingInvitations(authProvider.user!.email!);
                                    } catch (e) {
                                      showErrorSnackBar(context, 'Hylkääminen epäonnistui');
                                    } finally {
                                      if (mounted) setState(() => _isProcessing = false);
                                    }
                                  },
                            child: const Text('Hylkää', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Sulje'),
            ),
          ],
        );
      },
    );
  }
}