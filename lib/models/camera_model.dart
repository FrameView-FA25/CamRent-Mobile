import 'package:flutter/foundation.dart';

class CameraModel {
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

  CameraModel({
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

  static const List<String> _scenicImages = [
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500530855697-ec7e08b1e064?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1441829266145-b7a050c59a30?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500530855697-f43f1b1d7f8d?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1470770903676-69b98201ea1c?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500530855697-6eaaf43886c2?auto=format&fit=crop&w=1200&q=80',
  ];

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

    if (parts.isEmpty) {
      return 'Không yêu cầu đặt cọc';
    }

    return parts.join(' • ');
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
    return buffer.isEmpty ? 'Máy ảnh không tên' : buffer.toString();
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
  factory CameraModel.fromJson(Map<String, dynamic> json) {
    final brand = json['brand']?.toString() ?? '';
    final model = json['model']?.toString() ?? '';
    final variant = json['variant']?.toString();
    final branch = json['branch'] as Map<String, dynamic>?;
    final cameraId = json['id']?.toString() ?? json['_id']?.toString();
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
    if (depositCapMin != null && depositCapMin > 0) {
      final depositRange = depositCapMax != null && depositCapMax > 0
          ? '${formatCurrency(depositCapMin)} - ${formatCurrency(depositCapMax)}'
          : formatCurrency(depositCapMin);
      features.add('Cọc: $depositRange');
    }
    if (platformFeePercent > 0) {
      features.add('Phí nền tảng ${platformFeePercent.toStringAsFixed(0)}%');
    }
    if (estimatedValue > 0) {
      features.add('Giá trị ${formatCurrency(estimatedValue)}');
    }

    // Extract owner information - try multiple possible paths
    Map<String, dynamic>? owner;
    if (json['ownerUser'] != null) {
      owner = json['ownerUser'] as Map<String, dynamic>?;
      debugPrint('Camera ${cameraId}: Found ownerUser');
    } else if (json['owner'] != null) {
      owner = json['owner'] as Map<String, dynamic>?;
      debugPrint('Camera ${cameraId}: Found owner');
    } else if (json['ownerUserProfile'] != null) {
      owner = json['ownerUserProfile'] as Map<String, dynamic>?;
      debugPrint('Camera ${cameraId}: Found ownerUserProfile');
    } else {
      debugPrint('Camera ${cameraId}: No owner information found. Available keys: ${json.keys.where((k) => k.toString().toLowerCase().contains('owner')).toList()}');
    }
    
    // Extract branch manager information
    Map<String, dynamic>? branchManager;
    if (branch != null) {
      debugPrint('Camera ${cameraId}: Branch found. Branch keys: ${branch.keys.toList()}');
      if (branch['manager'] != null) {
        branchManager = branch['manager'] as Map<String, dynamic>?;
        debugPrint('Camera ${cameraId}: Found branch.manager');
      } else if (branch['managerUser'] != null) {
        branchManager = branch['managerUser'] as Map<String, dynamic>?;
        debugPrint('Camera ${cameraId}: Found branch.managerUser');
      } else if (branch['managerProfile'] != null) {
        branchManager = branch['managerProfile'] as Map<String, dynamic>?;
        debugPrint('Camera ${cameraId}: Found branch.managerProfile');
      } else {
        debugPrint('Camera ${cameraId}: No branch manager found in branch object');
      }
    } else {
      debugPrint('Camera ${cameraId}: No branch object found');
    }
    
    var ownerName = _extractContactName(owner);
    var branchManagerName = _extractContactName(branchManager);

    // Fallback to plain string fields if maps are not available
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
    debugPrint('Camera ${cameraId}: ownerName="$ownerName", branchManagerName="$branchManagerName"');
    if (ownerName.isEmpty && owner != null) {
      debugPrint('Camera ${cameraId}: ownerUser found but name extraction failed. Keys: ${owner.keys.toList()}');
    }
    if (branchManagerName.isEmpty && branchManager != null) {
      debugPrint('Camera ${cameraId}: branch manager found but name extraction failed. Keys: ${branchManager.keys.toList()}');
    }

    final descriptionParts = <String>[];
    if (estimatedValue > 0) {
      descriptionParts.add('Giá trị ước tính: ${formatCurrency(estimatedValue)}');
    }
    if (depositCapMin != null && depositCapMin > 0) {
      final maxText = depositCapMax != null && depositCapMax > 0
          ? ' - ${formatCurrency(depositCapMax)}'
          : '';
      descriptionParts.add(
        'Cọc tối thiểu: ${formatCurrency(depositCapMin)}$maxText',
      );
    }
    if (branchAddress.isNotEmpty) {
      descriptionParts.add('Địa chỉ: $branchAddress');
    }

    final fallbackImage = _selectScenicImage(
      brand: brand,
      id: cameraId,
    );

    return CameraModel(
      id: cameraId ?? '',
      name: _buildName(brand, model, variant),
      brand: brand,
      modelCode: model,
      variant: variant,
      description: descriptionParts.isNotEmpty
          ? descriptionParts.join(' • ')
          : 'Máy ảnh thuộc chi nhánh $branchName',
      pricePerDay: _toDouble(json['baseDailyRate']),
      imageUrl: mediaUrls.isNotEmpty ? mediaUrls.first : fallbackImage,
      features: features,
      isAvailable: json['isAvailable'] ??
          json['is_available'] ??
          json['available'] ??
          true,
      branchName: branchName,
      branchAddress: branchAddress,
      ownerName: ownerName,
      branchManagerName: branchManagerName,
      platformFeePercent: platformFeePercent,
      estimatedValue: estimatedValue,
      depositPercent: depositPercent,
      depositCapMin: depositCapMin,
      depositCapMax: depositCapMax,
      specsJson: json['specsJson']?.toString(),
      mediaUrls: mediaUrls,
    );
  }

  static String _selectScenicImage({required String brand, String? id}) {
    if (_scenicImages.isEmpty) {
      return 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80';
    }
    final seed = '${brand.toLowerCase()}_${id ?? ''}';
    final index = seed.isNotEmpty
        ? seed.hashCode.abs() % _scenicImages.length
        : DateTime.now().millisecondsSinceEpoch % _scenicImages.length;
    return _scenicImages[index];
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'model': modelCode,
      'variant': variant,
      'description': description,
      'pricePerDay': pricePerDay,
      'imageUrl': imageUrl,
      'features': features,
      'isAvailable': isAvailable,
      'branchName': branchName,
      'branchAddress': branchAddress,
      'ownerName': ownerName,
      'branchManagerName': branchManagerName,
      'platformFeePercent': platformFeePercent,
      'estimatedValue': estimatedValue,
      'depositPercent': depositPercent,
      'depositCapMin': depositCapMin,
      'depositCapMax': depositCapMax,
      'specsJson': specsJson,
      'mediaUrls': mediaUrls,
    };
  }

  // Sample data
  static List<CameraModel> getSampleCameras() {
    return [
      CameraModel(
        id: '1',
        name: 'Canon EOS R5',
        brand: 'Canon',
        modelCode: 'EOS R5',
        description:
            'Giá trị ước tính: 80 triệu VNĐ • Cọc tối thiểu: 10 triệu VNĐ',
        pricePerDay: 500000,
        imageUrl: _selectScenicImage(brand: 'Canon', id: '1'),
        features: const [
          'Chi nhánh: Demo',
          'Đặt cọc 30%',
          'Phí nền tảng 20%',
        ],
        branchName: 'Demo',
        ownerName: 'Chủ sở hữu A',
        branchManagerName: 'Quản lý chi nhánh A',
        platformFeePercent: 20,
        depositPercent: 30,
        estimatedValue: 80000000,
        depositCapMin: 10000000,
        depositCapMax: 30000000,
        mediaUrls: const [],
      ),
      CameraModel(
        id: '2',
        name: 'Sony A7 IV',
        brand: 'Sony',
        modelCode: 'A7 IV',
        description:
            'Giá trị ước tính: 70 triệu VNĐ • Cọc tối thiểu: 8 triệu VNĐ',
        pricePerDay: 450000,
        imageUrl: _selectScenicImage(brand: 'Sony', id: '2'),
        features: const [
          'Chi nhánh: Demo',
          'Đặt cọc 25%',
          'Phí nền tảng 18%',
        ],
        branchName: 'Demo',
        ownerName: 'Chủ sở hữu B',
        branchManagerName: 'Quản lý chi nhánh B',
        platformFeePercent: 18,
        depositPercent: 25,
        estimatedValue: 70000000,
        depositCapMin: 8000000,
        depositCapMax: 25000000,
        mediaUrls: const [],
      ),
      CameraModel(
        id: '3',
        name: 'Nikon Z6 II',
        brand: 'Nikon',
        modelCode: 'Z6 II',
        description:
            'Giá trị ước tính: 50 triệu VNĐ • Cọc tối thiểu: 6 triệu VNĐ',
        pricePerDay: 400000,
        imageUrl: _selectScenicImage(brand: 'Nikon', id: '3'),
        features: const [
          'Chi nhánh: Demo',
          'Đặt cọc 20%',
          'Phí nền tảng 15%',
        ],
        branchName: 'Demo',
        ownerName: 'Chủ sở hữu C',
        branchManagerName: 'Quản lý chi nhánh C',
        platformFeePercent: 15,
        depositPercent: 20,
        estimatedValue: 50000000,
        depositCapMin: 6000000,
        depositCapMax: 20000000,
        mediaUrls: const [],
      ),
    ];
  }
}

