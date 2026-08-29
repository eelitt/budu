import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lists pending household invites for accept/decline.
/// Banner count stays in sync via [SharedBudgetProvider] + InviteNotificationHandler.
class PendingInvitesDialog extends StatefulWidget {
  const PendingInvitesDialog({super.key});

  @override
  State<PendingInvitesDialog> createState() => _PendingInvitesDialogState();
}

class _PendingInvitesDialogState extends State<PendingInvitesDialog> {
  bool _isProcessing = false;

  Future<void> _accept({
    required SharedBudgetProvider sharedProvider,
    required AuthProvider authProvider,
    required String invitationId,
    required String sharedBudgetId,
  }) async {
    setState(() => _isProcessing = true);
    try {
      await sharedProvider.acceptInvitation(
        invitationId: invitationId,
        sharedBudgetId: sharedBudgetId,
        userId: authProvider.user!.uid,
      );
      if (!mounted) return;
      showSnackBar(
        context,
        'Kutsu hyväksytty!',
        backgroundColor: Colors.green,
      );
      await sharedProvider.fetchPendingInvitations(authProvider.user!.email);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Hyväksyminen epäonnistui');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _decline({
    required SharedBudgetProvider sharedProvider,
    required AuthProvider authProvider,
    required String invitationId,
  }) async {
    setState(() => _isProcessing = true);
    try {
      await sharedProvider.declineInvitation(invitationId);
      if (!mounted) return;
      showSnackBar(context, 'Kutsu hylätty');
      await sharedProvider.fetchPendingInvitations(authProvider.user!.email);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Hylkääminen epäonnistui');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SharedBudgetProvider>(
      builder: (context, sharedProvider, child) {
        final authProvider = Provider.of<AuthProvider>(context);
        final pending = sharedProvider.pendingInvitations;

        if (pending.isEmpty) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Odottavat kutsut'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final invite = pending[index];
                final budgetName =
                    invite.sharedBudgetName ?? 'Nimetön budjetti';
                final inviterEmail =
                    invite.inviterEmail ?? 'tuntematon@example.com';

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
                                : () => _accept(
                                      sharedProvider: sharedProvider,
                                      authProvider: authProvider,
                                      invitationId: invite.id,
                                      sharedBudgetId: invite.sharedBudgetId,
                                    ),
                            child: const Text(
                              'Hyväksy',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isProcessing
                                ? null
                                : () => _decline(
                                      sharedProvider: sharedProvider,
                                      authProvider: authProvider,
                                      invitationId: invite.id,
                                    ),
                            child: const Text(
                              'Hylkää',
                              style: TextStyle(color: Colors.red),
                            ),
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
