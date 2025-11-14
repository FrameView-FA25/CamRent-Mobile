import 'camera_model.dart';
import 'accessory_model.dart';

enum ProductType { camera, accessory }

class ProductItem {
  final ProductType type;
  final CameraModel? camera;
  final AccessoryModel? accessory;

  ProductItem.camera(this.camera) : type = ProductType.camera, accessory = null;
  ProductItem.accessory(this.accessory) : type = ProductType.accessory, camera = null;

  String get id => type == ProductType.camera ? camera!.id : accessory!.id;
  String get name => type == ProductType.camera ? camera!.name : accessory!.name;
  String get brand => type == ProductType.camera ? camera!.brand : accessory!.brand;
  String get imageUrl => type == ProductType.camera ? camera!.imageUrl : accessory!.imageUrl;
  double get pricePerDay => type == ProductType.camera ? camera!.pricePerDay : accessory!.pricePerDay;
  String get branchName => type == ProductType.camera ? camera!.branchName : accessory!.branchName;
  bool get isAvailable => type == ProductType.camera ? camera!.isAvailable : accessory!.isAvailable;
  String get description => type == ProductType.camera ? camera!.description : accessory!.description;
}

