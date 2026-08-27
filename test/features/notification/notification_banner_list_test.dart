import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NotificationProvider provider;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    provider = NotificationProvider();
  });

  test('upsert personal reminder appears in notifications', () {
    provider.upsert(
      const NotificationMessage(
        kind: NotificationKind.reminderPersonal,
        message: 'Henkilökohtainen puuttuu',
        type: NotificationType.warning,
      ),
    );

    expect(provider.notifications, hasLength(1));
    expect(
      provider.notifications.single.kind,
      NotificationKind.reminderPersonal,
    );
  });

  test('dismiss invite leaves personal reminder', () {
    provider.syncPendingInvites(1);
    provider.upsert(
      const NotificationMessage(
        kind: NotificationKind.reminderPersonal,
        message: 'Henkilökohtainen puuttuu',
        type: NotificationType.warning,
      ),
    );

    provider.removeKind(NotificationKind.pendingInvites);

    expect(provider.notifications, hasLength(1));
    expect(
      provider.notifications.single.kind,
      NotificationKind.reminderPersonal,
    );
  });

  test('clearReminders leaves pending invites', () {
    provider.syncPendingInvites(2);
    provider.upsert(
      const NotificationMessage(
        kind: NotificationKind.reminderPersonal,
        message: 'Henkilökohtainen puuttuu',
        type: NotificationType.warning,
      ),
    );

    provider.clearReminders();

    expect(provider.notifications, hasLength(1));
    expect(
      provider.notifications.single.kind,
      NotificationKind.pendingInvites,
    );
  });

  test('max 2: invite + personal hide shared', () {
    provider.syncPendingInvites(1);
    provider.upsert(
      const NotificationMessage(
        kind: NotificationKind.reminderPersonal,
        message: 'Henkilökohtainen puuttuu',
        type: NotificationType.warning,
      ),
    );
    provider.upsert(
      const NotificationMessage(
        kind: NotificationKind.reminderShared,
        message: 'Yhteistalous puuttuu',
        type: NotificationType.warning,
      ),
    );

    expect(provider.activeKinds, hasLength(3));
    expect(provider.notifications, hasLength(2));
    expect(
      provider.notifications.map((n) => n.kind),
      [
        NotificationKind.pendingInvites,
        NotificationKind.reminderPersonal,
      ],
    );
  });

  test('without invite, personal and shared both visible', () {
    provider.upsert(
      const NotificationMessage(
        kind: NotificationKind.reminderPersonal,
        message: 'Henkilökohtainen puuttuu',
        type: NotificationType.warning,
      ),
    );
    provider.upsert(
      const NotificationMessage(
        kind: NotificationKind.reminderShared,
        message: 'Yhteistalous puuttuu',
        type: NotificationType.warning,
      ),
    );

    expect(provider.notifications, hasLength(2));
    expect(
      provider.notifications.map((n) => n.kind),
      [
        NotificationKind.reminderPersonal,
        NotificationKind.reminderShared,
      ],
    );
  });

  test('syncPendingInvites(0) removes invite banner', () {
    provider.syncPendingInvites(1);
    expect(provider.activeKinds, contains(NotificationKind.pendingInvites));
    provider.syncPendingInvites(0);
    expect(
      provider.activeKinds,
      isNot(contains(NotificationKind.pendingInvites)),
    );
  });

  test('Finnish invite copy for one and many', () {
    provider.syncPendingInvites(1);
    expect(
      provider.notifications.single.message,
      'Sinulla on 1 odottava budjettikutsu',
    );
    provider.syncPendingInvites(3);
    expect(
      provider.notifications.single.message,
      'Sinulla on 3 odottavaa budjettikutsua',
    );
  });
}
