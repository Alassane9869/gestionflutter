class ClientPayment {
  final String id;
  final String clientId;
  final String accountId;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String? description;
  final String userId;
  final String? sessionId;
  final bool isSynced;

  ClientPayment({
    required this.id,
    required this.clientId,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.description,
    required this.userId,
    this.sessionId,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'account_id': accountId,
      'amount': amount,
      'date': date.toIso8601String(),
      'payment_method': paymentMethod,
      'description': description,
      'user_id': userId,
      'session_id': sessionId,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ClientPayment.fromMap(Map<String, dynamic> map) {
    return ClientPayment(
      id: map['id'] as String,
      clientId: map['client_id'] as String,
      accountId: map['account_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      paymentMethod: map['payment_method'] as String,
      description: map['description'] as String?,
      userId: map['user_id'] as String,
      sessionId: map['session_id'] as String?,
      isSynced: (map['is_synced'] as int?) == 1,
    );
  }
}
