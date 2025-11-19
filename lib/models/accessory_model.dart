import 'package:flutter/foundation.dart';

class AccessoryModel {
  final String id;
  final String name;
  final String brand;
  final String modelCode;
  final String? variant;
  final String description;
  final double pricePerDay;
  final String imageUrl;
  final List<String> features;
  final bool isAvailable;
  final String branchName;
  final String branchAddress;
  final String ownerName;
  final String branchManagerName;
  final double platformFeePercent;
  final double estimatedValue;
  final double depositPercent;
  final double? depositCapMin;
  final double? depositCapMax;
  final String? specsJson;
  final List<String> mediaUrls;

  AccessoryModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.modelCode,
    required this.description,
    required this.pricePerDay,
    required this.imageUrl,
    required this.features,
    this.variant,
    this.isAvailable = true,
    this.branchName = '',
    this.branchAddress = '',
    this.ownerName = '',
    this.branchManagerName = '',
    this.platformFeePercent = 0,
    this.estimatedValue = 0,
    this.depositPercent = 0,
    this.depositCapMin,
    this.depositCapMax,
    this.specsJson,
    this.mediaUrls = const [],
  });

  String get branchDisplayName => branchName.isNotEmpty ? branchName : 'Đang cập nhật';

  String? get branchAddressDisplay =>
      branchAddress.isNotEmpty ? branchAddress : null;

  String get ownerDisplayName => ownerName.isNotEmpty ? ownerName : 'Đang cập nhật';

  String? get ownerDisplayNameOrNull => ownerName.isNotEmpty ? ownerName : null;

  String get branchManagerDisplayName =>
      branchManagerName.isNotEmpty ? branchManagerName : 'Đang cập nhật';

  String? get branchManagerDisplayNameOrNull =>
      branchManagerName.isNotEmpty ? branchManagerName : null;

  String get shortPriceLabel {
    if (pricePerDay <= 0) {
      return 'Liên hệ';
    }
    final priceInThousands = pricePerDay / 1000;
    final formatted = priceInThousands % 1 == 0
        ? priceInThousands.toStringAsFixed(0)
        : priceInThousands.toStringAsFixed(1);
    return '${formatted}k';
  }

  String get pricePerDayFormatted {
    if (pricePerDay <= 0) {
      return '0';
    }
    final raw = pricePerDay.toStringAsFixed(0);
    return raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String get depositDetailLabel {
    final parts = <String>[];

    if (depositPercent > 0) {
      parts.add('${depositPercent.toStringAsFixed(0)}%');
    }

    if (depositCapMin != null && depositCapMin! > 0) {
      final range = depositCapMax != null && depositCapMax! > 0
          ? '${formatCurrency(depositCapMin!)} - ${formatCurrency(depositCapMax!)}'
          : formatCurrency(depositCapMin!);
      parts.add(range);
    }

    return parts.isEmpty ? 'Không áp dụng' : parts.join(' • ');
  }

  String get platformFeeLabel =>
      platformFeePercent > 0 ? '${platformFeePercent.toStringAsFixed(0)}%' : 'Không áp dụng';

  String get estimatedValueLabel =>
      estimatedValue > 0 ? formatCurrency(estimatedValue) : 'Đang cập nhật';

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _buildName(String brand, String model, String? variant) {
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
    return buffer.isEmpty ? 'Phụ kiện không tên' : buffer.toString();
  }

  static String _buildBranchAddress(Map<String, dynamic>? address) {
    if (address == null) return '';
    final parts = <String>[];
    void addPart(String? value) {
      if (value != null && value.trim().isNotEmpty) {
        parts.add(value.trim());
      }
    }

    addPart(address['line1']?.toString());
    addPart(address['line2']?.toString());
    addPart(address['ward']?.toString());
    addPart(address['district']?.toString());
    addPart(address['province']?.toString());
    addPart(address['country']?.toString());
    return parts.join(', ');
  }

  static String _extractContactName(Map<String, dynamic>? user) {
    if (user == null) return '';
    
    // Try multiple possible field names
    final candidates = [
      user['fullName'],
      user['full_name'],
      user['name'],
      user['displayName'],
      user['display_name'],
      user['userName'],
      user['user_name'],
      user['firstName'],
      user['first_name'],
      user['lastName'],
      user['last_name'],
      user['email'],
    ];
    
    for (final value in candidates) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null' && text != 'string') {
        return text;
      }
    }
    
    // If no name found, try to build from first + last name
    final firstName = user['firstName']?.toString() ?? user['first_name']?.toString();
    final lastName = user['lastName']?.toString() ?? user['last_name']?.toString();
    if (firstName != null && firstName.trim().isNotEmpty && 
        lastName != null && lastName.trim().isNotEmpty) {
      return '${firstName.trim()} ${lastName.trim()}';
    }
    
    return '';
  }

  static String formatCurrency(double value) {
    if (value <= 0) return '0 VNĐ';
    if (value >= 1000000) {
      final millions = value / 1000000;
      final formatted =
          millions % 1 == 0 ? millions.toStringAsFixed(0) : millions.toStringAsFixed(1);
      return '$formatted triệu VNĐ';
    }
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(0)} nghìn VNĐ';
    }
    return '${value.toStringAsFixed(0)} VNĐ';
  }

  // Create from JSON
  factory AccessoryModel.fromJson(Map<String, dynamic> json) {
    final brand = json['brand']?.toString() ?? '';
    final model = json['model']?.toString() ?? '';
    final variant = json['variant']?.toString();
    final branch = json['branch'] as Map<String, dynamic>?;
    final accessoryId = json['id']?.toString() ?? json['_id']?.toString();
    String branchName = branch?['name']?.toString() ?? '';
    String branchAddress = _buildBranchAddress(
      branch?['address'] as Map<String, dynamic>?,
    );
    branchName = branchName.isNotEmpty
        ? branchName
        : (json['branchName']?.toString() ?? '');
    branchAddress = branchAddress.isNotEmpty
        ? branchAddress
        : (json['branchAddress']?.toString() ?? '');
    // Extract owner information - try multiple possible paths
    Map<String, dynamic>? owner;
    if (json['ownerUser'] != null) {
      owner = json['ownerUser'] as Map<String, dynamic>?;
      debugPrint('Accessory ${accessoryId}: Found ownerUser');
    } else if (json['owner'] != null) {
      owner = json['owner'] as Map<String, dynamic>?;
      debugPrint('Accessory ${accessoryId}: Found owner');
    } else if (json['ownerUserProfile'] != null) {
      owner = json['ownerUserProfile'] as Map<String, dynamic>?;
      debugPrint('Accessory ${accessoryId}: Found ownerUserProfile');
    } else {
      debugPrint('Accessory ${accessoryId}: No owner information found. Available keys: ${json.keys.where((k) => k.toString().toLowerCase().contains('owner')).toList()}');
    }
    
    // Extract branch manager information
    Map<String, dynamic>? branchManager;
    if (branch != null) {
      debugPrint('Accessory ${accessoryId}: Branch found. Branch keys: ${branch.keys.toList()}');
      if (branch['manager'] != null) {
        branchManager = branch['manager'] as Map<String, dynamic>?;
        debugPrint('Accessory ${accessoryId}: Found branch.manager');
      } else if (branch['managerUser'] != null) {
        branchManager = branch['managerUser'] as Map<String, dynamic>?;
        debugPrint('Accessory ${accessoryId}: Found branch.managerUser');
      } else if (branch['managerProfile'] != null) {
        branchManager = branch['managerProfile'] as Map<String, dynamic>?;
        debugPrint('Accessory ${accessoryId}: Found branch.managerProfile');
      } else {
        debugPrint('Accessory ${accessoryId}: No branch manager found in branch object');
      }
    } else {
      debugPrint('Accessory ${accessoryId}: No branch object found');
    }
    
    var ownerName = _extractContactName(owner);
    var branchManagerName = _extractContactName(branchManager);

    if (ownerName.isEmpty) {
      final fallbackOwner = json['ownerName']?.toString().trim();
      if (fallbackOwner != null &&
          fallbackOwner.isNotEmpty &&
          fallbackOwner.toLowerCase() != 'string') {
        ownerName = fallbackOwner;
      }
    }
    if (branchManagerName.isEmpty) {
      final fallbackManager = json['branchManagerName']?.toString().trim();
      if (fallbackManager != null &&
          fallbackManager.isNotEmpty &&
          fallbackManager.toLowerCase() != 'string') {
        branchManagerName = fallbackManager;
      }
    }
    
    // Debug logging
    debugPrint('Accessory ${accessoryId}: ownerName="$ownerName", branchManagerName="$branchManagerName"');
    if (ownerName.isEmpty && owner != null) {
      debugPrint('Accessory ${accessoryId}: ownerUser found but name extraction failed. Keys: ${owner.keys.toList()}');
    }
    if (branchManagerName.isEmpty && branchManager != null) {
      debugPrint('Accessory ${accessoryId}: branch manager found but name extraction failed. Keys: ${branchManager.keys.toList()}');
    }
    final estimatedValue = _toDouble(json['estimatedValueVnd']);
    final depositCapMin = json['depositCapMinVnd'] != null
        ? _toDouble(json['depositCapMinVnd'])
        : null;
    final depositCapMax = json['depositCapMaxVnd'] != null
        ? _toDouble(json['depositCapMaxVnd'])
        : null;
    final platformFeePercent = _toDouble(json['platformFeePercent']);
    final depositPercent = _toDouble(json['depositPercent']);
    final mediaList = (json['media'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final mediaUrls = mediaList
        .map((item) => item['url']?.toString())
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();

    final features = <String>[];
    if (depositPercent > 0) {
      features.add('Đặt cọc ${depositPercent.toStringAsFixed(0)}%');
    }
    if (platformFeePercent > 0) {
      features.add('Phí nền tảng ${platformFeePercent.toStringAsFixed(0)}%');
    }

    final specsJson = json['specs']?.toString() ?? json['specsJson']?.toString();

    final imageUrl = mediaUrls.isNotEmpty
        ? mediaUrls.first
        : (json['imageUrl']?.toString() ??
            json['image']?.toString() ??
            json['image_url']?.toString() ??
            '');

    return AccessoryModel(
      id: accessoryId ?? '',
      name: _buildName(brand, model, variant),
      brand: brand,
      modelCode: model,
      variant: variant,
      description: json['description']?.toString() ?? '',
      pricePerDay: _toDouble(json['pricePerDay'] ?? json['price_per_day'] ?? json['dailyRate']),
      imageUrl: imageUrl,
      features: features,
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? true,
      branchName: branchName,
      branchAddress: branchAddress,
      ownerName: ownerName,
      branchManagerName: branchManagerName,
      platformFeePercent: platformFeePercent,
      estimatedValue: estimatedValue,
      depositPercent: depositPercent,
      depositCapMin: depositCapMin,
      depositCapMax: depositCapMax,
      specsJson: specsJson,
      mediaUrls: mediaUrls,
    );
  }
}

