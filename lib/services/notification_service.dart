import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add notification to database
  static Future<void> addNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    try {
      final notificationRef = _database
          .ref()
          .child('notifications')
          .child(userId)
          .push();
      await notificationRef.set({
        'title': title,
        'message': message,
        'body': message, // Add both message and body for compatibility
        'type': type,
        'relatedId': relatedId,
        'timestamp': ServerValue.timestamp,
        'read': false,
      });
      print('Notification added successfully for user: $userId, title: $title');
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  // Notify all users about new course
  static Future<void> notifyNewCourse(
    String courseTitle,
    String courseId,
  ) async {
    try {
      print('Starting to notify users about new course: $courseTitle');
      // Get all registered users from authentication
      final usersSnapshot = await _database.ref().child('users').get();
      if (usersSnapshot.exists) {
        final data = usersSnapshot.value as Map<dynamic, dynamic>;
        print('Found ${data.length} users to notify');

        for (final entry in data.entries) {
          final userId = entry.key.toString();
          final userData = entry.value as Map<dynamic, dynamic>;

          // Don't notify the current user (course creator)
          if (userId != _auth.currentUser?.uid) {
            print('Sending notification to user: $userId');
            await addNotification(
              userId: userId,
              title: 'New Course Available! 📚',
              message:
                  '$courseTitle is now available for enrollment. Check it out!',
              type: 'course',
              relatedId: courseId,
            );
          } else {
            print('Skipping notification for course creator: $userId');
          }
        }
        print('Finished sending course notifications');
      } else {
        print('No users found in database');
      }
    } catch (e) {
      print('Error notifying new course: $e');
    }
  }

  // Notify all users about new post
  static Future<void> notifyNewPost(String authorName, String postId) async {
    try {
      print('Starting to notify users about new post from: $authorName');
      // Get all registered users from authentication
      final usersSnapshot = await _database.ref().child('users').get();
      if (usersSnapshot.exists) {
        final data = usersSnapshot.value as Map<dynamic, dynamic>;
        print('Found ${data.length} users to notify');

        for (final entry in data.entries) {
          final userId = entry.key.toString();
          final userData = entry.value as Map<dynamic, dynamic>;

          // Don't notify the current user (post creator)
          if (userId != _auth.currentUser?.uid) {
            print('Sending notification to user: $userId');
            await addNotification(
              userId: userId,
              title: 'New Post from YHA Admin! 📝',
              message: '$authorName shared a new post. Check it out!',
              type: 'post',
              relatedId: postId,
            );
          } else {
            print('Skipping notification for post creator: $userId');
          }
        }
        print('Finished sending post notifications');
      } else {
        print('No users found in database');
      }
    } catch (e) {
      print('Error notifying new post: $e');
    }
  }

  // Notify about new message
  static Future<void> notifyNewMessage({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await addNotification(
      userId: receiverId,
      title: 'New Message',
      message:
          '$senderName: ${message.length > 50 ? '${message.substring(0, 50)}...' : message}',
      type: 'message',
      relatedId: chatId,
    );
  }

  // Mark notification as read
  static Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _database
          .ref()
          .child('notifications')
          .child(userId)
          .child(notificationId)
          .child('read')
          .set(true);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark notification as read when user opens chat
  static Future<void> markChatNotificationsAsRead(
    String userId,
    String chatId,
  ) async {
    try {
      final snapshot = await _database
          .ref()
          .child('notifications')
          .child(userId)
          .orderByChild('type')
          .equalTo('message')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in data.entries) {
          final notificationData = entry.value as Map<dynamic, dynamic>;
          if (notificationData['relatedId'] == chatId &&
              notificationData['read'] == false) {
            await _database
                .ref()
                .child('notifications')
                .child(userId)
                .child(entry.key)
                .child('read')
                .set(true);
          }
        }
      }
    } catch (e) {
      print('Error marking chat notifications as read: $e');
    }
  }

  // Get unread count
  static Stream<int> getUnreadCount(String userId) {
    return _database
        .ref()
        .child('notifications')
        .child(userId)
        .orderByChild('read')
        .equalTo(false)
        .onValue
        .map((event) {
          if (!event.snapshot.exists) return 0;
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          return data.length;
        });
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _database
          .ref()
          .child('notifications')
          .child(userId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in data.entries) {
          await _database
              .ref()
              .child('notifications')
              .child(userId)
              .child(entry.key)
              .child('read')
              .set(true);
        }
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get user notifications stream
  static Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _database
        .ref()
        .child('notifications')
        .child(userId)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
          final List<NotificationModel> notifications = [];

          if (event.snapshot.exists) {
            final data = event.snapshot.value;

            // Handle different data types
            if (data is Map<dynamic, dynamic>) {
              for (final entry in data.entries) {
                final notificationData = entry.value;

                // Ensure notificationData is a Map
                if (notificationData is Map<dynamic, dynamic>) {
                  // Handle both 'message' and 'body' fields for compatibility
                  final message =
                      notificationData['message'] ??
                      notificationData['body'] ??
                      '';

                  // Handle timestamp properly
                  final timestamp = notificationData['timestamp'];
                  DateTime createdAt;
                  if (timestamp != null) {
                    if (timestamp is int) {
                      createdAt = DateTime.fromMillisecondsSinceEpoch(
                        timestamp,
                      );
                    } else {
                      createdAt = DateTime.now();
                    }
                  } else {
                    createdAt = DateTime.now();
                  }

                  notifications.add(
                    NotificationModel(
                      id: entry.key,
                      title: notificationData['title'] ?? '',
                      body: message,
                      type: notificationData['type'] ?? 'general',
                      isRead: notificationData['read'] ?? false,
                      createdAt: createdAt,
                      relatedId: notificationData['relatedId'],
                    ),
                  );
                }
              }
            }
          }

          // Sort by timestamp (newest first)
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  static Future<void> notifyPostLike(
    String likerName,
    String postId,
    String postCreatorId,
  ) async {
    try {
      final notificationRef = FirebaseDatabase.instance
          .ref()
          .child('notifications')
          .child(postCreatorId)
          .push();

      await notificationRef.set({
        'title': 'Your post was liked! ❤️',
        'message': '$likerName liked your post.',
        'body': '$likerName liked your post.',
        'type': 'like',
        'relatedId': postId,
        'read': false,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error sending like notification: $e');
    }
  }

  // Add notification for new event
  static Future<void> notifyNewEvent(String eventTitle, String eventId) async {
    try {
      print('Starting to notify users about new event: $eventTitle');
      final usersSnapshot = await _database.ref().child('users').get();
      if (usersSnapshot.exists) {
        final data = usersSnapshot.value as Map<dynamic, dynamic>;
        print('Found ${data.length} users to notify');

        for (final entry in data.entries) {
          final userId = entry.key.toString();
          final userData = entry.value as Map<dynamic, dynamic>;

          // Don't notify the current user (event creator)
          if (userId != _auth.currentUser?.uid) {
            print('Sending notification to user: $userId');
            await addNotification(
              userId: userId,
              title: 'New Event! 🎉',
              message: '$eventTitle is happening soon. Don\'t miss out!',
              type: 'event',
              relatedId: eventId,
            );
          } else {
            print('Skipping notification for event creator: $userId');
          }
        }
        print('Finished sending event notifications');
      } else {
        print('No users found in database');
      }
    } catch (e) {
      print('Error notifying new event: $e');
    }
  }
}

// Notification Model class
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
  });
}
