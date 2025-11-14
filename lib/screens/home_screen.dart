import 'package:flutter/material.dart';
import '../models/camera_model.dart';
import '../models/accessory_model.dart';
import '../models/product_item.dart';
import '../services/api_service.dart';
import '../widgets/camera_card.dart';
import 'camera_detail_screen.dart';
import 'accessory_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum FilterType { all, camera, accessory }

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
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
      // Load cả cameras và accessories song song
      final results = await Future.wait([
        ApiService.getCameras().catchError((e) => <dynamic>[]),
        ApiService.getAccessories().catchError((e) => <dynamic>[]),
      ]);

      final camerasData = results[0];
      final accessoriesData = results[1];

      final products = <ProductItem>[];

      // Thêm cameras
      for (final json in camerasData) {
        try {
          if (json is Map<String, dynamic>) {
            final camera = CameraModel.fromJson(json);
            products.add(ProductItem.camera(camera));
          }
        } catch (e) {
          // Bỏ qua item không parse được
        }
      }

      // Thêm accessories
      for (final json in accessoriesData) {
        try {
          if (json is Map<String, dynamic>) {
            final accessory = AccessoryModel.fromJson(json);
            products.add(ProductItem.accessory(accessory));
          }
        } catch (e) {
          // Bỏ qua item không parse được
        }
      }

      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
        _filterProducts(); // Apply current filter
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Fallback to sample cameras on error
          _products =
              CameraModel.getSampleCameras()
                  .map((c) => ProductItem.camera(c))
                  .toList();
          _filteredProducts = _products;
        });
        _filterProducts(); // Apply current filter

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể tải danh sách sản phẩm. Đang sử dụng dữ liệu mẫu.',
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
      if (!mounted || _bannerPageController.hasClients == false) return;
      final nextIndex = (_currentBannerIndex + 1) % _getCameraImages().length;
      _bannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _startBannerAutoScroll();
    });
  }

  List<String> _getCameraImages() {
    return [
      'https://images.unsplash.com/photo-1606983340126-99ab4feaa64a?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1606983340126-99ab4feaa64a?auto=format&fit=crop&w=1200&q=80',
      'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=1200&q=80',
    ];
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      // Lọc theo type trước
      List<ProductItem> typeFiltered = _products;
      if (_selectedFilter == FilterType.camera) {
        typeFiltered =
            _products.where((p) => p.type == ProductType.camera).toList();
      } else if (_selectedFilter == FilterType.accessory) {
        typeFiltered =
            _products.where((p) => p.type == ProductType.accessory).toList();
      }

      // Sau đó lọc theo search query
      if (query.isEmpty) {
        _filteredProducts = typeFiltered;
      } else {
        _filteredProducts =
            typeFiltered.where((product) {
              final nameMatch = product.name.toLowerCase().contains(query);
              final brandMatch = product.brand.toLowerCase().contains(query);
              final branchMatch = product.branchName.toLowerCase().contains(
                query,
              );
              final descriptionMatch = product.description
                  .toLowerCase()
                  .contains(query);
              return nameMatch || brandMatch || branchMatch || descriptionMatch;
            }).toList();
      }
    });
  }

  void _setFilter(FilterType filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterProducts();
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
            // App Bar với ảnh thiên nhiên
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
                    // Ảnh thiên nhiên
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
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.7),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Gradient overlay nhẹ để text dễ đọc (nếu cần)
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
            // Camera images carousel
            SliverToBoxAdapter(
              child: Container(
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
                      itemCount: _getCameraImages().length,
                      itemBuilder: (context, index) {
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
                              _getCameraImages()[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.7),
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
                    // Page indicators
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _getCameraImages().length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _currentBannerIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Search bar
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
                      suffixIcon:
                          _searchController.text.isNotEmpty
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
            // Filter chips
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
            // Product list header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedFilter == FilterType.camera
                          ? 'Danh sách máy ảnh'
                          : _selectedFilter == FilterType.accessory
                          ? 'Danh sách phụ kiện'
                          : 'Danh sách sản phẩm',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_filteredProducts.length} sản phẩm',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Loading state
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            // Product list
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = _filteredProducts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: CameraCard(
                        camera:
                            product.type == ProductType.camera
                                ? product.camera!
                                : null,
                        accessory:
                            product.type == ProductType.accessory
                                ? product.accessory!
                                : null,
                        onTap: () {
                          if (product.type == ProductType.camera) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CameraDetailScreen(
                                      camera: product.camera!,
                                    ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => AccessoryDetailScreen(
                                      accessory: product.accessory!,
                                    ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }, childCount: _filteredProducts.length),
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
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
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
              color:
                  isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isSelected
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
