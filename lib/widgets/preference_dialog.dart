import 'package:flutter/material.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';
import 'package:flutter_random_chat/services/chat_service.dart';

class PreferenceDialog extends StatefulWidget {
  final ChatService chatService;
  
  const PreferenceDialog({
    Key? key,
    required this.chatService,
  }) : super(key: key);

  @override
  State<PreferenceDialog> createState() => _PreferenceDialogState();
}

class _PreferenceDialogState extends State<PreferenceDialog> {
  String _selectedPreferredGender = AppPreferences.preferredGender;
  int _selectedMaxDistance = AppPreferences.maxDistance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('매칭 선호도 설정'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 현재 포인트 표시
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, 
                       color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '현재 포인트: ${widget.chatService.points} P',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 선호도 활성화 상태 표시
            if (widget.chatService.isPreferenceActive) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.chatService.preferenceStatusText,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // 선호 성별 설정
            const Text(
              '선호 성별',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedPreferredGender,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('제한없음')),
                  DropdownMenuItem(value: 'male', child: Text('남성만')),
                  DropdownMenuItem(value: 'female', child: Text('여성만')),
                ],
                onChanged: widget.chatService.canChangePreference
                  ? (value) => setState(() => _selectedPreferredGender = value!)
                  : null,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 최대 거리 설정
            const Text(
              '최대 거리',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<int>(
                value: _selectedMaxDistance,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5km')),
                  DropdownMenuItem(value: 25, child: Text('25km')),
                  DropdownMenuItem(value: 50, child: Text('50km')),
                  DropdownMenuItem(value: 100, child: Text('100km')),
                  DropdownMenuItem(value: 10000, child: Text('제한없음')),
                ],
                onChanged: widget.chatService.canChangePreference
                  ? (value) => setState(() => _selectedMaxDistance = value!)
                  : null,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 안내 메시지
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• 선호도 설정 저장은 무료입니다.\n'
                      '• 선호도 활성화는 1,000 포인트가 필요하며 10분간 유지됩니다.\n'
                      '• 활성화 중에는 설정된 조건으로만 매칭됩니다.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        
        // 설정 저장 버튼
        if (widget.chatService.canSavePreferences)
          TextButton(
            onPressed: _isLoading ? null : _savePreferences,
            child: _isLoading 
              ? const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                )
              : const Text('저장'),
          ),
        
        // 활성화 버튼
        if (widget.chatService.canActivatePreference)
          ElevatedButton(
            onPressed: _isLoading ? null : _activatePreference,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: _isLoading 
              ? const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2, 
                    color: Colors.white
                  )
                )
              : const Text('활성화 (1000P)'),
          ),
      ],
    );
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    
    try {
      await widget.chatService.updatePreferences(
        _selectedPreferredGender,
        _selectedMaxDistance,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선호도 설정이 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('선호도 저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _activatePreference() async {
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선호도 활성화 확인'),
        content: const Text(
          '선호도 설정을 활성화하면 1,000 포인트가 차감됩니다.\n'
          '활성화 후 10분간 설정된 조건으로만 매칭됩니다.\n\n'
          '계속 하시겠습니까?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      await widget.chatService.activatePreference(
        _selectedPreferredGender,
        _selectedMaxDistance,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선호도 설정이 활성화되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('선호도 활성화 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}