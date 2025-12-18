import 'package:flutter/foundation.dart';

class BranchModel {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final bool isActive;
  final Map<String, dynamic> raw;

  BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.isActive = true,
    required this.raw,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    // Extract address information
    String? address;
    final addressData = json['address'];
    if (addressData is Map<String, dynamic>) {
      final parts = <String>[];
      if (addressData['street'] != null) {
        parts.add(addressData['street'].toString());
      }
      if (addressData['ward'] != null) {
        parts.add(addressData['ward'].toString());
      }
      if (addressData['district'] != null) {
        parts.add(addressData['district'].toString());
      }
      if (addressData['province'] != null) {
        parts.add(addressData['province'].toString());
      }
      if (addressData['city'] != null) {
        parts.add(addressData['city'].toString());
      }
      if (parts.isNotEmpty) {
        address = parts.join(', ');
      }
    } else if (addressData is String) {
      address = addressData;
    }

    // Fallback to direct address field
    if (address == null || address.isEmpty) {
      address = json['address']?.toString();
    }

    return BranchModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Chi nhánh',
      address: address,
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      isActive: json['isActive'] as bool? ?? 
                (json['active'] as bool?) ?? 
                true,
      raw: json,
    );
  }

  String get displayName => name.isNotEmpty ? name : 'Chi nhánh';
  
  String get displayAddress => address ?? 'Đang cập nhật';
}

