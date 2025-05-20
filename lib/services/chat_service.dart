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
      
      // SignalR 허브 연결 설정
      _hubConnection = HubConnectionBuilder()
        .withUrl('$_serverUrl/chathub')
        .withAutomaticReconnect()
        .build();
      
      // 이벤트 핸들러 등록
      _registerHubHandlers();
      
      // 연결 시작
      await _hubConnection!.start();
      
      // 클라이언트 등록
      await _registerClient();
      
      _isConnected = true;
      _connectionStatus = '연결됨';
      notifyListeners();
    } catch (e) {
      _connectionStatus = '연결 실패';
      notifyListeners();
      rethrow;
    }
  }
  
  // 연결 해제
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      try {
        await _hubConnection!.stop();
        _isConnected = false;
        _isMatched = false;
        _connectionStatus = '연결 끊김';
        _matchStatus = '매칭 없음';
        notifyListeners();
      } catch (e) {
        debugPrint('연결 해제 중 오류: $e');
        rethrow;
      }
    }
  }
  
  // 클라이언트 등록
  Future<void> _registerClient() async {
    try {
      // 성별 정보 가져오기
      final gender = AppPreferences.gender;
      
      // 등록 정보 전송
      await _hubConnection!.invoke('Register', args: [
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
      debugPrint('클라이언트 등록 중 오류: $e');
      rethrow;
    }
  }
  
  // 대기열 참가
  Future<void> joinQueue() async {
    if (!_isConnected) return;
    
    try {
      _matchStatus = '매칭 대기열에 참가 중...';
      notifyListeners();
      
      await _hubConnection!.invoke(
        'JoinWaitingQueue',
        args: [
          _latitude,
          _longitude,
          AppPreferences.gender,
          _preferredGenderValue,
          _maxDistance,
        ],
      );
    } catch (e) {
      _matchStatus = '매칭 대기열 참가 실패';
      notifyListeners();
      rethrow;
    }
  }
  
  // 대화 종료
  Future<void> endChat() async {
    if (!_isConnected) return;
    
    try {
      await _hubConnection!.invoke('EndChat');
      
      // 시스템 메시지 추가
      _messages.add(ChatMessage(
        content: '대화를 종료하고 새로운 상대를 찾습니다.',
        isFromMe: false,
        isSystemMessage: true,
      ));
      
      notifyListeners();
    } catch (e) {
      debugPrint('대화 종료 중 오류: $e');
      rethrow;
    }
  }
  
  // 메시지 전송
  Future<void> sendMessage(String message) async {
    if (!_isConnected || !_isMatched || message.trim().isEmpty) return;
    
    try {
      await _hubConnection!.invoke('SendMessage', args: [message]);
    } catch (e) {
      debugPrint('메시지 전송 중 오류: $e');
      rethrow;
    }
  }
  
  // 이미지 전송
  Future<void> sendImage(String filePath) async {
    if (!_isConnected || !_isMatched) return;
    
    try {
      // 진행 상태 표시
      _messages.add(ChatMessage(
        content: '이미지 업로드 중...',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
      
      // 멀티파트 폼 데이터 생성
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_serverUrl/api/client/$_clientId/image'),
      );
      
      // 파일 추가
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
      
      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('이미지 업로드 실패: ${response.body}');
      }
      
      // 성공 메시지
      _messages.add(ChatMessage(
        content: '이미지를 전송했습니다.',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
    } catch (e) {
      // 오류 메시지
      _messages.add(ChatMessage(
        content: '이미지 전송 중 오류가 발생했습니다: $e',
        isFromMe: false,
        isSystemMessage: true,
      ));
      notifyListeners();
      rethrow;
    }
  }
  
  // 선호도 업데이트
  Future<void> updatePreferences(String preferredGender, int maxDistance) async {
    if (!_isConnected) return;
    
    try {
      _preferredGenderValue = preferredGender;
      _maxDistance = maxDistance;
      
      await _hubConnection!.invoke(
        'UpdatePreferences',
        args: [preferredGender, maxDistance],
      );
      
      // 앱 설정에 저장
      AppPreferences.preferredGender = preferredGender;
      AppPreferences.maxDistance = maxDistance;
    } catch (e) {
      debugPrint('선호도 업데이트 중 오류: $e');
      rethrow;
    }
  }
  
  // 선호도 활성화
  Future<void> activatePreference(String preferredGender, int maxDistance) async {
    if (!_isConnected || !canActivatePreference) return;
    
    try {
      await _hubConnection!.invoke(
        'ActivatePreference',
        args: [preferredGender, maxDistance],
      );
    } catch (e) {
      debugPrint('선호도 활성화 중 오류: $e');
      rethrow;
    }
  }
  
  // 위치 업데이트
  Future<void> updateLocation(double latitude, double longitude) async {
    if (!_isConnected) return;
    
    try {
      _latitude = latitude;
      _longitude = longitude;
      
      await _hubConnection!.invoke(
        'UpdateLocation',
        args: [latitude, longitude],
      );
      
      // 앱 설정에 저장
      AppPreferences.latitude = latitude;
      AppPreferences.longitude = longitude;
      
      notifyListeners();
    } catch (e) {
      debugPrint('위치 업데이트 중 오류: $e');
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
      
      // 앱 설정에 저장
      AppPreferences.points = _points;
      if (_preferenceActiveUntil != null) {
        AppPreferences.preferenceActiveUntil = _preferenceActiveUntil!.millisecondsSinceEpoch;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('포인트 충전 중 오류: $e');
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
    
    _hubConnection!.onclose((error) {
      _isConnected = false;
      _isMatched = false;
      _connectionStatus = '연결 끊김';
      _matchStatus = '매칭 없음';
      
      if (error != null) {
        _messages.add(ChatMessage(
          content: '서버 연결이 끊어졌습니다: $error',
          isFromMe: false,
          isSystemMessage: true,
        ));
      }
      
      notifyListeners();
    });
  }
  
  // 등록 완료 핸들러
  void _handleRegistered(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    
    final data = jsonDecode(args[0].toString());
    _clientId = data['clientId'];
    
    // 포인트 정보
    if (data['points'] != null) {
      _points = data['points'];
    }
    
    // 선호도 활성화 정보
    if (data['preferenceActiveUntil'] != null && data['preferenceActiveUntil'] != 'null') {
      _preferenceActiveUntil = DateTime.parse(data['preferenceActiveUntil']);
    }
    
    // 앱 설정에 저장
    AppPreferences.clientId = _clientId ?? '';
    AppPreferences.points = _points;
    if (_preferenceActiveUntil != null) {
      AppPreferences.preferenceActiveUntil = _preferenceActiveUntil!.millisecondsSinceEpoch;
    }
    
    _connectionStatus = '등록됨: $_clientId';
    notifyListeners();
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
  }
  
  // 이미지 메시지 수신 핸들러
  void _handleReceiveImageMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    
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
    
    // 앱 설정에 저장
    AppPreferences.points = _points;
    if (_preferenceActiveUntil != null) {
      AppPreferences.preferenceActiveUntil = _preferenceActiveUntil!.millisecondsSinceEpoch;
    }
    
    notifyListeners();
  }
}