import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_random_chat/models/chat_message.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';

class ChatService extends ChangeNotifier {
  // 허브 연결
  HubConnection? _hubConnection;
  
  // HTTP 클라이언트
  final http.Client _httpClient = http.Client();
  
  // 상태 정보
  String _serverUrl = AppPreferences.serverUrl;
  String? _clientId;
  bool _isConnected = false;
  bool _isMatched = false;
  String _partnerGender = '';
  double _distance = 0;
  String _connectionStatus = '연결 끊김';
  String _matchStatus = '매칭 대기 중';
  int _points = 0;
  DateTime? _preferenceActiveUntil;
  
  // 사용자 정보
  double _latitude = 37.5642135;
  double _longitude = 127.0016985;
  String _preferredGenderValue = 'any';
  int _maxDistance = 10000;
  
  // 메시지 목록
  final List<ChatMessage> _messages = [];
  
  // 게터
  String get serverUrl => _serverUrl;
  String? get clientId => _clientId;
  bool get isConnected => _isConnected;
  bool get isMatched => _isMatched;
  String get partnerGender => _partnerGender;
  double get distance => _distance;
  String get connectionStatus => _connectionStatus;
  String get matchStatus => _matchStatus;
  double get latitude => _latitude;
  double get longitude => _longitude;
  int get points => _points;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  
  // 매칭 설정 관련
  bool get isPreferenceActive => 
    _preferenceActiveUntil != null && _preferenceActiveUntil!.isAfter(DateTime.now());
  
  String get preferenceStatusText {
    if (!isPreferenceActive) return '';
    
    final timeLeft = _preferenceActiveUntil!.difference(DateTime.now());
    return '선호도 설정 활성화: ${timeLeft.inMinutes}분 ${timeLeft.inSeconds % 60}초 남음';
  }
  
  bool get canChangePreference => 
    isConnected && (isPreferenceActive || (_preferredGenderValue == 'any' && _maxDistance == 10000));
  
  bool get canActivatePreference => 
    isConnected && !isPreferenceActive && _points >= 1000;
  
  bool get canSavePreferences => 
    isConnected && (isPreferenceActive || (_preferredGenderValue == 'any' && _maxDistance == 10000));
  
  // 메시지 송신 관련
  bool get canSendMessage => isConnected && isMatched;
  
  // 연결 상태 확인 헬퍼
  bool get _isConnectionValid => 
    _hubConnection != null && 
    _hubConnection!.state == HubConnectionState.Connected;
  
  // 초기화
  Future<void> initialize(String serverUrl) async {
    _serverUrl = serverUrl;
    AppPreferences.serverUrl = serverUrl;
    
    // 위치 정보 초기화
    _latitude = AppPreferences.latitude;
    _longitude = AppPreferences.longitude;
    _preferredGenderValue = AppPreferences.preferredGender;
    _maxDistance = AppPreferences.maxDistance;
    
    // 클라이언트 ID 로드
    _clientId = AppPreferences.clientId;
    _points = AppPreferences.points;
    
    // 선호도 활성화 시간 가져오기
    final preferenceTimestamp = AppPreferences.preferenceActiveUntil;
    if (preferenceTimestamp > 0) {
      _preferenceActiveUntil = DateTime.fromMillisecondsSinceEpoch(preferenceTimestamp);
      if (!isPreferenceActive) {
        _preferenceActiveUntil = null;
        AppPreferences.preferenceActiveUntil = 0;
      }
    }
  }
  
  // 서버 연결
  Future<void> connect() async {
    if (_isConnected) return;
    
    try {
      _connectionStatus = '연결 중...';
      notifyListeners();
      
      debugPrint('서버 연결 시도: $_serverUrl/chathub');
      
      // 기존 연결이 있다면 정리
      await disconnect();
      
      // SignalR 허브 연결 설정
      _hubConnection = HubConnectionBuilder()
        .withUrl('$_serverUrl/chathub')
        .withAutomaticReconnect(retryDelays: [0, 2000, 10000, 30000])
        .build();
      
      // 이벤트 핸들러 등록
      _registerHubHandlers();
      
      if (_hubConnection == null) {
        throw Exception('HubConnection이 null입니다.');
      }
      // 연결 시작 (타임아웃 설정)
      await _hubConnection!.start()?.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('연결 타임아웃');
        },
      );
      
      debugPrint('SignalR 연결 성공');
      
      // 연결 상태 확인
      if (!_isConnectionValid) {
        throw Exception('연결 상태가 유효하지 않음');
      }
      
      // 클라이언트 등록
      await _registerClient();
      
