import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_random_chat/models/chat_message.dart';
import 'package:flutter_random_chat/screens/image_viewer_screen.dart';
import 'package:flutter_random_chat/screens/store_screen.dart';
import 'package:flutter_random_chat/screens/settings_screen.dart';
import 'package:flutter_random_chat/services/chat_service.dart';
import 'package:flutter_random_chat/services/location_service.dart';
import 'package:flutter_random_chat/widgets/message_bubble.dart';
import 'package:flutter_random_chat/widgets/system_message.dart';
import 'package:flutter_random_chat/widgets/preference_dialog.dart';
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
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    
    // 챗 서비스 리스너 설정
    _setupChatServiceListeners();
    
    // 키보드 리스너 설정
    _setupKeyboardListener();
    
    // 초기 대기열 참가
    if (widget.chatService.isConnected && !widget.chatService.isMatched) {
      widget.chatService.joinQueue();
    }
  }
  
  void _setupChatServiceListeners() {
    // 상태 변경시 화면 갱신 (선호도 시간 업데이트 포함)
    widget.chatService.addListener(_onChatServiceChanged);
  }
  
  void _onChatServiceChanged() {
    if (mounted) {
      setState(() {
        // ChatService의 모든 상태 변경을 감지하여 UI 업데이트
        // 선호도 시간, 메시지, 연결 상태 등 모든 변경사항 반영
      });
      
      // 메시지가 추가되었을 때 스크롤 이동
      if (widget.chatService.messages.isNotEmpty) {
        _scrollToBottom();
      }
    }
  }
  
  void _setupKeyboardListener() {
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        // 키보드가 올라올 때 약간의 지연 후 스크롤
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });
  }
  
  void _scrollToBottom() {
    if (widget.chatService.messages.isNotEmpty && 
        _scrollController.hasClients && 
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    widget.chatService.removeListener(_onChatServiceChanged);
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('연결 실패: $e')),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    try {
      await widget.chatService.sendMessage(message);
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패: $e')),
        );
      }
    }
  }

  Future<void> _rematchOrEndChat() async {
    try {
      if (widget.chatService.isMatched) {
        await widget.chatService.endChat();
        // 대화 종료 시 자동으로 위치 업데이트
        await widget.chatService.refreshLocation();
      } else {
        // 재연결 시 자동으로 위치 업데이트
        await widget.chatService.refreshLocation();
        await widget.chatService.joinQueue();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요청 실패: $e')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 전송 실패: $e')),
        );
      }
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
    
    if (result == true && mounted) {
      setState(() {});
    }
  }

  // 선호도 설정 다이얼로그 열기
  void _openPreferenceDialog() {
    // 키보드가 열려있으면 먼저 닫기
    FocusScope.of(context).unfocus();
    
    // 키보드가 완전히 닫힐 때까지 잠시 대기
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => PreferenceDialog(
            chatService: widget.chatService,
          ),
        ).then((_) {
          // 다이얼로그 닫힌 후 화면 새로고침
          if (mounted) setState(() {});
        });
      }
    });
  }

  // 설정 화면 열기
  void _openSettingsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
    
    if (mounted) {
      setState(() {});
    }
  }

  // 위치 새로고침
  Future<void> _refreshLocation() async {
    try {
      await widget.chatService.refreshLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치가 새로고침되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 새로고침 실패: $e')),
        );
      }
    }
  }

  // 수동 위치 설정 다이얼로그
  Future<void> _showManualLocationDialog() async {
    final TextEditingController latController = TextEditingController();
    final TextEditingController lonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수동 위치 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('테스트용 위치를 수동으로 설정할 수 있습니다.'),
            const SizedBox(height: 16),
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: '위도 (Latitude)',
                hintText: '37.5665',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(
                labelText: '경도 (Longitude)', 
                hintText: '126.9780',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              if (lat != null && lon != null) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 숫자를 입력해주세요')),
                );
              }
            },
            child: const Text('설정'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final lat = double.parse(latController.text);
      final lon = double.parse(lonController.text);
      
      try {
        await LocationService.setManualLocation(lat, lon);
        await widget.chatService.refreshLocation();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('위치가 설정되었습니다: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('위치 설정 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 키보드가 올라올 때 화면 크기 조정 방식 설정
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Random Chat'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.my_location),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _refreshLocation();
                  break;
                case 'manual':
                  _showManualLocationDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('위치 새로고침'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manual',
                child: Row(
                  children: [
                    Icon(Icons.edit_location),
                    SizedBox(width: 8),
                    Text('수동 위치 설정'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _openPreferenceDialog,
            tooltip: '선호도 설정',
          ),
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: _openStore,
            tooltip: '상점',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsScreen,
            tooltip: '설정',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 선호도 활성화 시간 및 포인트 표시
            _buildStatusBar(),
            
            // 채팅 메시지 리스트 - Expanded 사용하여 남은 공간 모두 차지
            Expanded(
              child: Container(
                color: Colors.grey[50],
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: widget.chatService.isConnected 
                    ? _rematchOrEndChat 
                    : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(
                    widget.chatService.isMatched ? '재연결' : '연결',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            
            // 메시지 입력
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 포인트 표시
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.chatService.points} P',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          
          // 선호도 활성화 시간 표시
          if (widget.chatService.isPreferenceActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.chatService.preferenceStatusText.replaceAll('선호도 설정 활성화: ', ''),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_off,
                    color: Colors.grey,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '선호도 비활성화',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                enabled: widget.chatService.canSendMessage,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 40,
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.image, size: 20),
              onPressed: widget.chatService.canSendMessage
                ? _pickAndSendImage
                : null,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 40,
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.send, size: 20),
              onPressed: widget.chatService.canSendMessage
                ? _sendMessage
                : null,
              padding: EdgeInsets.zero,
            ),
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