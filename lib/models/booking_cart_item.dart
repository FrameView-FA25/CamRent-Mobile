import 'package:flutter/foundation.dart';
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
    // Tính số ngày thuê: từ ngày 10 đến ngày 11 là 1 ngày (không +1)
    return endDate!.difference(startDate!).inDays;
  }

  factory BookingCartItem.fromJson(Map<String, dynamic> json) {
    // Log raw JSON for debugging
    debugPrint('BookingCartItem.fromJson: Raw JSON keys: ${json.keys.toList()}');
    debugPrint('BookingCartItem.fromJson: Raw JSON (first 500 chars): ${json.toString().length > 500 ? json.toString().substring(0, 500) : json.toString()}');
    
    final camera = _asMap(json['camera']);
    final bookingItem = _asMap(json['bookingItem']);
    
    debugPrint('BookingCartItem.fromJson: camera map keys: ${camera.keys.toList()}');
    debugPrint('BookingCartItem.fromJson: bookingItem map keys: ${bookingItem.keys.toList()}');

    // Lấy ID - có thể là cart item ID hoặc booking item ID
    final id =
        _asString(json['id']) ??
        _asString(json['cartItemId']) ??
        _asString(json['bookingCartItemId']) ??
        _asString(json['bookingItemId']) ??
        _asString(bookingItem['id']) ??
        '';
    // Lấy item ID - có thể là cameraId hoặc accessoryId
    // Try direct fields first, then nested objects
    final cameraId =
        _asString(json['cameraId']) ??
        _asString(json['itemId']) ??
        _asString(json['accessoryId']) ??
        _asString(json['productId']) ??
        _asString(json['id']) ??  // Try root id as fallback
        _asString(camera['id']) ??
        _asString(camera['_id']) ??
        _asString(camera['cameraId']) ??
        _asString(bookingItem['cameraId']) ??
        _asString(bookingItem['itemId']) ??
        _asString(bookingItem['accessoryId']) ??
        _asString(bookingItem['id']) ??
        '';
    
    debugPrint('BookingCartItem.fromJson: cameraId: "$cameraId"');

    final branchName =
        _asString(json['branchName']) ??
        _asString(camera['branchName']) ??
        _asString(bookingItem['branchName']) ??
        '';

    // Lấy tên sản phẩm - có thể là camera hoặc accessory
    // Try direct fields first, then nested objects
    String cameraName =
        _asString(json['cameraName']) ??
        _asString(json['itemName']) ??
        _asString(json['name']) ??
        _asString(json['accessoryName']) ??
        _asString(json['productName']) ??
        _asString(json['title']) ??
        _asString(camera['name']) ??
        _asString(camera['cameraName']) ??
        _asString(bookingItem['name']) ??
        _asString(bookingItem['cameraName']) ??
        _asString(bookingItem['itemName']) ??
        '';
    
    debugPrint('BookingCartItem.fromJson: cameraName after first pass: "$cameraName"');

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
    
    // Log final values for debugging
    debugPrint('BookingCartItem.fromJson: Final cameraName: "$cameraName"');
    debugPrint('BookingCartItem.fromJson: Final cameraId: "$cameraId"');
    debugPrint('BookingCartItem.fromJson: Final branchName: "$branchName"');
    
    // Warning if critical fields are missing (might indicate date conflict)
    // Try to get cameraId from bookingItem if cameraId is empty
    var finalCameraId = cameraId;
    if (finalCameraId.isEmpty && cameraName == 'Máy ảnh') {
      debugPrint('BookingCartItem.fromJson: WARNING - cameraId is empty but type is camera. This might indicate a date conflict or missing camera info from backend.');
      debugPrint('BookingCartItem.fromJson: Attempting to extract cameraId from bookingItem...');
      
      // Try to get cameraId from bookingItem if available
      if (bookingItem.isNotEmpty) {
        final bookingItemCameraId = _asString(bookingItem['cameraId']) ??
            _asString(bookingItem['itemId']) ??
            _asString(bookingItem['id']);
        if (bookingItemCameraId != null && bookingItemCameraId.isNotEmpty) {
          debugPrint('BookingCartItem.fromJson: Found cameraId in bookingItem: $bookingItemCameraId');
          finalCameraId = bookingItemCameraId;
        }
      }
      
      // Last resort: if we have id and type is camera, use id as cameraId
      if (finalCameraId.isEmpty && id.isNotEmpty) {
        final itemType = json['type'] ?? json['itemType'] ?? json['bookingItemType'];
        if (itemType == 1 || itemType == BookingItemType.camera.value) {
          debugPrint('BookingCartItem.fromJson: Using id as cameraId fallback: $id');
          finalCameraId = id;
        }
      }
    }
    
    debugPrint('BookingCartItem.fromJson: Final cameraId: "$finalCameraId" (original: "$cameraId")');

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

    // Extract pricePerDay from multiple locations with more variations
    var pricePerDay = _toDouble(
      json['pricePerDay'] ??
          json['price_per_day'] ??
          json['dailyRate'] ??
          json['daily_rate'] ??
          json['rate'] ??
          json['unitPrice'] ??
          json['unit_price'] ??
          json['price'] ??
          camera['pricePerDay'] ??
          camera['price_per_day'] ??
          camera['baseDailyRate'] ??
          camera['base_daily_rate'] ??
          camera['dailyRate'] ??
          camera['daily_rate'] ??
          camera['price'] ??
          bookingItem['pricePerDay'] ??
          bookingItem['baseDailyRate'] ??
          bookingItem['dailyRate'] ??
          bookingItem['unitPrice'] ??
          bookingItem['price'],
    );

    final quantity = _toInt(
      json['quantity'] ?? json['qty'] ?? bookingItem['quantity'] ?? 1,
    );

    // Extract totalPrice from multiple locations
    var totalPrice = _toDouble(
      json['totalPrice'] ??
          json['total_price'] ??
          json['total'] ??
          json['totalAmount'] ??
          json['total_amount'] ??
          json['amount'] ??
          bookingItem['totalPrice'] ??
          bookingItem['total_price'] ??
          bookingItem['amount'] ??
          bookingItem['total'],
    );

    // Calculate totalPrice if not provided or if it's 0
    // Try multiple scenarios:
    // 1. If we have pricePerDay and dates, calculate from those
    if (totalPrice == 0 && pricePerDay > 0 && startDate != null && endDate != null) {
      final days = endDate.difference(startDate).inDays + 1;
      if (days > 0) {
        totalPrice = pricePerDay * days * quantity;
      }
    }
    
    // 2. If we have pricePerDay but no dates, use pricePerDay as total (fallback)
    if (totalPrice == 0 && pricePerDay > 0) {
      totalPrice = pricePerDay * quantity;
    }
    
    // 3. If we have totalPrice but no pricePerDay, try to reverse calculate
    if (pricePerDay == 0 && totalPrice > 0 && startDate != null && endDate != null) {
      final days = endDate.difference(startDate).inDays + 1;
      if (days > 0) {
        pricePerDay = totalPrice / (days * quantity);
      }
    }
    
    // 4. If still no pricePerDay but have totalPrice, use totalPrice / quantity
    if (pricePerDay == 0 && totalPrice > 0) {
      pricePerDay = totalPrice / quantity;
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
      cameraId: finalCameraId,
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
