import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'tasks_screen.dart';
import 'my_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "Loading...";
  String? userProfileImageBase64;
  int _selectedIndex = 0; // Default to 0 to show HomeScreenContent
  final TextEditingController _taskController = TextEditingController();
  List<Map<dynamic, dynamic>> _allTasks = [];
  List<Map<dynamic, dynamic>> _todayTasks = [];
  List<Map<dynamic, dynamic>> _completedTasks = [];

  // Variables for start and end times
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    // Set system navigation bar color to match the bottom navigation bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF2A2A40),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
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
          userProfileImageBase64 = data['profileImageBase64'] ?? null;
        });
      } else {
        setState(() {
          userName = "No Name Found";
          userProfileImageBase64 = null;
        });
      }
    }
  }

  Future<void> fetchTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid');

      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final allTasks = data.entries.map((entry) {
          return {
            'id': entry.key,
            ...entry.value as Map<dynamic, dynamic>,
          };
        }).toList();

        // Filter tasks for "Today Tasks" and "Completed Tasks"
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        setState(() {
          _allTasks = allTasks;
          _todayTasks = allTasks.where((task) {
            final taskDate = DateTime.parse(task['createdAt']);
            return taskDate.year == today.year &&
                taskDate.month == today.month &&
                taskDate.day == today.day &&
                task['completed'] != true;
          }).toList();
          _completedTasks = allTasks.where((task) {
            return task['completed'] == true;
          }).toList();
        });
      }
    }
  }

  Future<List<Map<dynamic, dynamic>>> addTask(String task, TimeOfDay? startTime, TimeOfDay? endTime) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid').push();
      await ref.set({
        'task': task,
        'createdAt': DateTime.now().toIso8601String(),
        'completed': false,
        'category': 'today',
        'startTime': startTime != null ? "${startTime.hour}:${startTime.minute}" : null,
        'endTime': endTime != null ? "${endTime.hour}:${startTime?.minute}" : null,
      });
      await fetchTasks();
      return _allTasks;
    }
    return [];
  }

  Future<void> toggleTaskCompletion(String taskId, bool currentStatus) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid/$taskId');
      await ref.update({'completed': !currentStatus});
      await fetchTasks();
    }
  }

  Future<void> deleteTask(String taskId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid/$taskId');
      await ref.remove();
      await fetchTasks();
    }
  }

  void _showAddTaskDialog(BuildContext context) {
    _startTime = null;
    _endTime = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF2A2A40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF7A12FF), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.3,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Task',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _taskController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Task',
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white70),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF7A12FF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () async {
                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (selectedTime != null) {
                        setDialogState(() {
                          _startTime = selectedTime;
                        });
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Start Time',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _startTime == null
                              ? 'Not set'
                              : _startTime!.format(context),
                          style: const TextStyle(color: Color(0xFF7A12FF), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: () async {
                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (selectedTime != null) {
                        setDialogState(() {
                          _endTime = selectedTime;
                        });
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'End Time',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _endTime == null
                              ? 'Not set'
                              : _endTime!.format(context),
                          style: const TextStyle(color: Color(0xFF7A12FF), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (_taskController.text.isNotEmpty) {
                            await addTask(_taskController.text, _startTime, _endTime);
                            _taskController.clear();
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7A12FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> get _screens {
    return [
      HomeScreenContent(
        userName: userName,
        userProfileImageBase64: userProfileImageBase64,
        todayTasks: _todayTasks,
        completedTasks: _completedTasks,
        onToggleCompletion: toggleTaskCompletion,
        onDeleteTask: deleteTask,
      ),
      const TasksScreen(),
      const MyProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF2A2A40),
          selectedItemColor: Color(0xFF7A12FF),
          unselectedItemColor: Color(0xB3FFFFFF),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2F),
        body: _screens[_selectedIndex],
        bottomNavigationBar: Container(
          color: const Color(0xFF2A2A40),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: const Color(0xFF2A2A40),
            selectedItemColor: const Color(0xFF7A12FF),
            unselectedItemColor: const Color(0xB3FFFFFF),
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Mine',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddTaskDialog(context),
          label: const Text('Create New Task'),
          icon: const Icon(Icons.add),
          backgroundColor: const Color(0xFF7A12FF),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class HomeScreenContent extends StatelessWidget {
  final String userName;
  final String? userProfileImageBase64;
  final List<Map<dynamic, dynamic>> todayTasks;
  final List<Map<dynamic, dynamic>> completedTasks;
  final Function(String, bool) onToggleCompletion;
  final Function(String) onDeleteTask;

  const HomeScreenContent({
    super.key,
    required this.userName,
    required this.userProfileImageBase64,
    required this.todayTasks,
    required this.completedTasks,
    required this.onToggleCompletion,
    required this.onDeleteTask,
  });

  @override
  Widget build(BuildContext context) {
    final currentTime = DateFormat('hh:mm a').format(DateTime.now());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with dynamic time, greeting, and profile image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentTime,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          "Hello $userName",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const Text(
                          "Keep Plan For 1 Day",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      backgroundImage: userProfileImageBase64 != null
                          ? MemoryImage(base64Decode(userProfileImageBase64!))
                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                      radius: 24,
                    ),
                  ],
                ),
              ),

              // Tabs for task categories
              const TabBar(
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Color(0xFF7A12FF),
                tabs: [
                  Tab(text: "Today Tasks"),
                  Tab(text: "Completed Tasks"),
                ],
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    // Today Tasks Tab
                    todayTasks.isEmpty
                        ? const Center(
                            child: Text(
                              "No tasks for today yet. Add a new task to get started!",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: todayTasks.length,
                            itemBuilder: (context, index) {
                              final task = todayTasks[index];
                              return Card(
                                color: const Color(0xFF2A2A40),
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  leading: IconButton(
                                    icon: Icon(
                                      task['completed']
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: task['completed']
                                          ? Colors.green
                                          : Colors.white70,
                                    ),
                                    onPressed: () => onToggleCompletion(task['id'], task['completed']),
                                  ),
                                  title: Text(
                                    task['task'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task['createdAt'],
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                      if (task['startTime'] != null)
                                        Text(
                                          'Start: ${task['startTime']}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      if (task['endTime'] != null)
                                        Text(
                                          'End: ${task['endTime']}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => onDeleteTask(task['id']),
                                  ),
                                ),
                              );
                            },
                          ),

                    // Completed Tasks Tab
                    completedTasks.isEmpty
                        ? const Center(
                            child: Text(
                              "No completed tasks yet.",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: completedTasks.length,
                            itemBuilder: (context, index) {
                              final task = completedTasks[index];
                              return Card(
                                color: const Color(0xFF2A2A40),
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  title: Text(
                                    task['task'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task['createdAt'],
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                      if (task['startTime'] != null)
                                        Text(
                                          'Start: ${task['startTime']}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      if (task['endTime'] != null)
                                        Text(
                                          'End: ${task['endTime']}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => onDeleteTask(task['id']),
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}