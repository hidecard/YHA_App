import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'admin/categories_screen.dart';
import 'admin/subjects_screen.dart';
import 'admin/instructors_screen.dart';
import 'admin/courses_management_screen.dart';
import 'admin/enrollments_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email == 'admin@yha.com' || user?.email == 'admin@gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: const Center(child: Text('Access denied. Admin only.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards
            _buildStatsSection(),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),

            const SizedBox(height: 24),

            // Management Section
            const Text(
              'Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildManagementGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref().onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

        int coursesCount = 0;
        int enrollmentsCount = 0;
        int categoriesCount = 0;
        int instructorsCount = 0;

        if (data != null) {
          coursesCount = (data['courses'] as Map?)?.length ?? 0;
          categoriesCount = (data['categories'] as Map?)?.length ?? 0;
          instructorsCount = (data['instructors'] as Map?)?.length ?? 0;

          // Count total enrollments
          if (data['enrollments'] != null) {
            final enrollments = data['enrollments'] as Map<dynamic, dynamic>;
            for (final courseEnrollments in enrollments.values) {
              if (courseEnrollments is Map) {
                enrollmentsCount += courseEnrollments.length;
              }
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Courses',
                coursesCount,
                Icons.school,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Enrollments',
                enrollmentsCount,
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Categories',
                categoriesCount,
                Icons.category,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Instructors',
                instructorsCount,
                Icons.person,
                Colors.purple,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
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
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'View Enrollments',
                Icons.assignment_ind,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EnrollmentsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Recent Enrollments',
                Icons.recent_actors,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EnrollmentsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Enrollment Analytics',
                Icons.analytics,
                Colors.purple,
                () => _showEnrollmentAnalytics(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Add Test Data',
                Icons.data_usage,
                Colors.blue,
                _addTestData,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementGrid() {
    final managementItems = [
      {
        'title': 'Courses',
        'icon': Icons.school,
        'color': Colors.blue,
        'screen': const CoursesManagementScreen(),
      },
      {
        'title': 'Enrollments',
        'icon': Icons.assignment_ind,
        'color': Colors.green,
        'screen': const EnrollmentsScreen(),
      },
      {
        'title': 'Categories',
        'icon': Icons.category,
        'color': Colors.orange,
        'screen': const CategoriesScreen(),
      },
      {
        'title': 'Subjects',
        'icon': Icons.subject,
        'color': Colors.teal,
        'screen': const SubjectsScreen(),
      },
      {
        'title': 'Instructors',
        'icon': Icons.person,
        'color': Colors.purple,
        'screen': const InstructorsScreen(),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: managementItems.length,
      itemBuilder: (context, index) {
        final item = managementItems[index];
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item['screen'] as Widget),
          ),
          child: Container(
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 48,
                  color: item['color'] as Color,
                ),
                const SizedBox(height: 12),
                Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addTestData() async {
    try {
      final db = FirebaseDatabase.instance.ref();

      // Add categories
      await db.child('categories').push().set({
        'name': 'Programming',
        'createdAt': ServerValue.timestamp,
      });

      await db.child('categories').push().set({
        'name': 'Design',
        'createdAt': ServerValue.timestamp,
      });

      // Add subjects
      await db.child('subjects').push().set({
        'name': 'Flutter',
        'createdAt': ServerValue.timestamp,
      });

      await db.child('subjects').push().set({
        'name': 'UI/UX',
        'createdAt': ServerValue.timestamp,
      });

      // Add instructors
      await db.child('instructors').push().set({
        'name': 'John Doe',
        'createdAt': ServerValue.timestamp,
      });

      await db.child('instructors').push().set({
        'name': 'Jane Smith',
        'createdAt': ServerValue.timestamp,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test data added successfully!')),
      );
    } catch (e) {
      print('Error adding test data: $e');
    }
  }

  void _showEnrollmentAnalytics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.purple[600]),
            const SizedBox(width: 8),
            const Text('Enrollment Analytics'),
          ],
        ),
        content: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref().child('enrollments').onValue,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Text('No enrollment data available');
            }

            final enrollmentsData =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            int totalEnrollments = 0;
            Map<String, int> courseEnrollments = {};
            Map<String, String> courseTitles = {};

            // Calculate analytics
            enrollmentsData.forEach((courseId, courseEnrollmentsData) {
              if (courseEnrollmentsData is Map) {
                final count = courseEnrollmentsData.length;
                totalEnrollments += count;
                courseEnrollments[courseId] = count;

                // Get course title if available
                if (courseEnrollmentsData.isNotEmpty) {
                  final firstEnrollment = courseEnrollmentsData.values.first;
                  if (firstEnrollment is Map &&
                      firstEnrollment['courseTitle'] != null) {
                    courseTitles[courseId] = firstEnrollment['courseTitle'];
                  }
                }
              }
            });

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Enrollments Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: Colors.blue[600], size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Enrollments',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              totalEnrollments.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Enrollments by Course
                  const Text(
                    'Enrollments by Course:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (courseEnrollments.isEmpty)
                    const Text(
                      'No course enrollments found',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...courseEnrollments.entries.map((entry) {
                      final courseTitle =
                          courseTitles[entry.key] ?? 'Course ${entry.key}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    courseTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Course ID: ${entry.key}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                '${entry.value} students',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EnrollmentsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
}
