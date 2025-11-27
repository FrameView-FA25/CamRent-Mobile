import 'package:flutter/foundation.dart';

import 'accessory_model.dart';
import 'camera_model.dart';

class ComboItemModel {
  final CameraModel? camera;
  final AccessoryModel? accessory;
  final int quantity;

  ComboItemModel({
    this.camera,
    this.accessory,
    required this.quantity,
  });

  factory ComboItemModel.fromJson(Map<String, dynamic> json) {
    CameraModel? camera;
    AccessoryModel? accessory;

    final cameraRaw = json['camera'] ?? json['Camera'];
    if (cameraRaw is Map<String, dynamic>) {
      camera = CameraModel.fromJson(cameraRaw);
    }

    final accessoryRaw = json['accessory'] ?? json['Accessory'];
    if (accessoryRaw is Map<String, dynamic>) {
      accessory = AccessoryModel.fromJson(accessoryRaw);
    }

    final quantity = _parseInt(json['quantity']);
    return ComboItemModel(
      camera: camera,
      accessory: accessory,
      quantity: quantity,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 1;
    }
    return 1;
  }
}

class ComboModel {
  static const List<String> _fallbackImages = [
    'https://images.unsplash.com/photo-1519183071298-a2962b7b8a3b?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1484704849700-f032a568e944?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1484704849700-f032a568e944?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
  ];

  final String id;
  final String name;
  final String description;
  final double? priceOverride;
  final double? depositOverride;
  final List<ComboItemModel> items;

  ComboModel({
    required this.id,
    required this.name,
    required this.description,
    this.priceOverride,
    this.depositOverride,
    required this.items,
  });

  factory ComboModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['Items'] ?? [];
    final parsedItems = <ComboItemModel>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          try {
            parsedItems.add(ComboItemModel.fromJson(entry));
          } catch (e, st) {
            debugPrint('ComboModel.fromJson: failed to parse item: $e\n$st');
          }
        }
      }
    }

    return ComboModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Combo',
      description: json['description']?.toString() ?? '',
      priceOverride: _toNullableDouble(json['priceOverride'] ?? json['price_override']),
      depositOverride: _toNullableDouble(json['depositOverride'] ?? json['deposit_override']),
      items: parsedItems,
    );
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  List<String> get features {
    final featureList = <String>[];
    final cameraCount = items.where((item) => item.camera != null).length;
    final accessoryCount = items.where((item) => item.accessory != null).length;
    if (cameraCount > 0) {
      featureList.add('$cameraCount máy ảnh');
    }
    if (accessoryCount > 0) {
      featureList.add('$accessoryCount phụ kiện');
    }
    if (depositOverride != null && depositOverride! > 0) {
      featureList.add('Cọc ${CameraModel.formatCurrency(depositOverride!)}');
    }
    if (featureList.isEmpty) {
      featureList.add('Combo máy ảnh & phụ kiện');
    }
    return featureList;
  }

  CameraModel? get _primaryCamera =>
      items.firstWhere((item) => item.camera != null, orElse: () => ComboItemModel(quantity: 1)).camera;

  AccessoryModel? get _primaryAccessory =>
      items.firstWhere((item) => item.accessory != null, orElse: () => ComboItemModel(quantity: 1)).accessory;

  String get imageUrl {
    final candidate = _primaryCamera?.imageUrl ??
        _primaryAccessory?.imageUrl;
    if (candidate != null && candidate.isNotEmpty) return candidate;
    final fallbackIndex = id.hashCode.abs() % _fallbackImages.length;
    return _fallbackImages[fallbackIndex];
  }

  double get pricePerDay {
    if (priceOverride != null && priceOverride! > 0) return priceOverride!;
    var total = 0.0;
    for (final item in items) {
      final quantity = item.quantity;
      final cameraPrice = item.camera?.pricePerDay ?? 0;
      final accessoryPrice = item.accessory?.pricePerDay ?? 0;
      total += (cameraPrice + accessoryPrice) * quantity;
    }
    return total;
  }

  String get shortPriceLabel {
    if (pricePerDay <= 0) return 'Liên hệ';
    final priceInThousands = pricePerDay / 1000;
    final formatted = priceInThousands % 1 == 0
        ? priceInThousands.toStringAsFixed(0)
        : priceInThousands.toStringAsFixed(1);
    return '${formatted}k';
  }

  double get estimatedValue {
    final cameraValue = _primaryCamera?.estimatedValue ?? 0;
    final accessoryValue = _primaryAccessory?.estimatedValue ?? 0;
    return cameraValue + accessoryValue;
  }

  double get platformFeePercent =>
      _primaryCamera?.platformFeePercent ?? _primaryAccessory?.platformFeePercent ?? 0;

  String get branchDisplayName =>
      _primaryCamera?.branchDisplayName ?? _primaryAccessory?.branchDisplayName ?? 'Đang cập nhật';

  String? get branchAddressDisplay =>
      _primaryCamera?.branchAddressDisplay ?? _primaryAccessory?.branchAddressDisplay;

  String? get ownerDisplayName =>
      _primaryCamera?.ownerDisplayNameOrNull ?? _primaryAccessory?.ownerDisplayNameOrNull;

  String? get branchManagerDisplayName =>
      _primaryCamera?.branchManagerDisplayNameOrNull ??
      _primaryAccessory?.branchManagerDisplayNameOrNull;

  String get depositDetailLabel {
    if (depositOverride != null && depositOverride! > 0) {
      return CameraModel.formatCurrency(depositOverride!);
    }
    return 'Không yêu cầu đặt cọc';
  }

  String get displayDescription {
    if (description.isNotEmpty) {
      return description;
    }
    final parts = <String>[];
    if (_primaryCamera != null) {
      parts.add(_primaryCamera!.name);
    }
    final accessoryNames = items
        .map((item) => item.accessory?.name)
        .whereType<String>()
        .toSet()
        .toList();
    if (accessoryNames.isNotEmpty) {
      parts.add(accessoryNames.join(', '));
    }
    if (parts.isEmpty) {
      return 'Combo máy ảnh & phụ kiện';
    }
    return parts.join(' · ');
  }

  String get brandLabel {
    return _primaryCamera?.brand ??
        _primaryAccessory?.brand ??
        'Combo';
  }
}

