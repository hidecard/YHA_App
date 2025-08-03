import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EnrollmentsScreen extends StatefulWidget {
  const EnrollmentsScreen({super.key});

  @override
  State<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends State<EnrollmentsScreen> {
  String? _selectedCourse;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Courses'),
        backgroundColor: const Color(0xFFFF6B01),
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by student name or email...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: const Color(0xFFFF6B01)),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 16),
                // Course Filter
                StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref()
                      .child('courses')
                      .onValue,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return const SizedBox.shrink();
                    }

                    final data =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    final courses = data.entries.map((e) {
                      final courseData = e.value as Map<dynamic, dynamic>;
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(courseData['title'] ?? 'Unknown Course'),
                      );
                    }).toList();

                    courses.insert(
                      0,
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Courses'),
                      ),
                    );

                    return DropdownButtonFormField<String>(
                      value: _selectedCourse,
                      decoration: InputDecoration(
                        labelText: 'Filter by Course',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: const Color(0xFFFF6B01),
                          ),
                        ),
                      ),
                      items: courses,
                      onChanged: (value) =>
                          setState(() => _selectedCourse = value),
                    );
                  },
                ),
              ],
            ),
          ),

          // Enrollments List
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('enrollments')
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_ind,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No enrollments found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final enrollmentsData =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<Map<String, dynamic>> allEnrollments = [];

                // Flatten enrollments data
                enrollmentsData.forEach((courseId, courseEnrollments) {
                  if (courseEnrollments is Map) {
                    courseEnrollments.forEach((userId, enrollmentData) {
                      if (enrollmentData is Map) {
                        allEnrollments.add({
                          'courseId': courseId,
                          'userId': userId,
                          'enrollmentData': enrollmentData,
                        });
                      }
                    });
                  }
                });

                // Filter by selected course
                if (_selectedCourse != null) {
                  allEnrollments = allEnrollments
                      .where(
                        (enrollment) =>
                            enrollment['courseId'] == _selectedCourse,
                      )
                      .toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  allEnrollments = allEnrollments.where((enrollment) {
                    final enrollmentData =
                        enrollment['enrollmentData'] as Map<dynamic, dynamic>;
                    final userName =
                        enrollmentData['userName']?.toString().toLowerCase() ??
                        '';
                    final userEmail =
                        enrollmentData['userEmail']?.toString().toLowerCase() ??
                        '';
                    final query = _searchQuery.toLowerCase();
                    return userName.contains(query) ||
                        userEmail.contains(query);
                  }).toList();
                }

                // Sort by enrollment date
                allEnrollments.sort((a, b) {
                  final aTime = a['enrollmentData']['enrolledAt'] ?? 0;
                  final bTime = b['enrollmentData']['enrolledAt'] ?? 0;
                  return bTime.compareTo(aTime);
                });

                if (allEnrollments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No enrollments found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allEnrollments.length,
                  itemBuilder: (context, index) {
                    final enrollment = allEnrollments[index];
                    return _buildEnrollmentCard(enrollment);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentCard(Map<String, dynamic> enrollment) {
    final courseId = enrollment['courseId'];
    final enrollmentData =
        enrollment['enrollmentData'] as Map<dynamic, dynamic>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref()
            .child('courses')
            .child(courseId)
            .onValue,
        builder: (context, courseSnapshot) {
          if (!courseSnapshot.hasData ||
              courseSnapshot.data!.snapshot.value == null) {
            return const SizedBox.shrink();
          }

          final courseData =
              courseSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Course Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: courseData['imageUrl'] != null
                          ? CachedNetworkImage(
                              imageUrl: courseData['imageUrl'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: const Color(0xFFFF852D).withOpacity(0.2),
                              child: const Icon(
                                Icons.school,
                                color: Color(0xFFFF6B01),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),

                    // Course Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseData['title'] ?? 'Unknown Course',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (courseData['category'] != null)
                            Text(
                              'Category: ${courseData['category']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Status Badge
                    _buildStatusBadge(enrollmentData['status'] ?? 'pending'),
                  ],
                ),

                const Divider(height: 24),

                // Student Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFFF852D).withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFFFF6B01),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enrollmentData['userName'] ?? 'Unknown Student',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            enrollmentData['userEmail'] ?? 'No email',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (enrollmentData['phoneNumber'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Phone: ${enrollmentData['phoneNumber']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Enrollment Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Enrolled on',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          _formatDate(enrollmentData['enrolledAt']),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          _formatTime(enrollmentData['enrolledAt']),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Additional Information
                if (enrollmentData['address'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (enrollmentData['address'] != null) ...[
                          _buildInfoRow('Address', enrollmentData['address']),
                        ],
                      ],
                    ),
                  ),
                ],

                // Admin Actions
                if ((enrollmentData['status'] ?? 'pending') == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveEnrollment(
                            courseId,
                            enrollmentData['userId'],
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B01),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejectEnrollment(
                            courseId,
                            enrollmentData['userId'],
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        statusText = 'Approved';
        break;
      case 'rejected':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        statusText = 'Rejected';
        break;
      case 'pending':
      default:
        backgroundColor = const Color(0xFFFF852D).withOpacity(0.2);
        textColor = const Color(0xFFFF6B01);
        statusText = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveEnrollment(String courseId, String userId) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('enrollments')
          .child(courseId)
          .child(userId)
          .update({
            'status': 'approved',
            'adminApproved': true,
            'adminApprovedAt': ServerValue.timestamp,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enrollment approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving enrollment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectEnrollment(String courseId, String userId) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Enrollment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this enrollment?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('enrollments')
            .child(courseId)
            .child(userId)
            .update({
              'status': 'rejected',
              'adminApproved': false,
              'adminApprovedAt': ServerValue.timestamp,
              'adminNotes': notesController.text.trim(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enrollment rejected successfully!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting enrollment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
