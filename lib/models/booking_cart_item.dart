import '../services/api_service.dart';

class BookingCartItem {
  final String id;
  final String cameraId;
  final String cameraName;
  final String branchName;
  final DateTime? startDate;
  final DateTime? endDate;
  final double pricePerDay;
  final double totalPrice;
  final BookingItemType? type;
  final int quantity;
  final String? imageUrl;
  final Map<String, dynamic> raw;

  const BookingCartItem({
    required this.id,
    required this.cameraId,
    required this.cameraName,
    required this.branchName,
    required this.startDate,
    required this.endDate,
    required this.pricePerDay,
    required this.totalPrice,
    required this.type,
    this.quantity = 1,
    this.imageUrl,
    required this.raw,
  });

  int get rentalDays {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }

  factory BookingCartItem.fromJson(Map<String, dynamic> json) {
    final camera = _asMap(json['camera']);
    final bookingItem = _asMap(json['bookingItem']);

    // Lấy ID - có thể là cart item ID hoặc booking item ID
    final id =
        _asString(json['id']) ??
        _asString(json['cartItemId']) ??
        _asString(json['bookingCartItemId']) ??
        _asString(json['bookingItemId']) ??
        _asString(bookingItem['id']) ??
        '';
    // Lấy item ID - có thể là cameraId hoặc accessoryId
    final cameraId =
        _asString(json['cameraId']) ??
        _asString(json['itemId']) ??
        _asString(json['accessoryId']) ??
        _asString(camera['id']) ??
        _asString(camera['_id']) ??
        _asString(bookingItem['cameraId']) ??
        _asString(bookingItem['itemId']) ??
        _asString(bookingItem['accessoryId']) ??
        '';

    final branchName =
        _asString(json['branchName']) ??
        _asString(camera['branchName']) ??
        _asString(bookingItem['branchName']) ??
        '';

    // Lấy tên sản phẩm - có thể là camera hoặc accessory
    String cameraName =
        _asString(json['cameraName']) ??
        _asString(json['itemName']) ??
        _asString(json['name']) ??
        _asString(json['accessoryName']) ??
        _asString(camera['name']) ??
        _asString(bookingItem['name']) ??
        '';

    if (cameraName.isEmpty) {
      // Thử build từ brand/model nếu có
      cameraName = _buildCameraName(
        brand:
            _asString(json['brand']) ??
            _asString(camera['brand']) ??
            _asString(bookingItem['brand']) ??
            '',
        model:
            _asString(json['model']) ??
            _asString(camera['model']) ??
            _asString(bookingItem['model']) ??
            '',
        variant:
            _asString(json['variant']) ??
            _asString(camera['variant']) ??
            _asString(bookingItem['variant']),
      );
    }

    // Nếu vẫn không có tên, dùng tên mặc định dựa trên type
    if (cameraName.isEmpty) {
      final itemType =
          json['type'] ?? json['itemType'] ?? json['bookingItemType'];
      if (itemType == 2 || itemType == BookingItemType.accessory.value) {
        cameraName = 'Phụ kiện';
      } else {
        cameraName = 'Máy ảnh';
      }
    }

    final startDate = _parseDate(
      json['startDate'] ??
          json['start_date'] ??
          json['fromDate'] ??
          json['from'] ??
          bookingItem['startDate'] ??
          bookingItem['start_date'] ??
          json['rentalDate'] ??
          json['rental_date'],
    );
    final endDate = _parseDate(
      json['endDate'] ??
          json['end_date'] ??
          json['toDate'] ??
          json['to'] ??
          bookingItem['endDate'] ??
          bookingItem['end_date'] ??
          json['returnDate'] ??
          json['return_date'],
    );

    final pricePerDay = _toDouble(
      json['pricePerDay'] ??
          json['price_per_day'] ??
          json['dailyRate'] ??
          json['daily_rate'] ??
          json['rate'] ??
          camera['pricePerDay'] ??
          camera['price_per_day'] ??
          camera['baseDailyRate'] ??
          camera['base_daily_rate'] ??
          bookingItem['pricePerDay'] ??
          bookingItem['baseDailyRate'],
    );

    final quantity = _toInt(
      json['quantity'] ?? json['qty'] ?? bookingItem['quantity'] ?? 1,
    );

    var totalPrice = _toDouble(
      json['totalPrice'] ??
          json['total_price'] ??
          json['total'] ??
          json['totalAmount'] ??
          json['total_amount'] ??
          bookingItem['totalPrice'] ??
          bookingItem['total_price'],
    );

    // Tính toán totalPrice nếu không có từ backend
    if (totalPrice == 0 &&
        pricePerDay > 0 &&
        startDate != null &&
        endDate != null) {
      final days = endDate.difference(startDate).inDays + 1;
      totalPrice = pricePerDay * days * quantity;
    }

    final typeValue =
        json['type'] ??
        json['itemType'] ??
        json['bookingItemType'] ??
        json['item_type'];

    final imageUrl = _asString(
      json['imageUrl'] ??
          json['image_url'] ??
          json['image'] ??
          camera['imageUrl'] ??
          camera['image_url'] ??
          camera['image'],
    );

    return BookingCartItem(
      id: id,
      cameraId: cameraId,
      cameraName: cameraName,
      branchName: branchName,
      startDate: startDate,
      endDate: endDate,
      pricePerDay: pricePerDay,
      totalPrice: totalPrice,
      type: BookingItemType.fromValue(typeValue),
      quantity: quantity,
      imageUrl: imageUrl,
      raw: json,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return {};
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 1;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String _buildCameraName({
    required String brand,
    required String model,
    String? variant,
  }) {
    final buffer = StringBuffer();
    if (brand.isNotEmpty) {
      buffer.write(brand);
    }
    if (model.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(model);
    }
    if (variant != null && variant.isNotEmpty) {
      buffer.write(' ');
      buffer.write(variant);
    }
    return buffer.isEmpty ? 'Máy ảnh chưa xác định' : buffer.toString();
  }
}