      _isConnected = true;
      _connectionStatus = '연결됨';
      notifyListeners();
      
    } catch (e) {
      debugPrint('연결 실패: $e');
      _connectionStatus = '연결 실패: $e';
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // 연결 해제
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      try {
        debugPrint('연결 해제 시도');
        await _hubConnection!.stop();
      } catch (e) {
        debugPrint('연결 해제 중 오류: $e');
      } finally {
        _hubConnection = null;
        _isConnected = false;
        _isMatched = false;
        _connectionStatus = '연결 끊김';
        _matchStatus = '매칭 없음';
        notifyListeners();
      }
    }
  }
  
  // 안전한 서버 호출을 위한 헬퍼
  Future<T> _safeInvoke<T>(String methodName, {List<Object>? args}) async {
  if (!_isConnectionValid) {
    throw Exception('서버 연결이 끊어졌습니다');
  }
  
  try {
    final result = await _hubConnection!.invoke(methodName, args: args);
    return result as T;
  } catch (e) {
    debugPrint('서버 호출 실패 ($methodName): $e');
    
    if (e.toString().contains('underlying connection being closed') ||
        e.toString().contains('connection is closed')) {
      _isConnected = false;
      _connectionStatus = '연결 끊김';
      notifyListeners();
    }
    rethrow;
  }
}
  
  // 클라이언트 등록
  Future<void> _registerClient() async {
    try {
      final gender = AppPreferences.gender;
      
      await _safeInvoke('Register', args: [
        {
          'ClientId': _clientId,
          'Latitude': _latitude,
          'Longitude': _longitude,
          'Gender': gender,
          'PreferredGender': _preferredGenderValue,
          'MaxDistance': _maxDistance,
          'Points': _points,
          'PreferenceActiveUntil': _preferenceActiveUntil?.toIso8601String(),
        }
      ]);
    } catch (e) {
      debugPrint('클라이언트 등록 실패: $e');
      rethrow;
    }
  }
  
  // 대기열 참가
  Future<void> joinQueue() async {
    if (!_isConnectionValid) {
      throw Exception('서버에 연결되어 있지 않습니다');
    }
    
    try {
      _matchStatus = '매칭 대기열에 참가 중...';
      notifyListeners();
      
      await _safeInvoke('JoinWaitingQueue', args: [
        _latitude,
        _longitude,
        AppPreferences.gender,
        _preferredGenderValue,
        _maxDistance,
      ]);
    } catch (e) {
      _matchStatus = '매칭 대기열 참가 실패: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  // 대화 종료
  Future<void> endChat() async {
    if (!_isConnectionValid) return;
    
    try {
      await _safeInvoke('EndChat');
      
      _messages.add(ChatMessage(
        content: '대화를 종료하고 새로운 상대를 찾습니다.',
        isFromMe: false,
        isSystemMessage: true,
      ));
      
      notifyListeners();
    } catch (e) {
      debugPrint('대화 종료 실패: $e');
      _messages.add(ChatMessage(
        content: '대화 종료 중 오류가 발생했습니다: $e',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
    }
  }
  
  // 메시지 전송
  Future<void> sendMessage(String message) async {
    if (!_isConnectionValid || !_isMatched || message.trim().isEmpty) return;
    
    try {
      await _safeInvoke('SendMessage', args: [message]);
    } catch (e) {
      debugPrint('메시지 전송 실패: $e');
      _messages.add(ChatMessage(
        content: '메시지 전송 실패: $e',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
      rethrow;
    }
  }
  
  // 이미지 전송
  Future<void> sendImage(String filePath) async {
    if (!_isConnectionValid || !_isMatched) return;
    
    try {
      _messages.add(ChatMessage(
        content: '이미지 업로드 중...',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_serverUrl/api/client/$_clientId/image'),
      );
      
      final file = File(filePath);
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: file.path.split('/').last,
      );
      
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('이미지 업로드 실패: ${response.body}');
      }
      
      _messages.add(ChatMessage(
        content: '이미지를 전송했습니다.',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
    } catch (e) {
      _messages.add(ChatMessage(
        content: '이미지 전송 실패: $e',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
      rethrow;
    }
  }
  
  // 선호도 업데이트
  Future<void> updatePreferences(String preferredGender, int maxDistance) async {
    if (!_isConnectionValid) return;
    
    try {
      _preferredGenderValue = preferredGender;
      _maxDistance = maxDistance;
      
      await _safeInvoke('UpdatePreferences', args: [preferredGender, maxDistance]);
      
      AppPreferences.preferredGender = preferredGender;
      AppPreferences.maxDistance = maxDistance;
    } catch (e) {
      debugPrint('선호도 업데이트 실패: $e');
      rethrow;
    }
  }
  
  // 선호도 활성화
  Future<void> activatePreference(String preferredGender, int maxDistance) async {
    if (!_isConnectionValid || !canActivatePreference) return;
    
    try {
      await _safeInvoke('ActivatePreference', args: [preferredGender, maxDistance]);
    } catch (e) {
      debugPrint('선호도 활성화 실패: $e');
      rethrow;
    }
  }
  
  // 위치 업데이트
  Future<void> updateLocation(double latitude, double longitude) async {
    if (!_isConnectionValid) return;
    
    try {
      _latitude = latitude;
      _longitude = longitude;
      
      await _safeInvoke('UpdateLocation', args: [latitude, longitude]);
      
      AppPreferences.latitude = latitude;
      AppPreferences.longitude = longitude;
      
      notifyListeners();
    } catch (e) {
      debugPrint('위치 업데이트 실패: $e');
    }
  }
  
  // 포인트 충전
  Future<void> chargePoints(int amount) async {
    if (_clientId == null) return;
    
    try {
      final request = {
        'ClientId': _clientId,
        'Amount': amount,
      };
      
      final response = await _httpClient.post(
        Uri.parse('$_serverUrl/api/client/$_clientId/points'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      );
      
      if (response.statusCode != 200) {
        throw Exception('포인트 충전 실패: ${response.body}');
      }
      
      final data = jsonDecode(response.body);
      _points = data['points'];
      
      if (data['preferenceActiveUntil'] != null) {
        _preferenceActiveUntil = DateTime.parse(data['preferenceActiveUntil']);
      }
      
      AppPreferences.points = _points;
      if (_preferenceActiveUntil != null) {
        AppPreferences.preferenceActiveUntil = _preferenceActiveUntil!.millisecondsSinceEpoch;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('포인트 충전 실패: $e');
      rethrow;
    }
  }
  
  // 이벤트 핸들러 등록
  void _registerHubHandlers() {
    _hubConnection!.on('Registered', _handleRegistered);
    _hubConnection!.on('EnqueuedToWaiting', _handleEnqueuedToWaiting);
    _hubConnection!.on('Matched', _handleMatched);
    _hubConnection!.on('MatchEnded', _handleMatchEnded);
    _hubConnection!.on('ReceiveMessage', _handleReceiveMessage);
    _hubConnection!.on('ReceiveImageMessage', _handleReceiveImageMessage);
    _hubConnection!.on('PreferencesUpdated', _handlePreferencesUpdated);
    _hubConnection!.on('PointsUpdated', _handlePointsUpdated);
    
    // 연결 종료 핸들러
    _hubConnection!.onclose(({Exception? error}) {
      debugPrint('SignalR 연결 종료됨: $error');
      _isConnected = false;
      _isMatched = false;
      _connectionStatus = '연결 끊김';
      _matchStatus = '매칭 없음';
      
      if (error != null) {
        _messages.add(ChatMessage(
          content: '서버 연결이 끊어졌습니다. 다시 연결을 시도해주세요.',
          isFromMe: false,
          isSystemMessage: true,
        ));
      }
      
      notifyListeners();
    });
    
    // 재연결 핸들러
    _hubConnection!.onreconnected(({String? connectionId}) {
      debugPrint('SignalR 재연결됨: $connectionId');
      _isConnected = true;
      _connectionStatus = '재연결됨';
      
      _messages.add(ChatMessage(
        content: '서버에 재연결되었습니다.',
        isFromMe: false,
        isSystemMessage: true,
      ));
      
      notifyListeners();
      
      // 재연결 후 클라이언트 다시 등록
      _registerClient().catchError((e) {
        debugPrint('재연결 후 등록 실패: $e');
      });
    });
  }
  
  // 등록 완료 핸들러
  void _handleRegistered(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    
    try {
      final data = jsonDecode(args[0].toString());
      _clientId = data['clientId'];
      
      if (data['points'] != null) {
        _points = data['points'];
      }
      
      if (data['preferenceActiveUntil'] != null && data['preferenceActiveUntil'] != 'null') {
        _preferenceActiveUntil = DateTime.parse(data['preferenceActiveUntil']);
      }
      
      AppPreferences.clientId = _clientId ?? '';
      AppPreferences.points = _points;
      if (_preferenceActiveUntil != null) {
        AppPreferences.preferenceActiveUntil = _preferenceActiveUntil!.millisecondsSinceEpoch;
      }
      
      _connectionStatus = '등록됨: $_clientId';
      notifyListeners();
    } catch (e) {
      debugPrint('등록 응답 처리 실패: $e');
    }
  }
  
  // 대기열 참가 핸들러
  void _handleEnqueuedToWaiting(List<Object?>? args) {
    _matchStatus = '매칭 대기 중...';
    _isMatched = false;
    notifyListeners();
  }
  
  // 매칭 완료 핸들러
  void _handleMatched(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    
    try {
      final data = jsonDecode(args[0].toString());
      _partnerGender = data['partnerGender'];
      _distance = data['distance'].toDouble();
      
      _isMatched = true;
      _matchStatus = '매칭됨: ${_partnerGender == 'male' ? '남성' : '여성'}, 거리: ${_distance.toStringAsFixed(1)}km';
      
      _messages.clear();
      _messages.add(ChatMessage(
        content: '새로운 상대방과 연결되었습니다. 상대방 성별: ${_partnerGender == 'male' ? '남성' : '여성'}, 거리: ${_distance.toStringAsFixed(1)}km',
        isFromMe: false,
        isSystemMessage: true,
      ));
      
      notifyListeners();
    } catch (e) {
      debugPrint('매칭 응답 처리 실패: $e');
    }
  }
  
  // 매칭 종료 핸들러
  void _handleMatchEnded(List<Object?>? args) {
    _isMatched = false;
    _matchStatus = '매칭 종료됨';
    
    _messages.add(ChatMessage(
      content: '상대방이 대화를 종료했습니다.',
      isFromMe: false,
      isSystemMessage: true,
    ));
    
    notifyListeners();
  }
  
  // 메시지 수신 핸들러
  void _handleReceiveMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    
    try {
      final data = jsonDecode(args[0].toString());
      final senderId = data['senderId'];
      final message = data['message'];
      final timestamp = DateTime.parse(data['timestamp']);
      
      final isFromMe = senderId == _clientId;
      
      _messages.add(ChatMessage(
        content: message,
        isFromMe: isFromMe,
        timestamp: timestamp,
      ));
      
      notifyListeners();
    } catch (e) {
      debugPrint('메시지 수신 처리 실패: $e');
    }
  }
  
  // 이미지 메시지 수신 핸들러
  void _handleReceiveImageMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    
    try {
      final data = jsonDecode(args[0].toString());
      final senderId = data['senderId'];
      final imageId = data['imageId'];
      final thumbnailUrl = data['thumbnailUrl'];
      final imageUrl = data['imageUrl'];
      final timestamp = DateTime.parse(data['timestamp']);
      
      final isFromMe = senderId == _clientId;
      
      _messages.add(ChatMessage(
        content: '[이미지]',
        isFromMe: isFromMe,
        timestamp: timestamp,
        thumbnailUrl: '$_serverUrl$thumbnailUrl',
        imageUrl: '$_serverUrl$imageUrl',
        isImageMessage: true,
      ));
      
      notifyListeners();
    } catch (e) {
      debugPrint('이미지 메시지 수신 처리 실패: $e');
    }
  }
  
  // 선호도 업데이트 핸들러
  void _handlePreferencesUpdated(List<Object?>? args) {
    _messages.add(ChatMessage(
      content: '매칭 선호도가 서버에 저장되었습니다.',
      isFromMe: false,
      isSystemMessage: true,
    ));
    
    notifyListeners();
  }
  
  // 포인트 업데이트 핸들러
  void _handlePointsUpdated(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    
    try {
      final data = jsonDecode(args[0].toString());
      _points = data['points'];
      
      DateTime? activeUntil;
      if (data['preferenceActiveUntil'] != null && data['preferenceActiveUntil'] != 'null') {
        activeUntil = DateTime.parse(data['preferenceActiveUntil']);
      }
      
      if (activeUntil != null) {
        _preferenceActiveUntil = activeUntil;
        _messages.add(ChatMessage(
          content: '포인트가 차감되어 선호도 설정이 10분간 활성화되었습니다. 남은 포인트: $_points P',
          isFromMe: false,
          isSystemMessage: true,
        ));
      } else {
        _messages.add(ChatMessage(
          content: '포인트가 업데이트 되었습니다. 현재 포인트: $_points P',
          isFromMe: false,
          isSystemMessage: true,
        ));
      }
      
      AppPreferences.points = _points;
      if (_preferenceActiveUntil != null) {
        AppPreferences.preferenceActiveUntil = _preferenceActiveUntil!.millisecondsSinceEpoch;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('포인트 업데이트 처리 실패: $e');
    }
  }
}