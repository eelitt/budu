import 'package:budu/features/notification/models/notification_message.dart';
import 'package:budu/features/notification/data/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async'; // Lisätty: StreamSubscription varten


/// NotificationProvider: Hallinnoi in-app-notifikaatioita.
/// Päivitetty: Käytä NotificationRepository:a data access:iin (modulaarinen), stream repositorysta.
/// Lataa init:ssa, kuuntele muutoksia reaaliaikaisesti. Virheenkäsittely loggauksella.
class NotificationProvider with ChangeNotifier {
  NotificationMessage? _currentNotification;
  List<NotificationMessage> _notifications = []; // Lista kaikista notifikaatioista (UI:lle)
  StreamSubscription<List<NotificationMessage>>? _notificationsSubscription; // Muutettu: StreamSubscription tyyppi repositoryn streamiin
  final NotificationRepository _repository = NotificationRepository(); // Lisätty: Repository-instanssi

  NotificationMessage? get currentNotification => _currentNotification;
  // Transient (paikalliset) notifikaatiot – ei tallenneta Firestoreen
  final List<NotificationMessage> _transientNotifications = [];

  // Yhdistetty lista: Firestore + transient
  List<NotificationMessage> get notifications =>
      [..._notifications, ..._transientNotifications];

  /// Näyttää transient-notifikaation (ei Firestoreen)
  void showTransientNotification(NotificationMessage message) {
    // Poista mahdollinen vanha saman ID:n notifikaatio
    _transientNotifications
        .removeWhere((n) => n.notificationId == message.notificationId);
    _transientNotifications.add(message);
    notifyListeners();
  }

  /// Poistaa transient-notifikaation ID:llä
  void removeTransientNotificationById(String? id) {
    if (id == null) return;
    _transientNotifications.removeWhere((n) => n.notificationId == id);
    notifyListeners();
  }

  /// Näyttää notifikaation (olemassa oleva, mutta päivitetty safe-notify:llä).
  void showNotification({
    required String message,
    required NotificationType type,
    VoidCallback? onAction,
    String? actionText,
  }) {
    _currentNotification = NotificationMessage(
      message: message,
      type: type,
      onAction: onAction,
      actionText: actionText,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Tyhjentää nykyisen notifikaation.
  void clearNotification() {
    _currentNotification = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Alustaa notifikaatioiden kuuntelun Firestoresta (kutsutaan esim. MainScreen:initState:ssa).
  /// Käytä repository:a stream:in hakemiseen (modulaarinen).
  void initializeNotifications(String userId) {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = _repository.getUnreadNotificationsStream(userId).listen((notifications) {
      _notifications = notifications.map((notif) {
        return NotificationMessage(
          message: notif.message,
          type: notif.type,
          onAction: () {
            // Handle action (esim. navigoi invitation:iin)
            if (notif.notificationId != null) {
              markAsRead(notif.notificationId!); // Merkitse luetuksi actionin jälkeen (käytä repositorya)
            }
          },
          actionText: 'Hyväksy', // Esim. invitationille
          notificationId: notif.notificationId,
        );
      }).toList();
      notifyListeners();
    }, onError: (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to stream notifications for user $userId',
      );
      print('NotificationProvider: Virhe notifikaatioiden streamissa: $e');
    });
  }

  /// Merkitsee notifikaation luetuksi (käytä repositorya).
  Future<void> markAsRead(String notificationId) async {
    // Oleta userId saatavilla (esim. authProvider.user!.uid - injektoi kutsujasta)
    // TODO: Lisää userId parametri, jos ei globaali
    final userId = 'TODO: Get from authProvider'; // Korvaa oikealla userId:llä (esim. injektoi)
    await _repository.markAsRead(userId, notificationId);
  }

  /// Peruuttaa stream-kuuntelijan (dispose:ssa).
  void cancelSubscriptions() {
    _notificationsSubscription?.cancel();
  }

  @override
  void dispose() {
    cancelSubscriptions();
    super.dispose();
  }
}