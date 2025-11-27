import 'camera_model.dart';
import 'accessory_model.dart';
import 'combo_model.dart';

enum ProductType { camera, accessory, combo }

class ProductItem {
  final ProductType type;
  final CameraModel? camera;
  final AccessoryModel? accessory;
  final ComboModel? combo;

  ProductItem.camera(this.camera)
      : type = ProductType.camera,
        accessory = null,
        combo = null;

  ProductItem.accessory(this.accessory)
      : type = ProductType.accessory,
        camera = null,
        combo = null;

  ProductItem.combo(this.combo)
      : type = ProductType.combo,
        camera = null,
        accessory = null;

  String get id {
    switch (type) {
      case ProductType.camera:
        return camera!.id;
      case ProductType.accessory:
        return accessory!.id;
      case ProductType.combo:
        return combo!.id;
    }
  }

  String get name {
    switch (type) {
      case ProductType.camera:
        return camera!.name;
      case ProductType.accessory:
        return accessory!.name;
      case ProductType.combo:
        return combo!.name;
    }
  }

  String get brand {
    switch (type) {
      case ProductType.camera:
        return camera!.brand;
      case ProductType.accessory:
        return accessory!.brand;
      case ProductType.combo:
        return combo!.brandLabel;
    }
  }

  String get imageUrl {
    switch (type) {
      case ProductType.camera:
        return camera!.imageUrl;
      case ProductType.accessory:
        return accessory!.imageUrl;
      case ProductType.combo:
        return combo!.imageUrl;
    }
  }

  double get pricePerDay {
    switch (type) {
      case ProductType.camera:
        return camera!.pricePerDay;
      case ProductType.accessory:
        return accessory!.pricePerDay;
      case ProductType.combo:
        return combo!.pricePerDay;
    }
  }

  String get branchName {
    switch (type) {
      case ProductType.camera:
        return camera!.branchName;
      case ProductType.accessory:
        return accessory!.branchName;
      case ProductType.combo:
        return combo!.branchDisplayName;
    }
  }

  bool get isAvailable {
    switch (type) {
      case ProductType.camera:
        return camera!.isAvailable;
      case ProductType.accessory:
        return accessory!.isAvailable;
      case ProductType.combo:
        return true;
    }
  }

  String get description {
    switch (type) {
      case ProductType.camera:
        return camera!.description;
      case ProductType.accessory:
        return accessory!.description;
      case ProductType.combo:
        return combo!.displayDescription;
    }
  }
}

