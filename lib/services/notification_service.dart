import 'package:flutter/material.dart';

class NotificationItem {
  final String title;
  final String body;
  final String timestamp;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void addPaymentNotification(String method, String amount, String refCode) {
    final String timeString = DateTime.now().toString().split('.').first;
    _notifications.insert(
      0,
      NotificationItem(
        title: 'Payment Successful ($method)',
        body: 'Your payment of PKR $amount was verified. Ref: $refCode',
        timestamp: timeString,
      ),
    );
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
  }
}
