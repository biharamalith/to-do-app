import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'sign_in_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String userName = "Loading...";
  String userEmail = "Loading...";
  String? userProfileImageBase64;
  int totalTasks = 0;
  int completedTasks = 0;
  int pendingTasks = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
    fetchTasks();
  }

  Future<void> fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('users/$uid');

      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          userName = data['name'] ?? 'No Name Found';
          userEmail = data['email'] ?? 'No Email Found';
          userProfileImageBase64 = data['profileImageBase64'] ?? null;
        });
      }
    }
  }

  Future<void> fetchTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid');

      ref.onValue.listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          // Flatten the nested structure: tasks/uid/{nestedId}/{taskId}
          final allTasks = <Map<dynamic, dynamic>>[];
          data.forEach((nestedId, tasksMap) {
            if (tasksMap is Map<dynamic, dynamic>) {
              tasksMap.forEach((taskId, taskData) {
                allTasks.add({
                  'id': taskId,
                  'nestedId': nestedId, // Store nestedId for use in updates
                  ...taskData as Map<dynamic, dynamic>,
                });
              });
            }
          });

          // Debugging: Print the tasks to inspect the data
          print("All Tasks (MyProfileScreen): $allTasks");

          setState(() {
            totalTasks = allTasks.length;
            completedTasks = allTasks.where((task) {
              final completed = task['completed'];
              if (completed == null) return false;
              if (completed is String) return completed.toLowerCase() == 'true';
              return completed == true;
            }).length;
            pendingTasks = totalTasks - completedTasks;

            // Debugging: Print the counts
            print("MyProfileScreen - Total Tasks: $totalTasks, Completed Tasks: $completedTasks, Pending Tasks: $pendingTasks");
          });
        } else {
          setState(() {
            totalTasks = 0;
            completedTasks = 0;
            pendingTasks = 0;
          });
          print("No tasks found for user $uid (MyProfileScreen)");
        }
      });
    }
  }

  Future<void> _pickAndProcessImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    // Crop the image
    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color(0xFF7A12FF),
          toolbarWidgetColor: Colors.white,
          backgroundColor: const Color(0xFF1A1A2F),
        ),
      ],
    );
    if (croppedFile == null) return;

    // Read the cropped image as bytes
    final Uint8List imageBytes = await croppedFile.readAsBytes();

    // Decode the image for compression
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return;

    // Compress the image (resize to 200x200 and reduce quality)
    img.Image resizedImage = img.copyResize(image, width: 200, height: 200);
    final compressedBytes = img.encodeJpg(resizedImage, quality: 85);

    // Convert to base64
    final String base64Image = base64Encode(compressedBytes);

    // Save to Firebase Realtime Database
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('users/$uid');
      await ref.update({'profileImageBase64': base64Image});

      // Update the UI
      setState(() {
        userProfileImageBase64 = base64Image;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Profile",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    backgroundImage: userProfileImageBase64 != null
                        ? MemoryImage(base64Decode(userProfileImageBase64!))
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                    radius: 48,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndProcessImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF7A12FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                userName,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Center(
              child: Text(
                userEmail,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: IconButton(
                onPressed: _signOut,
                icon: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 30,
                ),
                tooltip: 'Logout',
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: totalTasks > 0 ? completedTasks / totalTasks : 0,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7A12FF)),
                        ),
                      ),
                      Text(
                        totalTasks.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "TOTAL TASKS",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.hourglass_empty,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Pending",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pendingTasks.toString().padLeft(2, '0'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 32),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Completed",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        completedTasks.toString().padLeft(2, '0'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}