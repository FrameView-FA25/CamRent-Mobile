import 'package:flutter/material.dart';

import '../models/booking_cart_item.dart';
import '../models/booking_model.dart';
import '../models/camera_model.dart';
import '../services/api_service.dart';
import 'camera_detail_screen.dart';
import 'checkout_screen.dart';

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isCartLoading = true;
  bool _isHistoryLoading = true;

  String? _cartError;
  String? _historyError;

  List<BookingCartItem> _cartItems = const [];
  List<BookingModel> _historyItems = const [];

  double _totalAmount = 0;
  double _depositAmount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadCart();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isCartLoading = true;
      _cartError = null;
    });

    try {
      final data = await ApiService.getBookingCart();
      final items = _extractItems(data);
      final totals = _extractTotals(data, items);

      if (!mounted) return;
      setState(() {
        _cartItems = items;
        _totalAmount = totals.$1;
        _depositAmount = totals.$2;
        _isCartLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cartError = e.toString().replaceFirst('Exception: ', '');
        _isCartLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isHistoryLoading = true;
      _historyError = null;
    });

    try {
      final data = await ApiService.getBookings();
      final bookings =
          data
              .whereType<Map<String, dynamic>>()
              .map(BookingModel.fromJson)
              .toList();

      if (!mounted) return;
      setState(() {
        _historyItems = bookings;
        _isHistoryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString().replaceFirst('Exception: ', '');
        _isHistoryLoading = false;
      });
    }
  }

  List<BookingCartItem> _extractItems(Map<String, dynamic> data) {
    final candidates = [
      data['items'],
      data['cartItems'],
      if (data['data'] is List) data['data'],
      if (data['data'] is Map<String, dynamic>)
        (data['data'] as Map<String, dynamic>)['items'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map<String, dynamic>>()
            .map(BookingCartItem.fromJson)
            .toList();
      }
    }

    return const [];
  }

  (double, double) _extractTotals(
    Map<String, dynamic> data,
    List<BookingCartItem> items,
  ) {
    double getFromKeys(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value == null && data['data'] is Map<String, dynamic>) {
          final nested = (data['data'] as Map<String, dynamic>)[key];
          if (nested != null) {
            return _toDouble(nested);
          }
        }
        if (value != null) {
          return _toDouble(value);
        }
      }
      return 0;
    }

    final summary = data['summary'] as Map<String, dynamic>? ?? {};

    final total = getFromKeys(const ['totalAmount', 'totalPrice', 'total']);
    final totalFromSummary = _toDouble(summary['totalAmount']);
    final combinedTotal =
        totalFromSummary > 0 ? totalFromSummary : (total > 0 ? total : null);
    final calculatedTotal =
        combinedTotal ??
        items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);

    final deposit = getFromKeys(const ['depositAmount', 'totalDeposit']);
    final depositFromSummary = _toDouble(summary['depositAmount']);
    final combinedDeposit =
        depositFromSummary > 0
            ? depositFromSummary
            : (deposit > 0 ? deposit : 0.0);

    return (calculatedTotal, combinedDeposit);
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
      final itemType = item.type ?? BookingItemType.camera;

      // Lấy ID từ nhiều nguồn - ưu tiên bookingItemId vì đó là ID thực sự của item trong cart
      String? itemId = item.id;
      if (itemId.isEmpty) {
        // Thử lấy từ raw data
        final raw = item.raw;
        itemId =
            _asString(raw['id']) ??
            _asString(raw['bookingItemId']) ??
            _asString(raw['cartItemId']) ??
            _asString(raw['bookingCartItemId']) ??
            _asString(raw['bookingItem']?['id']);
      }

      if (itemId == null || itemId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy ID của item để xóa'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Debug: Log thông tin item để kiểm tra
      print(
        'Removing item: id=$itemId, type=${itemType.value}, name=${item.cameraName}',
      );

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
    return '$start → $end';
  }

  String _formatHistoryRange(BookingModel booking) {
    final start = _formatDate(booking.startDate);
    final end = _formatDate(booking.endDate);
    return '$start → $end';
  }

  Color _statusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange; // Chờ xử lý
      case 1:
        return Colors.blue; // Đã xác nhận
      case 2:
        return Colors.green; // Đang thuê
      case 3:
        return Colors.grey; // Đã trả
      case 4:
        return Colors.red; // Đã hủy
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Colors.white,
            ],
            stops: const [0.0, 0.3],
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
                            'Quản lý giỏ hàng và lịch sử đặt lịch',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.12),
                  ),
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey[600],
                  tabs: [
                    Tab(
                      icon: Icon(
                        Icons.shopping_cart,
                        color:
                            _tabController.index == 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600],
                      ),
                      text: 'Giỏ hàng',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.history,
                        color:
                            _tabController.index == 1
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600],
                      ),
                      text: 'Lịch sử',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildCartTab(context), _buildHistoryTab(context)],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          _tabController.index == 0 && _cartItems.isNotEmpty
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
                                      _loadHistory();
                                    });
                                  }
                                : null,
                        icon: const Icon(Icons.payment),
                        label: const Text(
                          'Thanh toán',
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
              : null,
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
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        itemCount: _cartItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final item = _cartItems[index];
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
                            item.type == BookingItemType.accessory
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
        },
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    if (_isHistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
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
                'Không thể tải lịch sử đặt lịch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _historyError!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_historyItems.isEmpty) {
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
                Icons.history,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Chưa có đặt lịch nào',
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
                'Khi bạn hoàn tất đặt lịch, chúng sẽ xuất hiện tại đây.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _historyItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final booking = _historyItems[index];
          final statusColor = _statusColor(booking.status);
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
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
                          Icons.camera_alt,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.cameraName.isNotEmpty
                                  ? booking.cameraName
                                  : 'Máy ảnh đã xóa',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatHistoryRange(booking),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          booking.statusString,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.customerName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.price_check,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCurrency(booking.totalPrice),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tạo lúc ${_formatDate(booking.createdAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
}
