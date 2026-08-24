import 'package:budu/features/budget/models/expense_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Loads events for one budget. Pages until exhausted so tracking is complete.
class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _eventsCollection({
    required bool isSharedBudget,
    required String userId,
    required String budgetId,
  }) {
    final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
    final parentDocId = isSharedBudget ? budgetId : userId;
    return _firestore.collection(collectionPath).doc(parentDocId).collection('events');
  }

  Query<Map<String, dynamic>> _eventsQuery({
    required bool isSharedBudget,
    required String userId,
    required String budgetId,
  }) {
    return _eventsCollection(
      isSharedBudget: isSharedBudget,
      userId: userId,
      budgetId: budgetId,
    )
        .where('budgetId', isEqualTo: budgetId)
        .orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _legacyQuery({
    required String userId,
    required String budgetId,
  }) {
    return _firestore
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .doc(budgetId)
        .collection('expenses')
        .orderBy('createdAt', descending: true);
  }

  Future<List<ExpenseEvent>> _readAll(
    Query<Map<String, dynamic>> base, {
    bool legacyIds = false,
  }) async {
    final snapshot = await base.get();
    return snapshot.docs.map((doc) {
      if (legacyIds) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return ExpenseEvent.fromMap(data, doc.id);
      }
      return ExpenseEvent.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// All events for [budgetId] (personal or shared). Legacy personal path if events is empty.
  Future<List<ExpenseEvent>> getEventsForBudget({
    required String userId,
    required String budgetId,
    bool isSharedBudget = false,
  }) async {
    try {
      final events = await _readAll(
        _eventsQuery(
          isSharedBudget: isSharedBudget,
          userId: userId,
          budgetId: budgetId,
        ),
      );
      if (events.isEmpty && !isSharedBudget) {
        return _readAll(
          _legacyQuery(userId: userId, budgetId: budgetId),
          legacyIds: true,
        );
      }
      return events;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason:
            'getEventsForBudget failed – userId: $userId, budgetId: $budgetId, isShared: $isSharedBudget',
      );
      rethrow;
    }
  }

  Future<void> saveEvent({
    required String userId,
    required ExpenseEvent event,
    bool isSharedBudget = false,
  }) async {
    final data = event.toMap();
    if (isSharedBudget) {
      data['userId'] = userId;
    }
    await _eventsCollection(
      isSharedBudget: isSharedBudget,
      userId: userId,
      budgetId: event.budgetId,
    ).doc(event.id).set(data);
  }

  Future<void> deleteEvent({
    required String userId,
    required String budgetId,
    required String eventId,
    bool isSharedBudget = false,
  }) async {
    final ref = _eventsCollection(
      isSharedBudget: isSharedBudget,
      userId: userId,
      budgetId: budgetId,
    ).doc(eventId);
    if ((await ref.get()).exists) {
      await ref.delete();
      return;
    }
    if (!isSharedBudget) {
      await _firestore
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc(budgetId)
          .collection('expenses')
          .doc(eventId)
          .delete();
    }
  }

  Future<bool> hasSubcategoryEvents({
    required String userId,
    required String budgetId,
    required String category,
    required String subcategory,
    bool isSharedBudget = false,
  }) async {
    final events = await _eventsCollection(
      isSharedBudget: isSharedBudget,
      userId: userId,
      budgetId: budgetId,
    )
        .where('budgetId', isEqualTo: budgetId)
        .where('category', isEqualTo: category)
        .where('subcategory', isEqualTo: subcategory)
        .limit(1)
        .get();
    if (events.docs.isNotEmpty) return true;
    if (isSharedBudget) return false;
    final legacy = await _firestore
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .doc(budgetId)
        .collection('expenses')
        .where('category', isEqualTo: category)
        .where('subcategory', isEqualTo: subcategory)
        .limit(1)
        .get();
    return legacy.docs.isNotEmpty;
  }

  Future<List<String>> deleteSubcategoryEvents({
    required String userId,
    required String budgetId,
    required String category,
    required String subcategory,
    bool isSharedBudget = false,
  }) async {
    final deletedIds = <String>[];
    final events = await _eventsCollection(
      isSharedBudget: isSharedBudget,
      userId: userId,
      budgetId: budgetId,
    )
        .where('budgetId', isEqualTo: budgetId)
        .where('category', isEqualTo: category)
        .where('subcategory', isEqualTo: subcategory)
        .get();
    deletedIds.addAll(events.docs.map((d) => d.id));
    await _deleteInBatches(events.docs);
    if (!isSharedBudget) {
      final legacy = await _firestore
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc(budgetId)
          .collection('expenses')
          .where('category', isEqualTo: category)
          .where('subcategory', isEqualTo: subcategory)
          .get();
      deletedIds.addAll(legacy.docs.map((d) => d.id));
      await _deleteInBatches(legacy.docs);
    }
    return deletedIds;
  }

  /// Deletes all events for [budgetId] (and personal legacy expenses). Batches of 500.
  Future<void> deleteEventsForBudget({
    required String userId,
    required String budgetId,
    bool isSharedBudget = false,
  }) async {
    try {
      final collectionPath = isSharedBudget ? 'shared_budgets' : 'budgets';
      final parentDocId = isSharedBudget ? budgetId : userId;
      final events = await _firestore
          .collection(collectionPath)
          .doc(parentDocId)
          .collection('events')
          .where('budgetId', isEqualTo: budgetId)
          .get();
      await _deleteInBatches(events.docs);

      if (!isSharedBudget) {
        final legacy = await _firestore
            .collection('budgets')
            .doc(userId)
            .collection('monthly_budgets')
            .doc(budgetId)
            .collection('expenses')
            .get();
        await _deleteInBatches(legacy.docs);
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason:
            'deleteEventsForBudget failed – userId: $userId, budgetId: $budgetId, isShared: $isSharedBudget',
      );
      rethrow;
    }
  }

  Future<void> _deleteInBatches(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    const chunk = 500;
    for (var i = 0; i < docs.length; i += chunk) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(chunk)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
