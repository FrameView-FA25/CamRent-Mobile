import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/camera_model.dart';
import '../../models/unavailable_range.dart';
import '../../services/api_service.dart';
import '../../main/main_screen.dart';
import '../../utils/vietnam_provinces.dart';

class BookingScreen extends StatefulWidget {
  final CameraModel camera;

  const BookingScreen({super.key, required this.camera});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  bool _isSubmitting = false;
  bool _isLoadingRanges = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Form fields
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedProvince;
  
  // Date selection
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Unavailable ranges
  List<UnavailableRange> _unavailableRanges = [];
  static const int _minDaysBetweenBookings = 7;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    _loadUnavailableRanges();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUnavailableRanges() async {
    setState(() {
      _isLoadingRanges = true;
    });

    try {
      final data = await ApiService.getUnavailableRanges(
        widget.camera.id,
        BookingItemType.camera,
      );
      
      if (mounted) {
        setState(() {
          _unavailableRanges = data
              .map((json) => UnavailableRange.fromJson(json))
              .where((range) => range.status.toLowerCase() != 'cancelled')
              .toList();
          _unavailableRanges.sort((a, b) => a.startDate.compareTo(b.startDate));
          _isLoadingRanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRanges = false;
        });
      }
    }
  }

  /// Check if a date is disabled (within unavailable range or buffer zone)
  /// Ví dụ: booking từ 1/2 đến 5/2 thì khóa từ 25/1 đến 12/2 (7 ngày trước và sau)
  bool _isDateDisabled(DateTime date) {
    // Don't allow past dates
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    if (dateOnly.isBefore(todayOnly)) {
      return true;
    }

    // Check if date is within any unavailable range or buffer zone
    for (final range in _unavailableRanges) {
      final rangeStart = DateTime(
        range.startDate.year,
        range.startDate.month,
        range.startDate.day,
      );
      final rangeEnd = DateTime(
        range.endDate.year,
        range.endDate.month,
        range.endDate.day,
      );
      
      // Calculate buffer zone (7 days before and after)
      // Ví dụ: booking từ 1/2 đến 5/2
      // bufferStart = 25/1 (1/2 - 7 ngày)
      // bufferEnd = 12/2 (5/2 + 7 ngày)
      final bufferStart = rangeStart.subtract(const Duration(days: _minDaysBetweenBookings));
      final bufferEnd = rangeEnd.add(const Duration(days: _minDaysBetweenBookings));
      
      // Check if date is within the buffer zone (inclusive)
      // date >= bufferStart && date <= bufferEnd
      if (!dateOnly.isBefore(bufferStart) && !dateOnly.isAfter(bufferEnd)) {
        return true;
      }
    }
    
    return false;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (date) => !_isDateDisabled(date),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày bắt đầu trước'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        // Must be after start date
        if (date.isBefore(_startDate!)) return false;
        return !_isDateDisabled(date);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _calculateRentalDays() {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays;
  }

  double _calculateTotalPrice() {
    final days = _calculateRentalDays();
    return days * widget.camera.pricePerDay;
  }

  String _formatPrice(double price) {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return "$formatted VNĐ";
  }

  Future<void> _addToCart() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProvince == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn tỉnh thành'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày bắt đầu và kết thúc'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate end date is after start date
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ngày kết thúc phải sau ngày bắt đầu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate selected date range doesn't conflict with unavailable ranges
    final selectedStart = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final selectedEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    
    for (final range in _unavailableRanges) {
      final rangeStart = DateTime(
        range.startDate.year,
        range.startDate.month,
        range.startDate.day,
      );
      final rangeEnd = DateTime(
        range.endDate.year,
        range.endDate.month,
        range.endDate.day,
      );
      
      final bufferStart = rangeStart.subtract(const Duration(days: _minDaysBetweenBookings));
      final bufferEnd = rangeEnd.add(const Duration(days: _minDaysBetweenBookings));
      
      // Check if selected range overlaps with buffer zone
      if ((selectedStart.isAfter(bufferStart.subtract(const Duration(days: 1))) &&
           selectedStart.isBefore(bufferEnd.add(const Duration(days: 1)))) ||
          (selectedEnd.isAfter(bufferStart.subtract(const Duration(days: 1))) &&
           selectedEnd.isBefore(bufferEnd.add(const Duration(days: 1)))) ||
          (selectedStart.isBefore(bufferStart) && selectedEnd.isAfter(bufferEnd))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Khoảng thời gian đã chọn trùng với lịch đặt khác hoặc quá gần (cần cách tối thiểu $_minDaysBetweenBookings ngày)',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await ApiService.addCameraToCart(
        cameraId: widget.camera.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;
      
      if (response['alreadyInCart'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.camera.name}\nĐã có trong giỏ hàng rồi'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        MainScreen.reloadCart();
        Navigator.of(context).pop(false);
        return;
      }
      
      MainScreen.reloadCart();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6600).withOpacity(0.25),
              const Color(0xFFFF6600).withOpacity(0.2),
              const Color(0xFF00A651).withOpacity(0.15),
              const Color(0xFF0066CC).withOpacity(0.1),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Đặt lịch thuê máy ảnh',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Camera Info Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      widget.camera.imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.camera_alt,
                                            color: Colors.grey[400],
                                          ),
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
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Customer Information Section
                            Text(
                              'Thông tin khách hàng',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Name field
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Họ và tên *',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập họ và tên';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Phone field
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Số điện thoại *',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                hintText: '0901234567',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập số điện thoại';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Email field
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                hintText: 'example@email.com',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            // Province dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedProvince,
                              decoration: InputDecoration(
                                labelText: 'Tỉnh/Thành phố *',
                                prefixIcon: const Icon(Icons.location_city_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: VietnamProvinces.provinces.map((province) {
                                return DropdownMenuItem(
                                  value: province,
                                  child: Text(province),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedProvince = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng chọn tỉnh/thành phố';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),
                            // Date Selection Section
                            Text(
                              'Chọn ngày thuê',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingRanges)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (_unavailableRanges.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, 
                                      size: 20, 
                                      color: Colors.orange[800],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Các ngày đã được đặt sẽ bị khóa (bao gồm 7 ngày trước và sau mỗi lịch đặt)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            ],
                            // Start Date
                            InkWell(
                              onTap: _selectStartDate,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _startDate != null
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[300]!,
                                    width: _startDate != null ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      color: _startDate != null
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ngày bắt đầu *',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _startDate != null
                                                ? _formatDate(_startDate!)
                                                : 'Chọn ngày bắt đầu',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: _startDate != null
                                                  ? Colors.black87
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_startDate != null)
                                      Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // End Date
                            InkWell(
                              onTap: _selectEndDate,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _endDate != null
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[300]!,
                                    width: _endDate != null ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_outlined,
                                      color: _endDate != null
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ngày kết thúc *',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _endDate != null
                                                ? _formatDate(_endDate!)
                                                : 'Chọn ngày kết thúc',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: _endDate != null
                                                  ? Colors.black87
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_endDate != null)
                                      Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            // Rental Summary
                            if (_startDate != null && _endDate != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Số ngày thuê:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          '${_calculateRentalDays()} ngày',
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
                                          'Tổng tiền:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          _formatPrice(_calculateTotalPrice()),
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
                            ],
                            const SizedBox(height: 32),
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _addToCart,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.shopping_cart),
                                label: Text(
                                  _isSubmitting ? 'Đang xử lý...' : 'Thêm vào giỏ hàng',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
