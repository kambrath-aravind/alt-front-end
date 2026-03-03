import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alt Admin')),
      body: ListView(
        children: [
          const ListTile(
            title: Text("Manually Link Alternatives"),
            subtitle: Text("Link 'Bad Chip A' to 'Good Chip B'"),
            trailing: Icon(Icons.link),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Recent Feedback (Thumbs Down)", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
             leading: const Icon(Icons.thumb_down, color: Colors.red),
             title: const Text("User disliked 'Kale Chips'"),
             subtitle: const Text("Reason: Too expensive"),
             trailing: TextButton(onPressed: () {}, child: const Text("Fix")),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // Add new link logic
        },
      ),
    );
  }
}
