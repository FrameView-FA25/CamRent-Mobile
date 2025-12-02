import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/camera_model.dart';
import '../../services/api_service.dart';
import '../../main/main_screen.dart';

class BookingScreen extends StatefulWidget {
  final CameraModel camera;

  const BookingScreen({super.key, required this.camera});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Helper function to clean ID by removing surrounding quotes
  String? _cleanId(dynamic id) {
    if (id == null) return null;
    String idStr = id.toString().trim();
    // Remove surrounding quotes if present
    if (idStr.startsWith('"') && idStr.endsWith('"')) {
      idStr = idStr.substring(1, idStr.length - 1);
    }
    if (idStr.startsWith("'") && idStr.endsWith("'")) {
      idStr = idStr.substring(1, idStr.length - 1);
    }
    return idStr.isEmpty ? null : idStr;
  }

  Future<void> _addToCart() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await ApiService.addCameraToCart(
        cameraId: widget.camera.id,
      );

      if (!mounted) return;
      
      // Check if item is already in cart
      if (response['alreadyInCart'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.camera.name}\nĐã có trong giỏ hàng rồi'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        // Reload cart to show the item that's already in cart
        MainScreen.reloadCart();
        Navigator.of(context).pop(false); // Return false to indicate not newly added
        return;
      }
      
      // Log full response to see all available keys
      debugPrint('BookingScreen._addToCart: Full response from addCameraToCart: $response');
      debugPrint('BookingScreen._addToCart: Response keys: ${response.keys.toList()}');
      
      // Extract cart ID from response - try multiple possible keys
      final rawCartId = response['cartId'] ?? 
                        response['cart_id'] ?? 
                        response['cartItemId'] ??
                        response['cart_item_id'] ??
                        response['bookingCartId'] ??
                        response['booking_cart_id'] ??
                        response['id'] ?? 
                        response['_id'] ??
                        response['bookingId'] ??
                        response['booking_id'];
      
      // Clean ID: remove surrounding quotes if present
      final cartId = _cleanId(rawCartId);
      
      debugPrint('BookingScreen._addToCart: Extracted cart ID (raw): $rawCartId');
      debugPrint('BookingScreen._addToCart: Extracted cart ID (cleaned): $cartId');
      
      // If no cart ID found, log all values to help debug
      if (cartId == null || cartId.isEmpty) {
        debugPrint('BookingScreen._addToCart: WARNING - No cart ID found in response!');
        debugPrint('BookingScreen._addToCart: All response values:');
        response.forEach((key, value) {
          debugPrint('  $key: $value (type: ${value.runtimeType})');
        });
      } else {
        debugPrint('BookingScreen._addToCart: Cart ID found: $cartId');
        // Show cart ID in a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm vào giỏ hàng\nMã giỏ hàng: $cartId'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Reload cart immediately after adding item
      MainScreen.reloadCart();
      
      // Return true to indicate item was added successfully
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

  String _formatPrice(double price) {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return "$formatted VNĐ";
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.white,
                        splashRadius: 24,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Đặt lịch thuê máy ảnh',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              widget.camera.imageUrl,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 60,
                                    color: Colors.grey[500],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.camera.name,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.camera.brand,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_formatPrice(widget.camera.pricePerDay)}/ngày',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Text(
                              widget.camera.description,
                              style: TextStyle(color: Colors.grey[700]),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Số lượng',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '1',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trạng thái',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Đang sẵn sàng',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _addToCart,
                            icon: const Icon(Icons.shopping_cart),
                            label: Text(
                              _isSubmitting ? 'Đang thêm...' : 'Thêm vào giỏ hàng',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Các sản phẩm khác sẽ được thêm từ danh sách sản phẩm.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
