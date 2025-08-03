import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:typed_data';

class CourseEditScreen extends StatefulWidget {
  final String courseId;
  final dynamic courseData;

  const CourseEditScreen({super.key, required this.courseId, this.courseData});

  @override
  State<CourseEditScreen> createState() => _CourseEditScreenState();
}

class _CourseEditScreenState extends State<CourseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();
  final _feeController = TextEditingController();

  String? _selectedCategoryName;
  String? _selectedInstructorName;
  List<String> _selectedSubjects = [];
  File? _imageFile;
  Uint8List? _webImageBytes;
  String? _currentImageUrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.courseData != null) {
      _setControllersFromData(widget.courseData);
    } else {
      _loadCourseData();
    }
  }

  void _setControllersFromData(Map<dynamic, dynamic> courseData) {
    _titleController.text = courseData['title'] ?? '';
    _descController.text = courseData['description'] ?? '';
    _dateController.text = courseData['date'] ?? '';
    _feeController.text = courseData['fee'] ?? '';
    _selectedCategoryName = courseData['category'];
    _selectedInstructorName = courseData['instructor'];
    _currentImageUrl = courseData['imageUrl'];
    if (courseData['subjects'] != null) {
      _selectedSubjects = List<String>.from(courseData['subjects']);
    }
    setState(() {});
  }

  Future<void> _loadCourseData() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('courses')
          .child(widget.courseId)
          .get();

      if (snapshot.exists) {
        final courseData = snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _titleController.text = courseData['title'] ?? '';
          _descController.text = courseData['description'] ?? '';
          _dateController.text = courseData['date'] ?? '';
          _feeController.text = courseData['fee'] ?? '';
          _selectedCategoryName = courseData['category'];
          _selectedInstructorName = courseData['instructor'];
          _currentImageUrl = courseData['imageUrl'];

          if (courseData['subjects'] != null) {
            _selectedSubjects = List<String>.from(courseData['subjects']);
          }
        });
      }
    } catch (e) {
      print('Error loading course data: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<String?> _uploadImage(File file) async {
    try {
      print('Starting image upload...');
      final fileName = 'course_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('course_images')
          .child(fileName);

      UploadTask uploadTask;
      if (kIsWeb && _webImageBytes != null) {
        uploadTask = ref.putData(
          _webImageBytes!,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploaded_by':
                  FirebaseAuth.instance.currentUser?.email ?? 'unknown',
              'upload_time': DateTime.now().toIso8601String(),
            },
          ),
        );
      } else {
        uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploaded_by':
                  FirebaseAuth.instance.currentUser?.email ?? 'unknown',
              'upload_time': DateTime.now().toIso8601String(),
            },
          ),
        );
      }

      final snapshot = await uploadTask;
      final downloadURL = await snapshot.ref.getDownloadURL();

      print('Image uploaded successfully: $downloadURL');
      return downloadURL;
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          _webImageBytes = await pickedFile.readAsBytes();
        }
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        print('Image picked successfully: ${pickedFile.path}');
      }
    } catch (e) {
      print('Image picker error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _updateCourse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjects.isEmpty) {
      setState(() => _error = 'Please select at least one subject');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String? imageUrl = _currentImageUrl;

      // Upload new image if selected
      if (_imageFile != null) {
        print('Uploading new image...');
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
        print('New image URL: $imageUrl');
      }

      // Update course data
      final courseData = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'date': _dateController.text.trim(),
        'fee': _feeController.text.trim(),
        'category': _selectedCategoryName,
        'subjects': _selectedSubjects,
        'instructor': _selectedInstructorName,
        'imageUrl': imageUrl,
        'updatedAt': ServerValue.timestamp,
        'status': 'active',
      };

      print('Updating course data: $courseData');

      await FirebaseDatabase.instance
          .ref()
          .child('courses')
          .child(widget.courseId)
          .update(courseData);

      print('Course updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating course: $e');
      setState(() => _error = 'Error updating course: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Image',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildImageWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget() {
    if (_imageFile != null) {
      // New image selected
      return kIsWeb && _webImageBytes != null
          ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
          : Image.file(_imageFile!, fit: BoxFit.cover);
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      // Current image from database
      return CachedNetworkImage(
        imageUrl: _currentImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 50, color: Colors.grey),
            Text(
              'Current image not available',
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              'Tap to select new image',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    } else {
      // No image
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
          Text('Tap to select image', style: TextStyle(color: Colors.grey)),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Course'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Course Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Please enter course title' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty == true ? 'Please enter description' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Please enter date' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _feeController,
                decoration: const InputDecoration(
                  labelText: 'Fee',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Please enter fee' : null,
              ),
              const SizedBox(height: 12),

              // Category Dropdown
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref()
                    .child('categories')
                    .onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return const CircularProgressIndicator();
                  }

                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  final categories = data.entries.map((e) {
                    final categoryData = e.value as Map<dynamic, dynamic>;
                    return DropdownMenuItem<String>(
                      value: categoryData['name'],
                      child: Text(categoryData['name']),
                    );
                  }).toList();

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCategoryName,
                    items: categories,
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryName = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a category' : null,
                  );
                },
              ),
              const SizedBox(height: 12),

              // Subjects Multi-select
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref()
                    .child('subjects')
                    .onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return const CircularProgressIndicator();
                  }

                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  final subjects = data.entries.map((e) {
                    final subjectData = e.value as Map<dynamic, dynamic>;
                    return subjectData['name'] as String;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Subjects', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Wrap(
                        children: subjects.map((subject) {
                          return CheckboxListTile(
                            title: Text(subject),
                            value: _selectedSubjects.contains(subject),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedSubjects.add(subject);
                                } else {
                                  _selectedSubjects.remove(subject);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Instructor Dropdown
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref()
                    .child('instructors')
                    .onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return const CircularProgressIndicator();
                  }

                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  final instructors = data.entries.map((e) {
                    final instructorData = e.value as Map<dynamic, dynamic>;
                    return DropdownMenuItem<String>(
                      value: instructorData['name'],
                      child: Text(instructorData['name']),
                    );
                  }).toList();

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Instructor',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedInstructorName,
                    items: instructors,
                    onChanged: (value) {
                      setState(() {
                        _selectedInstructorName = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select an instructor' : null,
                  );
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _updateCourse,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Update Course'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
