import 'package:flutter/material.dart';
import 'package:flutter_random_chat/models/product_item.dart';
import 'package:flutter_random_chat/services/chat_service.dart';

class StoreScreen extends StatefulWidget {
  final ChatService chatService;
  
  const StoreScreen({
    Key? key,
    required this.chatService,
  }) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late List<ProductItem> _products;
  
  @override
  void initState() {
    super.initState();
    _initializeProducts();
  }
  
  void _initializeProducts() {
    _products = [
      ProductItem(
        id: 'basic_points',
        name: '기본 포인트 패키지',
        description: '1,000 포인트 충전 (선호도 설정 1회 이용 가능)',
        price: 1000,
        pointsAmount: 1000,
      ),
      ProductItem(
        id: 'standard_points',
        name: '스탠다드 포인트 패키지',
        description: '3,000 포인트 충전 (선호도 설정 3회 이용 가능)',
        price: 3000,
        pointsAmount: 3000,
      ),
      ProductItem(
        id: 'premium_points',
        name: '프리미엄 포인트 패키지',
        description: '5,000 포인트 충전 (선호도 설정 5회 이용 가능)',
        price: 5000,
        pointsAmount: 5000,
      ),
      ProductItem(
        id: 'free_points',
        name: '무료 테스트 포인트',
        description: '테스트용 무료 포인트 1,000 P',
        price: 0,
        pointsAmount: 1000,
      ),
    ];
  }
  
  Future<void> _purchaseProduct(ProductItem product) async {
    if (product.price > 0) {
      // 결제 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('결제 확인'),
          content: Text(
            '${product.name}을(를) ${product.price}원에 구매하시겠습니까?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('결제'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // TODO: 실제 결제 처리 연동
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('결제가 완료되었습니다. ${product.pointsAmount} 포인트가 충전됩니다.'),
        ),
      );
    }
    
    // 포인트 충전 처리
    try {
      await widget.chatService.chargePoints(product.pointsAmount);
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.pointsAmount} 포인트가 충전되었습니다.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포인트 충전 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포인트 상점'),
      ),
      body: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 포인트: ${widget.chatService.points} P',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '선호도 설정을 활성화하면 10분간 선호하는 성별, 거리로 대화 상대를 찾을 수 있습니다.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          
          // 제품 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(product.description),
                              const SizedBox(height: 8),
                              Text(
                                product.priceText,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => _purchaseProduct(product),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('구매'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}