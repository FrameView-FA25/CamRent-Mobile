import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/camera_model.dart';

class CameraDetailScreen extends StatelessWidget {
  final CameraModel camera;

  const CameraDetailScreen({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    // Xử lý dữ liệu với fallback để đảm bảo UI luôn hiển thị
    final depositText = camera.depositDetailLabel.isNotEmpty 
        ? camera.depositDetailLabel 
        : 'Không yêu cầu đặt cọc';
    final platformFeeText = camera.platformFeeLabel.isNotEmpty 
        ? camera.platformFeeLabel 
        : 'Không áp dụng';
    final branchDisplay = camera.branchDisplayName.isNotEmpty 
        ? camera.branchDisplayName 
        : 'Đang cập nhật';
    final addressDisplay = (camera.branchAddressDisplay?.isNotEmpty ?? false)
        ? camera.branchAddressDisplay!
        : branchDisplay;
    final estimatedValueText = camera.estimatedValueLabel.isNotEmpty 
        ? camera.estimatedValueLabel 
        : 'Đang cập nhật';
    final ownerDisplay = camera.ownerDisplayName.isNotEmpty 
        ? camera.ownerDisplayName 
        : 'Đang cập nhật';
    final branchManagerDisplay = camera.branchManagerDisplayName.isNotEmpty 
        ? camera.branchManagerDisplayName 
        : 'Đang cập nhật';
    
    // Xử lý ảnh - kiểm tra URL hợp lệ
    final imageUrl = camera.imageUrl.isNotEmpty 
        ? camera.imageUrl 
        : null;
    final cameraName = camera.name.isNotEmpty 
        ? camera.name 
        : 'Máy ảnh';
    final cameraBrand = camera.brand.isNotEmpty 
        ? camera.brand 
        : 'Camera';
    final cameraDescription = camera.description.isNotEmpty 
        ? camera.description 
        : 'Máy ảnh chất lượng cao';
    
    // Parse specs from JSON
    Map<String, dynamic>? specsMap;
    String specsDisplay = 'Đang cập nhật';
    if (camera.specsJson != null && camera.specsJson!.isNotEmpty) {
      try {
        // Try to parse as JSON (may have escaped quotes)
        String cleanedSpecs = camera.specsJson!;
        // Remove escape characters if present
        cleanedSpecs = cleanedSpecs.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
        specsMap = jsonDecode(cleanedSpecs) as Map<String, dynamic>?;
        if (specsMap != null && specsMap.isNotEmpty) {
          final specsList = specsMap.entries.map((e) => '${e.key}: ${e.value}').toList();
          specsDisplay = specsList.join('\n');
        } else {
          // If not JSON, use as plain text
          specsDisplay = cleanedSpecs;
        }
      } catch (e) {
        // If parsing fails, use as plain text
        specsDisplay = camera.specsJson!;
      }
    }
    
    // Format other fields
    final modelCode = camera.modelCode.isNotEmpty ? camera.modelCode : 'Đang cập nhật';
    final variant = (camera.variant != null && camera.variant!.isNotEmpty) 
        ? camera.variant! 
        : 'Đang cập nhật';
    final cameraId = camera.id.isNotEmpty ? camera.id : 'Đang cập nhật';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Container(
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
              // Image với hero animation
              Hero(
                tag: 'product_${camera.id}',
                child: Container(
                  height: 300,
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: double.infinity,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        Colors.grey[100]!,
                      ],
                    ),
                  ),
                  child: ClipRect(
                    child: Stack(
                      children: [
                        // Image container với constraints để thu nhỏ ảnh
                        Center(
                          child: imageUrl != null && imageUrl.trim().isNotEmpty
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: double.infinity,
                                    maxHeight: 300,
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: 300,
                                    // Giảm kích thước ảnh trong memory để tối ưu performance
                                    // Giảm xuống 400x400 để tiết kiệm memory và tải nhanh hơn
                                    cacheWidth: 400,
                                    cacheHeight: 400,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        alignment: Alignment.center,
                                        height: 300,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                              Colors.grey[100]!,
                                            ],
                                          ),
                                        ),
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return SizedBox(
                                        height: 300,
                                        width: double.infinity,
                                        child: _buildImagePlaceholder(context),
                                      );
                                    },
                                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                      if (wasSynchronouslyLoaded) return child;
                                      return AnimatedOpacity(
                                        opacity: frame == null ? 0 : 1,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                        child: child,
                                      );
                                    },
                                  ),
                                )
                              : SizedBox(
                                  height: 380,
                                  width: double.infinity,
                                  child: _buildImagePlaceholder(context),
                                ),
                        ),
                        // Gradient overlay nhẹ ở dưới
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cameraBrand.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cameraName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      cameraDescription,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    // Price card với gradient
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.15),
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Giá thuê/ngày',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_money,
                                      size: 24,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    Text(
                                      camera.pricePerDayFormatted,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      ' VNĐ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Thông tin chi tiết',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.info_outline,
                      title: 'Mã máy ảnh',
                      value: cameraId,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.camera_alt,
                      title: 'Model',
                      value: modelCode,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.category,
                      title: 'Phiên bản',
                      value: variant,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.location_on,
                      title: 'Chi nhánh',
                      value: branchDisplay,
                      subtitle: addressDisplay,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.person,
                      title: 'Chủ sở hữu',
                      value: ownerDisplay,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.manage_accounts,
                      title: 'Quản lý chi nhánh',
                      value: branchManagerDisplay,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.account_balance_wallet,
                      title: 'Đặt cọc',
                      value: depositText,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.monetization_on,
                      title: 'Giá trị ước tính',
                      value: estimatedValueText,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      icon: Icons.percent,
                      title: 'Phí nền tảng',
                      value: platformFeeText,
                    ),
                    if (specsDisplay != 'Đang cập nhật') ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Thông số kỹ thuật',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: specsDisplay.split('\n').map((spec) {
                            if (spec.trim().isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(top: 6, right: 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      spec.trim(),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[700],
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Mô tả',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cameraDescription,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    if (camera.features.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Tính năng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            camera.features.map((feature) {
                              return Chip(
                                label: Text(feature),
                                backgroundColor: Colors.grey[200],
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
                // Add bottom padding
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 120,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Không có hình ảnh',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            subtitle != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
