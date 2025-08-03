import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyEnrollmentsScreen extends StatefulWidget {
  const MyEnrollmentsScreen({super.key});

  @override
  State<MyEnrollmentsScreen> createState() => _MyEnrollmentsScreenState();
}

class _MyEnrollmentsScreenState extends State<MyEnrollmentsScreen> {
  String? _selectedCourse;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Courses'),
        backgroundColor: const Color(0xFFFF6B01),
        foregroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Course Filter (optional)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref().child('courses').onValue,
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
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: const Color(0xFFFF6B01)),
                    ),
                  ),
                  items: courses,
                  onChanged: (value) => setState(() => _selectedCourse = value),
                );
              },
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
                    snapshot.data!.snapshot.value == null ||
                    _userId == null) {
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
                List<Map<String, dynamic>> myEnrollments = [];
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
                // Filter by selected course
                if (_selectedCourse != null) {
                  myEnrollments = myEnrollments
                      .where(
                        (enrollment) =>
                            enrollment['courseId'] == _selectedCourse,
                      )
                      .toList();
                }
                // Sort by enrollment date
                myEnrollments.sort((a, b) {
                  final aTime = a['enrollmentData']['enrolledAt'] ?? 0;
                  final bTime = b['enrollmentData']['enrolledAt'] ?? 0;
                  return bTime.compareTo(aTime);
                });
                if (myEnrollments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No enrollments for selected course',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: myEnrollments.length,
                  itemBuilder: (context, index) {
                    final enrollment = myEnrollments[index];
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
            child: Row(
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
                // Enrollment Info
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
                      _buildStatusBadge(enrollmentData['status'] ?? 'pending'),
                    ],
                  ),
                ),
                // Enrollment Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(enrollmentData['enrolledAt']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(enrollmentData['enrolledAt']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
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
        backgroundColor = const Color(0xFFFF852D).withOpacity(0.15);
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
}
