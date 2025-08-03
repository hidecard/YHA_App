import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseCreateScreen extends StatefulWidget {
  const CourseCreateScreen({super.key});

  @override
  State<CourseCreateScreen> createState() => _CourseCreateScreenState();
}

class _CourseCreateScreenState extends State<CourseCreateScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();
  final _feeController = TextEditingController();
  
  String? _selectedCategoryName;
  String? _selectedInstructorName;
  List<String> _selectedSubjects = [];
  File? _imageFile;
  bool _loading = false;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileName = 'courses/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _createCourse() async {
    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty ||
        _selectedCategoryName == null ||
        _selectedInstructorName == null) {
      setState(() => _error = 'Please fill all required fields');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? imageUrl;
      
      // Upload image if selected
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // Create course
      final courseRef = FirebaseDatabase.instance.ref().child('courses').push();
      final courseData = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'date': _dateController.text.trim(),
        'fee': _feeController.text.trim(),
        'category': _selectedCategoryName,
        'subjects': _selectedSubjects,
        'instructor': _selectedInstructorName,
        'imageUrl': imageUrl,
        'createdAt': ServerValue.timestamp,
        'status': 'active',
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      };

      await courseRef.set(courseData);
      
      // Register current user if not exists
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(currentUser.uid)
            .set({
          'email': currentUser.email,
          'name': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'User',
          'lastActive': ServerValue.timestamp,
        });
      }
      
      // Send notification to all users about new course
      await NotificationService.notifyNewCourse(
        _titleController.text.trim(),
        courseRef.key!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Error creating course: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Course'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red[700])),
              ),

            // Course Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Course Title *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Date
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Start Date',
                border: OutlineInputBorder(),
                hintText: 'e.g., Aug 15, 2024',
              ),
            ),
            const SizedBox(height: 16),

            // Fee
            TextField(
              controller: _feeController,
              decoration: const InputDecoration(
                labelText: 'Course Fee',
                border: OutlineInputBorder(),
                hintText: 'e.g., $99 or Free',
              ),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref().child('categories').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const CircularProgressIndicator();
                }
                
                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final categories = data.entries.map((e) {
                  final categoryData = e.value as Map<dynamic, dynamic>;
                  return categoryData['name'] as String;
                }).toList();

                return DropdownButtonFormField<String>(
                  value: _selectedCategoryName,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: categories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCategoryName = value),
                );
              },
            ),
            const SizedBox(height: 16),

            // Instructor Dropdown
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref().child('instructors').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const CircularProgressIndicator();
                }
                
                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final instructors = data.entries.map((e) {
                  final instructorData = e.value as Map<dynamic, dynamic>;
                  return instructorData['name'] as String;
                }).toList();

                return DropdownButtonFormField<String>(
                  value: _selectedInstructorName,
                  decoration: const InputDecoration(
                    labelText: 'Instructor *',
                    border: OutlineInputBorder(),
                  ),
                  items: instructors.map((instructor) => DropdownMenuItem(
                    value: instructor,
                    child: Text(instructor),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedInstructorName = value),
                );
              },
            ),
            const SizedBox(height: 16),

            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Tap to add course image', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _createCourse,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Course', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _feeController.dispose();
    super.dispose();
  }
}
