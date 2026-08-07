import 'package:flutter/material.dart';

// Incoming call detection aur navigation ab shell_screen.dart mein
// globally handle hoti hai. Yeh tab sirf placeholder show karta hai.
class CallTab extends StatelessWidget {
  const CallTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.call, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Incoming calls will appear automatically.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}