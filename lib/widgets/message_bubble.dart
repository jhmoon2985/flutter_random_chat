import 'package:flutter/material.dart';
import 'package:flutter_random_chat/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onImageTap;
  
  const MessageBubble({
    Key? key,
    required this.message,
    this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: message.isFromMe 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 시간 표시 (상대방 메시지일 경우 왼쪽에)
          if (!message.isFromMe)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Text(
                message.formattedTime,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
          // 메시지 내용
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: message.isFromMe 
                  ? Colors.blue[100] 
                  : Colors.white,
                border: Border.all(
                  color: message.isFromMe 
                    ? Colors.blue[300]! 
                    : Colors.grey[300]!,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: message.isImageMessage
                ? _buildImageMessage()
                : Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ),
          ),
          
          // 시간 표시 (내 메시지일 경우 오른쪽에)
          if (message.isFromMe)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                message.formattedTime,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onImageTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              message.thumbnailUrl ?? '',
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 200,
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '이미지를 클릭하면 원본을 볼 수 있습니다',
          style: TextStyle(
            fontSize: 10,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}