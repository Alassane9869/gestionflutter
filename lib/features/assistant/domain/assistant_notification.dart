class AssistantNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final dynamic actionPayload;

  AssistantNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.actionPayload,
  });

  AssistantNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    dynamic actionPayload,
  }) {
    return AssistantNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionPayload: actionPayload ?? this.actionPayload,
    );
  }
}
