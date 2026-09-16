import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/app_config.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of notifications for the current user from Firestore, ordered by newest first.
  Stream<List<NotificationItem>> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            // Format timestamp for UI display
            String timeString = '';
            var rawTimestamp = data['timestamp'];
            if (rawTimestamp is Timestamp) {
              timeString = rawTimestamp.toDate().toString().split('.').first;
            } else {
              timeString = DateTime.now().toString().split('.').first;
            }

            return NotificationItem(
              id: doc.id,
              title: data['title'] ?? 'Notification',
              body: data['body'] ?? '',
              timestamp: timeString,
              isRead: data['isRead'] ?? false,
            );
          }).toList();
        });
  }

  /// Get total count of unread notifications for badge counters.
  Stream<int> getUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a specific notification as read in Firestore.
  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Mark all unread notifications as read.
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final unreadDocs = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Completely delete all notifications for the current user.
  Future<void> clearAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final allDocs = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .get();

    for (var doc in allDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Delete a notification document from Firestore.
  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}

/// Centralized helper function supporting both Sandbox (Mock) and Real Live Payments
Future<void> handleSuccessfulPayment({
  required String gateway,
  required String planName,
  required String transactionId,
  required String mobileNo,
  required String amount,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final firestore = FirebaseFirestore.instance;
  final bool isLive = AppConfig.isLiveProductionMode;

  // Determine prefixes/labels based on live vs sandbox status
  final String modeLabel = isLive ? 'LIVE' : 'SANDBOX (MOCK)';
  final String statusLabel = isLive
      ? 'Verified (Live)'
      : 'Verified (Sandbox Simulation)';

  // 1. Update user subscription in Firestore
  await firestore.collection('users').doc(user.uid).set({
    'subscriptionPlan': planName,
    'paymentGateway': '$gateway ($modeLabel)',
    'verifiedPhoneNumber': mobileNo,
    'lastTransactionId': transactionId,
    'isLivePayment': isLive,
    'subscribedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  // 2. Log to payment_requests collection for admin review (tagged by mode)
  await firestore.collection('payment_requests').add({
    'userId': user.uid,
    'email': user.email ?? 'N/A',
    'plan': planName,
    'gateway': gateway,
    'transactionId': transactionId,
    'mobileNo': mobileNo,
    'mode': modeLabel,
    'timestamp': FieldValue.serverTimestamp(),
    'status': statusLabel,
  });

  // 3. Save a permanent notification to Firestore with clear mode indicators
  await firestore.collection('users').doc(user.uid).collection('notifications').add({
    'title': isLive
        ? 'Payment Successful ($gateway)'
        : 'Mock Payment Simulation ($gateway)',
    'body': isLive
        ? 'Your live payment of PKR $amount was verified. Ref: $transactionId'
        : '[SANDBOX TEST] Simulated payment of PKR $amount processed. Ref: $transactionId',
    'type': isLive ? 'payment_success_live' : 'payment_success_sandbox',
    'isLive': isLive,
    'timestamp': FieldValue.serverTimestamp(),
    'isRead': false,
  });
}
