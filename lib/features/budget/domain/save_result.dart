enum BudgetSaveStatus { ok, cancelled, failed }

/// Outcome of create-budget save. Cancel is not a failure.
class BudgetSaveResult {
  const BudgetSaveResult._({
    required this.status,
    this.budgetId,
    this.message,
  });

  const BudgetSaveResult.ok(String budgetId)
      : this._(status: BudgetSaveStatus.ok, budgetId: budgetId);

  const BudgetSaveResult.cancelled()
      : this._(status: BudgetSaveStatus.cancelled);

  const BudgetSaveResult.failed(String message)
      : this._(status: BudgetSaveStatus.failed, message: message);

  final BudgetSaveStatus status;
  final String? budgetId;
  final String? message;

  bool get isOk => status == BudgetSaveStatus.ok;
  bool get isCancelled => status == BudgetSaveStatus.cancelled;
  bool get isFailed => status == BudgetSaveStatus.failed;
}
