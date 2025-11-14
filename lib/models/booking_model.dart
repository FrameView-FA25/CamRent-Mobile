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
    if (items.isEmpty) return 'Không có sản phẩm';
    final firstItem = items.first;
    return firstItem.itemName ?? 'Sản phẩm';
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

    return BookingModel(
      id: json['id']?.toString() ?? '',
      type: json['type'] is int ? json['type'] : 1,
      renterId: json['renterId']?.toString(),
      renterName: renterName,
      renterEmail: renterEmail,
      renterPhone: renterPhone,
      pickupAt: pickupAt,
      returnAt: returnAt,
      branchId: json['branchId']?.toString(),
      branchName: branchName,
      status: json['status'] is int ? json['status'] : 0,
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
    return BookingItem(
      itemId: json['itemId']?.toString(),
      itemName: json['itemName']?.toString(),
      itemType: json['itemType']?.toString(),
      quantity: json['quantity'] is int ? json['quantity'] : 0,
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
