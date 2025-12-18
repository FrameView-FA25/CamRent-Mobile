import 'package:flutter/foundation.dart';

class BookingModel {
  final String id;
  final int type;
  final String? renterId;
  final String? renterName;
  final String? renterEmail;
  final String? renterPhone;
  final DateTime? pickupAt;
  final DateTime? returnAt;
  final String? branchId;
  final String? branchName;
  final int status;
  final String? statusText;
  final double snapshotRentalTotal;
  final double snapshotDepositAmount;
  final double snapshotBaseDailyRate;
  final List<BookingItem> items;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  BookingModel({
    required this.id,
    required this.type,
    this.renterId,
    this.renterName,
    this.renterEmail,
    this.renterPhone,
    this.pickupAt,
    this.returnAt,
    this.branchId,
    this.branchName,
    required this.status,
    this.statusText,
    required this.snapshotRentalTotal,
    required this.snapshotDepositAmount,
    required this.snapshotBaseDailyRate,
    required this.items,
    this.createdAt,
    required this.raw,
  });

  // Getters for backward compatibility
  String get cameraName {
    if (items.isEmpty) {
      // If no items but has total price, might be a booking in progress
      if (snapshotRentalTotal > 0) {
        return 'Đơn hàng đang xử lý';
      }
      return 'Chưa có sản phẩm';
    }
    
    // If only one item, try to get its name
    if (items.length == 1) {
      final item = items.first;
      if (item.itemName != null && item.itemName!.isNotEmpty) {
        return item.itemName!;
      }
      // If no name, use itemType
      if (item.itemType != null && item.itemType!.isNotEmpty) {
        return item.itemType!;
      }
      return 'Sản phẩm';
    }
    
    // If multiple items, show count
    final cameraCount = items.where((item) => item.itemType == 'Camera').length;
    final accessoryCount = items.where((item) => item.itemType == 'Accessory' || item.itemType == 'Accessories').length;
    
    final parts = <String>[];
    if (cameraCount > 0) {
      parts.add('$cameraCount máy ảnh');
    }
    if (accessoryCount > 0) {
      parts.add('$accessoryCount phụ kiện');
    }
    
    if (parts.isEmpty) {
      return '${items.length} sản phẩm';
    }
    
    return parts.join(', ');
  }

  String get customerName => renterName ?? 'Khách hàng';
  String get customerPhone => renterPhone ?? '';
  String get customerEmail => renterEmail ?? '';
  DateTime get startDate => pickupAt ?? DateTime.now();
  DateTime get endDate => returnAt ?? DateTime.now();
  double get totalPrice => snapshotRentalTotal;
  String get statusString => statusText ?? _getStatusString(status);

  String _getStatusString(int status) {
    switch (status) {
      case 0:
        return 'Giỏ hàng'; // Draft
      case 1:
        return 'Đã xác nhận'; // Confirmed
      case 2:
        return 'Đã nhận máy'; // PickedUp
      case 3:
        return 'Đã trả'; // Returned
      case 4:
        return 'Hoàn tất'; // Completed
      case 5:
        return 'Đã hủy'; // Cancelled
      case 6:
        return 'Quá hạn'; // Overdue
      default:
        return 'Không xác định';
    }
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Parse renter info
    final renter = json['renter'];
    String? renterName;
    String? renterEmail;
    String? renterPhone;
    if (renter is Map<String, dynamic>) {
      renterName = renter['fullName']?.toString();
      renterEmail = renter['email']?.toString();
      renterPhone = renter['phone']?.toString();
    }

    // Parse branch info
    final branch = json['branch'];
    String? branchName;
    if (branch is Map<String, dynamic>) {
      branchName = branch['name']?.toString();
    }

    // Parse dates
    DateTime? pickupAt;
    DateTime? returnAt;
    if (json['pickupAt'] != null) {
      pickupAt = DateTime.tryParse(json['pickupAt'].toString());
    }
    if (json['returnAt'] != null) {
      returnAt = DateTime.tryParse(json['returnAt'].toString());
    }

    // Parse items
    final itemsJson = json['items'] ?? [];
    final items = <BookingItem>[];
    if (itemsJson is List) {
      for (final itemJson in itemsJson) {
        if (itemJson is Map<String, dynamic>) {
          items.add(BookingItem.fromJson(itemJson));
        }
      }
    }

    // Parse createdAt
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      createdAt = DateTime.tryParse(json['createdAt'].toString());
    }

    // Parse type - can be string ("Rental") or int (1, 2)
    int bookingType = 1; // default
    if (json['type'] != null) {
      if (json['type'] is int) {
        bookingType = json['type'] as int;
      } else if (json['type'] is String) {
        final typeStr = json['type'].toString().toLowerCase();
        // Map string to int: "Rental" -> 1, "Sale" -> 2
        if (typeStr == 'rental') {
          bookingType = 1;
        } else if (typeStr == 'sale') {
          bookingType = 2;
        }
      }
    }

