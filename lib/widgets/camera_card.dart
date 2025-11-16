import 'package:flutter/material.dart';
import '../models/camera_model.dart';
import '../models/accessory_model.dart';

class CameraCard extends StatelessWidget {
  final CameraModel? camera;
  final AccessoryModel? accessory;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const CameraCard({
    super.key,
    this.camera,
    this.accessory,
    this.onTap,
    this.onAddToCart,
  }) : assert(
          camera != null || accessory != null,
          'Either camera or accessory must be provided',
        );

  bool get _isAccessory => accessory != null;
  String get _id => _isAccessory ? accessory!.id : camera!.id;
  String get _name => _isAccessory ? accessory!.name : camera!.name;
  String get _brand => _isAccessory ? accessory!.brand : camera!.brand;
  String get _imageUrl => _isAccessory ? accessory!.imageUrl : camera!.imageUrl;
  double get _pricePerDay =>
      _isAccessory ? accessory!.pricePerDay : camera!.pricePerDay;
  String get _description =>
      _isAccessory ? accessory!.description : camera!.description;
  bool get _isAvailable =>
      _isAccessory ? accessory!.isAvailable : camera!.isAvailable;
  String get _branchName =>
      _isAccessory ? accessory!.branchDisplayName : camera!.branchDisplayName;
  String? get _branchAddress =>
      _isAccessory
          ? accessory!.branchAddressDisplay
          : camera!.branchAddressDisplay;
  String get _depositText =>
      _isAccessory ? accessory!.depositDetailLabel : camera!.depositDetailLabel;
  double get _estimatedValue =>
      _isAccessory ? accessory!.estimatedValue : camera!.estimatedValue;
  double get _platformFeePercent =>
      _isAccessory ? accessory!.platformFeePercent : camera!.platformFeePercent;
  List<String> get _features =>
      _isAccessory ? accessory!.features : camera!.features;

  @override
  Widget build(BuildContext context) {
    final branchDisplay = _branchName;
    final addressDisplay = _branchAddress;
    final depositText = _depositText;
    final estimatedValueText =
        _estimatedValue > 0
            ? (_isAccessory
                ? AccessoryModel.formatCurrency(_estimatedValue)
                : CameraModel.formatCurrency(_estimatedValue))
            : null;
    final platformFeeText =
        _platformFeePercent > 0
            ? '${_platformFeePercent.toStringAsFixed(0)}%'
            : null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image với gradient overlay
            Hero(
              tag: '${_isAccessory ? 'accessory' : 'camera'}_$_id',
              child: Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.12),
                          Colors.grey[300]!,
                        ],
                      ),
                    ),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.05),
                        BlendMode.darken,
                      ),
                      child: Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        colorBlendMode: BlendMode.darken,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.3),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.camera_alt,
                                size: 80,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Status badge
                  if (!_isAvailable)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Đã thuê',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Available badge
                  if (_isAvailable)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Có sẵn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Price badge ở góc dưới
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.white.withOpacity(0.9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            _isAccessory
                                ? accessory!.shortPriceLabel
                                : camera!.shortPriceLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (_pricePerDay > 0)
                            Text(
                              '/ngày',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Add to cart button (plus icon)
                  if (_isAvailable && onAddToCart != null)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAddToCart,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand và rating
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _brand.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Text(
                    _description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    context,
                    icon: Icons.location_on,
                    label: 'Chi nhánh',
                    value: branchDisplay,
                    subtitle: addressDisplay,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    icon: Icons.account_balance_wallet,
                    label: 'Đặt cọc',
                    value: depositText,
                  ),
                  if (estimatedValueText != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      icon: Icons.monetization_on,
                      label: 'Giá trị ước tính',
                      value: estimatedValueText,
                    ),
                  ],
                  if (platformFeeText != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      icon: Icons.percent,
                      label: 'Phí nền tảng',
                      value: platformFeeText,
                    ),
                  ],
                  if (_features.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _features.take(3).map((feature) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.grey[100]!, Colors.grey[50]!],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    feature,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            subtitle != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
