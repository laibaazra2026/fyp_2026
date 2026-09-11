import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

/// Centralized helper function for all 3 payment methods (JazzCash, EasyPaisa, Card)
Future<void> handleSuccessfulPayment({
  required String gateway,
  required String planName,
  required String transactionId,
  required String mobileNo,
  required String amount,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // 1. Update user subscription in Firestore
  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
    'subscriptionPlan': planName,
    'paymentGateway': gateway,
    'verifiedPhoneNumber': mobileNo,
    'lastTransactionId': transactionId,
    'subscribedAt': FieldValue.serverTimestamp(),
  });

  // 2. Log to payment_requests collection for admin review
  await FirebaseFirestore.instance.collection('payment_requests').add({
    'userId': user.uid,
    'email': user.email ?? 'N/A',
    'plan': planName,
    'gateway': gateway,
    'transactionId': transactionId,
    'mobileNo': mobileNo,
    'timestamp': FieldValue.serverTimestamp(),
    'status': 'Verified',
  });

  // 3. Trigger the bell notification UI
  NotificationService().addPaymentNotification(gateway, amount, transactionId);
}
