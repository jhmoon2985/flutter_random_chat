import 'package:flutter/material.dart';
import 'package:flutter_random_chat/screens/splash_screen.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 앱 설정 초기화
  await AppPreferences.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Chat',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        primaryColor: const Color(0xFF4169E1), // 원본 앱의 색상
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // TextField 텍스트 색상 강제 설정
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          // TextField 내부 텍스트 색상 설정
          hintStyle: TextStyle(color: Colors.black45),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        primaryColor: const Color(0xFF4169E1),
        // 다크 테마에서도 텍스트 색상 명시적 설정
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),  
          titleMedium: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.white54),
        ),
      ),
      themeMode: ThemeMode.light, // 라이트 테마로 강제 설정
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}