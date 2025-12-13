import 'dart:async';
import 'package:flutter/material.dart';
import '../models/camera_model.dart';
import '../models/accessory_model.dart';
import '../models/combo_model.dart';
import '../models/unavailable_range.dart';
import '../services/api_service.dart';

class CameraCard extends StatefulWidget {
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

  BookingItemType get _itemType {
    if (_isCombo) return BookingItemType.combo;
    if (_isAccessory) return BookingItemType.accessory;
    return BookingItemType.camera;
  }

  @override
  State<CameraCard> createState() => _CameraCardState();
}

class _CameraCardState extends State<CameraCard> {
  List<UnavailableRange>? _cachedRanges;
  DateTime? _lastFetchTime;
  Timer? _refreshTimer;
  bool _isLoading = false;
  static const Duration _refreshInterval = Duration(minutes: 5);

  bool get _isAccessory => widget.accessory != null;
  bool get _isCombo => widget.combo != null;
  
  String get _id {
    if (_isCombo) return widget.combo!.id;
    if (_isAccessory) return widget.accessory!.id;
    return widget.camera!.id;
  }

  BookingItemType get _itemType {
    if (_isCombo) return BookingItemType.combo;
    if (_isAccessory) return BookingItemType.accessory;
    return BookingItemType.camera;
  }

  String get _name {
    if (_isCombo) return widget.combo!.name;
    if (_isAccessory) return widget.accessory!.name;
    return widget.camera!.name;
  }

  String get _brand {
    if (_isCombo) return widget.combo!.brandLabel;
    if (_isAccessory) return widget.accessory!.brand;
    return widget.camera!.brand;
  }

  String get _imageUrl {
    if (_isCombo) return widget.combo!.imageUrl;
    if (_isAccessory) return widget.accessory!.imageUrl;
    return widget.camera!.imageUrl;
  }

  double get _pricePerDay {
    if (_isCombo) return widget.combo!.pricePerDay;
    if (_isAccessory) return widget.accessory!.pricePerDay;
    return widget.camera!.pricePerDay;
  }

  String get _description {
    if (_isCombo) return widget.combo!.displayDescription;
    if (_isAccessory) return widget.accessory!.description;
    return widget.camera!.description;
  }

  String get _branchName {
    if (_isCombo) return widget.combo!.branchDisplayName;
    if (_isAccessory) return widget.accessory!.branchDisplayName;
    return widget.camera!.branchDisplayName;
  }

  @override
  void initState() {
    super.initState();
    _loadBookingStatus();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (mounted) {
        _loadBookingStatus();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadBookingStatus() async {
    // Skip if recently loaded (within 1 minute)
    if (_lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < const Duration(minutes: 1)) {
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ApiService.getUnavailableRanges(_id, _itemType);
      
      if (mounted) {
        setState(() {
          _cachedRanges = data
              .map((json) => UnavailableRange.fromJson(json))
              .where((range) => range.status.toLowerCase() != 'cancelled')
              .toList();
          _cachedRanges!.sort((a, b) => a.startDate.compareTo(b.startDate));
          _lastFetchTime = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Keep cached data on error
        });
      }
    }
  }

  Widget _buildBookingStatus() {
    // Show loading state
    if (_isLoading && _cachedRanges == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Đang kiểm tra...',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // If no data or empty, show as available
    if (_cachedRanges == null || _cachedRanges!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.green[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 12,
              color: Colors.green[700],
            ),
            const SizedBox(width: 4),
            Text(
              'Máy ảnh đang sẵn sàng',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Format dates for display (dd/MM/yyyy)
    String formatDate(DateTime date) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }

    // Get the first (upcoming) booking
    final firstBooking = _cachedRanges!.first;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_busy,
                size: 12,
                color: Colors.orange[700],
              ),
              const SizedBox(width: 4),
              Text(
                'Đã được đặt',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[900],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bắt đầu: ${formatDate(firstBooking.startDate)}',
            style: TextStyle(
              fontSize: 9,
              color: Colors.orange[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Kết thúc: ${formatDate(firstBooking.endDate)}',
            style: TextStyle(
              fontSize: 9,
              color: Colors.orange[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_cachedRanges!.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+${_cachedRanges!.length - 1} lịch đặt khác',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchDisplay = _branchName;

    final priceLabel = _isCombo
        ? widget.combo!.shortPriceLabel
        : _isAccessory
            ? widget.accessory!.shortPriceLabel
            : widget.camera!.shortPriceLabel;
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
          onTap: widget.onTap,
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
                      if (widget.onAddToCart != null)
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
                              onTap: widget.onAddToCart,
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
                      const SizedBox(height: 8),
                      // Booking Status - Show booking dates or available status
                      _buildBookingStatus(),
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
