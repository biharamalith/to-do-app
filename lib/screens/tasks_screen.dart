import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<dynamic, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid');

      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _tasks = data.entries.map((entry) {
            return {
              'id': entry.key,
              ...entry.value as Map<dynamic, dynamic>,
              'isEditing': false,
              'editController': TextEditingController(text: (entry.value as Map)['task']),
            };
          }).toList();
        });
      }
    }
  }

  Future<void> toggleTaskCompletion(String taskId, bool currentStatus) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid/$taskId');
      await ref.update({'completed': !currentStatus});
      fetchTasks();
    }
  }

  Future<void> deleteTask(String taskId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid/$taskId');
      await ref.remove();
      fetchTasks();
    }
  }

  Future<void> updateTask(String taskId, String newTask) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref().child('tasks/$uid/$taskId');
      await ref.update({'task': newTask});
      fetchTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Your Tasks",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(
                    child: Text(
                      "No tasks available.",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final isEditing = task['isEditing'] as bool;
                      final controller = task['editController'] as TextEditingController;

                      return Card(
                        color: Colors.white.withOpacity(0.1),
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          title: isEditing
                              ? TextField(
                                  controller: controller,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Edit Task',
                                    hintStyle: TextStyle(color: Colors.white54),
                                  ),
                                )
                              : Text(
                                  task['task'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    decoration: task['completed']
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                          subtitle: Text(
                            task['createdAt'],
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          leading: IconButton(
                            icon: Icon(
                              task['completed'] ? Icons.check_circle : Icons.circle_outlined,
                              color: task['completed'] ? Colors.green : Colors.white70,
                            ),
                            onPressed: () => toggleTaskCompletion(task['id'], task['completed']),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isEditing ? Icons.save : Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () {
                                  if (isEditing) {
                                    updateTask(task['id'], controller.text);
                                  } else {
                                    setState(() {
                                      _tasks[index]['isEditing'] = true;
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deleteTask(task['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
