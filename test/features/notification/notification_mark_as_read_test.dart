import 'package:budu/features/notification/data/notification_repository.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const todoUserId = 'TODO: Get from authProvider';

  test('markAsRead updates users/{uid}/notifications, not a TODO path', () async {
    final fake = FakeFirebaseFirestore();
    final repo = NotificationRepository(firestore: fake);
    final id = await repo.createNotification(
      userId: 'alice',
      type: 'invitation',
      message: 'Kutsu',
    );

    final provider = NotificationProvider(repository: repo);
    provider.initializeNotifications('alice');
    await provider.markAsRead(id);

    final doc = await fake
        .collection('users')
        .doc('alice')
        .collection('notifications')
        .doc(id)
        .get();
    expect(doc.data()?['read'], true);

    final leaked = await fake
        .collection('users')
        .doc(todoUserId)
        .collection('notifications')
        .doc(id)
        .get();
    expect(leaked.exists, isFalse);

    provider.cancelSubscriptions();
  });

  test('markAsRead before initialize does not write the TODO user', () async {
    final fake = FakeFirebaseFirestore();
    final repo = NotificationRepository(firestore: fake);
    final provider = NotificationProvider(repository: repo);
    await provider.markAsRead('n1');

    final leaked = await fake
        .collection('users')
        .doc(todoUserId)
        .collection('notifications')
        .get();
    expect(leaked.docs, isEmpty);
  });
}
