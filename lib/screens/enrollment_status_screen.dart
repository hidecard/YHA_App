import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EnrollmentStatusScreen extends StatefulWidget {
  const EnrollmentStatusScreen({super.key});

  @override
  State<EnrollmentStatusScreen> createState() => _EnrollmentStatusScreenState();
}

class _EnrollmentStatusScreenState extends State<EnrollmentStatusScreen> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Enrollment Status'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0.5,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref().child('enrollments').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_ind, size: 64, color: Colors.grey),
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
          List<Map<String, dynamic>> myEnrollments = [];

          if (_userId != null) {
            enrollmentsData.forEach((courseId, courseEnrollments) {
              if (courseEnrollments is Map &&
                  courseEnrollments[_userId] != null) {
                final enrollmentData = courseEnrollments[_userId];
                if (enrollmentData is Map) {
                  myEnrollments.add({
                    'courseId': courseId,
                    'enrollmentData': enrollmentData,
                  });
                }
              }
            });
          }

          // Sort by enrollment date
          myEnrollments.sort((a, b) {
            final aTime = a['enrollmentData']['enrolledAt'] ?? 0;
            final bTime = b['enrollmentData']['enrolledAt'] ?? 0;
            return bTime.compareTo(aTime);
          });

          if (myEnrollments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_ind, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No enrollments found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enroll in a course to see your status here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myEnrollments.length,
            itemBuilder: (context, index) {
              final enrollment = myEnrollments[index];
              return _buildEnrollmentStatusCard(enrollment);
            },
          );
        },
      ),
    );
  }

  Widget _buildEnrollmentStatusCard(Map<String, dynamic> enrollment) {
    final courseId = enrollment['courseId'];
    final enrollmentData =
        enrollment['enrollmentData'] as Map<dynamic, dynamic>;
    final status = enrollmentData['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                // Course Header
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
                              color: Colors.blue[100],
                              child: const Icon(
                                Icons.school,
                                color: Colors.blue,
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
                          if (courseData['instructor'] != null)
                            Text(
                              'Instructor: ${courseData['instructor']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Status Badge
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 16),

                // Status Details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusTitle(status),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getStatusDescription(status),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      if (status == 'rejected' &&
                          enrollmentData['adminNotes'] != null &&
                          enrollmentData['adminNotes']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rejection Reason:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                enrollmentData['adminNotes'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Enrollment Date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Enrolled on: ${_formatDate(enrollmentData['enrolledAt'])}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),

                if (enrollmentData['adminApprovedAt'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Processed on: ${_formatDate(enrollmentData['adminApprovedAt'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  String _getStatusTitle(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Enrollment Approved';
      case 'rejected':
        return 'Enrollment Rejected';
      case 'pending':
      default:
        return 'Under Review';
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Your enrollment has been approved by the administrator. You can now access the course materials.';
      case 'rejected':
        return 'Your enrollment has been rejected. Please review the reason below and contact support if needed.';
      case 'pending':
      default:
        return 'Your enrollment is currently under review by the administrator. You will be notified once a decision is made.';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
