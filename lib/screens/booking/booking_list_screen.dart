import 'package:flutter/material.dart';

import '../../models/booking_cart_item.dart';
import '../../models/camera_model.dart';
import '../../services/api_service.dart';
import '../camera/camera_detail_screen.dart';
import '../../checkout/checkout_screen.dart';

class BookingListScreen extends StatefulWidget {
  final int initialTabIndex;

  const BookingListScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  bool _isCartLoading = true;

  String? _cartError;

  List<BookingCartItem> _cartItems = const [];

  double _totalAmount = 0;
  double _depositAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  // Reload cart when screen becomes visible
  // This is called when navigating to this screen
  void reloadCart() {
    debugPrint('BookingListScreen: reloadCart() called, mounted: $mounted');
    if (mounted) {
      debugPrint('BookingListScreen: Calling _loadCart()');
      _loadCart();
    } else {
      debugPrint('BookingListScreen: WARNING - Cannot reload cart, widget not mounted');
    }
  }

  Future<void> _loadCart() async {
    setState(() {
      _isCartLoading = true;
      _cartError = null;
    });

    try {
      final data = await ApiService.getBookingCart();
      
      // Log raw data from API
      debugPrint('_loadCart: Raw data from API: $data');
      debugPrint('_loadCart: Data keys: ${data.keys.toList()}');
      debugPrint('_loadCart: Data["items"] type: ${data['items']?.runtimeType}');
      debugPrint('_loadCart: Data["items"] value: ${data['items']}');
      
      final items = _extractItems(data);
      final totals = _extractTotals(data, items);

      // Debug: Log extracted values
      debugPrint('Cart loaded: ${items.length} items');
      debugPrint('Total from response: ${totals.$1}, Deposit: ${totals.$2}');
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        debugPrint(
          'Item $i: ${item.cameraName}, '
          'pricePerDay: ${item.pricePerDay}, '
          'totalPrice: ${item.totalPrice}, '
          'quantity: ${item.quantity}, '
          'days: ${item.rentalDays}',
        );
      }

      if (!mounted) return;
      
      // Log state before update
      debugPrint('_loadCart: Before setState - current items: ${_cartItems.length}, new items: ${items.length}');
      debugPrint('_loadCart: Setting state with ${items.length} items');
      
      setState(() {
        _cartItems = items;
        _totalAmount = totals.$1;
        _depositAmount = totals.$2;
        _isCartLoading = false;
      });
      
      // Log state after update
      debugPrint('_loadCart: After setState - items: ${_cartItems.length}, isLoading: $_isCartLoading');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cartError = e.toString().replaceFirst('Exception: ', '');
        _isCartLoading = false;
      });
    }
  }

  List<BookingCartItem> _extractItems(Map<String, dynamic> data) {
    debugPrint('_extractItems: Starting extraction...');
    debugPrint('_extractItems: Data keys: ${data.keys.toList()}');
    
    final candidates = [
      data['items'],
      data['cartItems'],
      data['cartItemsList'],
      data['bookingItems'],
      if (data['data'] is List) data['data'],
      if (data['data'] is Map<String, dynamic>)
        (data['data'] as Map<String, dynamic>)['items'],
      if (data['data'] is Map<String, dynamic>)
        (data['data'] as Map<String, dynamic>)['cartItems'],
    ];

    debugPrint('_extractItems: Checking ${candidates.length} candidates...');
    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      debugPrint('_extractItems: Candidate $i: ${candidate.runtimeType}');
      if (candidate is List) {
        debugPrint('_extractItems: Found list with ${candidate.length} items');
        if (candidate.isEmpty) {
          debugPrint('_extractItems: List is empty');
          continue;
        }
        debugPrint('_extractItems: First item type: ${candidate.first.runtimeType}');
        try {
          final items = candidate
            .whereType<Map<String, dynamic>>()
              .map((item) {
                debugPrint('_extractItems: Parsing item: ${item.keys.toList()}');
                try {
                  final cartItem = BookingCartItem.fromJson(item);
                  // Check if item has minimal required info
                  if (cartItem.cameraId.isEmpty && cartItem.cameraName == 'Máy ảnh') {
                    debugPrint('_extractItems: WARNING - Item parsed but missing camera info. This might indicate a date conflict.');
                    debugPrint('_extractItems: Item raw data: $item');
                  }
                  return cartItem;
                } catch (e, stackTrace) {
                  debugPrint('_extractItems: Error parsing item: $e');
                  debugPrint('_extractItems: StackTrace: $stackTrace');
                  debugPrint('_extractItems: Item data: $item');
                  // Don't rethrow - continue with other items
                  // Skip this item instead of creating placeholder
                  debugPrint('_extractItems: Skipping item due to parse error');
                  return null; // Return null to filter out later
                }
              })
              .whereType<BookingCartItem>() // Filter out null items
            .toList();
          
          // Log before filtering by id
          debugPrint('_extractItems: Parsed ${items.length} items before id filter');
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            debugPrint('_extractItems: Item $i - id: "${item.id}", cameraId: "${item.cameraId}", cameraName: "${item.cameraName}"');
          }
          
          // Filter out items with empty id, but allow items with valid cameraId even if id is empty
          final validItems = items.where((item) {
            final hasValidId = item.id.isNotEmpty;
            final hasValidCameraId = item.cameraId.isNotEmpty;
            final isValid = hasValidId || hasValidCameraId;
            if (!isValid) {
              debugPrint('_extractItems: Filtering out item - id: "${item.id}", cameraId: "${item.cameraId}", cameraName: "${item.cameraName}"');
            }
            return isValid;
          }).toList();
          
          debugPrint('_extractItems: After filter: ${validItems.length} items (from ${items.length} parsed)');
          if (validItems.length < items.length) {
            debugPrint('_extractItems: WARNING - ${items.length - validItems.length} items were filtered out');
          }
          
          return validItems;
        } catch (e) {
          debugPrint('_extractItems: Error parsing items from candidate $i: $e');
          // Continue to next candidate
        }
      }
    }

    debugPrint('_extractItems: WARNING - No valid items found! Returning empty list.');
    return const [];
  }

  (double, double) _extractTotals(
    Map<String, dynamic> data,
    List<BookingCartItem> items,
  ) {
    // Helper function to search for a value across multiple locations and key variations
    double searchValue({
      required List<String> keyVariations,
      Map<String, dynamic>? source,
    }) {
      final searchData = source ?? data;
      final allLocations = <Map<String, dynamic>>[
        searchData,
        if (searchData['data'] is Map<String, dynamic>)
          searchData['data'] as Map<String, dynamic>,
        if (searchData['summary'] is Map<String, dynamic>)
          searchData['summary'] as Map<String, dynamic>,
        if (searchData['cart'] is Map<String, dynamic>)
          searchData['cart'] as Map<String, dynamic>,
        if (searchData['result'] is Map<String, dynamic>)
          searchData['result'] as Map<String, dynamic>,
      ];

      for (final location in allLocations) {
        
        for (final key in keyVariations) {
          final value = location[key];
          if (value != null) {
            final doubleValue = _toDouble(value);
            if (doubleValue > 0) {
              return doubleValue;
            }
          }
        }
      }

      return 0;
    }

    // Search for total amount with multiple key variations
    final totalKeyVariations = const [
      'totalAmount',
      'total_amount',
      'totalPrice',
      'total_price',
      'total',
      'grandTotal',
      'grand_total',
      'sum',
      'amount',
    ];

    final totalFromResponse = searchValue(keyVariations: totalKeyVariations);
    
    // Search for deposit amount with multiple key variations
    final depositKeyVariations = const [
      'depositAmount',
      'deposit_amount',
      'totalDeposit',
      'total_deposit',
      'deposit',
      'downPayment',
      'down_payment',
    ];

    final depositFromResponse = searchValue(keyVariations: depositKeyVariations);

    // Calculate total from items if not found in response
    // This is a fallback that should always work if items have valid totalPrice
    var calculatedTotalFromItems = items.fold<double>(
      0.0,
      (sum, item) {
        final itemTotal = item.totalPrice;
        // If item.totalPrice is 0 but we have pricePerDay and dates, calculate it
        if (itemTotal == 0 && item.pricePerDay > 0) {
          if (item.startDate != null && item.endDate != null) {
            final days = item.endDate!.difference(item.startDate!).inDays + 1;
            if (days > 0) {
              return sum + (item.pricePerDay * days * item.quantity);
            }
          }
          // Fallback: use pricePerDay * quantity if no dates
          return sum + (item.pricePerDay * item.quantity);
        }
        return sum + itemTotal;
      },
    );

    // Use response value if available, otherwise calculate from items
    // Prefer calculated from items if it's more than 0 (even if response has a value)
    // This ensures we always show correct totals
    final finalTotal = calculatedTotalFromItems > 0
        ? calculatedTotalFromItems
        : (totalFromResponse > 0 ? totalFromResponse : 0.0);

    // For deposit, prefer response value, default to 0 if not found
    final finalDeposit = depositFromResponse > 0 ? depositFromResponse : 0.0;

    return (finalTotal, finalDeposit);
  }

  Future<void> _handleRemove(BookingCartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa khỏi giỏ hàng'),
            content: Text(
              'Bạn có chắc chắn muốn xóa ${item.cameraName} khỏi giỏ hàng?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final raw = item.raw;
      
      // Extract type from raw data or use default
      BookingItemType itemType = item.type ?? BookingItemType.camera;
      
      // Try to determine type from raw data if not available
      if (item.type == null) {
        final typeValue = raw['type'] ?? 
                         raw['itemType'] ?? 
                         raw['bookingItemType'] ??
                         raw['item_type'];
        
        if (typeValue != null) {
          final parsedType = BookingItemType.fromValue(typeValue);
          if (parsedType != null) {
            itemType = parsedType;
          }
        }
        
        // Also check bookingItem nested object
        if (item.type == null && raw['bookingItem'] is Map) {
          final bookingItem = raw['bookingItem'] as Map<String, dynamic>;
          final bookingItemType = bookingItem['type'] ?? 
                                 bookingItem['itemType'] ??
                                 bookingItem['bookingItemType'];
          if (bookingItemType != null) {
            final parsedType = BookingItemType.fromValue(bookingItemType);
            if (parsedType != null) {
              itemType = parsedType;
            }
          }
        }
      }

      // Lấy ID từ nhiều nguồn - ưu tiên các ID có thể là cart item ID
      String? itemId = item.id;
      
      debugPrint('_handleRemove: Initial item.id=${item.id}, item.type=${item.type}');
      debugPrint('_handleRemove: Raw data keys: ${raw.keys.toList()}');
      
      // Nếu item.id rỗng hoặc không phải UUID, thử lấy từ raw data
      if (itemId.isEmpty || !_isValidUUID(itemId)) {
        debugPrint('_handleRemove: item.id is empty or not UUID, trying to extract from raw data...');
        
        // Thử các key có thể chứa cart item ID
        itemId =
            _asString(raw['id']) ??
            _asString(raw['bookingItemId']) ??
            _asString(raw['cartItemId']) ??
            _asString(raw['bookingCartItemId']) ??
            _asString(raw['bookingCartItem']?['id']) ??
            _asString(raw['bookingItem']?['id']) ??
            _asString(raw['itemId']);
        
        debugPrint('_handleRemove: Extracted itemId from raw data: $itemId');
        
        // Nếu vẫn không có, thử từ nested objects
        if ((itemId == null || itemId.isEmpty || !_isValidUUID(itemId)) && raw['bookingItem'] is Map) {
          final bookingItem = raw['bookingItem'] as Map<String, dynamic>;
          debugPrint('_handleRemove: Checking bookingItem object, keys: ${bookingItem.keys.toList()}');
          
          itemId = _asString(bookingItem['id']) ??
                   _asString(bookingItem['bookingItemId']) ??
                   _asString(bookingItem['itemId']);
          
          debugPrint('_handleRemove: Extracted itemId from bookingItem: $itemId');
        }
      }

      // Validate UUID format
      if (itemId == null || itemId.isEmpty) {
        debugPrint('_handleRemove: Cannot find item ID. Raw data: $raw');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy ID của item để xóa'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!_isValidUUID(itemId)) {
        debugPrint('_handleRemove: Item ID is not a valid UUID: $itemId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID không hợp lệ: $itemId'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Debug: Log thông tin item để kiểm tra
      debugPrint('_handleRemove: Final values - itemId=$itemId, type=${itemType.stringValue} (${itemType.value}), name=${item.cameraName}');
      debugPrint('_handleRemove: Calling ApiService.removeFromCart with: {id: $itemId, type: ${itemType.stringValue}}');

      await ApiService.removeFromCart(itemId: itemId, type: itemType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa ${item.cameraName} khỏi giỏ hàng'),
          backgroundColor: Colors.orange,
        ),
      );
      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      print('Error removing item: $errorMsg');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa: $errorMsg\nID: ${item.id}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _viewCameraDetails(BookingCartItem item) async {
    // Tìm cameraId từ nhiều nguồn
    final raw = item.raw;
    String? cameraId = item.cameraId;

    if (cameraId.isEmpty) {
      // Thử lấy từ raw data
      cameraId =
          raw['cameraId']?.toString() ??
          raw['camera']?['id']?.toString() ??
          raw['bookingItem']?['cameraId']?.toString() ??
          raw['itemId']?.toString() ??
          raw['id']?.toString();
    }

    // Thử tạo CameraModel từ cart item data trước (nếu có đầy đủ thông tin)
    final cameraData = raw['camera'] as Map<String, dynamic>?;

    if (cameraData != null && cameraData.isNotEmpty) {
      try {
        // Thử parse camera từ data có sẵn
        final camera = CameraModel.fromJson(cameraData);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraDetailScreen(camera: camera),
          ),
        );
        return;
      } catch (e) {
        // Nếu parse từ cart data thất bại, tiếp tục gọi API
      }
    }

    if (cameraId == null || cameraId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy ID camera trong giỏ hàng'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Hiển thị loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final fetchedCameraData = await ApiService.getCameraById(cameraId);

      if (fetchedCameraData.isEmpty) {
        throw Exception('API trả về dữ liệu rỗng');
      }

      final camera = CameraModel.fromJson(fetchedCameraData);

      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraDetailScreen(camera: camera),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog

      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tải thông tin camera: $errorMessage\nID: $cameraId',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatCurrency(double value) {
    if (value <= 0) return '0 VNĐ';
    final raw = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buffer.write(raw[i]);
      final position = raw.length - i - 1;
      if (position % 3 == 0 && position != 0) {
        buffer.write(',');
      }
    }
    return '${buffer.toString()} VNĐ';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa chọn';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatRange(BookingCartItem item) {
    final start = _formatDate(item.startDate);
    final end = _formatDate(item.endDate);
    if (item.startDate == null || item.endDate == null) {
      return 'Chưa chọn ngày thuê';
    }
    return '$start → $end';
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6600).withOpacity(0.25), // Cam - chủ đạo
              const Color(0xFFFF6600).withOpacity(0.2), // Cam - tiếp tục
              const Color(0xFF00A651).withOpacity(0.15), // Xanh lá - nhẹ
              const Color(0xFF0066CC).withOpacity(0.1), // Xanh dương - rất nhẹ
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shopping_bag,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đặt lịch của tôi',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Quản lý giỏ hàng',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildCartTab(context),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          _cartItems.isNotEmpty
              ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng cộng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatCurrency(_totalAmount),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (_depositAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đặt cọc dự kiến',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              _formatCurrency(_depositAmount),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed:
                            _cartItems.isNotEmpty
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CheckoutScreen(
                                          cartItems: _cartItems,
                                          totalAmount: _totalAmount,
                                          depositAmount: _depositAmount,
                                        ),
                                      ),
                                    ).then((_) {
                                      // Reload cart sau khi quay lại
                                      _loadCart();
                                    });
                                  }
                                : null,
                        icon: const Icon(Icons.payment),
                        label: const Text(
                          'Đặt lịch thuê',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : const SizedBox.shrink(),
    );
  }

  Widget _buildCartTab(BuildContext context) {
    if (_isCartLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cartError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Không thể tải giỏ hàng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _cartError!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCart,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove_shopping_cart,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Giỏ hàng của bạn đang trống',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Hãy thêm máy ảnh yêu thích vào giỏ để đặt lịch nhanh chóng hơn.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCart,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        itemCount: _cartItems.length,
        itemBuilder: (context, index) {
          final item = _cartItems[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index < _cartItems.length - 1 ? 16 : 0),
            child: _buildCartItem(item),
          );
        },
      ),
    );
  }

  Widget _buildCartItem(BookingCartItem item) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: InkWell(
              onTap: () => _viewCameraDetails(item),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            (item.type ?? BookingItemType.camera) == BookingItemType.accessory
                                ? Icons.memory
                                : Icons.camera_alt,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.cameraName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.branchName.isNotEmpty
                                    ? item.branchName
                                    : 'Chi nhánh chưa xác định',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'view') {
                              _viewCameraDetails(item);
                            } else if (value == 'remove') {
                              _handleRemove(item);
                            }
                          },
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 20),
                                      SizedBox(width: 8),
                                      Text('Xem chi tiết'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Xóa khỏi giỏ',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.imageUrl!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.camera_alt,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatRange(item),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (item.startDate != null &&
                                  item.endDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${item.rentalDays} ngày thuê',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.price_change,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_formatCurrency(item.pricePerDay)}/ngày',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (item.quantity > 1) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Số lượng: ${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Tổng tiền',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(item.totalPrice),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }


  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _isValidUUID(String? value) {
    if (value == null || value.isEmpty) return false;
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(value);
  }
}
