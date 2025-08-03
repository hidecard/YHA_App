import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_detail_screen.dart';
import 'group_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Modern Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFFFF6B01), const Color(0xFFFF852D)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.chat_bubble,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messages',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Connect with instructors and students',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.search, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Chat List
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFFF6B01),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  Widget _buildChatList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('chats')
          .orderByChild('lastMessageTime')
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = <Map<String, dynamic>>[];

        // Get direct chats
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          data.forEach((key, value) {
            final chatData = value as Map<dynamic, dynamic>;
            final participants =
                chatData['participants'] as Map<dynamic, dynamic>?;

            if (participants != null &&
                participants.containsKey(currentUser.uid)) {
              // Check if it's a direct chat (2 participants) or group chat
              if (chatData['type'] == 'group' || participants.length > 2) {
                // Group chat
                chats.add({
                  'chatId': key,
                  'name': chatData['groupName'] ?? 'Group Chat',
                  'message': chatData['lastMessage'] ?? 'No messages yet',
                  'time': _formatTime(chatData['lastMessageTime']),
                  'unread': chatData['unreadCount_${currentUser.uid}'] ?? 0,
                  'isGroup': true,
                  'otherUserId': '',
                });
              } else {
                // Direct chat
                String otherUserId = '';
                String otherUserName = 'Unknown';

                participants.forEach((userId, userInfo) {
                  if (userId != currentUser.uid) {
                    otherUserId = userId;
                    final userInfoMap = userInfo as Map<dynamic, dynamic>;
                    otherUserName = userInfoMap['name'] ?? 'Unknown';
                  }
                });

                chats.add({
                  'chatId': key,
                  'otherUserId': otherUserId,
                  'name': otherUserName,
                  'message': chatData['lastMessage'] ?? 'No messages yet',
                  'time': _formatTime(chatData['lastMessageTime']),
                  'unread': chatData['unreadCount_${currentUser.uid}'] ?? 0,
                  'isGroup': false,
                });
              }
            }
          });
        }

        // Get group chats from separate node
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref().child('group_chats').onValue,
          builder: (context, groupSnapshot) {
            if (groupSnapshot.hasData &&
                groupSnapshot.data!.snapshot.value != null) {
              final groupData =
                  groupSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;

              groupData.forEach((key, value) {
                final groupChatData = value as Map<dynamic, dynamic>;
                final members = groupChatData['members'] as List<dynamic>?;

                if (members != null && members.contains(currentUser.uid)) {
                  chats.add({
                    'chatId': key,
                    'name': groupChatData['name'] ?? 'Group Chat',
                    'message': groupChatData['lastMessage'] ?? 'Group created',
                    'time': _formatTime(groupChatData['lastMessageTime']),
                    'unread': 0,
                    'isGroup': true,
                    'otherUserId': '',
                  });
                }
              });
            }

            if (chats.isEmpty) {
              return const Center(
                child: Text('No chats yet. Start a conversation!'),
              );
            }

            // Sort by last message time
            chats.sort((a, b) => b['time'].compareTo(a['time']));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (chat['isGroup']) {
                          // Reset unread count for group chat
                          FirebaseDatabase.instance
                              .ref()
                              .child('group_chats')
                              .child(chat['chatId'])
                              .child('unreadCount_${currentUser.uid}')
                              .set(0);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupChatScreen(
                                groupId: chat['chatId'],
                                groupName: chat['name'],
                              ),
                            ),
                          );
                        } else {
                          // Reset unread count for direct chat
                          FirebaseDatabase.instance
                              .ref()
                              .child('chats')
                              .child(chat['chatId'])
                              .child('unreadCount_${currentUser.uid}')
                              .set(0);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailScreen(
                                chatId: chat['chatId'],
                                otherUserId: chat['otherUserId'],
                                otherUserName: chat['name'],
                              ),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: chat['isGroup']
                                  ? Colors.green[100]
                                  : Colors.purple[100],
                              child: Icon(
                                chat['isGroup'] ? Icons.group : Icons.person,
                                color: chat['isGroup']
                                    ? Colors.green[600]
                                    : Colors.purple[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (chat['isGroup'])
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            'Group',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chat['message'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  chat['time'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                if (chat['unread'] > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red[600],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${chat['unread']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
