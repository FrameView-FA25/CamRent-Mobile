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
        return 'Chờ xử lý';
      case 1:
        return 'Đã xác nhận';
      case 2:
        return 'Đang thuê';
      case 3:
        return 'Đã trả';
      case 4:
        return 'Đã hủy';
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

    // Parse status - can be string ("PendingApproval") or int (0-9)
    int bookingStatus = 0; // default
    if (json['status'] != null) {
      if (json['status'] is int) {
        bookingStatus = json['status'] as int;
      } else if (json['status'] is String) {
        final statusStr = json['status'].toString().toLowerCase();
        // Map common status strings to int values
        final statusMap = {
          'pendingapproval': 0,
          'pending': 0,
          'approved': 1,
          'confirmed': 1,
          'renting': 2,
          'active': 2,
          'returned': 3,
          'completed': 3,
          'cancelled': 4,
          'canceled': 4,
          'rejected': 5,
        };
        bookingStatus = statusMap[statusStr] ?? 0;
      }
    }

    return BookingModel(
      id: json['id']?.toString() ?? '',
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
      snapshotRentalTotal: (json['snapshotRentalTotal'] ?? 0).toDouble(),
      snapshotDepositAmount: (json['snapshotDepositAmount'] ?? 0).toDouble(),
      snapshotBaseDailyRate: (json['snapshotBaseDailyRate'] ?? 0).toDouble(),
      items: items,
      createdAt: createdAt,
      raw: json,
    );
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
    
    return BookingItem(
      itemId: json['itemId']?.toString(),
      itemName: json['itemName']?.toString(),
      itemType: json['itemType']?.toString(),
      quantity: quantity,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
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
