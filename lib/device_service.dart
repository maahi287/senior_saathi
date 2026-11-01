import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_helper.dart';
import 'device_model.dart';

/// Service responsible for automatically recognizing, identifying,
/// caching, and syncing device hardware and model specifications.
class DeviceService {
  static final DeviceService instance = DeviceService._internal();
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  DeviceModel? _cachedCurrentDevice;

  static const String _prefDeviceId = 'senior_saathi_device_id';
  static const String _prefDeviceModel = 'senior_saathi_device_model';
  static const String _prefDeviceBrand = 'senior_saathi_device_brand';
  static const String _prefDeviceType = 'senior_saathi_device_type';
  static const String _prefDeviceOsVersion = 'senior_saathi_device_os_version';

  /// Returns the current cached device or fetches and recognizes it automatically.
  DeviceModel? get cachedCurrentDevice => _cachedCurrentDevice;

  /// Initializes the service and auto-recognizes the device on startup.
  Future<DeviceModel> init({
    String? userName,
    String? userPhone,
    String? elderCode,
  }) async {
    final device = await getDeviceInfo(
      userName: userName,
      userPhone: userPhone,
      elderCode: elderCode,
    );
    await autoRegisterDevice(device: device);
    return device;
  }

  /// Automatically inspects hardware and operating system to recognize device specs.
  Future<DeviceModel> getDeviceInfo({
    String? userName,
    String? userPhone,
    String? elderCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Persistent Device UUID
      String deviceId = prefs.getString(_prefDeviceId) ?? '';
      if (deviceId.isEmpty) {
        deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 9000))}';
        await prefs.setString(_prefDeviceId, deviceId);
      }

      String deviceModel = 'Unknown Model';
      String manufacturer = 'Unknown Manufacturer';
      String brand = '';
      String deviceType = 'Phone';
      String osName = 'Unknown OS';
      String osVersion = '';
      String hardware = '';
      bool isPhysicalDevice = true;

      if (kIsWeb) {
        final web = await _deviceInfoPlugin.webBrowserInfo;
        deviceModel = web.browserName.name.toUpperCase();
        manufacturer = web.vendor ?? 'Web Browser';
        brand = 'Web';
        deviceType = 'Web';
        osName = 'Web (${web.platform ?? 'Browser'})';
        osVersion = web.userAgent ?? 'Unknown Browser';
        hardware = 'Concurrency: ${web.hardwareConcurrency ?? 1}';
        isPhysicalDevice = true;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final android = await _deviceInfoPlugin.androidInfo;
            deviceModel = android.model;
            manufacturer = android.manufacturer;
            brand = android.brand;
            deviceType = _isAndroidTablet(android) ? 'Tablet' : 'Phone';
            osName = 'Android';
            osVersion = '${android.version.release} (SDK ${android.version.sdkInt})';
            hardware = android.hardware;
            isPhysicalDevice = android.isPhysicalDevice;
            if (android.id.isNotEmpty && deviceId.startsWith('dev_')) {
              deviceId = android.id;
              await prefs.setString(_prefDeviceId, deviceId);
            }
            break;

          case TargetPlatform.iOS:
            final ios = await _deviceInfoPlugin.iosInfo;
            deviceModel = ios.utsname.machine.isNotEmpty ? ios.utsname.machine : ios.model;
            manufacturer = 'Apple';
            brand = 'Apple';
            deviceType = ios.model.toLowerCase().contains('ipad') ? 'Tablet' : 'Phone';
            osName = ios.systemName;
            osVersion = ios.systemVersion;
            hardware = ios.utsname.machine;
            isPhysicalDevice = ios.isPhysicalDevice;
            if (ios.identifierForVendor != null && ios.identifierForVendor!.isNotEmpty) {
              deviceId = ios.identifierForVendor!;
              await prefs.setString(_prefDeviceId, deviceId);
            }
            break;

          case TargetPlatform.windows:
            final win = await _deviceInfoPlugin.windowsInfo;
            deviceModel = win.computerName;
            manufacturer = 'Microsoft / PC';
            brand = 'Windows';
            deviceType = 'Desktop';
            osName = 'Windows';
            osVersion = win.productName;
            hardware = '${win.numberOfCores} Cores, ${win.systemMemoryInMegabytes} MB RAM';
            isPhysicalDevice = true;
            if (win.deviceId.isNotEmpty) {
              deviceId = win.deviceId;
              await prefs.setString(_prefDeviceId, deviceId);
            }
            break;

          case TargetPlatform.macOS:
            final mac = await _deviceInfoPlugin.macOsInfo;
            deviceModel = mac.model;
            manufacturer = 'Apple';
            brand = 'Apple';
            deviceType = 'Desktop';
            osName = 'macOS';
            osVersion = mac.osRelease;
            hardware = mac.computerName;
            isPhysicalDevice = true;
            if (mac.systemGUID != null && mac.systemGUID!.isNotEmpty) {
              deviceId = mac.systemGUID!;
              await prefs.setString(_prefDeviceId, deviceId);
            }
            break;

          case TargetPlatform.linux:
            final linux = await _deviceInfoPlugin.linuxInfo;
            deviceModel = linux.name;
            manufacturer = 'Linux';
            brand = 'Linux';
            deviceType = 'Desktop';
            osName = 'Linux';
            osVersion = linux.versionId ?? linux.version ?? 'Linux OS';
            hardware = linux.id;
            isPhysicalDevice = true;
            if (linux.machineId != null && linux.machineId!.isNotEmpty) {
              deviceId = linux.machineId!;
              await prefs.setString(_prefDeviceId, deviceId);
            }
            break;

          default:
            deviceModel = 'Unknown Device';
            manufacturer = 'Unknown';
            brand = 'Unknown';
            deviceType = 'Other';
            osName = 'Other';
            osVersion = '';
            break;
        }
      }

      // Read fallback or provided user identity
      final effectiveName = userName ?? prefs.getString('senior_saathi_user_name') ?? 'Senior Saathi User';
      final effectivePhone = userPhone ?? prefs.getString('senior_saathi_user_phone') ?? '';
      final effectiveElderCode = elderCode ?? prefs.getString('device_elder_code') ?? '';

      final recognizedDevice = DeviceModel(
        id: deviceId,
        deviceModel: deviceModel,
        manufacturer: manufacturer,
        brand: brand,
        deviceType: deviceType,
        osName: osName,
        osVersion: osVersion,
        hardware: hardware,
        isPhysicalDevice: isPhysicalDevice,
        lastActive: DateTime.now(),
        elderCode: effectiveElderCode,
        userName: effectiveName,
        userPhone: effectivePhone,
      );

      _cachedCurrentDevice = recognizedDevice;

      // Cache locally
      await prefs.setString(_prefDeviceModel, deviceModel);
      await prefs.setString(_prefDeviceBrand, manufacturer);
      await prefs.setString(_prefDeviceType, deviceType);
      await prefs.setString(_prefDeviceOsVersion, osVersion);

      // Save to local SQLite database
      await DatabaseHelper.instance.insertRecognizedDevice(recognizedDevice.toMap());

      return recognizedDevice;
    } catch (e) {
      debugPrint('Error recognizing device: $e');

      // Return a safe fallback device model
      final fallback = DeviceModel(
        id: 'fallback_device_id',
        deviceModel: 'Smart Mobile Device',
        manufacturer: 'Android/iOS',
        brand: 'Generic',
        deviceType: 'Phone',
        osName: defaultTargetPlatform.name,
        osVersion: 'Standard',
        hardware: 'ARM',
        isPhysicalDevice: true,
        lastActive: DateTime.now(),
      );
      _cachedCurrentDevice = fallback;
      return fallback;
    }
  }

  /// Automatically registers/syncs the recognized device to Firestore
  /// so family members and users can identify all present and future devices automatically.
  Future<void> autoRegisterDevice({
    DeviceModel? device,
    String? userId,
    String? userName,
    String? userPhone,
    String? elderCode,
  }) async {
    try {
      final current = device ?? await getDeviceInfo(
        userName: userName,
        userPhone: userPhone,
        elderCode: elderCode,
      );

      final authUser = FirebaseAuth.instance.currentUser;
      final effectiveUid = userId ?? authUser?.uid;
      final prefs = await SharedPreferences.getInstance();

      final phone = userPhone ?? prefs.getString('senior_saathi_user_phone') ?? authUser?.phoneNumber ?? '';
      final name = userName ?? prefs.getString('senior_saathi_user_name') ?? 'Senior Saathi User';
      final code = elderCode ?? prefs.getString('device_elder_code') ?? '';

      // 1. Sync to Firestore collection 'users/{uid}/devices/{deviceId}'
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(effectiveUid)
            .collection('devices')
            .doc(current.id)
            .set({
          ...current.toJson(),
          'lastSeen': FieldValue.serverTimestamp(),
          'registeredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also update primary user document with current active device summary
        await FirebaseFirestore.instance.collection('users').doc(effectiveUid).set({
          'activeDeviceModel': current.deviceModel,
          'activeDeviceBrand': current.manufacturer,
          'activeDeviceType': current.deviceType,
          'activeDeviceId': current.id,
          'lastDeviceUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 2. Sync to Firestore collection 'family_tracking/{cleanIdentifier}'
      String cleanIdentifier = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanIdentifier.isEmpty && code.isNotEmpty) {
        cleanIdentifier = code;
      }
      if (cleanIdentifier.isEmpty && effectiveUid != null) {
        cleanIdentifier = effectiveUid;
      }

      if (cleanIdentifier.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('family_tracking')
            .doc(cleanIdentifier)
            .set({
          'deviceModel': current.deviceModel,
          'deviceBrand': current.manufacturer,
          'deviceType': current.deviceType,
          'deviceOs': current.osName,
          'deviceOsVersion': current.osVersion,
          'deviceId': current.id,
          'deviceName': current.displayName,
          'isPhysicalDevice': current.isPhysicalDevice,
          'elderCode': code,
          'name': name,
          'phone': phone,
          'deviceLastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also log device in subcollection 'family_tracking/{cleanIdentifier}/devices/{deviceId}'
        await FirebaseFirestore.instance
            .collection('family_tracking')
            .doc(cleanIdentifier)
            .collection('devices')
            .doc(current.id)
            .set({
          ...current.toJson(),
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Device auto-registration skipped or offline: $e');
    }
  }

  /// Retrieves list of all recognized devices (from SQLite & Firestore).
  Future<List<DeviceModel>> getRecognizedDevices({String? targetElderCode}) async {
    final List<DeviceModel> devices = [];
    final Map<String, DeviceModel> byId = {};

    // 1. Fetch from local SQLite
    try {
      final rows = await DatabaseHelper.instance.getRecognizedDevices();
      for (final row in rows) {
        final d = DeviceModel.fromMap(row);
        byId[d.id] = d;
      }
    } catch (e) {
      debugPrint('SQLite device fetch error: $e');
    }

    // 2. Always ensure current recognized device is included
    final current = await getDeviceInfo();
    byId[current.id] = current;

    // 3. Try to fetch cloud registered devices if available
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .collection('devices')
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final d = DeviceModel.fromJson(data);
          byId[d.id] = d;
        }
      }

      // If tracking family elder, also query their registered devices
      if (targetElderCode != null && targetElderCode.trim().isNotEmpty) {
        final clean = targetElderCode.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
        final snap = await FirebaseFirestore.instance
            .collection('family_tracking')
            .doc(clean)
            .collection('devices')
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final d = DeviceModel.fromJson(data);
          byId[d.id] = d;
        }
      }
    } catch (e) {
      debugPrint('Firestore devices fetch error: $e');
    }

    devices.addAll(byId.values);
    devices.sort((a, b) => b.lastActive.compareTo(a.lastActive));
    return devices;
  }

  /// Remove a recognized device
  Future<void> removeDevice(String deviceId) async {
    try {
      await DatabaseHelper.instance.deleteRecognizedDevice(deviceId);
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .collection('devices')
            .doc(deviceId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error removing device: $e');
    }
  }

  bool _isAndroidTablet(AndroidDeviceInfo info) {
    final systemFeatures = info.systemFeatures;
    if (systemFeatures.contains('android.hardware.type.television') ||
        systemFeatures.contains('android.software.leanback')) {
      return false;
    }
    // Simple heuristic: tablets often don't have telephony
    if (!systemFeatures.contains('android.hardware.telephony')) {
      return true;
    }
    return false;
  }
}
