import 'package:flutter/material.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedGender = AppPreferences.gender;
  bool _pushNotificationEnabled = true; // SharedPreferences에서 가져올 수 있음
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 사용자 정보 섹션
          _buildSectionHeader('사용자 정보'),
          _buildGenderSetting(),
          const SizedBox(height: 24),
          
          // 알림 설정 섹션
          _buildSectionHeader('알림 설정'),
          _buildPushNotificationSetting(),
          const SizedBox(height: 24),
          
          // 앱 정보 섹션
          _buildSectionHeader('앱 정보'),
          _buildAppVersionInfo(),
          _buildUsageGuide(),
          _buildPrivacyPolicy(),
          _buildTermsOfService(),
          const SizedBox(height: 24),
          
          // 기타 설정
          _buildSectionHeader('기타'),
          _buildServerUrlSetting(),
          _buildCacheClean(),
          _buildAppReset(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildGenderSetting() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person),
        title: const Text('내 성별'),
        subtitle: Text(_selectedGender == 'male' ? '남성' : '여성'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showGenderDialog,
      ),
    );
  }

  Widget _buildPushNotificationSetting() {
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications),
        title: const Text('푸시 알림'),
        subtitle: const Text('새로운 메시지 및 매칭 알림'),
        value: _pushNotificationEnabled,
        onChanged: (bool value) {
          setState(() {
            _pushNotificationEnabled = value;
          });
          // TODO: SharedPreferences에 저장
          _showSnackBar('푸시 알림 설정이 ${value ? '활성화' : '비활성화'}되었습니다.');
        },
      ),
    );
  }

  Widget _buildAppVersionInfo() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info),
        title: const Text('앱 버전'),
        subtitle: const Text('v1.0.0 (Build 1)'),
        trailing: TextButton(
          onPressed: _checkForUpdates,
          child: const Text('업데이트 확인'),
        ),
      ),
    );
  }

  Widget _buildUsageGuide() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.help),
        title: const Text('이용 안내'),
        subtitle: const Text('앱 사용법 및 도움말'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showUsageGuide,
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.privacy_tip),
        title: const Text('개인정보 처리방침'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showPrivacyPolicy,
      ),
    );
  }

  Widget _buildTermsOfService() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description),
        title: const Text('서비스 이용약관'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showTermsOfService,
      ),
    );
  }

  Widget _buildServerUrlSetting() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.dns),
        title: const Text('서버 설정'),
        subtitle: Text(AppPreferences.serverUrl),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showServerUrlDialog,
      ),
    );
  }

  Widget _buildCacheClean() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cleaning_services),
        title: const Text('캐시 삭제'),
        subtitle: const Text('임시 파일 및 이미지 캐시 삭제'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showCacheCleanDialog,
      ),
    );
  }

  Widget _buildAppReset() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.restore, color: Colors.red),
        title: const Text('앱 초기화', style: TextStyle(color: Colors.red)),
        subtitle: const Text('모든 설정 및 데이터 삭제'),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
        onTap: _showResetDialog,
      ),
    );
  }

  void _showGenderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성별 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('남성'),
              value: 'male',
              groupValue: _selectedGender,
              onChanged: (value) {
                setState(() => _selectedGender = value!);
                AppPreferences.gender = value!;
                Navigator.pop(context);
                _showSnackBar('성별이 변경되었습니다. 다음 연결부터 적용됩니다.');
              },
            ),
            RadioListTile<String>(
              title: const Text('여성'),
              value: 'female',
              groupValue: _selectedGender,
              onChanged: (value) {
                setState(() => _selectedGender = value!);
                AppPreferences.gender = value!;
                Navigator.pop(context);
                _showSnackBar('성별이 변경되었습니다. 다음 연결부터 적용됩니다.');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _showServerUrlDialog() {
    final controller = TextEditingController(text: AppPreferences.serverUrl);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서버 URL 설정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '서버 URL',
            hintText: 'http://192.168.1.100:5115',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              AppPreferences.serverUrl = controller.text;
              Navigator.pop(context);
              _showSnackBar('서버 URL이 변경되었습니다. 앱을 재시작해주세요.');
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _checkForUpdates() {
    _showSnackBar('최신 버전입니다.');
  }

  void _showUsageGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이용 안내'),
        content: const SingleChildScrollView(
          child: Text('''
1. 앱 사용법
- 연결 버튼을 눌러 서버에 연결합니다.
- 매칭 대기열에 자동으로 참가됩니다.
- 상대방과 매칭되면 대화를 시작할 수 있습니다.

2. 선호도 설정
- 포인트를 사용하여 선호하는 성별과 거리를 설정할 수 있습니다.
- 선호도 설정은 10분간 유효합니다.

3. 이미지 전송
- 갤러리에서 이미지를 선택하여 전송할 수 있습니다.
- 이미지 크기는 512KB로 제한됩니다.

4. 위치 정보
- 앱은 근처의 사용자와 매칭하기 위해 위치 정보를 사용합니다.
- 위치 권한을 허용하지 않으면 기본 위치가 사용됩니다.

5. 주의사항
- 부적절한 내용은 신고될 수 있습니다.
- 타인을 존중하는 대화를 나누어 주세요.
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개인정보 처리방침'),
        content: const SingleChildScrollView(
          child: Text('''
개인정보 처리방침

1. 수집하는 개인정보
- 위치 정보 (매칭을 위한 목적)
- 성별 정보 (매칭을 위한 목적)
- 대화 내용 (서비스 제공을 위한 목적)

2. 개인정보 이용 목적
- 근거리 사용자 매칭 서비스 제공
- 서비스 품질 향상

3. 개인정보 보유 기간
- 대화 내용: 서비스 종료 시 즉시 삭제
- 위치 정보: 서비스 이용 중에만 사용

4. 개인정보 제3자 제공
- 원칙적으로 제3자에게 제공하지 않습니다.

5. 개인정보 처리 위탁
- 위탁하지 않습니다.

6. 정보주체의 권리
- 개인정보 처리 정지 요구권
- 개인정보 삭제 요구권

문의: admin@example.com
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서비스 이용약관'),
        content: const SingleChildScrollView(
          child: Text('''
서비스 이용약관

제1조 (목적)
본 약관은 Random Chat 서비스 이용에 관한 조건 및 절차를 규정함을 목적으로 합니다.

제2조 (서비스의 내용)
1. 근거리 익명 채팅 서비스
2. 이미지 전송 서비스
3. 매칭 선호도 설정 서비스

제3조 (이용자의 의무)
1. 타인을 존중하는 대화를 나누어야 합니다.
2. 부적절한 내용을 전송하지 않아야 합니다.
3. 개인정보를 무분별하게 공유하지 않아야 합니다.

제4조 (서비스 이용제한)
1. 부적절한 행위 시 서비스 이용이 제한될 수 있습니다.
2. 기술적 문제 발생 시 일시적으로 서비스가 중단될 수 있습니다.

제5조 (면책조항)
1. 서비스 이용 중 발생하는 문제에 대해 회사는 책임지지 않습니다.
2. 이용자 간의 분쟁에 대해 회사는 개입하지 않습니다.

문의: admin@example.com
최종 수정일: 2024년 1월 1일
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showCacheCleanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('임시 파일과 이미지 캐시를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 실제 캐시 삭제 로직 구현
              _showSnackBar('캐시가 삭제되었습니다.');
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 초기화'),
        content: const Text('모든 설정과 데이터가 삭제됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: SharedPreferences 초기화 로직
              _showSnackBar('앱이 초기화되었습니다. 앱을 재시작해주세요.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('초기화', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}