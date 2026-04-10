import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/assistant_notification.dart';

class AssistantNotificationNotifier extends Notifier<List<AssistantNotification>> {
  @override
  List<AssistantNotification> build() => [];

  void addNotification(AssistantNotification notification) {
    state = [notification, ...state];
  }

  void markAsRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearAll() {
    state = [];
  }
}

final assistantNotificationProvider = NotifierProvider<AssistantNotificationNotifier, List<AssistantNotification>>(
  AssistantNotificationNotifier.new,
);
