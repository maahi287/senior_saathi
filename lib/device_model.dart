import 'package:flutter/material.dart';

/// Model representing a recognized physical or virtual device.
class DeviceModel {
  final String id;
  final String deviceModel;
  final String manufacturer;
  final String brand;
  final String deviceType; // 'Phone', 'Tablet', 'Desktop', 'Web'
  final String osName;     // 'Android', 'iOS', 'Windows', 'Web', 'macOS', 'Linux'
  final String osVersion;  // e.g. '14 (API 34)', '17.4', '10.0.19045'
  final String hardware;   // Hardware / board info
  final bool isPhysicalDevice;
  final DateTime lastActive;
  final String elderCode;
  final String userName;
  final String userPhone;

  DeviceModel({
    required this.id,
    required this.deviceModel,
    required this.manufacturer,
    required this.brand,
    required this.deviceType,
    required this.osName,
    required this.osVersion,
    required this.hardware,
    required this.isPhysicalDevice,
    required this.lastActive,
    this.elderCode = '',
    this.userName = '',
    this.userPhone = '',
  });

  /// Friendly display name for the device (e.g. 'Samsung Galaxy S23' or 'Google Pixel 8')
  String get displayName {
    if (manufacturer.isNotEmpty &&
        !deviceModel.toLowerCase().contains(manufacturer.toLowerCase())) {
      return '$manufacturer $deviceModel'.trim();
    }
    return deviceModel.isNotEmpty ? deviceModel : 'Unknown Device';
  }

  /// Compact summary line (e.g. 'Samsung SM-G991B • Android 14')
  String get summary {
    return '$displayName • $osName $osVersion';
  }

  /// Appropriate icon based on device type and OS
  IconData get icon {
    switch (deviceType.toLowerCase()) {
      case 'phone':
        return osName.toLowerCase() == 'ios'
            ? Icons.phone_iphone_rounded
            : Icons.phone_android_rounded;
      case 'tablet':
        return Icons.tablet_mac_rounded;
      case 'desktop':
        return osName.toLowerCase() == 'windows'
            ? Icons.laptop_windows_rounded
            : Icons.laptop_mac_rounded;
      case 'web':
        return Icons.language_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  /// Convert to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceModel': deviceModel,
      'manufacturer': manufacturer,
      'brand': brand,
      'deviceType': deviceType,
      'osName': osName,
      'osVersion': osVersion,
      'hardware': hardware,
      'isPhysicalDevice': isPhysicalDevice ? 1 : 0,
      'lastActive': lastActive.toIso8601String(),
      'elderCode': elderCode,
      'userName': userName,
      'userPhone': userPhone,
    };
  }

  /// Create from SQLite Map
  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    return DeviceModel(
      id: map['id'] as String? ?? '',
      deviceModel: map['deviceModel'] as String? ?? 'Unknown Model',
      manufacturer: map['manufacturer'] as String? ?? 'Unknown Brand',
      brand: map['brand'] as String? ?? '',
      deviceType: map['deviceType'] as String? ?? 'Phone',
      osName: map['osName'] as String? ?? 'Unknown OS',
      osVersion: map['osVersion'] as String? ?? '',
      hardware: map['hardware'] as String? ?? '',
      isPhysicalDevice: (map['isPhysicalDevice'] as num? ?? 1) == 1,
      lastActive: map['lastActive'] != null
          ? DateTime.tryParse(map['lastActive'] as String) ?? DateTime.now()
          : DateTime.now(),
      elderCode: map['elderCode'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userPhone: map['userPhone'] as String? ?? '',
    );
  }

  /// Convert to JSON (for Firestore & SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceModel': deviceModel,
      'manufacturer': manufacturer,
      'brand': brand,
      'deviceType': deviceType,
      'osName': osName,
      'osVersion': osVersion,
      'hardware': hardware,
      'isPhysicalDevice': isPhysicalDevice,
      'lastActive': lastActive.toIso8601String(),
      'elderCode': elderCode,
      'userName': userName,
      'userPhone': userPhone,
    };
  }

  /// Create from JSON
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String? ?? '',
      deviceModel: json['deviceModel'] as String? ?? 'Unknown Model',
      manufacturer: json['manufacturer'] as String? ?? 'Unknown Brand',
      brand: json['brand'] as String? ?? '',
      deviceType: json['deviceType'] as String? ?? 'Phone',
      osName: json['osName'] as String? ?? 'Unknown OS',
      osVersion: json['osVersion'] as String? ?? '',
      hardware: json['hardware'] as String? ?? '',
      isPhysicalDevice: json['isPhysicalDevice'] as bool? ?? true,
      lastActive: json['lastActive'] != null
          ? DateTime.tryParse(json['lastActive'] as String) ?? DateTime.now()
          : DateTime.now(),
      elderCode: json['elderCode'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userPhone: json['userPhone'] as String? ?? '',
    );
  }

  DeviceModel copyWith({
    String? id,
    String? deviceModel,
    String? manufacturer,
    String? brand,
    String? deviceType,
    String? osName,
    String? osVersion,
    String? hardware,
    bool? isPhysicalDevice,
    DateTime? lastActive,
    String? elderCode,
    String? userName,
    String? userPhone,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      deviceModel: deviceModel ?? this.deviceModel,
      manufacturer: manufacturer ?? this.manufacturer,
      brand: brand ?? this.brand,
      deviceType: deviceType ?? this.deviceType,
      osName: osName ?? this.osName,
      osVersion: osVersion ?? this.osVersion,
      hardware: hardware ?? this.hardware,
      isPhysicalDevice: isPhysicalDevice ?? this.isPhysicalDevice,
      lastActive: lastActive ?? this.lastActive,
      elderCode: elderCode ?? this.elderCode,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
    );
  }
}
