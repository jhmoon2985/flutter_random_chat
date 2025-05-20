import 'package:flutter/material.dart';

class ChatMessage {
  final String content;
  final bool isFromMe;
  final bool isSystemMessage;
  final DateTime timestamp;
  final String? thumbnailUrl;
  final String? imageUrl;
  final bool isImageMessage;
  
  ChatMessage({
    required this.content,
    required this.isFromMe,
    this.isSystemMessage = false,
    DateTime? timestamp,
    this.thumbnailUrl,
    this.imageUrl,
    this.isImageMessage = false,
  }) : this.timestamp = timestamp ?? DateTime.now();
  
  String get formattedTime => 
    '${timestamp.hour.toString().padLeft(2, '0')}:'
    '${timestamp.minute.toString().padLeft(2, '0')}';
    
  HorizontalAlignment get messageAlignment =>
    isSystemMessage 
      ? HorizontalAlignment.center
      : isFromMe 
        ? HorizontalAlignment.right 
        : HorizontalAlignment.left;
        
  Color get messageBackground =>
    isSystemMessage 
      ? Colors.grey[300]!
      : isFromMe 
        ? Colors.lightBlue[100]! 
        : Colors.white;
}

enum HorizontalAlignment {
  left,
  center, 
  right,
}

// lib/models/product_item.dart - 상품 아이템 모델
class ProductItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final int pointsAmount;
  
  ProductItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.pointsAmount,
  });
  
  String get priceText => price > 0 ? '${price}원' : '무료';
}