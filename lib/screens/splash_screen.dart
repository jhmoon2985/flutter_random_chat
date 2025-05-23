import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_random_chat/screens/chat_screen.dart';
import 'package:flutter_random_chat/services/chat_service.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _statusText = "서버에 연결 중...";
  final ChatService _chatService = ChatService();
  bool _isError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    
    // 애니메이션 컨트롤러 생성
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 페이드인 애니메이션 생성
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    // 애니메이션 시작
    _controller.forward();
    
    // 서버 연결 시도
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    await Future.delayed(const Duration(seconds: 2)); // 스플래시 지연
    
    try {
      setState(() => _statusText = "서버에 연결 중...");

      // 서버 URL 가져오기 (기본값은 localhost)
      final serverUrl = AppPreferences.serverUrl;
      
      // 채팅 서비스 초기화 및 연결
      await _chatService.initialize(serverUrl);
      await _chatService.connect();
      
      setState(() => _statusText = "연결 성공! 화면 전환 중...");
      
      // 연결 성공 시 1초 후 메인 화면으로 이동
      Timer(const Duration(seconds: 1), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatService: _chatService),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.toString();
        _statusText = "연결 실패";
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: FadeTransition(
        opacity: _animation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고 이미지 (에셋으로 추가해야 합니다)
              SizedBox(
                width: 200,
                height: 200,
                child: Image.asset(
                  'assets/images/chat_logo.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Random Chat",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _statusText,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              if (_isError)
                ElevatedButton(
                  onPressed: () => _connectToServer(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('다시 시도'),
                )
              else
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              if (_isError)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "오류: $_errorMessage",
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}