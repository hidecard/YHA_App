import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'create_post_screen.dart';
import '../services/notification_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _selectedCategory;
  String? _selectedSubject;
  bool _showCreatePostDialog = false;

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

  // Like/Unlike post functionality with user tracking
  Future<void> _toggleLike(
    String postId,
    int currentLikes,
    List<String> likedBy,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userId = currentUser.uid;
      final isLiked = likedBy.contains(userId);

      if (isLiked) {
        // Unlike
        likedBy.remove(userId);
        await FirebaseDatabase.instance
            .ref()
            .child('posts')
            .child(postId)
            .update({'likes': currentLikes - 1, 'likedBy': likedBy});
      } else {
        // Like
        likedBy.add(userId);
        await FirebaseDatabase.instance
            .ref()
            .child('posts')
            .child(postId)
            .update({'likes': currentLikes + 1, 'likedBy': likedBy});

        // Send notification to post creator
        final postSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('posts')
            .child(postId)
            .get();

        if (postSnapshot.exists) {
          final postData = postSnapshot.value as Map<dynamic, dynamic>;
          final postCreatorId = postData['authorId'] ?? postData['createdBy'];

          if (postCreatorId != currentUser.uid) {
            await NotificationService.notifyPostLike(
              currentUser.displayName ??
                  currentUser.email?.split('@')[0] ??
                  'Someone',
              postId,
              postCreatorId,
            );
          }
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  // Show comments bottom sheet
  void _showComments(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(postId: postId),
    );
  }

  // Show user profile dialog
  void _showUserProfile(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue[100],
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'User ID: $userId',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('View Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.article),
                    label: const Text('View Posts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show post options dialog
  void _showPostOptions(String postId, String createdBy, String title) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Post'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Share functionality coming soon!'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report Post'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted!')),
                );
              },
            ),
            if (createdBy == currentUser.uid) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit functionality coming soon!'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Post'),
                      content: Text(
                        'Are you sure you want to delete "$title"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await FirebaseDatabase.instance
                          .ref()
                          .child('posts')
                          .child(postId)
                          .remove();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Post deleted successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting post: $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.feed,
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
                                  'Community Feed',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Share and discover posts',
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CreatePostScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filter Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Filter by category',
                                  hintStyle: TextStyle(color: Colors.white70),
                                  icon: Icon(
                                    Icons.category,
                                    color: Colors.white,
                                  ),
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: Colors.black87),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Categories'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'General',
                                    child: Text('General'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Programming',
                                    child: Text('Programming'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Design',
                                    child: Text('Design'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Business',
                                    child: Text('Business'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Technology',
                                    child: Text('Technology'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Education',
                                    child: Text('Education'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'News',
                                    child: Text('News'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Announcement',
                                    child: Text('Announcement'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedSubject,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Filter by subject',
                                  hintStyle: TextStyle(color: Colors.white70),
                                  icon: Icon(
                                    Icons.subject,
                                    color: Colors.white,
                                  ),
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: Colors.black87),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Subjects'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'General',
                                    child: Text('General'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Flutter',
                                    child: Text('Flutter'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'React',
                                    child: Text('React'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Python',
                                    child: Text('Python'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'JavaScript',
                                    child: Text('JavaScript'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Java',
                                    child: Text('Java'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'C++',
                                    child: Text('C++'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'HTML/CSS',
                                    child: Text('HTML/CSS'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Database',
                                    child: Text('Database'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Mobile Development',
                                    child: Text('Mobile Development'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'Web Development',
                                    child: Text('Web Development'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSubject = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Feed List
            Expanded(child: _buildFeedList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: const Color(0xFFFF6B01),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFeedList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('posts')
          .orderByChild('timestamp')
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = <Map<String, dynamic>>[];

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          data.forEach((key, value) {
            final postData = value as Map<dynamic, dynamic>;

            // Filter by selected category and subject if any
            bool shouldInclude = true;
            if (_selectedCategory != null &&
                postData['category'] != _selectedCategory) {
              shouldInclude = false;
            }
            if (_selectedSubject != null &&
                postData['subject'] != _selectedSubject) {
              shouldInclude = false;
            }

            if (shouldInclude) {
              final likedBy = postData['likedBy'] != null
                  ? List<String>.from(postData['likedBy'])
                  : <String>[];

              posts.add({
                'postId': key,
                'title': postData['title'] ?? 'Post',
                'content': postData['content'] ?? '',
                'imageUrl': postData['imageUrl'],
                'category': postData['category'] ?? 'General',
                'subject': postData['subject'] ?? 'General',
                'createdBy': postData['createdBy'] ?? postData['authorId'],
                'createdAt': postData['createdAt'] ?? postData['timestamp'],
                'userName':
                    postData['userName'] ??
                    postData['authorName'] ??
                    'Anonymous',
                'likes': postData['likes'] ?? 0,
                'comments': postData['comments'] ?? 0,
                'isAdminPost': postData['isAdminPost'] ?? false,
                'likedBy': likedBy,
              });
            }
          });
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _selectedCategory != null || _selectedSubject != null
                      ? 'No posts match your filters'
                      : 'No posts yet. Be the first to share!',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Sort by creation time (newest first)
        posts.sort(
          (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
        );

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final isLiked = post['likedBy'].contains(currentUser!.uid);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post Image
                  if (post['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: post['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),

                  // Post Details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showUserProfile(
                                post['createdBy'],
                                post['userName'],
                              ),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: post['isAdminPost']
                                    ? const Color(0xFFFF852D).withOpacity(0.2)
                                    : Colors.blue[100],
                                child: post['isAdminPost']
                                    ? const Icon(
                                        Icons.admin_panel_settings,
                                        size: 16,
                                        color: Color(0xFFFF6B01),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.blue[600],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _showUserProfile(
                                      post['createdBy'],
                                      post['userName'],
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          post['userName'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (post['isAdminPost']) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFF852D,
                                              ).withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'ADMIN',
                                              style: TextStyle(
                                                color: Color(0xFFFF6B01),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatTime(post['createdAt']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'options') {
                                  _showPostOptions(
                                    post['postId'],
                                    post['createdBy'],
                                    post['title'],
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'options',
                                  child: Row(
                                    children: [
                                      Icon(Icons.more_vert),
                                      SizedBox(width: 8),
                                      Text('More Options'),
                                    ],
                                  ),
                                ),
                              ],
                              child: const Icon(
                                Icons.more_vert,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                post['category'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                post['subject'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (post['content'].isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            post['content'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleLike(
                                post['postId'],
                                post['likes'],
                                List<String>.from(post['likedBy']),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 16,
                                    color: isLiked
                                        ? Colors.red
                                        : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post['likes']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLiked
                                          ? Colors.red
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _showComments(post['postId']),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.comment,
                                    size: 16,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post['comments']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Share functionality coming soon!',
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.share,
                                size: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

// Comments Bottom Sheet Widget
class CommentsBottomSheet extends StatefulWidget {
  final String postId;

  const CommentsBottomSheet({super.key, required this.postId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final commentRef = FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(widget.postId)
          .child('comments')
          .push();

      await commentRef.set({
        'content': _commentController.text.trim(),
        'authorId': currentUser.uid,
        'authorName':
            currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            'Anonymous',
        'timestamp': ServerValue.timestamp,
      });

      // Update comment count
      final postRef = FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(widget.postId);

      final postSnapshot = await postRef.get();
      if (postSnapshot.exists) {
        final postData = postSnapshot.value as Map<dynamic, dynamic>;
        final currentComments = postData['comments'] ?? 0;
        await postRef.update({'comments': currentComments + 1});
      }

      _commentController.clear();

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding comment: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('posts')
                  .child(widget.postId)
                  .child('comments')
                  .orderByChild('timestamp')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = <Map<String, dynamic>>[];

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                  data.forEach((key, value) {
                    final commentData = value as Map<dynamic, dynamic>;
                    comments.add({
                      'commentId': key,
                      'content': commentData['content'] ?? '',
                      'authorName': commentData['authorName'] ?? 'Anonymous',
                      'timestamp': commentData['timestamp'],
                    });
                  });
                }

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              comment['authorName'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      comment['authorName'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(comment['timestamp']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['content'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send),
                  color: const Color(0xFFFF6B01),
                ),
              ],
            ),
          ),
        ],
      ),
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
