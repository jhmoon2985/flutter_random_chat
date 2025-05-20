import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_random_chat/models/chat_message.dart';
import 'package:flutter_random_chat/screens/image_viewer_screen.dart';
import 'package:flutter_random_chat/screens/store_screen.dart';
import 'package:flutter_random_chat/services/chat_service.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';
import 'package:flutter_random_chat/widgets/message_bubble.dart';
import 'package:flutter_random_chat/widgets/system_message.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final ChatService chatService;
  
  const ChatScreen({
    Key? key,
    required this.chatService,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSettings = false;
  String _selectedGender = AppPreferences.gender;
  String _selectedPreferredGender = AppPreferences.preferredGender;
  int _selectedMaxDistance = AppPreferences.maxDistance;
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    
    // 챗 서비스 리스너 설정
    _setupChatServiceListeners();
    
    // 초기 대기열 참가
    if (widget.chatService.isConnected && !widget.chatService.isMatched) {
      widget.chatService.joinQueue();
    }
  }
  
  void _setupChatServiceListeners() {
    // 메시지 추가됐을 때 스크롤 이동
    widget.chatService.addListener(_scrollToBottom);
    
    // 상태 변경시 화면 갱신
    widget.chatService.addListener(() {
      if (mounted) setState(() {});
    });
  }
  
  void _scrollToBottom() {
    if (widget.chatService.messages.isNotEmpty && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    widget.chatService.removeListener(_scrollToBottom);
    super.dispose();
  }

  Future<void> _connectOrDisconnect() async {
    if (widget.chatService.isConnected) {
      await widget.chatService.disconnect();
    } else {
      try {
        await widget.chatService.connect();
        if (!widget.chatService.isMatched) {
          widget.chatService.joinQueue();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
    }
    setState(() {});
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    try {
      await widget.chatService.sendMessage(message);
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  Future<void> _rematchOrEndChat() async {
    try {
      if (widget.chatService.isMatched) {
        await widget.chatService.endChat();
      } else {
        await widget.chatService.joinQueue();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 실패: $e')),
      );
    }
  }

  Future<void> _savePreferences() async {
    try {
      final result = await widget.chatService.updatePreferences(
        _selectedPreferredGender,
        _selectedMaxDistance,
      );
      
      // 앱 설정에 저장
      AppPreferences.preferredGender = _selectedPreferredGender;
      AppPreferences.maxDistance = _selectedMaxDistance;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선호도 설정이 저장되었습니다')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('선호도 저장 실패: $e')),
      );
    }
  }

  Future<void> _activatePreference() async {
    if (widget.chatService.points < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포인트가 부족합니다. 1000 포인트가 필요합니다.')),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선호도 설정 활성화'),
        content: const Text('선호도 설정을 활성화하면 1,000 포인트가 차감됩니다. 계속 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final result = await widget.chatService.activatePreference(
          _selectedPreferredGender,
          _selectedMaxDistance,
        );
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('선호도 활성화 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (!widget.chatService.isConnected || !widget.chatService.isMatched) return;
    
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      // 파일 크기 확인 (최대 512KB)
      final fileSize = await File(pickedFile.path).length();
      const maxSize = 512 * 1024; // 512KB
      
      if (fileSize > maxSize) {
        // 사이즈 초과시 경고
        final compress = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('이미지 크기 초과'),
            content: Text(
              '이미지 크기가 제한을 초과했습니다.\n최대 크기: ${maxSize ~/ 1024}KB\n현재 크기: ${fileSize ~/ 1024}KB\n\n이미지를 압축하여 전송하시겠습니까?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('압축하여 전송'),
              ),
            ],
          ),
        );
        
        if (compress != true) return;
        
        // 이미지 픽커에서 더 낮은 품질로 다시 가져오기
        final compressedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 60,
        );
        
        if (compressedFile == null) return;
        
        await widget.chatService.sendImage(compressedFile.path);
      } else {
        // 정상 크기면 바로 전송
        await widget.chatService.sendImage(pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 전송 실패: $e')),
      );
    }
  }

  void _openStore() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoreScreen(
          chatService: widget.chatService,
        ),
      ),
    );
    
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Chat'),
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.settings_outlined : Icons.settings),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 정보
          _buildStatusBar(),
          
          // 설정 패널
          if (_showSettings) _buildSettingsPanel(),
          
          // 채팅 메시지 리스트
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                itemCount: widget.chatService.messages.length,
                itemBuilder: (context, index) {
                  final message = widget.chatService.messages[index];
                  
                  if (message.isSystemMessage) {
                    return SystemMessage(message: message);
                  } else {
                    return MessageBubble(
                      message: message,
                      onImageTap: message.isImageMessage 
                        ? () => _openImageViewer(message.imageUrl) 
                        : null,
                    );
                  }
                },
              ),
            ),
          ),
          
          // 재연결 버튼
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: widget.chatService.isConnected 
                ? _rematchOrEndChat 
                : null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(widget.chatService.isMatched ? '재연결' : '연결'),
            ),
          ),
          
          // 메시지 입력
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatService.connectionStatus,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.chatService.matchStatus,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "위치: ${widget.chatService.latitude.toStringAsFixed(6)}, "
                      "${widget.chatService.longitude.toStringAsFixed(6)}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "포인트: ${widget.chatService.points}P",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    if (widget.chatService.isPreferenceActive)
                      const SizedBox(height: 4),
                    if (widget.chatService.isPreferenceActive)
                      Text(
                        widget.chatService.preferenceStatusText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    width: 80,
                    child: ElevatedButton(
                      onPressed: _connectOrDisconnect,
                      child: Text(widget.chatService.isConnected ? '연결 해제' : '연결'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 80,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showSettings = !_showSettings),
                      child: const Text('설정'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 80,
                    child: OutlinedButton(
                      onPressed: _openStore,
                      child: const Text('상점'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 80,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('종료'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 80, child: Text('서버 URL:')),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: widget.chatService.serverUrl,
                  ),
                  enabled: !widget.chatService.isConnected,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  onChanged: (value) {
                    AppPreferences.serverUrl = value;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('내 성별:')),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('남성')),
                    DropdownMenuItem(value: 'female', child: Text('여성')),
                  ],
                  onChanged: !widget.chatService.isConnected
                    ? (value) {
                        if (value != null) {
                          setState(() => _selectedGender = value);
                          AppPreferences.gender = value;
                        }
                      }
                    : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('위도:')),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: widget.chatService.latitude.toStringAsFixed(6),
                  ),
                  enabled: widget.chatService.isConnected,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  onChanged: (value) {
                    final latitude = double.tryParse(value);
                    if (latitude != null) {
                      widget.chatService.updateLocation(
                        latitude,
                        widget.chatService.longitude,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 80, child: Text('경도:')),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: widget.chatService.longitude.toStringAsFixed(6),
                  ),
                  enabled: widget.chatService.isConnected,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  onChanged: (value) {
                    final longitude = double.tryParse(value);
                    if (longitude != null) {
                      widget.chatService.updateLocation(
                        widget.chatService.latitude,
                        longitude,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('선호 성별:')),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPreferredGender,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'any', child: Text('제한 없음')),
                    DropdownMenuItem(value: 'male', child: Text('남성만')),
                    DropdownMenuItem(value: 'female', child: Text('여성만')),
                  ],
                  onChanged: widget.chatService.canChangePreference
                    ? (value) {
                        if (value != null) {
                          setState(() => _selectedPreferredGender = value);
                        }
                      }
                    : null,
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 80, child: Text('최대 거리:')),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMaxDistance,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 km')),
                    DropdownMenuItem(value: 25, child: Text('25 km')),
                    DropdownMenuItem(value: 50, child: Text('50 km')),
                    DropdownMenuItem(value: 100, child: Text('100 km')),
                    DropdownMenuItem(value: 10000, child: Text('제한 없음')),
                  ],
                  onChanged: widget.chatService.canChangePreference
                    ? (value) {
                        if (value != null) {
                          setState(() => _selectedMaxDistance = value);
                        }
                      }
                    : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.chatService.canSavePreferences
                    ? _savePreferences
                    : null,
                  child: const Text('매칭 설정 저장'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.chatService.canActivatePreference
                    ? _activatePreference
                    : null,
                  child: const Text('선호도 활성화 (1000 포인트)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: widget.chatService.canSendMessage,
              decoration: const InputDecoration(
                hintText: '메시지를 입력하세요',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: widget.chatService.canSendMessage
              ? _pickAndSendImage
              : null,
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: widget.chatService.canSendMessage
              ? _sendMessage
              : null,
          ),
        ],
      ),
    );
  }

  void _openImageViewer(String? imageUrl) {
    if (imageUrl == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imageUrl: imageUrl),
      ),
    );
  }
}