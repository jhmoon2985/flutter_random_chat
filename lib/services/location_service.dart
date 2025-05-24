import 'package:flutter_random_chat/services/app_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  static Position? _currentPosition;
  static bool _isLocationEnabled = false;
  static StreamSubscription<Position>? _locationSubscription;
  static bool _hasRealGPS = false;
  
  // 현재 위치 정보 게터
  static Position? get currentPosition => _currentPosition;
  static bool get isLocationEnabled => _isLocationEnabled;
  static bool get hasRealGPS => _hasRealGPS;
  
  // 위치 권한 확인 및 요청
  static Future<bool> requestLocationPermission() async {
    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('위치 서비스가 비활성화되어 있습니다. 기본 위치를 사용합니다.');
        _hasRealGPS = false;
        return false;
      }

      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('위치 권한이 거부되었습니다. 기본 위치를 사용합니다.');
          _hasRealGPS = false;
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('위치 권한이 영구적으로 거부되었습니다. 기본 위치를 사용합니다.');
        _hasRealGPS = false;
        return false;
      }

      _isLocationEnabled = true;
      _hasRealGPS = true;
      return true;
    } catch (e) {
      print('위치 권한 요청 실패: $e. 기본 위치를 사용합니다.');
      _hasRealGPS = false;
      return false;
    }
  }

  // 현재 위치 가져오기
  static Future<Position?> getCurrentLocation() async {
    try {
      // 권한 확인
      bool hasPermission = await requestLocationPermission();
      
      if (!hasPermission) {
        // 권한이 없으면 저장된 위치 또는 기본 위치 사용
        return _getStoredOrDefaultLocation();
      }

      // 실제 GPS 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('GPS 타임아웃 - 저장된 위치 사용');
          throw TimeoutException('GPS timeout');
        },
      );

      _currentPosition = position;
      _hasRealGPS = true;
      
      // 위치 정보를 앱 설정에 저장
      AppPreferences.latitude = position.latitude;
      AppPreferences.longitude = position.longitude;
      
      print('실제 GPS 위치: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('실제 GPS 위치 가져오기 실패: $e');
      _hasRealGPS = false;
      
      // 오류 발생시 저장된 위치 또는 기본 위치 사용
      return _getStoredOrDefaultLocation();
    }
  }

  // 저장된 위치 또는 기본 위치 가져오기
  static Position _getStoredOrDefaultLocation() {
    double latitude = AppPreferences.latitude;
    double longitude = AppPreferences.longitude;
    
    // 기본 위치가 설정되지 않은 경우 서울 시청 좌표 사용
    if (latitude == 37.5642135 && longitude == 127.0016985) {
      print('기본 위치 사용: 서울시청');
    } else {
      print('저장된 위치 사용: $latitude, $longitude');
    }

    _currentPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: _hasRealGPS ? 10.0 : 1000.0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    
    return _currentPosition!;
  }

  // 위치 변경 감지 스트림
  static Stream<Position> getLocationStream() {
    return Stream.periodic(const Duration(seconds: 30), (index) async {
      return await getCurrentLocation();
    }).asyncMap((event) => event).where((position) => position != null).cast<Position>();
  }

  // 실제 GPS 스트림 (권한이 있을 때만)
  static Stream<Position> _getRealGPSStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // 50미터 이동시마다 업데이트
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .handleError((error) {
      print('GPS 스트림 오류: $error');
    });
  }

  // 위치 추적 시작
  static Future<void> startLocationTracking(Function(Position) onLocationChanged) async {
    try {
      // 기존 구독이 있다면 취소
      await stopLocationTracking();

      bool hasPermission = await requestLocationPermission();
      
      if (hasPermission && _hasRealGPS) {
        // 실제 GPS 사용
        print('실제 GPS 추적 시작');
        const LocationSettings locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50, // 50미터 이동시마다 업데이트
        );

        _locationSubscription = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          (Position position) {
            _currentPosition = position;
            AppPreferences.latitude = position.latitude;
            AppPreferences.longitude = position.longitude;
            onLocationChanged(position);
            print('GPS 위치 업데이트: ${position.latitude}, ${position.longitude}');
          },
          onError: (error) {
            print('GPS 추적 오류: $error');
            _hasRealGPS = false;
          },
        );
      } else {
        // 기본 위치 사용 - 주기적으로 체크
        print('기본 위치 추적 시작');
        Timer.periodic(const Duration(minutes: 1), (timer) async {
          Position? position = await getCurrentLocation();
          if (position != null) {
            onLocationChanged(position);
          }
        });
      }
    } catch (e) {
      print('위치 추적 시작 실패: $e');
    }
  }

  // 위치 추적 중단
  static Future<void> stopLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  // 두 지점 간의 거리 계산 (미터 단위)
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // 두 지점 간의 거리 계산 (킬로미터 단위)
  static double calculateDistanceInKm(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    double distanceInMeters = calculateDistance(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000;
  }

  // 수동 위치 설정 (테스트용)
  static Future<void> setManualLocation(double latitude, double longitude) async {
    try {
      AppPreferences.latitude = latitude;
      AppPreferences.longitude = longitude;
      
      _currentPosition = Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      
      _hasRealGPS = false; // 수동 설정은 실제 GPS가 아님
      print('수동 위치 설정: $latitude, $longitude');
    } catch (e) {
      print('수동 위치 설정 실패: $e');
    }
  }

  // GPS 상태 확인
  static Future<String> getLocationStatus() async {
    if (!_isLocationEnabled) {
      return '위치 서비스 비활성화';
    }
    
    if (_hasRealGPS) {
      return 'GPS 활성화';
    }
    
    return '기본 위치 사용';
  }

  // 위치 초기화
  static Future<void> initialize() async {
    try {
      await getCurrentLocation();
    } catch (e) {
      print('위치 서비스 초기화 실패: $e');
    }
  }

  // 위치 서비스 정리
  static Future<void> dispose() async {
    await stopLocationTracking();
    _currentPosition = null;
    _isLocationEnabled = false;
    _hasRealGPS = false;
  }
}