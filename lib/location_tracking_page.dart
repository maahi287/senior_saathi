import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'voice_assistant_widget.dart';
import 'device_service.dart';
import 'device_model.dart';
import 'device_page.dart';
import 'main.dart';

class LocationTrackingPage extends StatefulWidget {
  final String selectedLanguage;

  const LocationTrackingPage({
    super.key,
    this.selectedLanguage = 'English',
  });

  @override
  State<LocationTrackingPage> createState() => _LocationTrackingPageState();
}

class _LocationTrackingPageState extends State<LocationTrackingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();

  // User State
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isTracking = false;
  String? _errorMessage;

  // Stream & Timer
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _durationTimer;
  int _trackingSeconds = 0;

  // Movement Trail (Breadcrumb)
  final List<LatLng> _trailPoints = [];
  double _totalDistanceMeters = 0.0;
  bool _followUser = true;

  // Profile & Preferences
  String _userName = 'Senior Saathi User';
  String _userPhone = '';
  String _elderCode = '';
  List<Map<String, String>> _emergencyContacts = [];
  DeviceModel? _currentDevice;

  // Family Tracking
  final TextEditingController _familyCodeController = TextEditingController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _familyStreamSub;
  LatLng? _familyPosition;
  Map<String, dynamic>? _familyData;
  bool _isFamilyLoading = false;
  String? _familyError;
  List<String> _savedFamilyCodes = [];

  // Default fallback center: New Delhi, India
  static const LatLng _defaultCenter = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadUserData();
    _getMyLocation(initial: true);
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _durationTimer?.cancel();
    _familyStreamSub?.cancel();
    _tabController.dispose();
    _familyCodeController.dispose();
    super.dispose();
  }

  // =====================================================
  // TRANSLATIONS HELPER
  // =====================================================
  String _t({
    required String english,
    required String hindi,
    String? marathi,
    String? gujarati,
    String? telugu,
    String? tamil,
    String? bengali,
    String? kannada,
    String? malayalam,
    String? punjabi,
  }) {
    return appText(
      english: english,
      hindi: hindi,
      marathi: marathi ?? hindi,
      gujarati: gujarati ?? hindi,
      telugu: telugu ?? english,
      tamil: tamil ?? english,
      bengali: bengali ?? hindi,
      kannada: kannada ?? english,
      malayalam: malayalam ?? english,
      punjabi: punjabi ?? hindi,
      selectedLanguage: widget.selectedLanguage,
    );
  }

  // =====================================================
  // INITIALIZATION & USER DATA
  // =====================================================
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('senior_saathi_user_name');
      final savedPhone = prefs.getString('senior_saathi_user_phone');
      final savedContacts = prefs.getStringList('emergency_contacts');
      final savedFamily = prefs.getStringList('saved_family_codes');

      final authUser = FirebaseAuth.instance.currentUser;

      String phone = savedPhone ?? authUser?.phoneNumber ?? '';
      String name = savedName ?? authUser?.displayName ?? 'Senior Saathi User';

      // Clean phone number to get 6-10 digit elder code
      String code = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (code.length > 6) {
        code = code.substring(code.length - 6);
      }
      if (code.isEmpty) {
        code = (prefs.getString('device_elder_code') ??
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString());
        await prefs.setString('device_elder_code', code);
      }

      List<Map<String, String>> contacts = [];
      if (savedContacts != null) {
        contacts = savedContacts.map((c) {
          final parts = c.split('|');
          return {
            'name': parts.isNotEmpty ? parts[0] : '',
            'phone': parts.length > 1 ? parts[1] : '',
          };
        }).toList();
      }

      // Auto-identify device hardware & specs
      final dev = await DeviceService.instance.getDeviceInfo(
        userName: name,
        userPhone: phone,
        elderCode: code,
      );
      await DeviceService.instance.autoRegisterDevice(device: dev);

      if (mounted) {
        setState(() {
          _userName = name.isNotEmpty ? name : 'Senior Saathi User';
          _userPhone = phone;
          _elderCode = code;
          _emergencyContacts = contacts;
          _savedFamilyCodes = savedFamily ?? [];
          _currentDevice = dev;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  String _getIdentifier() {
    if (_userPhone.isNotEmpty) {
      return _userPhone.replaceAll(RegExp(r'[^0-9]'), '');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
    return _elderCode.isNotEmpty ? _elderCode : 'guest_elder';
  }

  // =====================================================
  // LOCATION PERMISSIONS & ACQUISITION
  // =====================================================
  Future<bool> _handleLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showDialog(
          title: _t(
            english: 'Location Service Disabled',
            hindi: 'लोकेशन सेवा बंद है',
          ),
          message: _t(
            english: 'Please enable Location (GPS) in your phone settings to view and track your location.',
            hindi: 'कृपया अपना स्थान देखने और ट्रैक करने के लिए अपने फोन सेटिंग्स में लोकेशन (GPS) चालू करें।',
          ),
          actionLabel: _t(english: 'Open Settings', hindi: 'सेटिंग्स खोलें'),
          onAction: () => Geolocator.openLocationSettings(),
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showDialog(
          title: _t(
            english: 'Location Permission Needed',
            hindi: 'लोकेशन अनुमति आवश्यक है',
          ),
          message: _t(
            english: 'Senior Saathi needs location access to track and display your real-time position on the map.',
            hindi: 'सीनियर साथी को मैप पर आपकी लाइव लोकेशन दिखाने के लिए अनुमति की आवश्यकता है।',
          ),
          actionLabel: _t(english: 'Grant in Settings', hindi: 'सेटिंग्स में अनुमति दें'),
          onAction: () => Geolocator.openAppSettings(),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _getMyLocation({bool initial = false}) async {
    final hasPerm = await _handleLocationPermission();
    if (!hasPerm) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = pos;
        _isLoading = false;
      });

      final target = LatLng(pos.latitude, pos.longitude);
      _mapController.move(target, 16.0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!initial) {
          _errorMessage = _t(
            english: 'Could not fetch current location. Please ensure GPS is active.',
            hindi: 'स्थान प्राप्त नहीं हो सका। कृपया सुनिश्चित करें कि GPS चालू है।',
          );
        }
      });
    }
  }

  // =====================================================
  // REAL-TIME LIVE TRACKING
  // =====================================================
  Future<void> _startTracking() async {
    if (_isTracking) return;

    final hasPerm = await _handleLocationPermission();
    if (!hasPerm) return;

    setState(() {
      _isTracking = true;
      _errorMessage = null;
      _trackingSeconds = 0;
      _totalDistanceMeters = 0.0;
      _trailPoints.clear();
    });

    // Start Timer
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _trackingSeconds++;
        });
      }
    });

    // Start GPS Stream
    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 4, // triggers every 4 meters
      ),
    ).listen(
      (Position pos) {
        if (!mounted) return;

        final newPoint = LatLng(pos.latitude, pos.longitude);

        setState(() {
          if (_trailPoints.isNotEmpty) {
            final last = _trailPoints.last;
            final dist = Geolocator.distanceBetween(
              last.latitude,
              last.longitude,
              pos.latitude,
              pos.longitude,
            );
            if (dist > 1.5) {
              _totalDistanceMeters += dist;
              _trailPoints.add(newPoint);
            }
          } else {
            _trailPoints.add(newPoint);
          }
          _currentPosition = pos;
        });

        if (_followUser && _tabController.index == 0) {
          try {
            _mapController.move(newPoint, _mapController.camera.zoom);
          } catch (_) {}
        }

        // Sync with Cloud for family visibility
        _syncLocationToCloud(pos, isSharing: true);
      },
      onError: (err) {
        if (!mounted) return;
        _showSnack(
          _t(
            english: 'GPS stream interrupted. Retrying...',
            hindi: 'GPS सिग्नल में रुकावट आई। पुनः प्रयास कर रहे हैं...',
          ),
        );
      },
    );

    _showSnack(
      _t(
        english: 'Live OpenStreetMap tracking started!',
        hindi: 'लाइव ट्रैकिंग शुरू हो गई है!',
      ),
      isSuccess: true,
    );
  }

  Future<void> _stopTracking() async {
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    if (_currentPosition != null) {
      _syncLocationToCloud(_currentPosition!, isSharing: false);
    }

    if (mounted) {
      setState(() {
        _isTracking = false;
      });
      _showSnack(
        _t(
          english: 'Live tracking stopped.',
          hindi: 'लाइव ट्रैकिंग बंद कर दी गई है।',
        ),
      );
    }
  }

  Future<void> _syncLocationToCloud(Position pos, {required bool isSharing}) async {
    try {
      final id = _getIdentifier();
      if (id.isEmpty) return;

      await FirebaseFirestore.instance.collection('family_tracking').doc(id).set({
        'userId': id,
        'elderCode': _elderCode,
        'name': _userName,
        'phone': _userPhone,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'speed': pos.speed >= 0 ? pos.speed : 0.0,
        'heading': pos.heading,
        'altitude': pos.altitude,
        'isSharing': isSharing,
        'deviceModel': _currentDevice?.deviceModel ?? 'Smart Phone',
        'deviceBrand': _currentDevice?.manufacturer ?? '',
        'deviceType': _currentDevice?.deviceType ?? 'Phone',
        'deviceOs': _currentDevice?.osName ?? '',
        'deviceOsVersion': _currentDevice?.osVersion ?? '',
        'deviceId': _currentDevice?.id ?? '',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Graceful offline fallback - map tracking still functions locally
      debugPrint('Cloud sync skipped or offline: $e');
    }
  }

  // =====================================================
  // FAMILY TRACKING SYSTEM
  // =====================================================
  void _trackFamilyMember(String targetCode) {
    final cleanCode = targetCode.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    if (cleanCode.isEmpty) {
      _showSnack(
        _t(
          english: 'Please enter a valid Phone Number or Elder Code.',
          hindi: 'कृपया एक मान्य फ़ोन नंबर या कोड दर्ज करें।',
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    _familyStreamSub?.cancel();

    setState(() {
      _isFamilyLoading = true;
      _familyError = null;
    });

    // Save to quick-access family list
    if (!_savedFamilyCodes.contains(cleanCode)) {
      _savedFamilyCodes.add(cleanCode);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList('saved_family_codes', _savedFamilyCodes);
      });
    }

    _familyStreamSub = FirebaseFirestore.instance
        .collection('family_tracking')
        .doc(cleanCode)
        .snapshots()
        .listen(
      (doc) {
        if (!mounted) return;
        if (!doc.exists || doc.data() == null) {
          setState(() {
            _isFamilyLoading = false;
            _familyPosition = null;
            _familyData = null;
            _familyError = _t(
              english: 'No live tracking signal found for this code yet. Ask your loved one to tap "Start Sharing".',
              hindi: 'इस कोड के लिए कोई लाइव सिग्नल नहीं मिला। अपने परिजन से "Start Sharing" दबाने को कहें।',
            );
          });
          return;
        }

        final data = doc.data()!;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          final famPoint = LatLng(lat, lng);
          setState(() {
            _isFamilyLoading = false;
            _familyPosition = famPoint;
            _familyData = data;
            _familyError = null;
          });

          // Focus on family member
          _mapController.move(famPoint, 16.0);
        } else {
          setState(() {
            _isFamilyLoading = false;
            _familyError = _t(
              english: 'Coordinates not available for this family member.',
              hindi: 'इस परिजन के निर्देशांक उपलब्ध नहीं हैं।',
            );
          });
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isFamilyLoading = false;
          _familyError = _t(
            english: 'Unable to connect to family member stream.',
            hindi: 'परिजन के लाइव ट्रैकिंग से जुड़ने में असमर्थ।',
          );
        });
      },
    );
  }

  // =====================================================
  // SHARING & SOS BROADCAST
  // =====================================================
  String _generateShareText(Position pos) {
    final osmLink =
        'https://www.openstreetmap.org/?mlat=${pos.latitude}&mlon=${pos.longitude}#map=17/${pos.latitude.toStringAsFixed(5)}/${pos.longitude.toStringAsFixed(5)}';
    final gmapsLink =
        'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    final speed = (pos.speed >= 0 ? pos.speed * 3.6 : 0).toStringAsFixed(1);
    final devName = _currentDevice?.displayName ?? 'Smart Phone';

    return '🚨 *Senior Saathi Location Alert*\n'
        'Sender: $_userName\n'
        '📱 Device: $devName\n'
        '📍 Live Map (OpenStreetMap): $osmLink\n'
        '🌐 Google Maps: $gmapsLink\n'
        'Speed: $speed km/h | Accuracy: ±${pos.accuracy.toStringAsFixed(0)}m\n'
        'Elder ID: ${_elderCode.isNotEmpty ? _elderCode : _userPhone}';
  }

  Future<void> _shareViaWhatsApp() async {
    if (_currentPosition == null) {
      await _getMyLocation();
      if (_currentPosition == null) return;
    }
    final text = _generateShareText(_currentPosition!);
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('WhatsApp is not installed on this device.');
    }
  }

  Future<void> _shareViaSMS([String? targetPhone]) async {
    if (_currentPosition == null) {
      await _getMyLocation();
      if (_currentPosition == null) return;
    }
    final text = _generateShareText(_currentPosition!);
    final phone = targetPhone ?? '';
    final url = Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnack('Unable to open SMS app.');
    }
  }

  void _copyLocationLink() {
    if (_currentPosition == null) return;
    final osmLink =
        'https://www.openstreetmap.org/?mlat=${_currentPosition!.latitude}&mlon=${_currentPosition!.longitude}#map=17/${_currentPosition!.latitude}/${_currentPosition!.longitude}';
    Clipboard.setData(ClipboardData(text: osmLink));
    _showSnack(
      _t(
        english: 'OpenStreetMap link copied to clipboard!',
        hindi: 'OpenStreetMap लिंक कॉपी हो गया!',
      ),
      isSuccess: true,
    );
  }

  void _showEmergencySOSSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emergency_rounded,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(
                              english: 'Emergency Location SOS',
                              hindi: 'आपातकालीन स्थान SOS',
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            _t(
                              english: 'Instant alert to family & emergency services',
                              hindi: 'परिवार और आपातकालीन सेवाओं को तुरंत सूचित करें',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF25D366),
                    child: Icon(Icons.chat_rounded, color: Colors.white),
                  ),
                  title: Text(
                    _t(
                      english: 'Send SOS on WhatsApp',
                      hindi: 'WhatsApp पर SOS भेजें',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _t(
                      english: 'Share live OpenStreetMap link with contacts',
                      hindi: 'संपर्कों के साथ लाइव मैप लिंक साझा करें',
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareViaWhatsApp();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF5B7C99),
                    child: Icon(Icons.sms_rounded, color: Colors.white),
                  ),
                  title: Text(
                    _t(
                      english: 'Send SOS via SMS',
                      hindi: 'SMS द्वारा SOS भेजें',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _emergencyContacts.isNotEmpty
                        ? '${_emergencyContacts.length} ${_t(english: 'emergency contacts saved', hindi: 'आपातकालीन संपर्क सुरक्षित')}'
                        : _t(
                            english: 'Send to any contact',
                            hindi: 'किसी भी संपर्क को भेजें',
                          ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_emergencyContacts.isNotEmpty) {
                      _shareViaSMS(_emergencyContacts.first['phone']);
                    } else {
                      _shareViaSMS();
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                  ),
                  title: Text(
                    _t(
                      english: 'Call National Emergency (112)',
                      hindi: 'राष्ट्रीय आपातकालीन नंबर (112) डायल करें',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = Uri.parse('tel:112');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLinkFamilyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.family_restroom, color: Color(0xFF5B7C99)),
              const SizedBox(width: 10),
              Text(
                _t(
                  english: 'My Sharing Code',
                  hindi: 'मेरा शेयरिंग कोड',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _t(
                  english: 'Share this code or your phone number with your family member so they can track your live location:',
                  hindi: 'अपने परिजन के साथ यह कोड या फोन नंबर शेयर करें ताकि वे आपकी लाइव लोकेशन देख सकें:',
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B7C99).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF5B7C99), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getIdentifier(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Color(0xFF5B7C99),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFF5B7C99)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _getIdentifier()));
                        Navigator.pop(ctx);
                        _showSnack(
                          _t(
                            english: 'Sharing code copied!',
                            hindi: 'शेयरिंग कोड कॉपी हुआ!',
                          ),
                          isSuccess: true,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  english: 'Your name: $_userName',
                  hindi: 'आपका नाम: $_userName',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t(english: 'Close', hindi: 'बंद करें')),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // MAP CONTROLS & HELPERS
  // =====================================================
  void _zoomIn() {
    try {
      final z = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (z + 1).clamp(3.0, 18.0));
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final z = _mapController.camera.zoom;
      _mapController.move(_mapController.camera.center, (z - 1).clamp(3.0, 18.0));
    } catch (_) {}
  }

  void _recenterOnUser() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
    } else {
      _getMyLocation();
    }
  }

  void _recenterOnFamily() {
    if (_familyPosition != null) {
      _mapController.move(_familyPosition!, 16.0);
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _buildVoiceStatus() {
    if (_isTracking) {
      final speed = _currentPosition != null && _currentPosition!.speed >= 0
          ? (_currentPosition!.speed * 3.6).toStringAsFixed(1)
          : '0';
      final distance = _totalDistanceMeters >= 1000
          ? '${(_totalDistanceMeters / 1000).toStringAsFixed(1)} km'
          : '${_totalDistanceMeters.toStringAsFixed(0)} meters';
      return _t(
        english:
            'Live GPS Tracking is active. Current speed is $speed kilometers per hour, distance covered is $distance.',
        hindi:
            'लाइव जीपीएस ट्रैकिंग सक्रिय है। आपकी वर्तमान गति $speed किलोमीटर प्रति घंटा है और तय की गई दूरी $distance है।',
      );
    } else {
      return _t(
        english:
            'Location Tracking. Tap Start Tracking to trace your route on OpenStreetMap, or tap Track Family to see loved ones.',
        hindi:
            'लोकेशन ट्रैकिंग। अपना रास्ता ओपन-स्ट्रीट-मैप पर देखने के लिए ट्रैकिंग शुरू करें दबाएं।',
      );
    }
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF6C9A7A) : Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDialog({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t(english: 'Cancel', hindi: 'रद्द करें')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B7C99),
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD METHOD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final LatLng initialMapCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_familyPosition ?? _defaultCenter);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: Text(
          _t(
            english: 'GPS Live Tracking',
            hindi: 'GPS लाइव ट्रैकिंग',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8F5F0),
        foregroundColor: const Color(0xFF5B7C99),
        elevation: 0,
        actions: [
          SpeakerIconButton(
            textToRead: _buildVoiceStatus(),
            selectedLanguage: widget.selectedLanguage,
            size: 26,
          ),
          IconButton(
            tooltip: _t(english: 'Device Info', hindi: 'डिवाइस पहचान'),
            icon: const Icon(Icons.devices_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DevicePage(selectedLanguage: widget.selectedLanguage),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _t(english: 'My Sharing Code', hindi: 'मेरा शेयरिंग कोड'),
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: _showLinkFamilyDialog,
          ),
          IconButton(
            tooltip: _t(english: 'Emergency SOS', hindi: 'आपातकालीन SOS'),
            icon: const Icon(Icons.emergency_rounded, color: Colors.red),
            onPressed: _showEmergencySOSSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5B7C99),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF5B7C99),
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.my_location_rounded),
              text: _t(english: 'My Live Map', hindi: 'मेरा लाइव मैप'),
            ),
            Tab(
              icon: const Icon(Icons.family_restroom_rounded),
              text: _t(english: 'Track Family', hindi: 'परिजन ट्रैकिंग'),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // =====================================================
          // 1. OPENSTREETMAP LEAFLET CANVAS
          // =====================================================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialMapCenter,
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              // OpenStreetMap Tile Layer (Leaflet standard)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.senior_saathi',
                maxZoom: 19,
              ),

              // Breadcrumb Trail (Movement Path)
              if (_trailPoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trailPoints,
                      strokeWidth: 5.0,
                      color: const Color(0xFF5B7C99),
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),

              // GPS Accuracy Circle
              if (_currentPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      radius: _currentPosition!.accuracy.clamp(10.0, 150.0),
                      useRadiusInMeter: true,
                      color: const Color(0xFF5B7C99).withValues(alpha: 0.18),
                      borderColor: const Color(0xFF5B7C99).withValues(alpha: 0.6),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // Starting Point of Tracking
                  if (_trailPoints.isNotEmpty)
                    Marker(
                      point: _trailPoints.first,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C9A7A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                  // Current User Marker
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 54,
                      height: 54,
                      child: _buildUserPinMarker(),
                    ),

                  // Family Member Marker
                  if (_familyPosition != null)
                    Marker(
                      point: _familyPosition!,
                      width: 60,
                      height: 60,
                      child: _buildFamilyPinMarker(),
                    ),
                ],
              ),
            ],
          ),

          // =====================================================
          // 2. FLOATING MAP CONTROLS (Recenter, Zoom, Follow)
          // =====================================================
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _floatingMapButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _floatingMapButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 12),
                _floatingMapButton(
                  icon: _followUser
                      ? Icons.navigation_rounded
                      : Icons.navigation_outlined,
                  color: _followUser ? const Color(0xFF5B7C99) : Colors.white,
                  iconColor: _followUser ? Colors.white : const Color(0xFF5B7C99),
                  tooltip: 'Auto-follow Me',
                  onTap: () {
                    setState(() => _followUser = !_followUser);
                    if (_followUser) _recenterOnUser();
                  },
                ),
                const SizedBox(height: 8),
                _floatingMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recenter on Me',
                  onTap: _recenterOnUser,
                ),
                if (_familyPosition != null) ...[
                  const SizedBox(height: 8),
                  _floatingMapButton(
                    icon: Icons.family_restroom_rounded,
                    color: Colors.orange.shade700,
                    iconColor: Colors.white,
                    tooltip: 'Recenter on Family Member',
                    onTap: _recenterOnFamily,
                  ),
                ],
              ],
            ),
          ),

          // =====================================================
          // 3. OSM ATTRIBUTION BADGE
          // =====================================================
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 14, color: Colors.black54),
                  SizedBox(width: 4),
                  Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =====================================================
          // 4. BOTTOM ACTION & STATS PANEL
          // =====================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
      bottomNavigationBar: VoiceAssistantSpeakingBanner(
        selectedLanguage: widget.selectedLanguage,
      ),
    );
  }

  // =====================================================
  // MARKER WIDGETS
  // =====================================================
  Widget _buildUserPinMarker() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF5B7C99),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.person_pin_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyPinMarker() {
    final name = _familyData?['name'] ?? 'Family Member';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(
          Icons.location_on,
          color: Colors.orange,
          size: 34,
        ),
      ],
    );
  }

  Widget _floatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = const Color(0xFF5B7C99),
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // BOTTOM PANEL (TABS VIEW)
  // =====================================================
  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F5F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.42,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _tabController.index == 0
                ? _buildMyTrackerTab()
                : _buildFamilyTrackerTab(),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // TAB 1: MY TRACKER VIEW
  // =====================================================
  Widget _buildMyTrackerTab() {
    final speed = _currentPosition != null && _currentPosition!.speed >= 0
        ? (_currentPosition!.speed * 3.6).toStringAsFixed(1)
        : '0.0';

    final distance = _totalDistanceMeters >= 1000
        ? '${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km'
        : '${_totalDistanceMeters.toStringAsFixed(0)} m';

    final accuracy = _currentPosition != null
        ? '±${_currentPosition!.accuracy.toStringAsFixed(0)} m'
        : '--';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Status Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isTracking
                        ? const Color(0xFF6C9A7A)
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isTracking
                      ? _t(
                          english: 'Live Tracking Active',
                          hindi: 'लाइव ट्रैकिंग सक्रिय',
                        )
                      : _t(
                          english: 'Tracking Inactive',
                          hindi: 'ट्रैकिंग बंद है',
                        ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isTracking
                        ? const Color(0xFF6C9A7A)
                        : Colors.black54,
                  ),
                ),
              ],
            ),
            if (_isTracking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C9A7A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⏱️ ${_formatDuration(_trackingSeconds)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C9A7A),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Auto-Recognized Device Chip
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DevicePage(selectedLanguage: widget.selectedLanguage),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  _currentDevice?.icon ?? Icons.phone_android_rounded,
                  size: 16,
                  color: const Color(0xFF5B7C99),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_t(english: 'This Device', hindi: 'यह डिवाइस')}: ${_currentDevice?.displayName ?? 'Auto-Recognizing...'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF30485C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C9A7A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _t(english: 'Auto-Recognized', hindi: 'पहचाना गया'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C9A7A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Metrics Row
        Row(
          children: [
            _metricCard(
              title: _t(english: 'Speed', hindi: 'गति'),
              value: '$speed km/h',
              icon: Icons.speed_rounded,
            ),
            const SizedBox(width: 8),
            _metricCard(
              title: _t(english: 'Distance', hindi: 'दूरी'),
              value: distance,
              icon: Icons.route_rounded,
            ),
            const SizedBox(width: 8),
            _metricCard(
              title: _t(english: 'Accuracy', hindi: 'सटीकता'),
              value: accuracy,
              icon: Icons.gps_fixed_rounded,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Action Buttons Row
        Row(
          children: [
            // Start / Stop Tracking Button
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : (_isTracking ? _stopTracking : _startTracking),
                icon: Icon(
                  _isTracking
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 22,
                ),
                label: Text(
                  _isTracking
                      ? _t(english: 'Stop Tracking', hindi: 'ट्रैकिंग रोकें')
                      : _t(english: 'Start Tracking', hindi: 'ट्रैकिंग शुरू करें'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking
                      ? Colors.red.shade700
                      : const Color(0xFF6C9A7A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Get Current Location Button
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _getMyLocation(),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 20),
                label: Text(
                  _t(english: 'Fix GPS', hindi: 'स्थान लें'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5B7C99),
                  side: const BorderSide(color: Color(0xFF5B7C99), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Quick Share Row (WhatsApp, SMS, Copy Link)
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _shareViaWhatsApp,
                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                label: const Text(
                  'WhatsApp',
                  style: TextStyle(
                    color: Color(0xFF25D366),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _shareViaSMS(),
                icon: const Icon(Icons.sms_rounded, color: Color(0xFF5B7C99), size: 18),
                label: Text(
                  _t(english: 'SMS Alert', hindi: 'SMS अलर्ट'),
                  style: const TextStyle(
                    color: Color(0xFF5B7C99),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF5B7C99).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _t(english: 'Copy Link', hindi: 'लिंक कॉपी करें'),
              icon: const Icon(Icons.copy_rounded, color: Colors.black54),
              onPressed: _copyLocationLink,
            ),
          ],
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
      ],
    );
  }

  // =====================================================
  // TAB 2: FAMILY TRACKER VIEW
  // =====================================================
  Widget _buildFamilyTrackerTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _familyCodeController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: _t(
                    english: 'Enter Elder Code or Phone',
                    hindi: 'परिजन का कोड या फ़ोन दर्ज करें',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5B7C99)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isFamilyLoading
                  ? null
                  : () => _trackFamilyMember(_familyCodeController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B7C99),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isFamilyLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _t(english: 'Track', hindi: 'देखें'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),

        // Quick Pick Saved Family Codes
        if (_savedFamilyCodes.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _savedFamilyCodes.map((code) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text(code),
                    onPressed: () {
                      _familyCodeController.text = code;
                      _trackFamilyMember(code);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Family Member Status Card
        if (_familyPosition != null && _familyData != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade300),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          radius: 18,
                          child: const Icon(
                            Icons.person,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _familyData!['name'] ?? 'Family Member',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              _familyData!['phone'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            if (_familyData!['deviceModel'] != null) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    _familyData!['deviceType'] == 'Desktop'
                                        ? Icons.laptop_rounded
                                        : Icons.phone_android_rounded,
                                    size: 13,
                                    color: const Color(0xFF6C9A7A),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_familyData!['deviceModel']}${_familyData!['deviceOs'] != null ? ' (${_familyData!['deviceOs']})' : ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6C9A7A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.directions_rounded, color: Color(0xFF5B7C99)),
                      tooltip: _t(english: 'Directions', hindi: 'रास्ता देखें'),
                      onPressed: () async {
                        final lat = _familyPosition!.latitude;
                        final lng = _familyPosition!.longitude;
                        final url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ),
                if (_currentPosition != null) ...[
                  const Divider(height: 16),
                  Text(
                    '📍 ${_t(english: 'Distance away', hindi: 'आपसे दूरी')}: '
                    '${(Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, _familyPosition!.latitude, _familyPosition!.longitude) / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF5B7C99),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if (_familyError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _familyError!,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            _t(
              english: 'Enter the loved one’s 6-digit Elder Code or Phone Number to view their real-time location on OpenStreetMap.',
              hindi: 'अपने परिजन का 6 अंकों का कोड या फ़ोन नंबर दर्ज करके OpenStreetMap पर उनका लाइव स्थान देखें।',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5B7C99)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
