import 'package:flutter/material.dart';
import 'package:flutter_random_chat/models/chat_message.dart';

class SystemMessage extends StatelessWidget {
  final ChatMessage message;
  
  const SystemMessage({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          decoration: BoxDecoration(
            color: Colors.amber[100],
            border: Border.all(
              color: Colors.amber[300]!,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}