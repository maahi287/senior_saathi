import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'device_model.dart';
import 'device_service.dart';
import 'main.dart';
import 'voice_assistant_widget.dart';

class DevicePage extends StatefulWidget {
  final String selectedLanguage;

  const DevicePage({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  DeviceModel? _currentDevice;
  List<DeviceModel> _recognizedDevices = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices({bool showRefreshSpinner = false}) async {
    if (showRefreshSpinner) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final current = await DeviceService.instance.getDeviceInfo();
      final all = await DeviceService.instance.getRecognizedDevices();

      if (mounted) {
        setState(() {
          _currentDevice = current;
          _recognizedDevices = all;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

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

  String _buildVoiceDescription() {
    if (_currentDevice == null) {
      return _t(
        english: 'Device Recognition page. Identifying your device model and hardware.',
        hindi: 'डिवाइस पहचान पेज। आपके फ़ोन मॉडल और हार्डवेयर की पहचान की जा रही है।',
      );
    }
    return _t(
      english:
          'Your current device is automatically recognized as ${_currentDevice!.displayName}, running ${_currentDevice!.osName} ${_currentDevice!.osVersion}. All present and future devices are recognized automatically without manual entry.',
      hindi:
          'आपका वर्तमान डिवाइस स्वचालित रूप से ${_currentDevice!.displayName} के रूप में पहचाना गया है, जिसमें ${_currentDevice!.osName} ${_currentDevice!.osVersion} चल रहा है। भविष्य के सभी डिवाइस बिना किसी मैन्युअल प्रविष्टि के अपने आप पहचाने जाते हैं।',
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5B7C99),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: Text(
          _t(
            english: 'Device Recognition',
            hindi: 'डिवाइस पहचान',
            marathi: 'डिव्हाइस ओळख',
            gujarati: 'ડિવાઇસ ઓળખ',
            telugu: 'పరికర గుర్తింపు',
            tamil: 'சாதன அடையாளம்',
            bengali: 'ডিভাইস সনাক্তকরণ',
            kannada: 'ಸಾಧನ ಗುರುತಿಸುವಿಕೆ',
            malayalam: 'ഉപകരണ തിരിച്ചറിയൽ',
            punjabi: 'ਡਿਵਾਈਸ ਪਛਾਣ',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8F5F0),
        foregroundColor: const Color(0xFF5B7C99),
        elevation: 0,
        actions: [
          SpeakerIconButton(
            textToRead: _buildVoiceDescription(),
            selectedLanguage: widget.selectedLanguage,
            size: 26,
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: _t(english: 'Re-identify Device', hindi: 'पुनः पहचानें'),
            onPressed: _isRefreshing ? null : () => _loadDevices(showRefreshSpinner: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadDevices(showRefreshSpinner: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Current Auto-Recognized Device Card
                  _buildCurrentDeviceCard(),

                  const SizedBox(height: 18),

                  // 2. Automated Recognition Info Banner
                  _buildAutomationExplainerCard(),

                  const SizedBox(height: 18),

                  // 3. Recognized Devices List (Present & Future)
                  _buildRecognizedDevicesSection(),
                ],
              ),
            ),
      bottomNavigationBar: VoiceAssistantSpeakingBanner(
        selectedLanguage: widget.selectedLanguage,
      ),
    );
  }

  Widget _buildCurrentDeviceCard() {
    final device = _currentDevice;
    if (device == null) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B7C99).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    device.icon,
                    size: 32,
                    color: const Color(0xFF5B7C99),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C9A7A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF6C9A7A)),
                            const SizedBox(width: 4),
                            Text(
                              _t(
                                english: 'Auto-Recognized Device',
                                hindi: 'स्वचालित रूप से पहचाना गया',
                                marathi: 'आपोआप ओळखलेले डिव्हाइस',
                                gujarati: 'આપોઆપ ઓળખાયેલું ડિવાઇસ',
                                telugu: 'స్వయంచాలకంగా గుర్తించబడిన పరికరం',
                                tamil: 'தானாக அடையாளம் காணப்பட்ட சாதனம்',
                                bengali: 'স্বয়ংক্রিয়ভাবে সনাক্ত ডিভাইস',
                                kannada: 'ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಗುರುತಿಸಲಾದ ಸಾಧನ',
                                malayalam: 'സ്വയം തിരിച്ചറിഞ്ഞ ഉപകരണം',
                                punjabi: 'ਆਪਣੇ ਆਪ ਪਛਾਣਿਆ ਗਿਆ ਡਿਵਾਈਸ',
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C9A7A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF30485C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            // Specs Grid
            _buildSpecRow(
              icon: Icons.phone_android_rounded,
              label: _t(english: 'Model', hindi: 'मॉडल'),
              value: device.deviceModel,
            ),
            const SizedBox(height: 10),
            _buildSpecRow(
              icon: Icons.business_rounded,
              label: _t(english: 'Manufacturer', hindi: 'निर्माता'),
              value: device.manufacturer.isNotEmpty ? device.manufacturer : 'Generic',
            ),
            const SizedBox(height: 10),
            _buildSpecRow(
              icon: Icons.settings_system_daydream_rounded,
              label: _t(english: 'Operating System', hindi: 'ऑपरेटिंग सिस्टम'),
              value: '${device.osName} ${device.osVersion}',
            ),
            const SizedBox(height: 10),
            _buildSpecRow(
              icon: Icons.memory_rounded,
              label: _t(english: 'Hardware / Board', hindi: 'हार्डवेयर'),
              value: device.hardware.isNotEmpty ? device.hardware : 'Standard Chipset',
            ),
            const SizedBox(height: 10),
            _buildSpecRow(
              icon: Icons.fingerprint_rounded,
              label: _t(english: 'Device ID', hindi: 'डिवाइस आईडी'),
              value: device.id,
              isCopyable: true,
            ),

            const SizedBox(height: 16),

            // Auto-sync status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 20, color: Color(0xFF6C9A7A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(
                        english: 'Synchronized with Family & Location Tracking',
                        hindi: 'परिवार और लोकेशन ट्रैकिंग के साथ सिंक है',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String label,
    required String value,
    bool isCopyable = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5B7C99)),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (isCopyable)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              _showSnack(_t(
                english: 'Device ID copied to clipboard!',
                hindi: 'डिवाइस आईडी कॉपी हो गई!',
              ));
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF5B7C99)),
            ),
          ),
      ],
    );
  }

  Widget _buildAutomationExplainerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF5B7C99).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B7C99).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF5B7C99),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    english: 'Zero Manual Entry - Automated Recognition',
                    hindi: 'मैन्युअल प्रविष्टि समाप्त - स्वचालित पहचान',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF30485C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    english:
                        'Any phone, tablet, or device you or your family members use in the future will be recognized automatically. The phone model and OS are immediately linked to your safety profile and live maps.',
                    hindi:
                        'भविष्य में आपके या आपके परिवार द्वारा उपयोग किया जाने वाला कोई भी फ़ोन या डिवाइस अपने आप पहचाना जाएगा। फ़ोन मॉडल और सिस्टम विवरण आपकी सुरक्षा प्रोफ़ाइल और लाइव मैप से तुरंत जुड़ जाते हैं।',
                  ),
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizedDevicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t(
                english: 'All Recognized Devices',
                hindi: 'सभी पहचाने गए डिवाइस',
              ),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF30485C),
              ),
            ),
            Text(
              '${_recognizedDevices.length} ${_t(english: 'detected', hindi: 'मिले')}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_recognizedDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _t(
                english: 'No past devices recorded yet.',
                hindi: 'अभी तक कोई पिछला डिवाइस दर्ज नहीं है।',
              ),
              style: const TextStyle(color: Colors.black54),
            ),
          )
        else
          ..._recognizedDevices.map((device) {
            final isCurrent = device.id == _currentDevice?.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: isCurrent
                    ? const BorderSide(color: Color(0xFF6C9A7A), width: 1.5)
                    : BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCurrent
                      ? const Color(0xFF6C9A7A).withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  child: Icon(
                    device.icon,
                    color: isCurrent ? const Color(0xFF6C9A7A) : Colors.black54,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C9A7A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _t(english: 'Current', hindi: 'वर्तमान'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${device.osName} ${device.osVersion} • ${device.deviceType}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: !isCurrent
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        tooltip: _t(english: 'Remove', hindi: 'हटाएं'),
                        onPressed: () async {
                          await DeviceService.instance.removeDevice(device.id);
                          _loadDevices();
                          _showSnack(_t(
                            english: 'Device removed.',
                            hindi: 'डिवाइस हटा दिया गया।',
                          ));
                        },
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }
}
