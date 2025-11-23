import 'package:flutter/material.dart';
import '../../models/camera_model.dart';
import '../../services/api_service.dart';

class BookingScreen extends StatefulWidget {
  final CameraModel camera;

  const BookingScreen({super.key, required this.camera});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _existingBookings = [];

  @override
  void initState() {
    super.initState();
    _loadExistingBookings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadExistingBookings() async {
    try {
      final bookings = await ApiService.getCameraBookings(widget.camera.id);
      if (mounted) {
        setState(() {
          _existingBookings = bookings;
        });
      }
    } catch (e) {
      // Silently fail - we'll still validate on submit
      debugPrint('Error loading existing bookings: $e');
    }
  }

  // Check if dates overlap with existing bookings
  bool _isDateRangeAvailable(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    for (final booking in _existingBookings) {
      final pickupAt = booking['pickupAt'];
      final returnAt = booking['returnAt'];
      
      if (pickupAt == null || returnAt == null) continue;

      DateTime? bookingStart;
      DateTime? bookingEnd;

      if (pickupAt is String) {
        bookingStart = DateTime.tryParse(pickupAt);
      } else if (pickupAt is DateTime) {
        bookingStart = pickupAt;
      }

      if (returnAt is String) {
        bookingEnd = DateTime.tryParse(returnAt);
      } else if (returnAt is DateTime) {
        bookingEnd = returnAt;
      }

      if (bookingStart == null || bookingEnd == null) continue;

      final bookingStartDate = DateTime(bookingStart.year, bookingStart.month, bookingStart.day);
      final bookingEndDate = DateTime(bookingEnd.year, bookingEnd.month, bookingEnd.day);

      // Check if dates overlap
      // Overlap occurs if: start <= bookingEnd && end >= bookingStart
      if (startDate.isBefore(bookingEndDate.add(const Duration(days: 1))) &&
          endDate.isAfter(bookingStartDate.subtract(const Duration(days: 1)))) {
        return false;
      }
    }
    return true;
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today, // Không cho chọn quá khứ
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final pickedDate = DateTime(picked.year, picked.month, picked.day);
      if (pickedDate.isBefore(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chọn ngày trong quá khứ'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() {
        _startDate = pickedDate;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày bắt đầu trước')),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final pickedDate = DateTime(picked.year, picked.month, picked.day);
      if (pickedDate.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ngày kết thúc phải sau ngày bắt đầu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() {
        _endDate = pickedDate;
      });
    }
  }

  double _calculateTotal() {
    if (_startDate == null || _endDate == null) return 0;
    final days = _endDate!.difference(_startDate!).inDays + 1;
    return widget.camera.pricePerDay * days;
  }

  Future<void> _submitBooking() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày bắt đầu và ngày kết thúc'),
        ),
      );
      return;
    }

    // Validate dates
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final endDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    // Check if start date is in the past
    if (startDate.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thuê trong quá khứ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if dates overlap with existing bookings
    if (!_isDateRangeAvailable(startDate, endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máy ảnh đã được thuê trong khoảng thời gian này. Vui lòng chọn thời gian khác.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Thêm vào giỏ hàng'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Máy ảnh: ${widget.camera.name}'),
                const SizedBox(height: 8),
                Text('Ngày bắt đầu: ${_formatDate(_startDate!)}'),
                Text('Ngày kết thúc: ${_formatDate(_endDate!)}'),
                const SizedBox(height: 8),
                Text(
                  'Tổng tiền dự kiến: ${_formatPrice(_calculateTotal())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Thêm'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _addToCart();
    }
  }

  Future<void> _addToCart() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiService.addCameraToCart(
        cameraId: widget.camera.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VNĐ';
  }

  @override
  Widget build(BuildContext context) {
    final totalDays =
        _startDate != null && _endDate != null
            ? _endDate!.difference(_startDate!).inDays + 1
            : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch thuê máy ảnh')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Camera info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.network(
                          widget.camera.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.camera_alt,
                              color: Colors.grey[500],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.camera.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.camera.brand,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatPrice(widget.camera.pricePerDay)}/ngày',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (widget.camera.ownerDisplayNameOrNull != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Chủ sở hữu: ${widget.camera.ownerDisplayNameOrNull}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            if (widget.camera.branchManagerDisplayNameOrNull != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Quản lý chi nhánh: ${widget.camera.branchManagerDisplayNameOrNull}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thông tin ngày thuê',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Start date
              InkWell(
                onTap: _selectStartDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày bắt đầu',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  child: Text(
                    _startDate != null
                        ? _formatDate(_startDate!)
                        : 'Chọn ngày bắt đầu',
                    style: TextStyle(
                      color:
                          _startDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // End date
              InkWell(
                onTap: _selectEndDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày kết thúc',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  child: Text(
                    _endDate != null
                        ? _formatDate(_endDate!)
                        : 'Chọn ngày kết thúc',
                    style: TextStyle(
                      color: _endDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Total summary
              if (_startDate != null && _endDate != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Số ngày thuê:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '$totalDays ngày',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Giá/ngày:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _formatPrice(widget.camera.pricePerDay),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng tiền:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatPrice(_calculateTotal()),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Thêm vào giỏ hàng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
