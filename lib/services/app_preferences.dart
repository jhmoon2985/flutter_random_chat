import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static late SharedPreferences _prefs;
  
  // 앱 설정 초기화
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // 클라이언트 ID
  static String get clientId => _prefs.getString('clientId') ?? '';
  static set clientId(String value) => _prefs.setString('clientId', value);
  
  // 서버 URL
  static String get serverUrl => _prefs.getString('serverUrl') ?? 'http://localhost:5115';
  static set serverUrl(String value) => _prefs.setString('serverUrl', value);
  
  // 위치 정보
  static double get latitude => _prefs.getDouble('latitude') ?? 37.5642135;
  static set latitude(double value) => _prefs.setDouble('latitude', value);
  
  static double get longitude => _prefs.getDouble('longitude') ?? 127.0016985;
  static set longitude(double value) => _prefs.setDouble('longitude', value);
  
  // 사용자 정보
  static String get gender => _prefs.getString('gender') ?? 'male';
  static set gender(String value) => _prefs.setString('gender', value);
  
  // 매칭 선호도
  static String get preferredGender => _prefs.getString('preferredGender') ?? 'any';
  static set preferredGender(String value) => _prefs.setString('preferredGender', value);
  
  static int get maxDistance => _prefs.getInt('maxDistance') ?? 10000;
  static set maxDistance(int value) => _prefs.setInt('maxDistance', value);
  
  // 포인트 정보
  static int get points => _prefs.getInt('points') ?? 0;
  static set points(int value) => _prefs.setInt('points', value);
  
  // 선호도 활성화 시간 (밀리초 타임스탬프)
  static int get preferenceActiveUntil => _prefs.getInt('preferenceActiveUntil') ?? 0;
  static set preferenceActiveUntil(int value) => _prefs.setInt('preferenceActiveUntil', value);
}