import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'device_service.dart';
import 'device_model.dart';
import 'device_page.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  final List<Reminder> reminders;
  final String selectedLanguage;
  final Function(String) changeLanguage;
  final Function(Reminder) addReminder;
  final Function(Reminder) deleteReminder;
  final Function(Reminder, Reminder) editReminder;
  final Function(Reminder) toggleTaken;

  const LoginPage({
    super.key,
    required this.reminders,
    required this.selectedLanguage,
    required this.changeLanguage,
    required this.addReminder,
    required this.deleteReminder,
    required this.editReminder,
    required this.toggleTaken,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _otpSent = false;
  bool _obscureOtp = false;
  late String _currentLanguage;

  // Firebase Phone Auth
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmationResult;

  // OTP Resend Countdown
  Timer? _resendTimer;
  int _resendCountdown = 30;
  bool _canResend = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  static const String _prefIsLoggedIn = 'senior_saathi_is_logged_in';
  static const String _prefUserName = 'senior_saathi_user_name';
  static const String _prefUserPhone = 'senior_saathi_user_phone';

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  DeviceModel? _recognizedDevice;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.selectedLanguage;
    DeviceService.instance.getDeviceInfo().then((d) {
      if (mounted) setState(() => _recognizedDevice = d);
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // =====================================================
  // TRANSLATION HELPER
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
      selectedLanguage: _currentLanguage,
    );
  }

  // =====================================================
  // RESEND TIMER
  // =====================================================
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 30;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _resendCountdown = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  // =====================================================
  // SEND OTP
  // =====================================================
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final rawPhone = _phoneController.text.trim();
    final phone = '+91$rawPhone';

    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        final confirmation =
            await FirebaseAuth.instance.signInWithPhoneNumber(phone);

        if (!mounted) return;
        setState(() {
          _webConfirmationResult = confirmation;
          _otpSent = true;
          _isLoading = false;
        });
        _startResendTimer();
        _showSnack(
          _t(
            english: 'OTP sent to $phone',
            hindi: '$phone पर ओटीपी भेजा गया',
          ),
          isSuccess: true,
        );
      } else if (_isDesktop) {
        // Desktop environment (Windows/macOS/Linux):
        // Firebase Auth phone SMS verification is unsupported on desktop platforms.
        // Provide test mode so developers and users are never blocked.
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _verificationId = 'desktop_test_id';
          _otpSent = true;
          _isLoading = false;
        });
        _startResendTimer();
        _showSnack(
          _t(
            english: 'Desktop Mode: Use Test OTP 123456',
            hindi: 'डेस्कटॉप मोड: टेस्ट ओटीपी 123456 का उपयोग करें',
          ),
          isSuccess: true,
        );
      } else {
        // Mobile (Android / iOS)
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          forceResendingToken: _resendToken,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            debugPrint('Firebase phone auto-verification triggered');
            try {
              final userCredential =
                  await FirebaseAuth.instance.signInWithCredential(credential);
              await _onAuthSuccess(
                userCredential.user?.phoneNumber ?? phone,
                userCredential.user?.uid,
              );
            } catch (e) {
              debugPrint('Auto sign-in error: $e');
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            debugPrint('Firebase verificationFailed: ${e.code} - ${e.message}');
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _otpSent = false;
            });
            _showFriendlyFirebaseError(e);
          },
          codeSent: (String verificationId, int? resendToken) {
            debugPrint('Firebase codeSent: $verificationId');
            if (!mounted) return;
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _otpSent = true;
              _isLoading = false;
            });
            _startResendTimer();
            _showSnack(
              _t(
                english: 'OTP sent successfully to $phone',
                hindi: '$phone पर ओटीपी सफलतापूर्वक भेजा गया',
              ),
              isSuccess: true,
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            debugPrint('Firebase codeAutoRetrievalTimeout: $verificationId');
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
              });
            }
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showFriendlyFirebaseError(e);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(_t(
          english: 'Unable to send OTP. Please try again.',
          hindi: 'ओटीपी भेजने में असमर्थ। कृपया पुनः प्रयास करें।',
        ));
      }
    }
  }

  // =====================================================
  // RESEND OTP
  // =====================================================
  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;
    _otpController.clear();
    await _sendOtp();
  }

  // =====================================================
  // CHANGE PHONE NUMBER
  // =====================================================
  void _changePhoneNumber() {
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _verificationId = null;
      _webConfirmationResult = null;
      _isLoading = false;
    });
  }

  // =====================================================
  // VERIFY OTP
  // =====================================================
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showSnack(
        _t(
          english: 'Please enter the complete 6-digit OTP.',
          hindi: 'कृपया पूरा 6-अंकों का ओटीपी दर्ज करें।',
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Desktop or Test bypass
      if (_verificationId == 'desktop_test_id' || (_isDesktop && otp == '123456')) {
        await Future.delayed(const Duration(milliseconds: 600));
        await _onAuthSuccess('+91${_phoneController.text.trim()}', 'desktop_user');
        return;
      }

      UserCredential credential;

      if (kIsWeb) {
        final confirmation = _webConfirmationResult;
        if (confirmation == null) {
          _showSnack(
            _t(
              english: 'Session expired. Please request a new OTP.',
              hindi: 'सत्र समाप्त। कृपया नया ओटीपी मांगें।',
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        credential = await confirmation.confirm(otp);
      } else {
        final verificationId = _verificationId;
        if (verificationId == null) {
          _showSnack(
            _t(
              english: 'Session expired. Please request a new OTP.',
              hindi: 'सत्र समाप्त। कृपया नया ओटीपी मांगें।',
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final phoneCredential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otp,
        );

        credential = await FirebaseAuth.instance.signInWithCredential(
          phoneCredential,
        );
      }

      final user = credential.user;
      await _onAuthSuccess(
        user?.phoneNumber ?? '+91${_phoneController.text.trim()}',
        user?.uid,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showFriendlyFirebaseError(e);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(
          _t(
            english: 'OTP verification failed. Please try again.',
            hindi: 'ओटीपी सत्यापन विफल रहा। कृपया पुनः प्रयास करें।',
          ),
        );
      }
    }
  }

  // =====================================================
  // AUTH SUCCESS HANDLER
  // =====================================================
  Future<void> _onAuthSuccess(String phone, String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enteredName = _nameController.text.trim();
      final name = enteredName.isNotEmpty
          ? enteredName
          : (prefs.getString(_prefUserName) ?? 'Friend');

      await prefs.setBool(_prefIsLoggedIn, true);
      await prefs.setString(_prefUserPhone, phone);
      await prefs.setString(_prefUserName, name);

      // Save user profile in Firestore
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'uid': uid,
            'name': name,
            'phone': phone,
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Firestore profile sync error (ignored): $e');
        }
      }

      // Automatically register and sync recognized device specs
      try {
        await DeviceService.instance.autoRegisterDevice(
          userId: uid,
          userName: name,
          userPhone: phone,
        );
      } catch (e) {
        debugPrint('Device auto-registration error: $e');
      }
    } catch (e) {
      debugPrint('Error saving login state: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _proceedToHome();
  }

  // =====================================================
  // FRIENDLY FIREBASE ERRORS
  // =====================================================
  void _showFriendlyFirebaseError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'invalid-phone-number':
        message = _t(
          english: 'Please enter a valid 10-digit mobile number.',
          hindi: 'कृपया एक मान्य 10 अंकों का मोबाइल नंबर दर्ज करें।',
        );
        break;
      case 'quota-exceeded':
        message = _t(
          english: 'Daily SMS quota reached. Please try again tomorrow or use test login.',
          hindi: 'आज के लिए SMS सीमा समाप्त हो गई है। कृपया कल प्रयास करें।',
        );
        break;
      case 'invalid-verification-code':
        message = _t(
          english: 'Incorrect OTP. Please check the 6-digit code and try again.',
          hindi: 'गलत ओटीपी। कृपया 6-अंकों का कोड जांचें और पुनः प्रयास करें।',
        );
        break;
      case 'session-expired':
        message = _t(
          english: 'OTP has expired. Please tap "Resend OTP" to get a new code.',
          hindi: 'ओटीपी समाप्त हो गया है। नया कोड पाने के लिए "Resend OTP" दबाएं।',
        );
        break;
      case 'too-many-requests':
        message = _t(
          english: 'Too many requests. Please wait a few minutes before trying again.',
          hindi: 'बहुत अधिक प्रयास। कृपया कुछ मिनट प्रतीक्षा करें।',
        );
        break;
      case 'missing-client-identifier':
      case 'app-not-authorized':
        message = _t(
          english: 'App authorization check failed. Please ensure Play Integrity / SHA-1 is added.',
          hindi: 'ऐप प्रमाणीकरण जांच विफल रही। कृपया SHA-1 सेटिंग्स की जांच करें।',
        );
        break;
      default:
        message = e.message ??
            _t(
              english: 'Authentication failed. Please try again.',
              hindi: 'प्रमाणीकरण विफल रहा। कृपया पुनः प्रयास करें।',
            );
    }
    _showSnack(message);
  }

  void _proceedToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          reminders: widget.reminders,
          selectedLanguage: _currentLanguage,
          addReminder: widget.addReminder,
          deleteReminder: widget.deleteReminder,
          editReminder: widget.editReminder,
          toggleTaken: widget.toggleTaken,
        ),
      ),
    );
  }

  void _continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsLoggedIn, false);
    await prefs.setString(_prefUserName, 'Guest');

    if (!mounted) return;
    _proceedToHome();
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF6C9A7A) : const Color(0xFF30485C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _t(
              english: 'Choose Your Language',
              hindi: 'अपनी भाषा चुनें',
              marathi: 'तुमची भाषा निवडा',
              gujarati: 'તમારી ભાષા પસંદ કરો',
              telugu: 'మీ భాషను ఎంచుకోండి',
              tamil: 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
              bengali: 'আপনার ভাষা নির্বাচন করুন',
              kannada: 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ',
              malayalam: 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക',
              punjabi: 'ਆਪਣੀ ਭਾਸ਼ਾ ਚੁਣੋ',
            ),
          ),
          content: SizedBox(
            height: 400,
            width: double.maxFinite,
            child: ListView(
              children: AppLanguage.languages.map((language) {
                return ListTile(
                  title: Text(
                    language,
                    style: TextStyle(
                      fontWeight: _currentLanguage == language
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _currentLanguage == language
                          ? const Color(0xFF5B7C99)
                          : Colors.black87,
                    ),
                  ),
                  trailing: _currentLanguage == language
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF5B7C99))
                      : null,
                  onTap: () {
                    widget.changeLanguage(language);
                    setState(() {
                      _currentLanguage = language;
                    });
                    Navigator.pop(dialogContext);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // BUILD METHOD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF30485C), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showLanguageSelector,
            icon: const Icon(Icons.language_rounded,
                color: Color(0xFF5B7C99), size: 22),
            label: Text(
              _currentLanguage,
              style: const TextStyle(
                color: Color(0xFF5B7C99),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3EDF4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFF5B7C99),
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Heading
                  Text(
                    _otpSent
                        ? _t(
                            english: 'Enter OTP Verification',
                            hindi: 'ओटीपी सत्यापन दर्ज करें',
                            marathi: 'ओटीपी पडताळणी प्रविष्ट करा',
                            gujarati: 'ઓટીપી ચકાસણી દાખલ કરો',
                            telugu: 'OTP ధృవీకరణను నమోదు చేయండి',
                            tamil: 'OTP சரிபார்ப்பை உள்ளிடவும்',
                            bengali: 'ওটিপি যাচাইকরণ লিখুন',
                            kannada: 'OTP ಪರಿಶೀಲನೆಯನ್ನು ನಮೂದಿಸಿ',
                            malayalam: 'OTP പരിശോധന നൽകുക',
                            punjabi: 'OTP ਪੁਸ਼ਟੀਕਰਨ ਦਰਜ ਕਰੋ',
                          )
                        : (_isRegisterMode
                            ? _t(
                                english: 'Create Account',
                                hindi: 'नया खाता बनाएं',
                                marathi: 'नवीन खाते तयार करा',
                                gujarati: 'નવું ખાતું બનાવો',
                                telugu: 'కొత్త ఖాతా సృష్టించండి',
                                tamil: 'புதிய கணக்கை உருவாக்கவும்',
                                bengali: 'নতুন অ্যাকাউন্ট তৈরি করুন',
                                kannada: 'ಹೊಸ ಖಾತೆ ರಚಿಸಿ',
                                malayalam: 'പുതിയ അക്കൗണ്ട് ഉണ്ടാക്കുക',
                                punjabi: 'ਨਵਾਂ ਖਾਤਾ ਬਣਾਓ',
                              )
                            : _t(
                                english: 'Welcome Back',
                                hindi: 'वापसी पर स्वागत है',
                                marathi: 'पुन्हा स्वागत आहे',
                                gujarati: 'ફરી સ્વાગત છે',
                                telugu: 'తిరిగి స్వాగతం',
                                tamil: 'மீண்டும் வரவேற்கிறோம்',
                                bengali: 'আবারও স্বাগতম',
                                kannada: 'ಮತ್ತೆ ಸ್ವಾಗತ',
                                malayalam: 'വീണ്ടും സ്വാഗതം',
                                punjabi: 'ਜੀ ਆਇਆਂ ਨੂੰ',
                              )),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF263B4A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _otpSent
                        ? _t(
                            english: 'A 6-digit code has been sent to your mobile',
                            hindi: 'आपके मोबाइल पर 6-अंकों का कोड भेजा गया है',
                            marathi: 'तुमच्या मोबाईलवर ६-अंकी कोड पाठवला आहे',
                            gujarati: 'તમારા મોબાઇલ પર 6-અંકનો કોડ મોકલ્યો છે',
                            telugu: 'మీ మొబైల్‌కు 6 అంకెల కోడ్ పంపబడింది',
                            tamil: 'உங்கள் மொபைலுக்கு 6 இலக்க குறியீடு அனுப்பப்பட்டது',
                            bengali: 'আপনার মোবাইলে ৬-সংখ্যার কোড পাঠানো হয়েছে',
                            kannada: 'ನಿಮ್ಮ ಮೊಬೈಲ್‌ಗೆ 6 ಅಂಕಿಗಳ ಕೋಡ್ ಕಳುಹಿಸಲಾಗಿದೆ',
                            malayalam: 'നിങ്ങളുടെ മൊബൈലിലേക്ക് 6 അക്ക കോഡ് അയച്ചിട്ടുണ്ട്',
                            punjabi: 'ਤੁਹਾਡੇ ਮੋਬਾਈਲ ਤੇ 6-ਅੰਕਾਂ ਦਾ ਕੋਡ ਭੇਜਿਆ ਗਿਆ ਹੈ',
                          )
                        : (_isRegisterMode
                            ? _t(
                                english: 'Enter your phone to register as a Senior Saathi',
                                hindi: 'सीनियर साथी के रूप में जुड़ने के लिए फोन नंबर दर्ज करें',
                              )
                            : _t(
                                english: 'Sign in to access your reminders & companion',
                                hindi: 'अपने रिमाइंडर्स और साथी तक पहुँचने के लिए साइन इन करें',
                              )),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF687780),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // =====================================================
                  // STEP 1: PHONE & NAME INPUT (Before OTP Sent)
                  // =====================================================
                  if (!_otpSent) ...[
                    // Auto-Recognized Device Indicator
                    if (_recognizedDevice != null) ...[
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DevicePage(selectedLanguage: _currentLanguage),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C9A7A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF6C9A7A).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _recognizedDevice!.icon,
                                size: 18,
                                color: const Color(0xFF6C9A7A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_t(english: 'Identified Device', hindi: 'पहचाना गया डिवाइस')}: ${_recognizedDevice!.displayName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF30485C),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Color(0xFF6C9A7A),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Mode Selector Tabs (Sign In / Register)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EFF5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isRegisterMode = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: !_isRegisterMode
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !_isRegisterMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  _t(
                                    english: 'Sign In',
                                    hindi: 'साइन इन',
                                    marathi: 'साइन इन',
                                    gujarati: 'સાઇન ઇન',
                                    telugu: 'సైన్ ఇన్',
                                    tamil: 'உள்நுழைவு',
                                    bengali: 'সাইন ইন',
                                    kannada: 'ಸೈನ್ ಇನ್',
                                    malayalam: 'സൈൻ ഇൻ',
                                    punjabi: 'ਸਾਈਨ ਇਨ',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: !_isRegisterMode
                                        ? const Color(0xFF30485C)
                                        : const Color(0xFF7A8B99),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isRegisterMode = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: _isRegisterMode
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isRegisterMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  _t(
                                    english: 'New Account',
                                    hindi: 'नया खाता',
                                    marathi: 'नवीन खाते',
                                    gujarati: 'નવું ખાતું',
                                    telugu: 'కొత్త ఖాతా',
                                    tamil: 'புதிய கணக்கு',
                                    bengali: 'নতুন অ্যাকাউন্ট',
                                    kannada: 'ಹೊಸ ಖಾತೆ',
                                    malayalam: 'പുതിയ അക്കൗണ്ട്',
                                    punjabi: 'ਨਵਾਂ ਖਾਤਾ',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: _isRegisterMode
                                        ? const Color(0xFF30485C)
                                        : const Color(0xFF7A8B99),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Name Field (Register Mode Only)
                    if (_isRegisterMode) ...[
                      Text(
                        _t(
                          english: 'Your Name',
                          hindi: 'आपका नाम',
                          marathi: 'तुमचे नाव',
                          gujarati: 'તમારું નામ',
                          telugu: 'మీ పేరు',
                          tamil: 'உங்கள் பெயர்',
                          bengali: 'আপনার নাম',
                          kannada: 'ನಿಮ್ಮ ಹೆಸರು',
                          malayalam: 'നിങ്ങളുടെ പേര്',
                          punjabi: 'ਤੁਹਾਡਾ ਨਾਮ',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF30485C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: Color(0xFF5B7C99), size: 26),
                          hintText: _t(
                            english: 'e.g. Ramesh Kumar',
                            hindi: 'उदा. रमेश कुमार',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFD9E3EA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFD9E3EA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xFF5B7C99), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 18),
                        ),
                        validator: (val) {
                          if (_isRegisterMode &&
                              (val == null || val.trim().isEmpty)) {
                            return _t(
                              english: 'Please enter your name',
                              hindi: 'कृपया अपना नाम दर्ज करें',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Phone Number Field
                    Text(
                      _t(
                        english: 'Mobile Number',
                        hindi: 'मोबाइल नंबर',
                        marathi: 'मोबाईल नंबर',
                        gujarati: 'મોબાઈલ નંબર',
                        telugu: 'మొబైల్ నంబర్',
                        tamil: 'மொபைல் எண்',
                        bengali: 'মোবাইল নম্বর',
                        kannada: 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ',
                        malayalam: 'മൊബൈൽ നമ്പർ',
                        punjabi: 'ਮੋਬਾਈਲ ਨੰਬਰ',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF30485C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.phone_outlined,
                            color: Color(0xFF5B7C99), size: 26),
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF30485C)),
                        hintText: '98765 43210',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Color(0xFFD9E3EA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Color(0xFFD9E3EA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF5B7C99), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 10) {
                          return _t(
                            english: 'Please enter a valid 10-digit number',
                            hindi: 'कृपया 10 अंकों का मान्य नंबर दर्ज करें',
                          );
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // Send OTP Button
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B7C99),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _t(
                                      english: 'Get OTP',
                                      hindi: 'ओटीपी प्राप्त करें',
                                      marathi: 'ओटीपी मिळवा',
                                      gujarati: 'ઓટીપી મેળવો',
                                      telugu: 'OTP పొందండి',
                                      tamil: 'OTP பெறுக',
                                      bengali: 'ওটিপি পান',
                                      kannada: 'OTP ಪಡೆಯಿರಿ',
                                      malayalam: 'OTP നേടുക',
                                      punjabi: 'OTP ਪ੍ਰਾਪਤ ਕਰੋ',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 24),
                                ],
                              ),
                      ),
                    ),
                  ],

                  // =====================================================
                  // STEP 2: OTP VERIFICATION (When OTP Sent)
                  // =====================================================
                  if (_otpSent) ...[
                    // Number Info Card with Change Option
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF5B7C99).withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFE3EDF4),
                            child: Icon(Icons.phone_android_rounded,
                                color: Color(0xFF5B7C99), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(
                                    english: 'Code sent to',
                                    hindi: 'कोड भेजा गया',
                                  ),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                                Text(
                                  '+91 ${_phoneController.text.trim()}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF30485C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isLoading ? null : _changePhoneNumber,
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: Text(
                              _t(english: 'Change', hindi: 'बदलें'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF5B7C99),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 6-Digit OTP Field
                    Text(
                      _t(
                        english: '6-Digit Verification Code (OTP)',
                        hindi: '6-अंकों का सत्यापन कोड (ओटीपी)',
                        marathi: '६-अंकी पडताळणी कोड (OTP)',
                        gujarati: '6-અંકનો ચકાસણી કોડ (OTP)',
                        telugu: '6 అంకెల ధృవీకరణ కోడ్ (OTP)',
                        tamil: '6 இலக்க சரிபார்ப்பு குறியீடு (OTP)',
                        bengali: '৬-সংখ্যার যাচাইকরণ কোড (OTP)',
                        kannada: '6 ಅಂಕಿಗಳ ಪರಿಶೀಲನಾ ಕೋಡ್ (OTP)',
                        malayalam: '6 അക്ക പരിശോധന കോഡ് (OTP)',
                        punjabi: '6-ਅੰਕਾਂ ਦਾ ਪੁਸ਼ਟੀਕਰਨ ਕੋਡ (OTP)',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF30485C),
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _otpController,
                      obscureText: _obscureOtp,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 12,
                        color: Color(0xFF30485C),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.lock_clock_rounded,
                            color: Color(0xFF5B7C99), size: 26),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureOtp
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: const Color(0xFF5B7C99),
                          ),
                          onPressed: () =>
                              setState(() => _obscureOtp = !_obscureOtp),
                        ),
                        hintText: '••••••',
                        hintStyle: const TextStyle(
                            letterSpacing: 10, color: Colors.black26),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Color(0xFFD9E3EA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Color(0xFFD9E3EA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF5B7C99), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length != 6) {
                          return _t(
                            english: 'Please enter the 6-digit OTP',
                            hindi: 'कृपया 6 अंकों का ओटीपी दर्ज करें',
                          );
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Resend Timer Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canResend) ...[
                          const Icon(Icons.timer_outlined,
                              size: 18, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            '${_t(english: 'Resend OTP in', hindi: 'ओटीपी पुनः भेजें')} ${_resendCountdown}s',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ] else ...[
                          Text(
                            _t(
                              english: "Didn't receive the code?",
                              hindi: 'कोड प्राप्त नहीं हुआ?',
                            ),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _resendOtp,
                            child: Text(
                              _t(english: 'Resend OTP', hindi: 'पुनः भेजें'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5B7C99),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Verify & Continue Button
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C9A7A),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _t(
                                      english: 'Verify & Continue',
                                      hindi: 'सत्यापित करें और आगे बढ़ें',
                                      marathi: 'सत्यापित करा आणि पुढे जा',
                                      gujarati: 'ચકાસો અને આગળ વધો',
                                      telugu: 'ధృవీకరించి కొనసాగించండి',
                                      tamil: 'சரிபார்த்து தொடரவும்',
                                      bengali: 'যাচাই করুন ও এগিয়ে যান',
                                      kannada: 'ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಮುಂದುವರಿಯಿರಿ',
                                      malayalam: 'പരിശോധിച്ച് തുടരുക',
                                      punjabi: 'ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਜਾਰੀ ਰੱਖੋ',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.check_circle_rounded,
                                      size: 24),
                                ],
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Continue as Guest Option
                  Center(
                    child: TextButton.icon(
                      onPressed: _continueAsGuest,
                      icon: const Icon(Icons.directions_walk_rounded,
                          color: Color(0xFF687780)),
                      label: Text(
                        _t(
                          english: 'Skip & Continue as Guest',
                          hindi: 'स्किप करें और अतिथि के रूप में जारी रखें',
                          marathi: 'वगळा आणि पाहुणे म्हणून सुरू ठेवा',
                          gujarati: 'છોડો અને મહેમાન તરીકે આગળ વધો',
                          telugu: 'దాటవేసి అతిథిగా కొనసాగండి',
                          tamil: 'தவிர்த்து விருந்தினராக தொடரவும்',
                          bengali: 'এড়িয়ে যান ও অতিথি হিসেবে চালিয়ে যান',
                          kannada: 'ಬಿಟ್ಟುಬಿಡಿ ಮತ್ತು ಅತಿಥಿಯಾಗಿ ಮುಂದುವರಿಯಿರಿ',
                          malayalam: 'ഒഴിവാക്കി അതിഥിയായി തുടരുക',
                          punjabi: 'ਛੱਡੋ ਅਤੇ ਮਹਿਮਾਨ ਵਜੋਂ ਜਾਰੀ ਰੱਖੋ',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF687780),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Senior-friendly Hint Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFF5B7C99), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _otpSent
                                ? _t(
                                    english:
                                        'Tip: Please check your SMS messages for the 6-digit verification code.',
                                    hindi:
                                        'सुझाव: कृपया 6-अंकों के सत्यापन कोड के लिए अपने एसएमएस संदेशों की जांच करें।',
                                  )
                                : _t(
                                    english:
                                        'Tip: A quick 6-digit code will be sent to your mobile to sign you in securely.',
                                    hindi:
                                        'सुझाव: सुरक्षित साइन इन के लिए आपके मोबाइल पर 6-अंकों का त्वरित कोड भेजा जाएगा।',
                                  ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF40596D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
