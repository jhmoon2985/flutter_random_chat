import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_random_chat/screens/chat_screen.dart';
import 'package:flutter_random_chat/services/chat_service.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';
import 'package:flutter_random_chat/services/location_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _statusText = "앱을 초기화하는 중...";
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
    
    // 앱 초기화 시작
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 1)); // 스플래시 지연
    
    try {
      // 1. 위치 권한 요청 및 현재 위치 가져오기
      setState(() => _statusText = "위치 권한을 확인하는 중...");
      
      bool hasLocationPermission = await LocationService.requestLocationPermission();
      if (!hasLocationPermission) {
        setState(() => _statusText = "위치 권한이 없어도 계속 진행합니다...");
        await Future.delayed(const Duration(seconds: 1));
      } else {
        setState(() => _statusText = "현재 위치를 가져오는 중...");
        await LocationService.getCurrentLocation();
      }
      
      // 2. 서버 연결
      setState(() => _statusText = "서버에 연결하는 중...");

      // 서버 URL 가져오기 (기본값은 설정된 값)
      final serverUrl = AppPreferences.serverUrl;
      
      // 채팅 서비스 초기화 및 연결
      await _chatService.initialize(serverUrl);
      await _chatService.connect();
      
      setState(() => _statusText = "연결 성공! 화면 전환 중...");
      
      // 연결 성공 시 1초 후 메인 화면으로 이동
      Timer(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChatScreen(chatService: _chatService),
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.toString();
        _statusText = "초기화 실패";
      });
    }
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _isError = false;
      _errorMessage = "";
      _statusText = "다시 시도하는 중...";
    });
    
    await _initializeApp();
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
              // 로고 아이콘 (이미지가 없을 경우 아이콘으로 대체)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (_isError)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _retryInitialization,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text('다시 시도'),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        "오류: $_errorMessage",
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}