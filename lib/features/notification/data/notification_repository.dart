import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:budu/features/notification/models/notification_message.dart'; // Lisätty: Käytä mallia parsintaan

/// Repositorio notifikaatioiden tallentamiseen ja hakemiseen Firestoresta.
/// Kaikki operaatiot keskitetty tänne modulaarisuuden vuoksi.
/// Optimoitu: Query limitit, batch-write massatoimintoihin, reaaliaikainen stream unread-notifikaatioille.
/// Virheenkäsittely: Loggaa Crashlytics:iin, heitä error kutsujalle.
class NotificationRepository {
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  /// Luo notifikaation annetulle käyttäjälle (tukee optional batch:a atomisiin operaatioihin).
  /// Jos batch annettu, ei committaa tässä (kutsu commit kutsujassa).
  Future<String> createNotification({
    required String userId,
    required String type,
    required String message,
    String? invitationId,
    WriteBatch? batch,
  }) async {
    try {
      final notificationRef = _usersCollection
          .doc(userId)
          .collection('notifications')
          .doc(); // Auto-ID
      final data = {
        'type': type,
        'message': message,
        'invitationId': invitationId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (batch != null) {
        batch.set(notificationRef, data);
      } else {
        await notificationRef.set(data);
      }
      return notificationRef.id; // Palauta ID (esim. markAsRead:lle)
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to create notification for user $userId',
      );
      throw Exception('Notifikaation luonti epäonnistui: $e');
    }
  }

  /// Palauttaa streamin lukemattomista notifikaatioista reaaliaikaiseen kuunteluun.
  /// Optimoitu: Query vain unread, orderBy timestamp, limit 50 (vähentää kuluja).
  Stream<List<NotificationMessage>> getUnreadNotificationsStream(String userId) {
    return _usersCollection
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return NotificationMessage(
                message: data['message'] as String,
                type: _mapStringToType(data['type'] as String),
                onAction: null, // TODO: Lisää action kutsujassa (esim. provider:ssa)
                actionText: null,
                notificationId: doc.id, // Lisätty: ID markAsRead:lle
              );
            }).toList())
        .handleError((e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to stream unread notifications for user $userId',
      );
      throw Exception('Notifikaatioiden stream epäonnistui: $e');
    });
  }

  /// Merkitsee notifikaation luetuksi (update read=true).
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _usersCollection
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to mark notification as read: $notificationId for user $userId',
      );
      throw Exception('Notifikaation merkintä luetuksi epäonnistui: $e');
    }
  }

  /// Map string tyyppiin (esim. 'invitation' -> NotificationType.warning).
  /// Sisäinen: Käytetään parsinnassa.
  NotificationType _mapStringToType(String type) {
    switch (type) {
      case 'invitation':
        return NotificationType.warning; // Esim. keltainen banneri kutsulle
      case 'error':
        return NotificationType.error;
      case 'success':
        return NotificationType.success;
      default:
        return NotificationType.warning;
    }
  }
}