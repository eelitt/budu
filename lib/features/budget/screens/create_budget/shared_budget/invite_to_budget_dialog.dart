import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Invite a registered user to an existing household budget.
class InviteToExistingBudgetDialog extends StatefulWidget {
  final String sharedBudgetId;

  const InviteToExistingBudgetDialog({
    super.key,
    required this.sharedBudgetId,
  });

  @override
  State<InviteToExistingBudgetDialog> createState() =>
      _InviteToExistingBudgetDialogState();
}

class _InviteToExistingBudgetDialogState
    extends State<InviteToExistingBudgetDialog> {
  final _inviteeEmailController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _inviteeEmailController.dispose();
    super.dispose();
  }

  Future<void> _createInvitation(BuildContext context) async {
    final inviteeEmail = _inviteeEmailController.text;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sharedBudgetProvider =
        Provider.of<SharedBudgetProvider>(context, listen: false);

    if (normalizeInviteEmailForLookup(inviteeEmail).isEmpty) {
      setState(() {
        _errorMessage = inviteValidationMessage(InviteValidation.emptyEmail);
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await sharedBudgetProvider.inviteUser(
        sharedBudgetId: widget.sharedBudgetId,
        inviterId: authProvider.user!.uid,
        inviterEmail: authProvider.user!.email,
        inviteeEmail: inviteeEmail,
      );
      await FirebaseCrashlytics.instance.log(
        'InviteToExistingBudgetDialog: Kutsu lähetetty, sharedBudgetId: ${widget.sharedBudgetId}',
      );
      if (mounted) {
        Navigator.pop(context, normalizeInviteEmailForLookup(inviteeEmail));
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason:
            'Failed to create invitation for sharedBudgetId ${widget.sharedBudgetId}',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
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