    // Parse status - can be string ("PendingApproval", "Draft") or int (0-9)
    int bookingStatus = 0; // default
    if (json['status'] != null) {
      if (json['status'] is int) {
        bookingStatus = json['status'] as int;
      } else if (json['status'] is String) {
        final statusStr = json['status'].toString().toLowerCase();
        // Map common status strings to int values
        final statusMap = {
          'draft': 0, // Draft = 0
          'pendingapproval': 0,
          'pending': 0,
          'approved': 1,
          'confirmed': 1, // Confirmed = 1
          'pickedup': 2, // PickedUp = 2
          'renting': 2,
          'active': 2,
          'returned': 3, // Returned = 3
          'completed': 4, // Completed = 4
          'cancelled': 5, // Cancelled = 5
          'canceled': 5,
          'overdue': 6, // Overdue = 6
          'rejected': 5,
        };
        bookingStatus = statusMap[statusStr] ?? 0;
      }
    }

    // Get id - if empty, generate a temporary id from other fields
    var id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    id = id.trim();
    
    // Remove surrounding quotes if present (e.g., "abc123" -> abc123)
    if (id.startsWith('"') && id.endsWith('"')) {
      id = id.substring(1, id.length - 1);
    }
    if (id.startsWith("'") && id.endsWith("'")) {
      id = id.substring(1, id.length - 1);
    }
    id = id.trim();
    
    // If id is empty, try to generate one from other fields
    if (id.isEmpty) {
      // Try to use createdAt + renterId as temporary identifier
      final createdAtStr = json['createdAt']?.toString() ?? '';
      final renterIdStr = json['renterId']?.toString() ?? '';
      if (createdAtStr.isNotEmpty || renterIdStr.isNotEmpty) {
        id = 'temp_${createdAtStr}_$renterIdStr'.hashCode.toString();
        debugPrint('BookingModel: Generated temporary id: $id (original id was empty)');
      } else {
        // Last resort: use current timestamp
        id = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('BookingModel: Generated temporary id from timestamp: $id');
      }
    }

    return BookingModel(
      id: id,
      type: bookingType,
      renterId: json['renterId']?.toString(),
      renterName: renterName,
      renterEmail: renterEmail,
      renterPhone: renterPhone,
      pickupAt: pickupAt,
      returnAt: returnAt,
      branchId: json['branchId']?.toString(),
      branchName: branchName,
      status: bookingStatus,
      statusText: json['statusText']?.toString(),

      snapshotRentalTotal: _parseDouble(
        json['snapshotRentalTotal'] ?? 
        json['snapshot_rental_total'] ?? 
        json['rentalTotal'] ?? 
        json['rental_total'] ?? 
        json['total'] ?? 
        json['totalPrice'] ?? 
        json['total_price'] ?? 
        0,
      ),
      snapshotDepositAmount: _parseDouble(
        json['snapshotDepositAmount'] ?? 
        json['snapshot_deposit_amount'] ?? 
        json['depositAmount'] ?? 
        json['deposit_amount'] ?? 
        json['deposit'] ?? 
        0,
      ),
      snapshotBaseDailyRate: _parseDouble(
        json['snapshotBaseDailyRate'] ?? 
        json['snapshot_base_daily_rate'] ?? 
        json['baseDailyRate'] ?? 
        json['base_daily_rate'] ?? 
        json['dailyRate'] ?? 
        json['daily_rate'] ?? 
        0,
      ),
      items: items,
      createdAt: createdAt,
      raw: json,
    );
  }
 
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) {
      return value.toDouble();
    }
    final text = value.toString().replaceAll(',', '').trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }
}

class BookingItem {
  final String? itemId;
  final String? itemName;
  final String? itemType;
  final int quantity;
  final double unitPrice;

  BookingItem({
    this.itemId,
    this.itemName,
    this.itemType,
    required this.quantity,
    required this.unitPrice,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    // quantity might not be in response, default to 1
    final quantity = json['quantity'] is int 
        ? json['quantity'] as int 
        : (json['quantity'] != null 
            ? int.tryParse(json['quantity'].toString()) ?? 1 
            : 1);
    
    // Parse unitPrice - can be in different fields
    final unitPrice = BookingModel._parseDouble(
      json['unitPrice'] ?? 
      json['unit_price'] ?? 
      json['price'] ?? 
      json['dailyRate'] ?? 
      json['daily_rate'] ?? 
      0,
    );
    
    return BookingItem(
      itemId: json['itemId']?.toString(),
      itemName: json['itemName']?.toString(),
      itemType: json['itemType']?.toString(),
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemType': itemType,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}
