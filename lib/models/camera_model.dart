class CameraModel {
  final String id;
  final String name;
  final String brand;
  final String description;
  final double pricePerDay;
  final String imageUrl;
  final List<String> features;
  final bool isAvailable;

  CameraModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.pricePerDay,
    required this.imageUrl,
    required this.features,
    this.isAvailable = true,
  });

  // Sample data
  static List<CameraModel> getSampleCameras() {
    return [
      CameraModel(
        id: '1',
        name: 'Canon EOS R5',
        brand: 'Canon',
        description:
            'Máy ảnh mirrorless full-frame với độ phân giải 45MP, quay video 8K, chống rung 5 trục.',
        pricePerDay: 500000,
        imageUrl: 'https://via.placeholder.com/300x200?text=Canon+EOS+R5',
        features: ['45MP', '8K Video', 'IBIS', 'Weather Sealed'],
        isAvailable: true,
      ),
      CameraModel(
        id: '2',
        name: 'Sony A7 IV',
        brand: 'Sony',
        description:
            'Máy ảnh mirrorless full-frame với cảm biến 33MP, autofocus nhanh, quay video 4K.',
        pricePerDay: 450000,
        imageUrl: 'https://via.placeholder.com/300x200?text=Sony+A7+IV',
        features: ['33MP', '4K Video', 'Real-time AF', '10fps'],
        isAvailable: true,
      ),
      CameraModel(
        id: '3',
        name: 'Nikon Z6 II',
        brand: 'Nikon',
        description:
            'Máy ảnh mirrorless full-frame với cảm biến 24.5MP, hiệu năng tốt trong điều kiện ánh sáng yếu.',
        pricePerDay: 400000,
        imageUrl: 'https://via.placeholder.com/300x200?text=Nikon+Z6+II',
        features: ['24.5MP', '4K Video', 'Dual Processors', 'Low Light'],
        isAvailable: true,
      ),
      CameraModel(
        id: '4',
        name: 'Canon EOS 5D Mark IV',
        brand: 'Canon',
        description:
            'Máy ảnh DSLR full-frame chuyên nghiệp với cảm biến 30.4MP, độ bền cao.',
        pricePerDay: 350000,
        imageUrl: 'https://via.placeholder.com/300x200?text=Canon+5D+Mark+IV',
        features: ['30.4MP', '7fps', '4K Video', 'Professional'],
        isAvailable: true,
      ),
      CameraModel(
        id: '5',
        name: 'Sony A7S III',
        brand: 'Sony',
        description:
            'Máy ảnh mirrorless chuyên quay video với cảm biến 12MP, quay 4K 120fps.',
        pricePerDay: 550000,
        imageUrl: 'https://via.placeholder.com/300x200?text=Sony+A7S+III',
        features: ['12MP', '4K 120fps', 'Low Light King', 'Video Focused'],
        isAvailable: false,
      ),
      CameraModel(
        id: '6',
        name: 'Fujifilm X-T5',
        brand: 'Fujifilm',
        description:
            'Máy ảnh mirrorless APS-C với cảm biến 40MP, màu sắc tuyệt đẹp, thiết kế retro.',
        pricePerDay: 380000,
        imageUrl: 'https://via.placeholder.com/300x200?text=Fujifilm+X-T5',
        features: ['40MP', 'Film Simulation', 'Retro Design', '6K Video'],
        isAvailable: true,
      ),
    ];
  }
}

