import 'package:flutter/material.dart';
import '../models/camera_model.dart';
import '../models/accessory_model.dart';
import '../models/combo_model.dart';

class CameraCard extends StatelessWidget {
  final CameraModel? camera;
  final AccessoryModel? accessory;
  final ComboModel? combo;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const CameraCard({
    super.key,
    this.camera,
    this.accessory,
    this.combo,
    this.onTap,
    this.onAddToCart,
  }) : assert(
          camera != null || accessory != null || combo != null,
          'Either camera, accessory, or combo must be provided',
        );

  bool get _isAccessory => accessory != null;
  bool get _isCombo => combo != null;
  String get _id {
    if (_isCombo) return combo!.id;
    if (_isAccessory) return accessory!.id;
    return camera!.id;
  }

  String get _name {
    if (_isCombo) return combo!.name;
    if (_isAccessory) return accessory!.name;
    return camera!.name;
  }

  String get _brand {
    if (_isCombo) return combo!.brandLabel;
    if (_isAccessory) return accessory!.brand;
    return camera!.brand;
  }

  String get _imageUrl {
    if (_isCombo) return combo!.imageUrl;
    if (_isAccessory) return accessory!.imageUrl;
    return camera!.imageUrl;
  }

  double get _pricePerDay {
    if (_isCombo) return combo!.pricePerDay;
    if (_isAccessory) return accessory!.pricePerDay;
    return camera!.pricePerDay;
  }

  String get _description {
    if (_isCombo) return combo!.displayDescription;
    if (_isAccessory) return accessory!.description;
    return camera!.description;
  }

  String get _branchName {
    if (_isCombo) return combo!.branchDisplayName;
    if (_isAccessory) return accessory!.branchDisplayName;
    return camera!.branchDisplayName;
  }

  String? get _branchAddress {
    if (_isCombo) return combo!.branchAddressDisplay;
    if (_isAccessory) return accessory!.branchAddressDisplay;
    return camera!.branchAddressDisplay;
  }

  String? get _ownerName {
    if (_isCombo) return combo!.ownerDisplayName;
    if (_isAccessory) return accessory!.ownerDisplayNameOrNull;
    return camera!.ownerDisplayNameOrNull;
  }

  String? get _branchManagerName {
    if (_isCombo) return combo!.branchManagerDisplayName;
    if (_isAccessory) return accessory!.branchManagerDisplayNameOrNull;
    return camera!.branchManagerDisplayNameOrNull;
  }

  String get _depositText {
    if (_isCombo) return combo!.depositDetailLabel;
    if (_isAccessory) return accessory!.depositDetailLabel;
    return camera!.depositDetailLabel;
  }

  double get _estimatedValue {
    if (_isCombo) return combo!.estimatedValue;
    if (_isAccessory) return accessory!.estimatedValue;
    return camera!.estimatedValue;
  }

  double get _platformFeePercent {
    if (_isCombo) return combo!.platformFeePercent;
    if (_isAccessory) return accessory!.platformFeePercent;
    return camera!.platformFeePercent;
  }

  List<String> get _features {
    if (_isCombo) return combo!.features;
    if (_isAccessory) return accessory!.features;
    return camera!.features;
  }

  @override
  Widget build(BuildContext context) {
    final branchDisplay = _branchName;

    final priceLabel = _isCombo
        ? combo!.shortPriceLabel
        : _isAccessory
            ? accessory!.shortPriceLabel
            : camera!.shortPriceLabel;
    final priceCycle = _pricePerDay > 0 ? '/ngày' : '';

    return Container(
      constraints: const BoxConstraints(
        minHeight: 420,
        maxHeight: 420,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product Image - Apple Store Style
              Hero(
                tag: 'product_$_id',
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: Image.network(
                          _imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[50],
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[50],
                            child: Center(
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                      // Add to cart button - Floating
                      if (onAddToCart != null)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 0,
                            shadowColor: Colors.black.withOpacity(0.1),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onAddToCart,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.add_shopping_cart_rounded,
                                  color: Colors.black87,
                                  size: 20,
                                ),
                              ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ),
              // Content - Compact Style
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        child: Text(
                          _brand.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Product Name
                      Text(
                        _name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          letterSpacing: -0.3,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Description
                      Expanded(
                        child: Text(
                          _description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            height: 1.4,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            priceLabel,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (priceCycle.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                priceCycle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Location Info - Compact
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              branchDisplay,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
