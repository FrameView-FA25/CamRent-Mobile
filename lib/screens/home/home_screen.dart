import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/camera_model.dart';
import '../../models/accessory_model.dart';
import '../../models/product_item.dart';
import '../../services/api_service.dart';
import '../../widgets/camera_card.dart';
import '../../main/main_screen.dart';
import '../camera/camera_detail_screen.dart';
import '../accessory/accessory_detail_screen.dart';
import '../booking/booking_history_screen.dart';
import '../booking/booking_screen.dart';
import '../booking/booking_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum FilterType { all, camera, accessory }

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Random _random = Random();
  List<ProductItem> _products = [];
  List<ProductItem> _filteredProducts = [];
  bool _isLoading = true;
  FilterType _selectedFilter = FilterType.all;
  final PageController _bannerPageController = PageController();
  int _currentBannerIndex = 0;

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<dynamic> camerasData = [];
      List<dynamic> accessoriesData = [];
      String? errorMessage;

      try {
        camerasData = await ApiService.getCameras();
      } catch (e) {
        errorMessage = 'Không thể tải danh sách máy ảnh: ${e.toString().replaceFirst('Exception: ', '')}';
      }

      try {
        accessoriesData = await ApiService.getAccessories();
      } catch (e) {
        if (errorMessage != null) {
          errorMessage += '\nKhông thể tải danh sách phụ kiện: ${e.toString().replaceFirst('Exception: ', '')}';
        } else {
          errorMessage = 'Không thể tải danh sách phụ kiện: ${e.toString().replaceFirst('Exception: ', '')}';
        }
      }

      final products = <ProductItem>[];
      for (final json in camerasData) {
        if (json is Map<String, dynamic>) {
          final camera = CameraModel.fromJson(json);
          products.add(ProductItem.camera(camera));
        }
      }

      for (final json in accessoriesData) {
        if (json is Map<String, dynamic>) {
          final accessory = AccessoryModel.fromJson(json);
          products.add(ProductItem.accessory(accessory));
        }
      }

      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
          _currentBannerIndex = 0;
        });
        if (_bannerPageController.hasClients) {
          _bannerPageController.jumpToPage(0);
        }
        _filterProducts();

        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(products.isEmpty
                  ? errorMessage
                  : 'Đã tải một phần danh sách sản phẩm. $errorMessage'),
              backgroundColor: products.isEmpty ? Colors.red : Colors.orange,
            ),
          );        
        } else if (products.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hiện tại chưa có sản phẩm nào trong hệ thống.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _products = CameraModel.getSampleCameras()
              .map((c) => ProductItem.camera(c))
              .toList();
          _filteredProducts = _products;
        });
        _filterProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể tải danh sách sản phẩm: ${e.toString().replaceFirst('Exception: ', '')}\nĐang sử dụng dữ liệu mẫu.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _loadProducts();
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final bannerImages = _bannerImages;
      if (bannerImages.isEmpty || !_bannerPageController.hasClients) {
        _startBannerAutoScroll();
        return;
      }
      final nextIndex = (_currentBannerIndex + 1) % bannerImages.length;
      _bannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _startBannerAutoScroll();
    });
  }

  List<String> get _bannerImages {
    final seenUrls = <String>{};
    final images = <String>[];
    for (final product in _products) {
      final imageUrl = product.imageUrl.trim();
      if (imageUrl.isEmpty) continue;
      if (seenUrls.add(imageUrl)) {
        images.add(imageUrl);
      }
    }
    return images;
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<ProductItem> typeFiltered = List.from(_products);
      if (_selectedFilter == FilterType.camera) {
        typeFiltered =
            _products.where((p) => p.type == ProductType.camera).toList();
      } else if (_selectedFilter == FilterType.accessory) {
        typeFiltered =
            _products.where((p) => p.type == ProductType.accessory).toList();
      }

      final filtered = query.isEmpty
          ? typeFiltered
          : typeFiltered.where((product) {
              final nameMatch = product.name.toLowerCase().contains(query);
              final brandMatch = product.brand.toLowerCase().contains(query);
              final branchMatch =
                  product.branchName.toLowerCase().contains(query);
              final descriptionMatch =
                  product.description.toLowerCase().contains(query);
              return nameMatch || brandMatch || branchMatch || descriptionMatch;
            }).toList();

      if (_selectedFilter == FilterType.all && query.isEmpty) {
        filtered.shuffle(_random);
      }

      _filteredProducts = filtered;
    });
  }

  void _setFilter(FilterType filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterProducts();
  }

  Future<void> _handleAddToCart(ProductItem product) async {
    try {
      if (product.type == ProductType.camera) {
        final added = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => BookingScreen(camera: product.camera!),
          ),
        );
        if (added == true && mounted) {
          _showAddToCartSnack(product.name, showCartAction: true);
        }
        return;
      }

      final response = await ApiService.addAccessoryToCart(accessoryId: product.id);
      if (!mounted) return;
      
      // Check if item is already in cart
      if (response['alreadyInCart'] == true) {
        _showAddToCartSnack(
          product.name, 
          cartId: null,
          isAlreadyInCart: true,
        );
        // Reload cart to show the item that's already in cart
        // This ensures UI displays items even when API says "already in cart"
        MainScreen.reloadCart();
        return;
      }
      
      // Log full response to see all available keys
      debugPrint('_handleAddToCart: Full response from addAccessoryToCart: $response');
      debugPrint('_handleAddToCart: Response keys: ${response.keys.toList()}');
      
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
      
      debugPrint('_handleAddToCart: Extracted cart ID (raw): $rawCartId');
      debugPrint('_handleAddToCart: Extracted cart ID (cleaned): $cartId');
      
      // If no cart ID found, log all values to help debug
      if (cartId == null) {
        debugPrint('_handleAddToCart: WARNING - No cart ID found in response!');
        debugPrint('_handleAddToCart: All response values:');
        response.forEach((key, value) {
          debugPrint('  $key: $value (type: ${value.runtimeType})');
        });
      }
      
      _showAddToCartSnack(product.name, cartId: cartId);
      // Reload cart immediately after adding item
      MainScreen.reloadCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  void _showAddToCartSnack(String itemName, {bool showCartAction = false, String? cartId, bool isAlreadyInCart = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 8,
        backgroundColor: isAlreadyInCart ? Colors.orange[900] : Colors.grey[900],
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAlreadyInCart ? Icons.info_outline : Icons.shopping_cart_outlined,
                color: isAlreadyInCart ? Colors.orange[400] : Colors.greenAccent[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAlreadyInCart ? 'Đã có trong giỏ hàng' : 'Đã thêm vào giỏ hàng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    itemName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isAlreadyInCart) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sản phẩm này đã có trong giỏ hàng',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[300],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (cartId != null && cartId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Mã giỏ hàng: $cartId',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.greenAccent[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showCartAction)
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BookingListScreen(),
                    ),
                  ).then((_) {
                    // Reload cart when returning from cart screen
                    // This ensures cart is refreshed after adding items
                    debugPrint('_showAddToCartSnack: Returned from BookingListScreen, cart should reload automatically');
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.greenAccent[200],
                ),
                child: const Text('Xem giỏ'),
              ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToBookingHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BookingHistoryScreen(),
      ),
    );
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
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                title: const SizedBox.shrink(),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1600&q=80',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              elevation: 0,
            ),
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final bannerImages = _bannerImages;
                  if (bannerImages.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.all(16),
                    height: 200,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _bannerPageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentBannerIndex = index;
                            });
                          },
                          itemCount: bannerImages.length,
                          itemBuilder: (context, index) {
                            final imageUrl = bannerImages[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                  .expectedTotalBytes !=
                                              null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
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
                                            Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.camera_alt,
                                          size: 64,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              bannerImages.length,
                              (index) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentBannerIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        context,
                        label: 'Tất cả',
                        isSelected: _selectedFilter == FilterType.all,
                        icon: Icons.apps,
                        onTap: () => _setFilter(FilterType.all),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context,
                        label: 'Máy ảnh',
                        isSelected: _selectedFilter == FilterType.camera,
                        icon: Icons.camera_alt,
                        onTap: () => _setFilter(FilterType.camera),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        context,
                        label: 'Phụ kiện',
                        isSelected: _selectedFilter == FilterType.accessory,
                        icon: Icons.memory,
                        onTap: () => _setFilter(FilterType.accessory),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFilter == FilterType.camera
                              ? 'Máy ảnh'
                              : _selectedFilter == FilterType.accessory
                                  ? 'Phụ kiện'
                                  : 'Sản phẩm',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.0,
                            color: Colors.black87,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_filteredProducts.length} sản phẩm',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredProducts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Không tìm thấy sản phẩm nào',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thử tìm kiếm với từ khóa khác',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = _filteredProducts[index];
                    return CameraCard(
                      camera: product.type == ProductType.camera
                          ? product.camera!
                          : null,
                      accessory: product.type == ProductType.accessory
                          ? product.accessory!
                          : null,
                      onTap: () {
                        if (product.type == ProductType.camera) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CameraDetailScreen(
                                camera: product.camera!,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccessoryDetailScreen(
                                accessory: product.accessory!,
                              ),
                            ),
                          );
                        }
                      },
                      onAddToCart: () => _handleAddToCart(product),
                    );
                  }, childCount: _filteredProducts.length),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ElevatedButton.icon(
                  onPressed: _navigateToBookingHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Lịch sử đặt lịch'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      BuildContext context, {
        required String label,
        required bool isSelected,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
