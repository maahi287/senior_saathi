import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

import 'database_helper.dart';

import 'login_page.dart';
import 'prescriptions_page.dart';
import 'medical_reports_page.dart';
import 'location_tracking_page.dart';
import 'app_learning_hub.dart';
import 'voice_assistant_service.dart';
import 'voice_assistant_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// =====================================================
// LANGUAGE SYSTEM
// =====================================================

class AppLanguage {
  static const String english = 'English';
  static const String hindi = 'Hindi';
  static const String marathi = 'Marathi';
  static const String gujarati = 'Gujarati';
  static const String telugu = 'Telugu';
  static const String tamil = 'Tamil';
  static const String bengali = 'Bengali';
  static const String kannada = 'Kannada';
  static const String malayalam = 'Malayalam';
  static const String punjabi = 'Punjabi';

  static const List<String> languages = [
    english,
    hindi,
    marathi,
    gujarati,
    telugu,
    tamil,
    bengali,
    kannada,
    malayalam,
    punjabi,
  ];
}
String appText({
  required String english,
  required String hindi,
  required String marathi,
  required String gujarati,
  required String telugu,
  required String tamil,
  required String bengali,
  required String kannada,
  required String malayalam,
  required String punjabi,
  required String selectedLanguage,
}) {
  switch (selectedLanguage) {
    case AppLanguage.hindi:
      return hindi;

    case AppLanguage.marathi:
      return marathi;

    case AppLanguage.gujarati:
      return gujarati;

    case AppLanguage.telugu:
      return telugu;

    case AppLanguage.tamil:
      return tamil;

    case AppLanguage.bengali:
      return bengali;

    case AppLanguage.kannada:
      return kannada;

    case AppLanguage.malayalam:
      return malayalam;

    case AppLanguage.punjabi:
      return punjabi;

    default:
      return english;
  }
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SeniorSaathiApp());
}


// =====================================================
// REMINDER MODEL
// =====================================================

class Reminder {
  String id;
  String title;
  String details;
  String type;
  DateTime dateTime;
  bool isTaken;

  // Scheduling
  String scheduleType;
  List<int> selectedDays;

  Reminder({
    String? id,
    required this.title,
    required this.details,
    required this.type,
    required this.dateTime,
    this.isTaken = false,

    // Default schedule = Every day
    this.scheduleType = 'daily',

    // Empty until user selects specific days
    this.selectedDays = const [],
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'details': details,
      'type': type,
      'dateTime': dateTime.toIso8601String(),
      'isTaken': isTaken,

      // Scheduling
      'scheduleType': scheduleType,
      'selectedDays': selectedDays,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      details: json['details'] as String,
      type: json['type'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      isTaken: json['isTaken'] as bool,

      // Supports old reminders too
      scheduleType: json['scheduleType'] as String? ?? 'daily',

      selectedDays: json['selectedDays'] != null
          ? List<int>.from(json['selectedDays'])
          : [],
    );
  }
  
  // Convert Reminder to a SQLite database row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'details': details,
      'type': type,
      'dateTime': dateTime.toIso8601String(),
      'isTaken': isTaken ? 1 : 0,
      'scheduleType': scheduleType,
      'selectedDays': jsonEncode(selectedDays),
    };
  }

  // Create Reminder from a SQLite database row
  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      title: map['title'] as String,
      details: map['details'] as String,
      type: map['type'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      isTaken: (map['isTaken'] as num) == 1,
      scheduleType: map['scheduleType'] as String? ?? 'daily',
      selectedDays: map['selectedDays'] != null
          ? List<int>.from(
              jsonDecode(map['selectedDays'] as String) as List,
            )
          : [],
    );
  }

}

// =====================================================
// APP
// =====================================================

class SeniorSaathiApp extends StatefulWidget {
  const SeniorSaathiApp({super.key});

  @override
  State<SeniorSaathiApp> createState() => _SeniorSaathiAppState();
}

class _SeniorSaathiAppState extends State<SeniorSaathiApp> {
  final List<Reminder> reminders = [];

  static const String _storageKey = 'senior_saathi_reminders';
  static const String _languageKey = 'senior_saathi_language';

  bool _isLoading = true;

  String _selectedLanguage = AppLanguage.english;

    @override
    void initState() {
    super.initState();
    _loadReminders();
    _loadLanguage();
  }
    Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage = prefs.getString(_languageKey);

    if (savedLanguage != null &&
        AppLanguage.languages.contains(savedLanguage)) {
      setState(() {
        _selectedLanguage = savedLanguage;
      });
    }
  }

  Future<void> _changeLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _languageKey,
      language,
    );

    setState(() {
      _selectedLanguage = language;
    });
  }

  
Future<void> _loadReminders() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_storageKey);

  final dbHelper = DatabaseHelper.instance;

  // First, try loading reminders from SQLite.
  var rows = await dbHelper.getReminders();

  // If SQLite is empty, migrate existing reminders from SharedPreferences.
  if (rows.isEmpty && saved != null) {
    final List<dynamic> decoded = jsonDecode(saved);

    for (final item in decoded) {
      final reminder = Reminder.fromJson(
        Map<String, dynamic>.from(item as Map),
      );

      await dbHelper.insertReminder(reminder.toMap());
    }

    // Read the migrated reminders back from SQLite.
    rows = await dbHelper.getReminders();
  }

  final loadedReminders = rows
      .map((row) => Reminder.fromMap(row))
      .toList();

  if (!mounted) return;

  setState(() {
    reminders
      ..clear()
      ..addAll(loadedReminders);

    _sortReminders();
    _isLoading = false;
  });
}


  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  
Future<void> addReminder(Reminder reminder) async {
  setState(() {
    reminders.add(reminder);
    _sortReminders();
  });

  await DatabaseHelper.instance.insertReminder(
    reminder.toMap(),
  );

  // Keep the existing backup during the transition.
  await _saveReminders();
}

Future<void> deleteReminder(Reminder reminder) async {
  setState(() {
    reminders.remove(reminder);
  });

  await DatabaseHelper.instance.deleteReminder(
    reminder.id,
  );

  await _saveReminders();
}

Future<void> editReminder(
  Reminder oldReminder,
  Reminder newReminder,
) async {
  setState(() {
    final index = reminders.indexOf(oldReminder);

    if (index != -1) {
      reminders[index] = newReminder;
      _sortReminders();
    }
  });

  await DatabaseHelper.instance.updateReminder(
    oldReminder.id,
    newReminder.toMap(),
  );

  await _saveReminders();
}

Future<void> toggleTaken(Reminder reminder) async {
  setState(() {
    reminder.isTaken = !reminder.isTaken;
  });

  await DatabaseHelper.instance.updateReminder(
    reminder.id,
    reminder.toMap(),
  );

  await _saveReminders();
}


  void _sortReminders() {
    reminders.sort(
      (a, b) => a.dateTime.compareTo(b.dateTime),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Senior Saathi',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F5F0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B7C99),
        ),
      ),
            home: _isLoading
          ? const Scaffold(
              backgroundColor: Color(0xFFF8F5F0),
              body: Center(child: CircularProgressIndicator()),
            )
          : WelcomePage(
        reminders: reminders,
        selectedLanguage: _selectedLanguage,
        changeLanguage: _changeLanguage,
        addReminder: addReminder,
        deleteReminder: deleteReminder,
        editReminder: editReminder,
                toggleTaken: toggleTaken,
            ),
    );
  }
  void _showLanguageDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Choose Your Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.languages.map((language) {
            return ListTile(
              title: Text(language),
              onTap: () {
                _changeLanguage(language);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      );
    },
  );
}
}

// =====================================================
// WELCOME PAGE
// =====================================================

class WelcomePage extends StatelessWidget {
  final List<Reminder> reminders;
  final Function(String) changeLanguage;
  final Function(Reminder) addReminder;
  final Function(Reminder) deleteReminder;
  final Function(Reminder, Reminder) editReminder;
  final Function(Reminder) toggleTaken;
  final String selectedLanguage;

  const WelcomePage({
    super.key,
    required this.reminders,
    required this.changeLanguage,
    required this.addReminder,
    required this.deleteReminder,
    required this.editReminder,
    required this.toggleTaken,
    required this.selectedLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EDF4),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFF5B7C99),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Senior Saathi',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF30485C),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 35),

              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0F5),
                  borderRadius: BorderRadius.circular(35),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.diversity_1_rounded,
                        size: 90,
                        color: Color(0xFF5B7C99),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Always by your side',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF40596D),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Text(
  appText(
    english: 'Welcome to Senior Saathi',
    hindi: 'Senior Saathi में आपका स्वागत है',
    marathi: 'Senior Saathi मध्ये आपले स्वागत आहे',
    gujarati: 'Senior Saathi માં આપનું સ્વાગત છે',
    telugu: 'Senior Saathi కి స్వాగతం',
    tamil: 'Senior Saathi க்கு வரவேற்கிறோம்',
    bengali: 'Senior Saathi-তে আপনাকে স্বাগতম',
    kannada: 'Senior Saathi ಗೆ ಸ್ವಾಗತ',
    malayalam: 'Senior Saathi-ലേക്ക് സ്വാഗതം',
    punjabi: 'Senior Saathi ਵਿੱਚ ਤੁਹਾਡਾ ਸੁਆਗਤ ਹੈ',
    selectedLanguage: selectedLanguage,
  ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263B4A),
                ),
              ),

              const SizedBox(height: 12),

               Text(
  appText(
    english: 'Your trusted companion for everyday life.',
    hindi: 'आपके रोज़मर्रा के जीवन का भरोसेमंद साथी।',
    marathi: 'तुमच्या दैनंदिन जीवनातील विश्वासू साथीदार.',
    gujarati: 'તમારા રોજિંદા જીવનનો વિશ્વાસુ સાથી.',
    telugu: 'మీ రోజువారీ జీవితానికి నమ్మకమైన సహచరుడు.',
    tamil: 'உங்கள் அன்றாட வாழ்க்கைக்கான நம்பகமான துணை.',
    bengali: 'আপনার দৈনন্দিন জীবনের বিশ্বস্ত সঙ্গী।',
    kannada: 'ನಿಮ್ಮ ದೈನಂದಿನ ಜೀವನದ ವಿಶ್ವಾಸಾರ್ಹ ಸಂಗಾತಿ.',
    malayalam: 'നിങ്ങളുടെ ദൈനംദിന ജീവിതത്തിലെ വിശ്വസ്ത കൂട്ടുകാരൻ.',
    punjabi: 'ਤੁਹਾਡੀ ਰੋਜ਼ਾਨਾ ਜ਼ਿੰਦਗੀ ਦਾ ਭਰੋਸੇਮੰਦ ਸਾਥੀ।',
    selectedLanguage: selectedLanguage,
  ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF687780),
                ),
              ),

              const SizedBox(height: 35),
              GestureDetector(
  onTap: () {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            appText(
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
              selectedLanguage: selectedLanguage,
            ),
          ),
          content: SizedBox(
            height: 400,
            width: double.maxFinite,
            child: ListView(
              children: AppLanguage.languages.map((language) {
                return ListTile(
                  title: Text(language),
                  onTap: () {
                    changeLanguage(language);
                    Navigator.pop(dialogContext);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  },
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFD9E3EA),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.language_rounded,
          color: Color(0xFF5B7C99),
          size: 30,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            selectedLanguage,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded),
      ],
    ),
  ),
),

const SizedBox(height: 25),

SizedBox(
  width: double.infinity,
  height: 62,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          
builder: (context) => LoginPage(
  reminders: reminders,
  selectedLanguage: selectedLanguage,
  changeLanguage: (language) {},
  addReminder: addReminder,
  deleteReminder: deleteReminder,
  editReminder: editReminder,
  toggleTaken: toggleTaken,
),

        ),
      );
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF5B7C99),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          appText(
            english: 'Get Started',
            hindi: 'शुरू करें',
            marathi: 'सुरू करा',
            gujarati: 'શરૂ કરો',
            telugu: 'ప్రారంభించండి',
            tamil: 'தொடங்குங்கள்',
            bengali: 'শুরু করুন',
            kannada: 'ಪ್ರಾರಂಭಿಸಿ',
            malayalam: 'ആരംഭിക്കുക',
            punjabi: 'ਸ਼ੁਰੂ ਕਰੋ',
            selectedLanguage: selectedLanguage,
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_forward_rounded),
      ],
    ),
  ),
),

const SizedBox(height: 25),

Text(
  'Made with care for our seniors ❤️',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 14,
    color: Color(0xFF89949B),
  ),
),

const SizedBox(height: 25),
          ],
        ),
      ),
    ),
    );
  }
}

// =====================================================
// HOME PAGE
// =====================================================

class HomePage extends StatefulWidget {
  final List<Reminder> reminders;
  final String selectedLanguage;
  final Function(Reminder) addReminder;
  final Function(Reminder) deleteReminder;
  final Function(Reminder, Reminder) editReminder;
  final Function(Reminder) toggleTaken;

  const HomePage({
    super.key,
    required this.reminders,
    required this.selectedLanguage,
    required this.addReminder,
    required this.deleteReminder,
    required this.editReminder,
    required this.toggleTaken,
  });

    @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showReminders = false; String _buildHomeSpeechText() { final count = widget.reminders.length; return appText(english: 'Welcome to Senior Saathi. You have $count reminders set. Your main services are Emergency, Medicines, Health, Family, Learn Apps, Reminders, and Location Tracking.', hindi: 'सीनियर साथी में आपका स्वागत है। आपके $count रिमाइंडर सेट हैं। आपकी मुख्य सेवाएं हैं: आपातकालीन, दवाइयां, स्वास्थ्य, परिवार, ऐप्स सीखें, और लोकेशन ट्रैकिंग।', marathi: 'Senior Saathi मध्ये आपले स्वागत आहे. तुमची $count स्मरणपत्रे सेट आहेत.', gujarati: 'Senior Saathi માં આપનું સ્વાગત છે. તમારા $count રિમાઇન્ડર્સ સેટ છે.', telugu: 'Senior Saathi కు స్వాగతం.', tamil: 'Senior Saathi-க்கு வரவேற்கிறோம்.', bengali: 'Senior Saathi-তে স্বাগতম।', kannada: 'Senior Saathi ಗೆ ಸ್ವಾಗತ.', malayalam: 'Senior Saathi-ലേക്ക് സ്വാഗതം.', punjabi: 'Senior Saathi ਵਿੱਚ ਸਵਾਗਤ ਹੈ।', selectedLanguage: widget.selectedLanguage); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      appText(
        english: 'Hello 👋',
        hindi: 'नमस्ते 👋',
        marathi: 'नमस्कार 👋',
        gujarati: 'નમસ્તે 👋',
        telugu: 'నమస్కారం 👋',
        tamil: 'வணக்கம் 👋',
        bengali: 'নমস্কার 👋',
        kannada: 'ನಮಸ್ಕಾರ 👋',
        malayalam: 'നമസ്കാരം 👋',
        punjabi: 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ 👋',
selectedLanguage: widget.selectedLanguage,      ),
      style: const TextStyle(
        fontSize: 17,
        color: Color(0xFF687780),
      ),
    ),
    Text(
      appText(
        english: 'Welcome to Senior Saathi',
        hindi: 'Senior Saathi में आपका स्वागत है',
        marathi: 'Senior Saathi मध्ये आपले स्वागत आहे',
        gujarati: 'Senior Saathi માં આપનું સ્વાગત છે',
        telugu: 'Senior Saathi కు స్వాగతం',
        tamil: 'Senior Saathi-க்கு வரவேற்கிறோம்',
        bengali: 'Senior Saathi-তে আপনাকে স্বাগতম',
        kannada: 'Senior Saathi ಗೆ ಸ್ವಾಗತ',
        malayalam: 'Senior Saathi-ലേക്ക് സ്വാഗതം',
        punjabi: 'Senior Saathi ਵਿੱਚ ਤੁਹਾਡਾ ਸਵਾਗਤ ਹੈ',
        selectedLanguage: widget.selectedLanguage,
      ),
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF263B4A),
      ),
    ),
  ],
),
        actions: [
          SpeakerIconButton(
            textToRead: _buildHomeSpeechText(),
            selectedLanguage: widget.selectedLanguage,
            size: 26,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: CircleAvatar(
              backgroundColor: Color(0xFFE3EDF4),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF5B7C99),
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================
            // TODAY CARD
            // =================================================

            Text(
  appText(
    english: 'What would you like to do?',
    hindi: 'आप क्या करना चाहेंगे?',
    marathi: 'तुम्हाला काय करायचे आहे?',
    gujarati: 'તમે શું કરવા માંગો છો?',
    telugu: 'మీరు ఏమి చేయాలనుకుంటున్నారు?',
    tamil: 'நீங்கள் என்ன செய்ய விரும்புகிறீர்கள்?',
    bengali: 'আপনি কী করতে চান?',
    kannada: 'ನೀವು ಏನು ಮಾಡಲು ಬಯಸುತ್ತೀರಿ?',
    malayalam: 'നിങ്ങൾ എന്താണ് ചെയ്യാൻ ആഗ്രഹിക്കുന്നത്?',
    punjabi: 'ਤੁਸੀਂ ਕੀ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
    selectedLanguage: widget.selectedLanguage,
  ),
  style: const TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.bold,
    color: Color(0xFF263B4A),
  ),
),
            const SizedBox(height: 18),

            // =================================================
            // SERVICES
            // =================================================

            // =================================================
// UPCOMING REMINDER
// =================================================

// =================================================
// REMINDER BELL
// =================================================

if (widget.reminders.isNotEmpty) ...[
  GestureDetector(
    onTap: () {
      setState(() {
        _showReminders = !_showReminders;
      });
    },
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 5),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFC28B57).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 30,
              color: Color(0xFFC28B57),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              '${widget.reminders.length} ${appText(
                english: 'Reminders set',
                hindi: 'रिमाइंडर सेट हैं',
                marathi: 'स्मरणपत्रे सेट आहेत',
                gujarati: 'રિમાઇન્ડર્સ સેટ છે',
                telugu: 'రిమైండర్‌లు సెట్ చేయబడ్డాయి',
                tamil: 'நினைவூட்டல்கள் அமைக்கப்பட்டுள்ளன',
                bengali: 'রিমাইন্ডার সেট করা হয়েছে',
                kannada: 'ಜ್ಞಾಪನೆಗಳನ್ನು ಹೊಂದಿಸಲಾಗಿದೆ',
                malayalam: 'ഓർമ്മപ്പെടുത്തലുകൾ സജ്ജമാക്കി',
                punjabi: 'ਰਿਮਾਈਂਡਰ ਸੈੱਟ ਹਨ',
                selectedLanguage: widget.selectedLanguage,
              )}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF30485C),
              ),
            ),
          ),

          Icon(
            _showReminders
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 32,
            color: const Color(0xFF5B7C99),
          ),
        ],
      ),
    ),
  ),

  // =================================================
  // ALL REMINDERS
  // =================================================

  if (_showReminders)
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: widget.reminders.map((reminder) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  reminder.type == 'Medicine'
                      ? Icons.medication_rounded
                      : reminder.type == 'Health'
                          ? Icons.medical_services_rounded
                          : Icons.notifications_rounded,
                  color: const Color(0xFF5B7C99),
                  size: 28,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF30485C),
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        reminder.details,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF687780),
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '${reminder.dateTime.day}/${reminder.dateTime.month}/${reminder.dateTime.year} • ${TimeOfDay.fromDateTime(reminder.dateTime).format(context)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5B7C99),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ),
],

GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.80,
              children: [
                _serviceCard(
                  context,
                  Icons.emergency_rounded,
                  appText(
  english: 'Emergency',
  hindi: 'आपातकाल',
  marathi: 'आपत्कालीन मदत',
  gujarati: 'કટોકટી',
  telugu: 'అత్యవసరం',
  tamil: 'அவசரநிலை',
  bengali: 'জরুরি অবস্থা',
  kannada: 'ತುರ್ತು ಪರಿಸ್ಥಿತಿ',
  malayalam: 'അടിയന്തരാവസ്ഥ',
  punjabi: 'ਐਮਰਜੈਂਸੀ',
  selectedLanguage: widget.selectedLanguage,
),
                  const Color(0xFFD95C5C),
                  EmergencyPage(
  selectedLanguage: widget.selectedLanguage,
),
                ),

                _serviceCard(
  context,
  Icons.medication_rounded,
  appText(
    english: 'Medicines',
    hindi: 'दवाइयाँ',
    marathi: 'औषधे',
    gujarati: 'દવાઓ',
    telugu: 'మందులు',
    tamil: 'மருந்துகள்',
    bengali: 'ওষুধ',
    kannada: 'ಔಷಧಿಗಳು',
    malayalam: 'മരുന്നുകൾ',
    punjabi: 'ਦਵਾਈਆਂ',
    selectedLanguage: widget.selectedLanguage,
  ),
  const Color(0xFF6C9A7A),
  MedicinesPage(
    addReminder: widget.addReminder,
    selectedLanguage: widget.selectedLanguage,
  ),
),

                _serviceCard(
                  context,
                  Icons.medical_services_rounded,
                  appText(
  english: 'Health',
  hindi: 'स्वास्थ्य',
  marathi: 'आरोग्य',
  gujarati: 'આરોગ્ય',
  telugu: 'ఆరోగ్యం',
  tamil: 'உடல்நலம்',
  bengali: 'স্বাস্থ্য',
  kannada: 'ಆರೋಗ್ಯ',
  malayalam: 'ആരോഗ്യം',
  punjabi: 'ਸਿਹਤ',
  selectedLanguage: widget.selectedLanguage,
),
                  const Color(0xFF6B8EAD),
HealthPage(
  addReminder: widget.addReminder,
  selectedLanguage: widget.selectedLanguage,
)
                ),

                _serviceCard(
                  context,
                  Icons.family_restroom_rounded,
                  appText(
  english: 'Family',
  hindi: 'परिवार',
  marathi: 'कुटुंब',
  gujarati: 'પરિવાર',
  telugu: 'కుటుంబం',
  tamil: 'குடும்பம்',
  bengali: 'পরিবার',
  kannada: 'ಕುಟುಂಬ',
  malayalam: 'കുടുംബം',
  punjabi: 'ਪਰਿਵਾਰ',
  selectedLanguage: widget.selectedLanguage,
),
                  const Color(0xFFB4869F),
                  FamilyPage(
  addReminder: widget.addReminder,
  selectedLanguage: widget.selectedLanguage,
),
                ),

                _serviceCard(
                  context,
                  Icons.smartphone_rounded,
                  appText(
  english: 'Learn Apps',
  hindi: 'ऐप्स सीखें',
  marathi: 'अॅप्स शिका',
  gujarati: 'એપ્સ શીખો',
  telugu: 'యాప్‌లను నేర్చుకోండి',
  tamil: 'ஆப்களை கற்றுக்கொள்ளுங்கள்',
  bengali: 'অ্যাপ শিখুন',
  kannada: 'ಆ್ಯಪ್‌ಗಳನ್ನು ಕಲಿಯಿರಿ',
  malayalam: 'ആപ്പുകൾ പഠിക്കുക',
  punjabi: 'ਐਪਸ ਸਿੱਖੋ',
  selectedLanguage: widget.selectedLanguage,
),
                  const Color(0xFF8A7BA8),
AppLearningHubPage(
  selectedLanguage: widget.selectedLanguage,
),
                ),

                _serviceCard(
                  context,
                  Icons.notifications_rounded,
                  appText(
  english: 'My Reminders',
  hindi: 'मेरे रिमाइंडर',
  marathi: 'माझे स्मरणपत्र',
  gujarati: 'મારા રિમાઇન્ડર્સ',
  telugu: 'నా రిమైండర్లు',
  tamil: 'எனது நினைவூட்டல்கள்',
  bengali: 'আমার রিমাইন্ডার',
  kannada: 'ನನ್ನ ಜ್ಞಾಪನೆಗಳು',
  malayalam: 'എന്റെ ഓർമ്മപ്പെടുത്തലുകൾ',
  punjabi: 'ਮੇਰੇ ਰਿਮਾਈਂਡਰ',
  selectedLanguage: widget.selectedLanguage,
),
                  const Color(0xFFC28B57),
                  RemindersPage(
  reminders: widget.reminders,
  deleteReminder: widget.deleteReminder,
  editReminder: widget.editReminder,
  toggleTaken: widget.toggleTaken,
  selectedLanguage: widget.selectedLanguage,
),
               
                ),

                _serviceCard(
                  context,
                  Icons.location_on_rounded,
                  appText(
                    english: 'My Location',
                    hindi: 'मेरी लोकेशन',
                    marathi: 'माझे स्थान',
                    gujarati: 'મારું સ્થાન',
                    telugu: 'నా స్థానం',
                    tamil: 'எனது இருப்பிடம்',
                    bengali: 'আমার অবস্থান',
                    kannada: 'ನನ್ನ ಸ್ಥಳ',
                    malayalam: 'എന്റെ സ്ഥലം',
                    punjabi: 'ਮੇਰੀ ਲੋਕੇਸ਼ਨ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  const Color(0xFF5B7C99),
                  LocationTrackingPage(
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),
                

                _serviceCard(
                  context,
                  Icons.medical_services_rounded,
                  'Prescriptions',
                  const Color(0xFF6C9A7A),
                  PrescriptionsPage(
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),

                _serviceCard(
                  context,
                  Icons.description_rounded,
                  'Medical Reports',
                  const Color(0xFFC28B57),
                  MedicalReportsPage(
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),

              ],

            ),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
decoration: BoxDecoration(                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    size: 38,
                    color: Color(0xFF5B7C99),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        appText(
  english: 'Need help?',
  hindi: 'मदद चाहिए?',
  marathi: 'मदत हवी आहे?',
  gujarati: 'મદદ જોઈએ છે?',
  telugu: 'సహాయం కావాలా?',
  tamil: 'உதவி தேவையா?',
  bengali: 'সাহায্য দরকার?',
  kannada: 'ಸಹಾಯ ಬೇಕೇ?',
  malayalam: 'സഹായം വേണോ?',
  punjabi: 'ਮਦਦ ਚਾਹੀਦੀ ਹੈ?',
  selectedLanguage: widget.selectedLanguage,
),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF30485C),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
  appText(
    english: 'Senior Saathi can guide you step by step.',
    hindi: 'Senior Saathi आपको हर कदम पर मार्गदर्शन कर सकता है।',
    marathi: 'Senior Saathi तुम्हाला प्रत्येक पायरीवर मार्गदर्शन करू शकते.',
    gujarati: 'Senior Saathi તમને દરેક પગલે માર્ગદર્શન આપી શકે છે.',
    telugu: 'Senior Saathi మీకు ప్రతి దశలో మార్గనిర్దేశం చేయగలదు.',
    tamil: 'Senior Saathi உங்களுக்கு ஒவ்வொரு படியாகவும் வழிகாட்டும்.',
    bengali: 'Senior Saathi আপনাকে ধাপে ধাপে সাহায্য করতে পারে।',
    kannada: 'Senior Saathi ನಿಮಗೆ ಹಂತ ಹಂತವಾಗಿ ಮಾರ್ಗದರ್ಶನ ನೀಡಬಹುದು.',
    malayalam: 'Senior Saathi നിങ്ങളെ ഓരോ ഘട്ടത്തിലും നയിക്കും.',
    punjabi: 'Senior Saathi ਤੁਹਾਨੂੰ ਹਰ ਕਦਮ ਤੇ ਮਾਰਗਦਰਸ਼ਨ ਕਰ ਸਕਦਾ ਹੈ।',
    selectedLanguage: widget.selectedLanguage,
  ),
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF687780),
                          ),
                        ),
                      ],
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

  Widget _serviceCard(
    BuildContext context,
    IconData icon,
    String title,
    Color iconColor,
    Widget page,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => page,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 5),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF40596D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// SIMPLE PAGE
// =====================================================

class SimplePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const SimplePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF263B4A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: iconColor.withValues(alpha: 0.12),
                    child: Icon(
                      icon,
                      size: 45,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Color(0xFF687780),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

// =====================================================
// EMERGENCY
// =====================================================

class EmergencyPage extends StatefulWidget {
  final String selectedLanguage;

  const EmergencyPage({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  List<Map<String, String>> emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  // =====================================================
  // LOAD SAVED CONTACTS
  // =====================================================

  Future<void> _loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();

    final savedContacts = prefs.getStringList('emergency_contacts');

    if (savedContacts != null) {
      setState(() {
        emergencyContacts = savedContacts.map((contact) {
          final parts = contact.split('|');

          return {
            'name': parts.isNotEmpty ? parts[0] : '',
            'phone': parts.length > 1 ? parts[1] : '',
          };
        }).toList();
      });
    }
  }

  // =====================================================
  // SAVE CONTACTS
  // =====================================================

  Future<void> _saveEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();

    final contactList = emergencyContacts.map((contact) {
      return '${contact['name']}|${contact['phone']}';
    }).toList();

    await prefs.setStringList(
      'emergency_contacts',
      contactList,
    );
  }

  // =====================================================
  // MAKE PHONE CALL
  // =====================================================

  Future<void> _makeCall(
    BuildContext context,
    String number,
  ) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: number,
    );

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to open phone dialer for $number',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to make the call.'),
          ),
        );
      }
    }
  }

  // =====================================================
  // CONFIRM EMERGENCY CALL
  // =====================================================

  void _confirmCall(
  BuildContext context,
  String service,
  String number,
) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          '${appText(
            english: 'Call',
            hindi: 'कॉल करें',
            marathi: 'कॉल करा',
            gujarati: 'કૉલ કરો',
            telugu: 'కాల్ చేయాలా',
            tamil: 'அழைக்கவா',
            bengali: 'কল করবেন?',
            kannada: 'ಕರೆ ಮಾಡಬೇಕೆ?',
            malayalam: 'വിളിക്കണോ?',
            punjabi: 'ਕਾਲ ਕਰੋ?',
            selectedLanguage: widget.selectedLanguage,
          )} $service?',
        ),
        content: Text(
          '${appText(
            english: 'Do you want to call',
            hindi: 'क्या आप कॉल करना चाहते हैं',
            marathi: 'तुम्हाला कॉल करायचा आहे का',
            gujarati: 'શું તમે કૉલ કરવા માંગો છો',
            telugu: 'మీరు కాల్ చేయాలనుకుంటున్నారా',
            tamil: 'நீங்கள் அழைக்க விரும்புகிறீர்களா',
            bengali: 'আপনি কি কল করতে চান',
            kannada: 'ನೀವು ಕರೆ ಮಾಡಲು ಬಯಸುವಿರಾ',
            malayalam: 'നിങ്ങൾ വിളിക്കാൻ ആഗ്രഹിക്കുന്നുണ്ടോ',
            punjabi: 'ਕੀ ਤੁਸੀਂ ਕਾਲ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ',
            selectedLanguage: widget.selectedLanguage,
          )} $service $number?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              appText(
                english: 'CANCEL',
                hindi: 'रद्द करें',
                marathi: 'रद्द करा',
                gujarati: 'રદ કરો',
                telugu: 'రద్దు చేయండి',
                tamil: 'ரத்து செய்',
                bengali: 'বাতিল করুন',
                kannada: 'ರದ್ದುಮಾಡಿ',
                malayalam: 'റദ്ദാക്കുക',
                punjabi: 'ਰੱਦ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _makeCall(context, number);
            },
            child: Text(
              appText(
                english: 'CALL NOW',
                hindi: 'अभी कॉल करें',
                marathi: 'आता कॉल करा',
                gujarati: 'હમણાં કૉલ કરો',
                telugu: 'ఇప్పుడే కాల్ చేయండి',
                tamil: 'இப்போது அழைக்கவும்',
                bengali: 'এখনই কল করুন',
                kannada: 'ಈಗ ಕರೆ ಮಾಡಿ',
                malayalam: 'ഇപ്പോൾ വിളിക്കുക',
                punjabi: 'ਹੁਣੇ ਕਾਲ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),
        ],
      );
    },
  );
}
  // =====================================================
  // ADD / EDIT CONTACT
  // =====================================================

  void _showContactDialog(
  BuildContext context, {
  int? editIndex,
}) {
  final nameController = TextEditingController(
    text: editIndex != null
        ? emergencyContacts[editIndex]['name']
        : '',
  );

  final phoneController = TextEditingController(
    text: editIndex != null
        ? emergencyContacts[editIndex]['phone']
        : '',
  );

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          editIndex == null
              ? appText(
                  english: 'Add Emergency Contact',
                  hindi: 'आपातकालीन संपर्क जोड़ें',
                  marathi: 'आपत्कालीन संपर्क जोडा',
                  gujarati: 'કટોકટીનો સંપર્ક ઉમેરો',
                  telugu: 'అత్యవసర పరిచయాన్ని జోడించండి',
                  tamil: 'அவசர தொடர்பைச் சேர்க்கவும்',
                  bengali: 'জরুরি পরিচিতি যোগ করুন',
                  kannada: 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಸೇರಿಸಿ',
                  malayalam: 'അടിയന്തര കോൺടാക്റ്റ് ചേർക്കുക',
                  punjabi: 'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਸ਼ਾਮਲ ਕਰੋ',
                  selectedLanguage: widget.selectedLanguage,
                )
              : appText(
                  english: 'Edit Emergency Contact',
                  hindi: 'आपातकालीन संपर्क संपादित करें',
                  marathi: 'आपत्कालीन संपर्क संपादित करा',
                  gujarati: 'કટોકટીના સંપર્કમાં ફેરફાર કરો',
                  telugu: 'అత్యవసర పరిచయాన్ని సవరించండి',
                  tamil: 'அவசர தொடர்பைத் திருத்தவும்',
                  bengali: 'জরুরি পরিচিতি সম্পাদনা করুন',
                  kannada: 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಸಂಪಾದಿಸಿ',
                  malayalam: 'അടിയന്തര കോൺടാക്റ്റ് എഡിറ്റ് ചെയ്യുക',
                  punjabi: 'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਸੋਧੋ',
                  selectedLanguage: widget.selectedLanguage,
                ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: appText(
                    english: 'Name',
                    hindi: 'नाम',
                    marathi: 'नाव',
                    gujarati: 'નામ',
                    telugu: 'పేరు',
                    tamil: 'பெயர்',
                    bengali: 'নাম',
                    kannada: 'ಹೆಸರು',
                    malayalam: 'പേര്',
                    punjabi: 'ਨਾਮ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  hintText: appText(
                    english: 'Example: Daughter',
                    hindi: 'उदाहरण: बेटी',
                    marathi: 'उदाहरण: मुलगी',
                    gujarati: 'ઉદાહરણ: પુત્રી',
                    telugu: 'ఉదాహరణ: కుమార్తె',
                    tamil: 'உதாரணம்: மகள்',
                    bengali: 'উদাহরণ: মেয়ে',
                    kannada: 'ಉದಾಹರಣೆ: ಮಗಳು',
                    malayalam: 'ഉദാഹരണം: മകൾ',
                    punjabi: 'ਉਦਾਹਰਨ: ਧੀ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: appText(
                    english: 'Phone Number',
                    hindi: 'फ़ोन नंबर',
                    marathi: 'फोन नंबर',
                    gujarati: 'ફોન નંબર',
                    telugu: 'ఫోన్ నంబర్',
                    tamil: 'தொலைபேசி எண்',
                    bengali: 'ফোন নম্বর',
                    kannada: 'ಫೋನ್ ಸಂಖ್ಯೆ',
                    malayalam: 'ഫോൺ നമ്പർ',
                    punjabi: 'ਫੋਨ ਨੰਬਰ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  hintText: 'Example: 9876543210',
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              appText(
                english: 'CANCEL',
                hindi: 'रद्द करें',
                marathi: 'रद्द करा',
                gujarati: 'રદ કરો',
                telugu: 'రద్దు చేయండి',
                tamil: 'ரத்து செய்',
                bengali: 'বাতিল করুন',
                kannada: 'ರದ್ದುಮಾಡಿ',
                malayalam: 'റദ്ദാക്കുക',
                punjabi: 'ਰੱਦ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      appText(
                        english:
                            'Please enter both name and phone number.',
                        hindi:
                            'कृपया नाम और फोन नंबर दोनों दर्ज करें।',
                        marathi:
                            'कृपया नाव आणि फोन नंबर दोन्ही प्रविष्ट करा.',
                        gujarati:
                            'કૃપા કરીને નામ અને ફોન નંબર બંને દાખલ કરો.',
                        telugu:
                            'దయచేసి పేరు మరియు ఫోన్ నంబర్ రెండింటినీ నమోదు చేయండి.',
                        tamil:
                            'தயவுசெய்து பெயர் மற்றும் தொலைபேசி எண்ணை உள்ளிடவும்.',
                        bengali:
                            'অনুগ্রহ করে নাম এবং ফোন নম্বর দুটিই লিখুন।',
                        kannada:
                            'ದಯವಿಟ್ಟು ಹೆಸರು ಮತ್ತು ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.',
                        malayalam:
                            'ദയവായി പേരും ഫോൺ നമ്പറും നൽകുക.',
                        punjabi:
                            'ਕਿਰਪਾ ਕਰਕੇ ਨਾਮ ਅਤੇ ਫੋਨ ਨੰਬਰ ਦੋਵੇਂ ਦਰਜ ਕਰੋ।',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                );
                return;
              }

              if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      appText(
                        english:
                            'Please enter a valid 10-digit phone number.',
                        hindi:
                            'कृपया 10 अंकों का सही फोन नंबर दर्ज करें।',
                        marathi:
                            'कृपया 10 अंकी योग्य फोन नंबर प्रविष्ट करा.',
                        gujarati:
                            'કૃપા કરીને 10 અંકનો માન્ય ફોન નંબર દાખલ કરો.',
                        telugu:
                            'దయచేసి సరైన 10 అంకెల ఫోన్ నంబర్‌ను నమోదు చేయండి.',
                        tamil:
                            'சரியான 10 இலக்க தொலைபேசி எண்ணை உள்ளிடவும்.',
                        bengali:
                            'অনুগ্রহ করে একটি বৈধ ১০ সংখ্যার ফোন নম্বর লিখুন।',
                        kannada:
                            'ದಯವಿಟ್ಟು ಸರಿಯಾದ 10 ಅಂಕಿಯ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.',
                        malayalam:
                            'ദയവായി സാധുവായ 10 അക്ക ഫോൺ നമ്പർ നൽകുക.',
                        punjabi:
                            'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ 10 ਅੰਕਾਂ ਦਾ ਫੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ।',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                );
                return;
              }

              if (editIndex == null) {
                if (emergencyContacts.length >= 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        appText(
                          english:
                              'You can save a maximum of 4 emergency contacts.',
                          hindi:
                              'आप अधिकतम 4 आपातकालीन संपर्क सहेज सकते हैं।',
                          marathi:
                              'तुम्ही जास्तीत जास्त 4 आपत्कालीन संपर्क जतन करू शकता.',
                          gujarati:
                              'તમે વધુમાં વધુ 4 કટોકટી સંપર્કો સાચવી શકો છો.',
                          telugu:
                              'మీరు గరిష్టంగా 4 అత్యవసర పరిచయాలను సేవ్ చేయవచ్చు.',
                          tamil:
                              'நீங்கள் அதிகபட்சம் 4 அவசர தொடர்புகளைச் சேமிக்கலாம்.',
                          bengali:
                              'আপনি সর্বোচ্চ ৪টি জরুরি পরিচিতি সংরক্ষণ করতে পারেন।',
                          kannada:
                              'ನೀವು ಗರಿಷ್ಠ 4 ತುರ್ತು ಸಂಪರ್ಕಗಳನ್ನು ಉಳಿಸಬಹುದು.',
                          malayalam:
                              'നിങ്ങൾക്ക് പരമാവധി 4 അടിയന്തര കോൺടാക്റ്റുകൾ സേവ് ചെയ്യാം.',
                          punjabi:
                              'ਤੁਸੀਂ ਵੱਧ ਤੋਂ ਵੱਧ 4 ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਸੇਵ ਕਰ ਸਕਦੇ ਹੋ.',
                          selectedLanguage: widget.selectedLanguage,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                emergencyContacts.add({
                  'name': name,
                  'phone': phone,
                });
              } else {
                emergencyContacts[editIndex] = {
                  'name': name,
                  'phone': phone,
                };
              }

              await _saveEmergencyContacts();

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (mounted) {
                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      editIndex == null
                          ? appText(
                              english:
                                  'Emergency contact added successfully.',
                              hindi:
                                  'आपातकालीन संपर्क सफलतापूर्वक जोड़ा गया।',
                              marathi:
                                  'आपत्कालीन संपर्क यशस्वीरित्या जोडला गेला.',
                              gujarati:
                                  'કટોકટીનો સંપર્ક સફળતાપૂર્વક ઉમેરવામાં આવ્યો.',
                              telugu:
                                  'అత్యవసర పరిచయం విజయవంతంగా జోడించబడింది.',
                              tamil:
                                  'அவசர தொடர்பு வெற்றிகரமாக சேர்க்கப்பட்டது.',
                              bengali:
                                  'জরুরি পরিচিতি সফলভাবে যোগ করা হয়েছে।',
                              kannada:
                                  'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸೇರಿಸಲಾಗಿದೆ.',
                              malayalam:
                                  'അടിയന്തര കോൺടാക്റ്റ് വിജയകരമായി ചേർത്തു.',
                              punjabi:
                                  'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਸਫਲਤਾਪੂਰਵਕ ਸ਼ਾਮਲ ਕੀਤਾ ਗਿਆ।',
                              selectedLanguage: widget.selectedLanguage,
                            )
                          : appText(
                              english:
                                  'Emergency contact updated successfully.',
                              hindi:
                                  'आपातकालीन संपर्क सफलतापूर्वक अपडेट किया गया।',
                              marathi:
                                  'आपत्कालीन संपर्क यशस्वीरित्या अपडेट केला.',
                              gujarati:
                                  'કટોકટીનો સંપર્ક સફળતાપૂર્વક અપડેટ કરવામાં આવ્યો.',
                              telugu:
                                  'అత్యవసర పరిచయం విజయవంతంగా నవీకరించబడింది.',
                              tamil:
                                  'அவசர தொடர்பு வெற்றிகரமாக புதுப்பிக்கப்பட்டது.',
                              bengali:
                                  'জরুরি পরিচিতি সফলভাবে আপডেট করা হয়েছে।',
                              kannada:
                                  'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ನವೀಕರಿಸಲಾಗಿದೆ.',
                              malayalam:
                                  'അടിയന്തര കോൺടാക്റ്റ് വിജയകരമായി അപ്‌ഡേറ്റ് ചെയ്തു.',
                              punjabi:
                                  'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਸਫਲਤਾਪੂਰਵਕ ਅੱਪਡੇਟ ਕੀਤਾ ਗਿਆ।',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                    ),
                  ),
                );
              }
            },
            child: Text(
              editIndex == null
                  ? appText(
                      english: 'ADD CONTACT',
                      hindi: 'संपर्क जोड़ें',
                      marathi: 'संपर्क जोडा',
                      gujarati: 'સંપર્ક ઉમેરો',
                      telugu: 'పరిచయాన్ని జోడించండి',
                      tamil: 'தொடர்பைச் சேர்க்கவும்',
                      bengali: 'পরিচিতি যোগ করুন',
                      kannada: 'ಸಂಪರ್ಕವನ್ನು ಸೇರಿಸಿ',
                      malayalam: 'കോൺടാക്റ്റ് ചേർക്കുക',
                      punjabi: 'ਸੰਪਰਕ ਸ਼ਾਮਲ ਕਰੋ',
                      selectedLanguage: widget.selectedLanguage,
                    )
                  : appText(
                      english: 'SAVE CHANGES',
                      hindi: 'परिवर्तन सहेजें',
                      marathi: 'बदल जतन करा',
                      gujarati: 'ફેરફારો સાચવો',
                      telugu: 'మార్పులను సేవ్ చేయండి',
                      tamil: 'மாற்றங்களைச் சேமிக்கவும்',
                      bengali: 'পরিবর্তনগুলি সংরক্ষণ করুন',
                      kannada: 'ಬದಲಾವಣೆಗಳನ್ನು ಉಳಿಸಿ',
                      malayalam: 'മാറ്റങ്ങൾ സേവ് ചെയ്യുക',
                      punjabi: 'ਤਬਦੀਲੀਆਂ ਸੇਵ ਕਰੋ',
                      selectedLanguage: widget.selectedLanguage,
                    ),
            ),
          ),
        ],
      );
    },
  );
}
  // =====================================================
  // DELETE CONTACT
  // =====================================================

void _deleteContact(int index) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          appText(
            english: 'Delete Contact?',
            hindi: 'संपर्क हटाएं?',
            marathi: 'संपर्क हटवायचा आहे का?',
            gujarati: 'સંપર્ક કાઢી નાખવો છે?',
            telugu: 'పరిచయాన్ని తొలగించాలా?',
            tamil: 'தொடர்பை நீக்கவா?',
            bengali: 'পরিচিতি মুছবেন?',
            kannada: 'ಸಂಪರ್ಕವನ್ನು ಅಳಿಸಬೇಕೆ?',
            malayalam: 'കോൺടാക്റ്റ് ഇല്ലാതാക്കണോ?',
            punjabi: 'ਸੰਪਰਕ ਮਿਟਾਉਣਾ ਹੈ?',
            selectedLanguage: widget.selectedLanguage,
          ),
        ),
        content: Text(
          appText(
            english:
                'Do you want to remove ${emergencyContacts[index]['name']} from emergency contacts?',
            hindi:
                'क्या आप ${emergencyContacts[index]['name']} को आपातकालीन संपर्कों से हटाना चाहते हैं?',
            marathi:
                'तुम्हाला ${emergencyContacts[index]['name']} यांना आपत्कालीन संपर्कांमधून हटवायचे आहे का?',
            gujarati:
                'શું તમે ${emergencyContacts[index]['name']} ને કટોકટીના સંપર્કોમાંથી દૂર કરવા માંગો છો?',
            telugu:
                'మీరు ${emergencyContacts[index]['name']}ని అత్యవసర పరిచయాల నుండి తొలగించాలనుకుంటున్నారా?',
            tamil:
                '${emergencyContacts[index]['name']} அவர்களை அவசர தொடர்புகளில் இருந்து நீக்க விரும்புகிறீர்களா?',
            bengali:
                'আপনি কি ${emergencyContacts[index]['name']} কে জরুরি পরিচিতি থেকে সরাতে চান?',
            kannada:
                'ನೀವು ${emergencyContacts[index]['name']} ಅವರನ್ನು ತುರ್ತು ಸಂಪರ್ಕಗಳಿಂದ ತೆಗೆದುಹಾಕಲು ಬಯಸುತ್ತೀರಾ?',
            malayalam:
                '${emergencyContacts[index]['name']} എന്ന കോൺടാക്റ്റിനെ അടിയന്തര കോൺടാക്റ്റുകളിൽ നിന്ന് നീക്കം ചെയ്യണോ?',
            punjabi:
                'ਕੀ ਤੁਸੀਂ ${emergencyContacts[index]['name']} ਨੂੰ ਐਮਰਜੈਂਸੀ ਸੰਪਰਕਾਂ ਤੋਂ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
            selectedLanguage: widget.selectedLanguage,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              appText(
                english: 'CANCEL',
                hindi: 'रद्द करें',
                marathi: 'रद्द करा',
                gujarati: 'રદ કરો',
                telugu: 'రద్దు చేయండి',
                tamil: 'ரத்து செய்',
                bengali: 'বাতিল করুন',
                kannada: 'ರದ್ದುಮಾಡಿ',
                malayalam: 'റദ്ദാക്കുക',
                punjabi: 'ਰੱਦ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              emergencyContacts.removeAt(index);

              await _saveEmergencyContacts();

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (mounted) {
                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      appText(
                        english: 'Emergency contact deleted.',
                        hindi: 'आपातकालीन संपर्क हटा दिया गया।',
                        marathi: 'आपत्कालीन संपर्क हटवला गेला.',
                        gujarati: 'કટોકટીનો સંપર્ક કાઢી નાખવામાં આવ્યો.',
                        telugu: 'అత్యవసర పరిచయం తొలగించబడింది.',
                        tamil: 'அவசர தொடர்பு நீக்கப்பட்டது.',
                        bengali: 'জরুরি পরিচিতি মুছে ফেলা হয়েছে।',
                        kannada: 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಅಳಿಸಲಾಗಿದೆ.',
                        malayalam: 'അടിയന്തര കോൺടാക്റ്റ് ഇല്ലാതാക്കി.',
                        punjabi: 'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਮਿਟਾ ਦਿੱਤਾ ਗਿਆ।',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                );
              }
            },
            child: Text(
              appText(
                english: 'DELETE',
                hindi: 'हटाएं',
                marathi: 'हटवा',
                gujarati: 'કાઢી નાખો',
                telugu: 'తొలగించండి',
                tamil: 'நீக்கு',
                bengali: 'মুছুন',
                kannada: 'ಅಳಿಸಿ',
                malayalam: 'ഇല്ലാതാക്കുക',
                punjabi: 'ਮਿਟਾਓ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),
        ],
      );
    },
  );
}

  // =====================================================
  // EMERGENCY CONTACTS SECTION
  // =====================================================

  Widget _emergencyContactsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (emergencyContacts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFFF1F5F2),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.contact_phone_rounded,
                  size: 50,
                  color: Color(0xFF6C9A7A),
                ),
                SizedBox(height: 10),
                Text(
  appText(
    english: 'No emergency contacts added',
    hindi: 'कोई आपातकालीन संपर्क नहीं जोड़ा गया है',
    marathi: 'कोणतेही आपत्कालीन संपर्क जोडलेले नाहीत',
    gujarati: 'કોઈ કટોકટી સંપર્ક ઉમેરવામાં આવ્યો નથી',
    telugu: 'ఎటువంటి అత్యవసర పరిచయాలు జోడించబడలేదు',
    tamil: 'அவசர தொடர்புகள் எதுவும் சேர்க்கப்படவில்லை',
    bengali: 'কোনো জরুরি পরিচিতি যোগ করা হয়নি',
    kannada: 'ಯಾವುದೇ ತುರ್ತು ಸಂಪರ್ಕಗಳನ್ನು ಸೇರಿಸಲಾಗಿಲ್ಲ',
    malayalam: 'അടിയന്തര കോൺടാക്റ്റുകളൊന്നും ചേർത്തിട്ടില്ല',
    punjabi: 'ਕੋਈ ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਸ਼ਾਮਲ ਨਹੀਂ ਕੀਤਾ ਗਿਆ',
    selectedLanguage: widget.selectedLanguage,
  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
  appText(
    english: 'Add family members or trusted people who can help you during an emergency.',
    hindi: 'परिवार के सदस्यों या भरोसेमंद लोगों को जोड़ें जो आपातकाल में आपकी मदद कर सकें।',
    marathi: 'आपत्कालीन परिस्थितीत मदत करू शकतील असे कुटुंबातील सदस्य किंवा विश्वासू लोक जोडा.',
    gujarati: 'કટોકટી દરમિયાન તમારી મદદ કરી શકે તેવા પરિવારના સભ્યો અથવા વિશ્વાસુ લોકોને ઉમેરો.',
    telugu: 'అత్యవసర సమయంలో మీకు సహాయం చేయగల కుటుంబ సభ్యులను లేదా నమ్మకమైన వ్యక్తులను జోడించండి.',
    tamil: 'அவசர நேரத்தில் உங்களுக்கு உதவக்கூடிய குடும்ப உறுப்பினர்கள் அல்லது நம்பகமானவர்களைச் சேர்க்கவும்.',
    bengali: 'জরুরি অবস্থায় আপনাকে সাহায্য করতে পারেন এমন পরিবারের সদস্য বা বিশ্বস্ত ব্যক্তিদের যোগ করুন।',
    kannada: 'ತುರ್ತು ಸಂದರ್ಭದಲ್ಲಿ ನಿಮಗೆ ಸಹಾಯ ಮಾಡಬಹುದಾದ ಕುಟುಂಬದ ಸದಸ್ಯರು ಅಥವಾ ವಿಶ್ವಾಸಾರ್ಹ ವ್ಯಕ್ತಿಗಳನ್ನು ಸೇರಿಸಿ.',
    malayalam: 'അടിയന്തര സാഹചര്യത്തിൽ നിങ്ങളെ സഹായിക്കാൻ കഴിയുന്ന കുടുംബാംഗങ്ങളെയോ വിശ്വസ്തരായ ആളുകളെയോ ചേർക്കുക.',
    punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰਾਂ ਜਾਂ ਭਰੋਸੇਯੋਗ ਲੋਕਾਂ ਨੂੰ ਸ਼ਾਮਲ ਕਰੋ ਜੋ ਐਮਰਜੈਂਸੀ ਦੌਰਾਨ ਤੁਹਾਡੀ ਮਦਦ ਕਰ ਸਕਣ।',
    selectedLanguage: widget.selectedLanguage,
  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

        if (emergencyContacts.isNotEmpty)
          ...List.generate(
            emergencyContacts.length,
            (index) {
              final contact = emergencyContacts[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF6C9A7A),
                        child: Text(
                          contact['name']!.isNotEmpty
                              ? contact['name']![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact['name']!,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              contact['phone']!,
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
tooltip: appText(
  english: 'Call',
  hindi: 'कॉल करें',
  marathi: 'कॉल करा',
  gujarati: 'કૉલ કરો',
  telugu: 'కాల్ చేయండి',
  tamil: 'அழைக்கவும்',
  bengali: 'কল করুন',
  kannada: 'ಕರೆ ಮಾಡಿ',
  malayalam: 'വിളിക്കുക',
  punjabi: 'ਕਾਲ ਕਰੋ',
  selectedLanguage: widget.selectedLanguage,
),                        icon: const Icon(
                          Icons.call_rounded,
                          size: 28,
                        ),
                        onPressed: () {
                          _confirmCall(
                            context,
                            contact['name']!,
                            contact['phone']!,
                          );
                        },
                      ),

                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showContactDialog(
                              context,
                              editIndex: index,
                            );
                          } else if (value == 'delete') {
                            _deleteContact(index);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 10),
                                Text(
                                appText(
    english: 'Edit',
    hindi: 'संपादित करें',
    marathi: 'संपादित करा',
    gujarati: 'ફેરફાર કરો',
    telugu: 'సవరించండి',
    tamil: 'திருத்தவும்',
    bengali: 'সম্পাদনা করুন',
    kannada: 'ಸಂಪಾದಿಸಿ',
    malayalam: 'എഡിറ്റ് ചെയ്യുക',
    punjabi: 'ਸੋਧੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
),                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete),
                                SizedBox(width: 10),
                                Text(
                                 appText(
    english: 'Delete',
    hindi: 'हटाएं',
    marathi: 'हटवा',
    gujarati: 'કાઢી નાખો',
    telugu: 'తొలగించండి',
    tamil: 'நீக்கவும்',
    bengali: 'মুছে ফেলুন',
    kannada: 'ಅಳಿಸಿ',
    malayalam: 'ഇല്ലാതാക്കുക',
    punjabi: 'ਮਿਟਾਓ',
    selectedLanguage: widget.selectedLanguage,
  ),
),                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 8),

        if (emergencyContacts.length < 4)
          OutlinedButton.icon(
            onPressed: () {
              _showContactDialog(context);
            },
            icon: const Icon(Icons.add),
            label: Text(
  appText(
    english: 'ADD EMERGENCY CONTACT',
    hindi: 'आपातकालीन संपर्क जोड़ें',
    marathi: 'आपत्कालीन संपर्क जोडा',
    gujarati: 'કટોકટીનો સંપર્ક ઉમેરો',
    telugu: 'అత్యవసర పరిచయాన్ని జోడించండి',
    tamil: 'அவசர தொடர்பைச் சேர்க்கவும்',
    bengali: 'জরুরি পরিচিতি যোগ করুন',
    kannada: 'ತುರ್ತು ಸಂಪರ್ಕವನ್ನು ಸೇರಿಸಿ',
    malayalam: 'അടിയന്തര കോൺടാക്റ്റ് ചേർക്കുക',
    punjabi: 'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ ਸ਼ਾਮਲ ਕਰੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
),
          ),

        if (emergencyContacts.length >= 4)
           Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
  appText(
    english: 'You have reached the maximum of 4 emergency contacts.',
    hindi: 'आप 4 आपातकालीन संपर्कों की अधिकतम सीमा तक पहुंच गए हैं।',
    marathi: 'तुम्ही 4 आपत्कालीन संपर्कांची कमाल मर्यादा गाठली आहे.',
    gujarati: 'તમે 4 કટોકટી સંપર્કોની મહત્તમ મર્યાદા સુધી પહોંચી ગયા છો.',
    telugu: 'మీరు గరిష్టంగా 4 అత్యవసర పరిచయాల పరిమితిని చేరుకున్నారు.',
    tamil: 'நீங்கள் அதிகபட்சமாக 4 அவசர தொடர்புகளின் வரம்பை அடைந்துவிட்டீர்கள்.',
    bengali: 'আপনি সর্বোচ্চ ৪টি জরুরি পরিচিতির সীমায় পৌঁছেছেন।',
    kannada: 'ನೀವು ಗರಿಷ್ಠ 4 ತುರ್ತು ಸಂಪರ್ಕಗಳ ಮಿತಿಯನ್ನು ತಲುಪಿದ್ದೀರಿ.',
    malayalam: 'നിങ്ങൾ പരമാവധി 4 അടിയന്തര കോൺടാക്റ്റുകളുടെ പരിധിയിലെത്തി.',
    punjabi: 'ਤੁਸੀਂ 4 ਐਮਰਜੈਂਸੀ ਸੰਪਰਕਾਂ ਦੀ ਵੱਧ ਤੋਂ ਵੱਧ ਸੀਮਾ ਤੱਕ ਪਹੁੰਚ ਗਏ ਹੋ.',
    selectedLanguage: widget.selectedLanguage,
  ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: appText(
  english: 'Emergency Help',
  hindi: 'आपातकालीन सहायता',
  marathi: 'आपत्कालीन मदत',
  gujarati: 'કટોકટીમાં મદદ',
  telugu: 'అత్యవసర సహాయం',
  tamil: 'அவசர உதவி',
  bengali: 'জরুরি সহায়তা',
  kannada: 'ತುರ್ತು ಸಹಾಯ',
  malayalam: 'അടിയന്തര സഹായം',
  punjabi: 'ਐਮਰਜੈਂਸੀ ਸਹਾਇਤਾ',
  selectedLanguage: widget.selectedLanguage,
),
      subtitle: appText(
  english: 'Get help quickly when you need it.',
  hindi: 'जब जरूरत हो तब जल्दी मदद पाएं।',
  marathi: 'गरज असताना लवकर मदत मिळवा.',
  gujarati: 'જ્યારે જરૂર હોય ત્યારે ઝડપથી મદદ મેળવો.',
  telugu: 'మీకు అవసరమైనప్పుడు త్వరగా సహాయం పొందండి.',
  tamil: 'தேவைப்படும் போது விரைவாக உதவி பெறுங்கள்.',
  bengali: 'প্রয়োজনের সময় দ্রুত সাহায্য পান।',
  kannada: 'ಅಗತ್ಯವಿದ್ದಾಗ ತ್ವರಿತವಾಗಿ ಸಹಾಯ ಪಡೆಯಿರಿ.',
  malayalam: 'ആവശ്യമുള്ളപ്പോൾ വേഗത്തിൽ സഹായം നേടുക.',
  punjabi: 'ਜਦੋਂ ਲੋੜ ਹੋਵੇ ਤਾਂ ਜਲਦੀ ਮਦਦ ਪ੍ਰਾਪਤ ਕਰੋ।',
  selectedLanguage: widget.selectedLanguage,
),
      icon: Icons.emergency_rounded,
      iconColor: const Color(0xFFD95C5C),
      children: [
        // AMBULANCE
        _bigActionCard(
          context,
          Icons.local_hospital_rounded,
          appText(
  english: 'Ambulance',
  hindi: 'एम्बुलेंस',
  marathi: 'रुग्णवाहिका',
  gujarati: 'એમ્બ્યુલન્સ',
  telugu: 'అంబులెన్స్',
  tamil: 'ஆம்புலன்ஸ்',
  bengali: 'অ্যাম্বুলেন্স',
  kannada: 'ಆಂಬ್ಯುಲೆನ್ಸ್',
  malayalam: 'ആംബുലൻസ്',
  punjabi: 'ਐਂਬੂਲੈਂਸ',
  selectedLanguage: widget.selectedLanguage,
),

appText(
  english: 'Call for medical emergency',
  hindi: 'चिकित्सा आपातकाल के लिए कॉल करें',
  marathi: 'वैद्यकीय आपत्कालासाठी कॉल करा',
  gujarati: 'તબીબી કટોકટી માટે કૉલ કરો',
  telugu: 'వైద్య అత్యవసర పరిస్థితికి కాల్ చేయండి',
  tamil: 'மருத்துவ அவசரநிலைக்கு அழைக்கவும்',
  bengali: 'চিকিৎসা জরুরি অবস্থার জন্য কল করুন',
  kannada: 'ವೈದ್ಯಕೀಯ ತುರ್ತು ಪರಿಸ್ಥಿತಿಗೆ ಕರೆ ಮಾಡಿ',
  malayalam: 'മെഡിക്കൽ അടിയന്തരാവസ്ഥയ്ക്ക് വിളിക്കുക',
  punjabi: 'ਮੈਡੀਕਲ ਐਮਰਜੈਂਸੀ ਲਈ ਕਾਲ ਕਰੋ',
  selectedLanguage: widget.selectedLanguage,
),
          const Color(0xFFD95C5C),
          onTap: () {
            _confirmCall(
              context,
              'Ambulance',
              '108',
            );
          },
        ),

        // POLICE
        _bigActionCard(
          context,
          Icons.local_police_rounded,
          appText(
  english: 'Police',
  hindi: 'पुलिस',
  marathi: 'पोलीस',
  gujarati: 'પોલીસ',
  telugu: 'పోలీసులు',
  tamil: 'காவல்துறை',
  bengali: 'পুলিশ',
  kannada: 'ಪೊಲೀಸ್',
  malayalam: 'പോലീസ്',
  punjabi: 'ਪੁਲਿਸ',
  selectedLanguage: widget.selectedLanguage,
),

appText(
  english: 'Get police assistance',
  hindi: 'पुलिस की सहायता प्राप्त करें',
  marathi: 'पोलीसांची मदत मिळवा',
  gujarati: 'પોલીસની મદદ મેળવો',
  telugu: 'పోలీసుల సహాయం పొందండి',
  tamil: 'காவல்துறை உதவியைப் பெறுங்கள்',
  bengali: 'পুলিশের সাহায্য নিন',
  kannada: 'ಪೊಲೀಸರ ಸಹಾಯ ಪಡೆಯಿರಿ',
  malayalam: 'പോലീസ് സഹായം നേടുക',
  punjabi: 'ਪੁਲਿਸ ਦੀ ਮਦਦ ਪ੍ਰਾਪਤ ਕਰੋ',
  selectedLanguage: widget.selectedLanguage,
),
          const Color(0xFF5B7C99),
          onTap: () {
            _confirmCall(
              context,
              'Police',
              '112',
            );
          },
        ),

        // FIRE BRIGADE
        _bigActionCard(
          context,
          Icons.local_fire_department_rounded,
          appText(
  english: 'Fire Brigade',
  hindi: 'दमकल विभाग',
  marathi: 'अग्निशमन दल',
  gujarati: 'ફાયર બ્રિગેડ',
  telugu: 'అగ్నిమాపక దళం',
  tamil: 'தீயணைப்புப் படை',
  bengali: 'দমকল বাহিনী',
  kannada: 'ಅಗ್ನಿಶಾಮಕ ದಳ',
  malayalam: 'അഗ്നിശമന സേന',
  punjabi: 'ਫਾਇਰ ਬ੍ਰਿਗੇਡ',
  selectedLanguage: widget.selectedLanguage,
),

appText(
  english: 'Report a fire emergency',
  hindi: 'आग लगने की आपात स्थिति की सूचना दें',
  marathi: 'आगीच्या आपत्कालाची माहिती द्या',
  gujarati: 'આગની કટોકટીની જાણ કરો',
  telugu: 'అగ్ని ప్రమాదాన్ని నివేదించండి',
  tamil: 'தீ விபத்தைப் பற்றி தெரிவிக்கவும்',
  bengali: 'অগ্নিকাণ্ডের জরুরি পরিস্থিতির খবর দিন',
  kannada: 'ಅಗ್ನಿ ತುರ್ತು ಪರಿಸ್ಥಿತಿಯನ್ನು ವರದಿ ಮಾಡಿ',
  malayalam: 'തീപിടിത്ത അടിയന്തരാവസ്ഥ റിപ്പോർട്ട് ചെയ്യുക',
  punjabi: 'ਅੱਗ ਦੀ ਐਮਰਜੈਂਸੀ ਦੀ ਸੂਚਨਾ ਦਿਓ',
  selectedLanguage: widget.selectedLanguage,
),
          const Color(0xFFC56A3D),
          onTap: () {
            _confirmCall(
              context,
              'Fire Brigade',
              '101',
            );
          },
        ),

        const SizedBox(height: 10),

        // EMERGENCY CONTACTS
       _bigActionCard(
  context,
  Icons.contact_phone_rounded,

  appText(
    english: 'Emergency Contacts',
    hindi: 'आपातकालीन संपर्क',
    marathi: 'आपत्कालीन संपर्क',
    gujarati: 'કટોકટીના સંપર્કો',
    telugu: 'అత్యవసర పరిచయాలు',
    tamil: 'அவசர தொடர்புகள்',
    bengali: 'জরুরি পরিচিতি',
    kannada: 'ತುರ್ತು ಸಂಪರ್ಕಗಳು',
    malayalam: 'അടിയന്തര കോൺടാക്റ്റുകൾ',
    punjabi: 'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ',
    selectedLanguage: widget.selectedLanguage,
  ),

  emergencyContacts.isEmpty
      ? appText(
          english: 'Add family members or trusted people',
          hindi: 'परिवार के सदस्यों या भरोसेमंद लोगों को जोड़ें',
          marathi: 'कुटुंबातील सदस्य किंवा विश्वासू लोक जोडा',
          gujarati: 'પરિવારના સભ્યો અથવા વિશ્વાસુ લોકોને ઉમેરો',
          telugu: 'కుటుంబ సభ్యులు లేదా నమ్మకమైన వ్యక్తులను జోడించండి',
          tamil: 'குடும்ப உறுப்பினர்கள் அல்லது நம்பகமானவர்களைச் சேர்க்கவும்',
          bengali: 'পরিবারের সদস্য বা বিশ্বস্ত ব্যক্তিদের যোগ করুন',
          kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರು ಅಥವಾ ವಿಶ್ವಾಸಾರ್ಹ ವ್ಯಕ್ತಿಗಳನ್ನು ಸೇರಿಸಿ',
          malayalam: 'കുടുംബാംഗങ്ങളെയോ വിശ്വസ്തരായ ആളുകളെയോ ചേർക്കുക',
          punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰਾਂ ਜਾਂ ਭਰੋਸੇਯੋਗ ਲੋਕਾਂ ਨੂੰ ਸ਼ਾਮਲ ਕਰੋ',
          selectedLanguage: widget.selectedLanguage,
        )
      : appText(
          english:
              '${emergencyContacts.length} contact${emergencyContacts.length == 1 ? '' : 's'} saved',
          hindi:
              '${emergencyContacts.length} संपर्क सहेजे गए',
          marathi:
              '${emergencyContacts.length} संपर्क जतन केले',
          gujarati:
              '${emergencyContacts.length} સંપર્કો સાચવવામાં આવ્યા',
          telugu:
              '${emergencyContacts.length} పరిచయాలు సేవ్ చేయబడ్డాయి',
          tamil:
              '${emergencyContacts.length} தொடர்புகள் சேமிக்கப்பட்டன',
          bengali:
              '${emergencyContacts.length}টি পরিচিতি সংরক্ষিত হয়েছে',
          kannada:
              '${emergencyContacts.length} ಸಂಪರ್ಕಗಳನ್ನು ಉಳಿಸಲಾಗಿದೆ',
          malayalam:
              '${emergencyContacts.length} കോൺടാക്റ്റുകൾ സേവ് ചെയ്തു',
          punjabi:
              '${emergencyContacts.length} ਸੰਪਰਕ ਸੇਵ ਕੀਤੇ ਗਏ',
          selectedLanguage: widget.selectedLanguage,
        ),

  const Color(0xFF6C9A7A),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (sheetContext) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
  appText(
    english: 'Emergency Contacts',
    hindi: 'आपातकालीन संपर्क',
    marathi: 'आपत्कालीन संपर्क',
    gujarati: 'કટોકટીના સંપર્કો',
    telugu: 'అత్యవసర పరిచయాలు',
    tamil: 'அவசர தொடர்புகள்',
    bengali: 'জরুরি পরিচিতি',
    kannada: 'ತುರ್ತು ಸಂಪರ್ಕಗಳು',
    malayalam: 'അടിയന്തര കോൺടാക്റ്റുകൾ',
    punjabi: 'ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ',
    selectedLanguage: widget.selectedLanguage,
  ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
  appText(
    english: 'You can save up to 4 people.',
    hindi: 'आप अधिकतम 4 लोगों को सहेज सकते हैं।',
    marathi: 'तुम्ही जास्तीत जास्त 4 लोकांना जतन करू शकता.',
    gujarati: 'તમે વધુમાં વધુ 4 લોકોને સાચવી શકો છો.',
    telugu: 'మీరు గరిష్టంగా 4 మందిని సేవ్ చేయవచ్చు.',
    tamil: 'நீங்கள் அதிகபட்சம் 4 பேரைச் சேமிக்கலாம்.',
    bengali: 'আপনি সর্বোচ্চ ৪ জনকে সংরক্ষণ করতে পারেন।',
    kannada: 'ನೀವು ಗರಿಷ್ಠ 4 ಜನರನ್ನು ಉಳಿಸಬಹುದು.',
    malayalam: 'നിങ്ങൾക്ക് പരമാവധി 4 പേരെ സേവ് ചെയ്യാം.',
    punjabi: 'ਤੁਸੀਂ ਵੱਧ ਤੋਂ ਵੱਧ 4 ਲੋਕਾਂ ਨੂੰ ਸੇਵ ਕਰ ਸਕਦੇ ਹੋ.',
    selectedLanguage: widget.selectedLanguage,
  ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 20),

                          _emergencyContactsSection(
                            context,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}


// =====================================================
// MEDICINES
// =====================================================

class MedicinesPage extends StatelessWidget {
  final Function(Reminder) addReminder;
  final String selectedLanguage;

  const MedicinesPage({
    super.key,
    required this.addReminder,
    required this.selectedLanguage,
  });

  @override
Widget build(BuildContext context) {
  return SimplePage(
    title: appText(
      english: 'Medicines',
      hindi: 'दवाइयाँ',
      marathi: 'औषधे',
      gujarati: 'દવાઓ',
      telugu: 'మందులు',
      tamil: 'மருந்துகள்',
      bengali: 'ওষুধ',
      kannada: 'ಔಷಧಿಗಳು',
      malayalam: 'മരുന്നുകൾ',
      punjabi: 'ਦਵਾਈਆਂ',
      selectedLanguage: selectedLanguage,
    ),
    subtitle: appText(
      english: 'Keep track of your medicines and doses.',
      hindi: 'अपनी दवाइयों और खुराक का ध्यान रखें।',
      marathi: 'तुमच्या औषधांचा आणि डोसचा मागोवा ठेवा.',
      gujarati: 'તમારી દવાઓ અને ડોઝનો ટ્રૅક રાખો.',
      telugu: 'మీ మందులు మరియు మోతాదులను ట్రాక్ చేయండి.',
      tamil: 'உங்கள் மருந்துகள் மற்றும் அளவுகளைக் கண்காணிக்கவும்.',
      bengali: 'আপনার ওষুধ এবং ডোজের হিসাব রাখুন।',
      kannada: 'ನಿಮ್ಮ ಔಷಧಿಗಳು ಮತ್ತು ಪ್ರಮಾಣಗಳನ್ನು ಗಮನದಲ್ಲಿಡಿ.',
      malayalam: 'നിങ്ങളുടെ മരുന്നുകളും ഡോസുകളും ശ്രദ്ധിക്കുക.',
      punjabi: 'ਆਪਣੀਆਂ ਦਵਾਈਆਂ ਅਤੇ ਖੁਰਾਕਾਂ ਦਾ ਧਿਆਨ ਰੱਖੋ।',
      selectedLanguage: selectedLanguage,
    ),
    icon: Icons.medication_rounded,
    iconColor: const Color(0xFF6C9A7A),
    children: [
      _bigActionCard(
        context,
        Icons.add_circle_rounded,
        appText(
          english: 'Add Medicine',
          hindi: 'दवा जोड़ें',
          marathi: 'औषध जोडा',
          gujarati: 'દવા ઉમેરો',
          telugu: 'మందును జోడించండి',
          tamil: 'மருந்தைச் சேர்க்கவும்',
          bengali: 'ওষুধ যোগ করুন',
          kannada: 'ಔಷಧಿಯನ್ನು ಸೇರಿಸಿ',
          malayalam: 'മരുന്ന് ചേർക്കുക',
          punjabi: 'ਦਵਾਈ ਸ਼ਾਮਲ ਕਰੋ',
          selectedLanguage: selectedLanguage,
        ),
        appText(
          english: 'Add medicine name, dosage and time',
          hindi: 'दवा का नाम, खुराक और समय जोड़ें',
          marathi: 'औषधाचे नाव, डोस आणि वेळ जोडा',
          gujarati: 'દવાનું નામ, ડોઝ અને સમય ઉમેરો',
          telugu: 'మందు పేరు, మోతాదు మరియు సమయాన్ని జోడించండి',
          tamil: 'மருந்தின் பெயர், அளவு மற்றும் நேரத்தைச் சேர்க்கவும்',
          bengali: 'ওষুধের নাম, ডোজ এবং সময় যোগ করুন',
          kannada: 'ಔಷಧಿಯ ಹೆಸರು, ಪ್ರಮಾಣ ಮತ್ತು ಸಮಯವನ್ನು ಸೇರಿಸಿ',
          malayalam: 'മരുന്നിന്റെ പേര്, ഡോസ്, സമയം എന്നിവ ചേർക്കുക',
          punjabi: 'ਦਵਾਈ ਦਾ ਨਾਮ, ਖੁਰਾਕ ਅਤੇ ਸਮਾਂ ਸ਼ਾਮਲ ਕਰੋ',
          selectedLanguage: selectedLanguage,
        ),
        const Color(0xFF6C9A7A),
        onTap: () {
          _showMedicineDialog(context);
        },
      ),
      _infoCard(
        Icons.access_time_rounded,
        appText(
          english: 'Medicine Schedule',
          hindi: 'दवा का समय',
          marathi: 'औषध वेळापत्रक',
          gujarati: 'દવા સમયપત્રક',
          telugu: 'మందుల షెడ్యూల్',
          tamil: 'மருந்து அட்டவணை',
          bengali: 'ওষুধের সময়সূচি',
          kannada: 'ಔಷಧಿ ವೇಳಾಪಟ್ಟಿ',
          malayalam: 'മരുന്ന് ഷെഡ്യൂൾ',
          punjabi: 'ਦਵਾਈ ਦਾ ਸਮਾਂ-ਸੂਚੀ',
          selectedLanguage: selectedLanguage,
        ),
        appText(
          english: 'Your medicine reminders appear in My Reminders.',
          hindi: 'आपकी दवा की याद दिलाने वाली सूचनाएँ मेरे रिमाइंडर में दिखाई देंगी।',
          marathi: 'तुमचे औषध स्मरणपत्र माझ्या स्मरणपत्रांमध्ये दिसतील.',
          gujarati: 'તમારા દવાના રિમાઇન્ડર્સ મારા રિમાઇન્ડર્સમાં દેખાશે.',
          telugu: 'మీ మందుల రిమైండర్‌లు నా రిమైండర్‌లలో కనిపిస్తాయి.',
          tamil: 'உங்கள் மருந்து நினைவூட்டல்கள் என் நினைவூட்டல்களில் தோன்றும்.',
          bengali: 'আপনার ওষুধের রিমাইন্ডারগুলি আমার রিমাইন্ডারে দেখা যাবে।',
          kannada: 'ನಿಮ್ಮ ಔಷಧಿ ಜ್ಞಾಪನೆಗಳು ನನ್ನ ಜ್ಞಾಪನೆಗಳಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.',
          malayalam: 'നിങ്ങളുടെ മരുന്ന് റിമൈൻഡറുകൾ എന്റെ റിമൈൻഡറുകളിൽ കാണിക്കും.',
          punjabi: 'ਤੁਹਾਡੀਆਂ ਦਵਾਈਆਂ ਦੇ ਰਿਮਾਈਂਡਰ ਮੇਰੇ ਰਿਮਾਈਂਡਰਾਂ ਵਿੱਚ ਦਿਖਾਈ ਦੇਣਗੇ।',
          selectedLanguage: selectedLanguage,
        ),
        const Color(0xFF5B7C99),
      ),
    ],
  );
}

void _showMedicineDialog(BuildContext context) {
  final nameController = TextEditingController();
  final dosageController = TextEditingController();

  TimeOfDay selectedTime = TimeOfDay.now();

  // Scheduling
  String scheduleType = 'daily';
  Set<int> selectedDays = {};
  DateTime selectedDate = DateTime.now();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              appText(
                english: 'Add Medicine',
                hindi: 'दवा जोड़ें',
                marathi: 'औषध जोडा',
                gujarati: 'દવા ઉમેરો',
                telugu: 'మందును జోడించండి',
                tamil: 'மருந்தைச் சேர்க்கவும்',
                bengali: 'ওষুধ যোগ করুন',
                kannada: 'ಔಷಧಿಯನ್ನು ಸೇರಿಸಿ',
                malayalam: 'മരുന്ന് ചേർക്കുക',
                punjabi: 'ਦਵਾਈ ਸ਼ਾਮਲ ਕਰੋ',
                selectedLanguage: selectedLanguage,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: appText(
                        english: 'Medicine name',
                        hindi: 'दवा का नाम',
                        marathi: 'औषधाचे नाव',
                        gujarati: 'દવાનું નામ',
                        telugu: 'మందు పేరు',
                        tamil: 'மருந்தின் பெயர்',
                        bengali: 'ওষুধের নাম',
                        kannada: 'ಔಷಧಿಯ ಹೆಸರು',
                        malayalam: 'മരുന്നിന്റെ പേര്',
                        punjabi: 'ਦਵਾਈ ਦਾ ਨਾਮ',
                        selectedLanguage: selectedLanguage,
                      ),
                      prefixIcon: const Icon(Icons.medication_rounded),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: dosageController,
                    decoration: InputDecoration(
                      labelText: appText(
                        english: 'Dosage',
                        hindi: 'खुराक',
                        marathi: 'डोस',
                        gujarati: 'ડોઝ',
                        telugu: 'మోతాదు',
                        tamil: 'அளவு',
                        bengali: 'ডোজ',
                        kannada: 'ಪ್ರಮಾಣ',
                        malayalam: 'ഡോസ്',
                        punjabi: 'ਖੁਰਾਕ',
                        selectedLanguage: selectedLanguage,
                      ),
                      prefixIcon: const Icon(Icons.numbers_rounded),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // TIME
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: Text(
                      '${appText(
                        english: 'Time',
                        hindi: 'समय',
                        marathi: 'वेळ',
                        gujarati: 'સમય',
                        telugu: 'సమయం',
                        tamil: 'நேரம்',
                        bengali: 'সময়',
                        kannada: 'ಸಮಯ',
                        malayalam: 'സമയം',
                        punjabi: 'ਸਮਾਂ',
                        selectedLanguage: selectedLanguage,
                      )}: ${selectedTime.format(context)}',
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );

                      if (time != null) {
                        setDialogState(() {
                          selectedTime = time;
                        });
                      }
                    },
                  ),

                  const Divider(),

                  // REPEAT TITLE
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      appText(
                        english: 'Repeat',
                        hindi: 'दोहराएं',
                        marathi: 'पुन्हा',
                        gujarati: 'પુનરાવર્તન',
                        telugu: 'పునరావృతం',
                        tamil: 'மீண்டும்',
                        bengali: 'পুনরাবৃত্তি',
                        kannada: 'ಪುನರಾವರ್ತಿಸಿ',
                        malayalam: 'ആവർത്തിക്കുക',
                        punjabi: 'ਦੁਹਰਾਓ',
                        selectedLanguage: selectedLanguage,
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF30485C),
                      ),
                    ),
                  ),

                  // EVERY DAY
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'daily',
                    groupValue: scheduleType,
                    title: Text(
                      appText(
                        english: 'Every day',
                        hindi: 'हर दिन',
                        marathi: 'दररोज',
                        gujarati: 'દરરોજ',
                        telugu: 'ప్రతి రోజు',
                        tamil: 'தினமும்',
                        bengali: 'প্রতিদিন',
                        kannada: 'ಪ್ರತಿದಿನ',
                        malayalam: 'എല്ലാ ദിവസവും',
                        punjabi: 'ਹਰ ਰੋਜ਼',
                        selectedLanguage: selectedLanguage,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        scheduleType = value!;
                      });
                    },
                  ),

                  // SELECTED DAYS
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'selectedDays',
                    groupValue: scheduleType,
                    title: Text(
                      appText(
                        english: 'Selected days',
                        hindi: 'चुने हुए दिन',
                        marathi: 'निवडलेले दिवस',
                        gujarati: 'પસંદ કરેલા દિવસો',
                        telugu: 'ఎంచుకున్న రోజులు',
                        tamil: 'தேர்ந்தெடுத்த நாட்கள்',
                        bengali: 'নির্বাচিত দিন',
                        kannada: 'ಆಯ್ದ ದಿನಗಳು',
                        malayalam: 'തിരഞ്ഞെടുത്ത ദിവസങ്ങൾ',
                        punjabi: 'ਚੁਣੇ ਹੋਏ ਦਿਨ',
                        selectedLanguage: selectedLanguage,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        scheduleType = value!;
                      });
                    },
                  ),

                  // DAYS
                  if (scheduleType == 'selectedDays')
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        {'day': 1, 'label': 'Mon'},
                        {'day': 2, 'label': 'Tue'},
                        {'day': 3, 'label': 'Wed'},
                        {'day': 4, 'label': 'Thu'},
                        {'day': 5, 'label': 'Fri'},
                        {'day': 6, 'label': 'Sat'},
                        {'day': 7, 'label': 'Sun'},
                      ].map((item) {
                        final day = item['day'] as int;
                        final label = item['label'] as String;

                        return FilterChip(
                          label: Text(label),
                          selected: selectedDays.contains(day),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                  // ONCE
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'once',
                    groupValue: scheduleType,
                    title: Text(
                      appText(
                        english: 'Once on a particular date',
                        hindi: 'किसी खास तारीख को एक बार',
                        marathi: 'ठराविक तारखेला एकदा',
                        gujarati: 'ચોક્કસ તારીખે એકવાર',
                        telugu: 'నిర్దిష్ట తేదీన ఒకసారి',
                        tamil: 'குறிப்பிட்ட தேதியில் ஒருமுறை',
                        bengali: 'নির্দিষ্ট তারিখে একবার',
                        kannada: 'ನಿರ್ದಿಷ್ಟ ದಿನಾಂಕದಂದು ಒಮ್ಮೆ',
                        malayalam: 'ഒരു പ്രത്യേക തീയതിയിൽ ഒരിക്കൽ',
                        punjabi: 'ਕਿਸੇ ਖਾਸ ਤਾਰੀਖ ਨੂੰ ਇੱਕ ਵਾਰ',
                        selectedLanguage: selectedLanguage,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        scheduleType = value!;
                      });
                    },
                  ),

                  // DATE PICKER
                  if (scheduleType == 'once')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate.isBefore(DateTime.now())
                              ? DateTime.now()
                              : selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );

                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  appText(
                    english: 'Cancel',
                    hindi: 'रद्द करें',
                    marathi: 'रद्द करा',
                    gujarati: 'રદ કરો',
                    telugu: 'రద్దు చేయండి',
                    tamil: 'ரத்து செய்',
                    bengali: 'বাতিল করুন',
                    kannada: 'ರದ್ದುಮಾಡಿ',
                    malayalam: 'റദ്ദാക്കുക',
                    punjabi: 'ਰੱਦ ਕਰੋ',
                    selectedLanguage: selectedLanguage,
                  ),
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    return;
                  }

                  final now = DateTime.now();

                  DateTime reminderDate;

                  if (scheduleType == 'once') {
                    reminderDate = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                  } else {
                    reminderDate = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    if (reminderDate.isBefore(now)) {
                      reminderDate =
                          reminderDate.add(const Duration(days: 1));
                    }
                  }

                  addReminder(
                    Reminder(
                      title: nameController.text.trim(),
                      details:
                          '${appText(
                            english: 'Dosage',
                            hindi: 'खुराक',
                            marathi: 'डोस',
                            gujarati: 'ડોઝ',
                            telugu: 'మోతాదు',
                            tamil: 'அளவு',
                            bengali: 'ডোজ',
                            kannada: 'ಪ್ರಮಾಣ',
                            malayalam: 'ഡോസ്',
                            punjabi: 'ਖੁਰਾਕ',
                            selectedLanguage: selectedLanguage,
                          )}: ${dosageController.text.trim().isEmpty ? appText(
                            english: 'Not specified',
                            hindi: 'निर्दिष्ट नहीं',
                            marathi: 'नमूद केलेले नाही',
                            gujarati: 'ઉલ્લેખિત નથી',
                            telugu: 'పేర్కొనలేదు',
                            tamil: 'குறிப்பிடப்படவில்லை',
                            bengali: 'উল্লেখ করা হয়নি',
                            kannada: 'ನಿರ್ದಿಷ್ಟಪಡಿಸಲಾಗಿಲ್ಲ',
                            malayalam: 'വ്യക്തമാക്കിയിട്ടില്ല',
                            punjabi: 'ਨਿਰਧਾਰਤ ਨਹੀਂ',
                            selectedLanguage: selectedLanguage,
                          ) : dosageController.text.trim()}',
                      type: 'Medicine',
                      dateTime: reminderDate,

                      // Scheduling
                      scheduleType: scheduleType,
                      selectedDays: selectedDays.toList(),
                    ),
                  );

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        appText(
                          english: 'Medicine reminder added!',
                          hindi: 'दवा की याद दिलाने वाला रिमाइंडर जोड़ दिया गया!',
                          marathi: 'औषधाचे स्मरणपत्र जोडले गेले!',
                          gujarati: 'દવાનું રિમાઇન્ડર ઉમેરવામાં આવ્યું!',
                          telugu: 'మందుల రిమైండర్ జోడించబడింది!',
                          tamil: 'மருந்து நினைவூட்டல் சேர்க்கப்பட்டது!',
                          bengali: 'ওষুধের রিমাইন্ডার যোগ করা হয়েছে!',
                          kannada: 'ಔಷಧಿ ಜ್ಞಾಪನೆಯನ್ನು ಸೇರಿಸಲಾಗಿದೆ!',
                          malayalam: 'മരുന്ന് റിമൈൻഡർ ചേർത്തു!',
                          punjabi: 'ਦਵਾਈ ਦਾ ਰਿਮਾਈਂਡਰ ਸ਼ਾਮਲ ਕੀਤਾ ਗਿਆ!',
                          selectedLanguage: selectedLanguage,
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  appText(
                    english: 'Save',
                    hindi: 'सहेजें',
                    marathi: 'जतन करा',
                    gujarati: 'સાચવો',
                    telugu: 'సేవ్ చేయండి',
                    tamil: 'சேமிக்கவும்',
                    bengali: 'সংরক্ষণ করুন',
                    kannada: 'ಉಳಿಸಿ',
                    malayalam: 'സേവ് ചെയ്യുക',
                    punjabi: 'ਸੇਵ ਕਰੋ',
                    selectedLanguage: selectedLanguage,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
}

// =====================================================
// HEALTH
// =====================================================

class HealthPage extends StatefulWidget {
  final Function(Reminder) addReminder;
  final String selectedLanguage;

  const HealthPage({
    super.key,
    required this.addReminder,
    required this.selectedLanguage,
  });

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  Map<String, String>? doctorInfo;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
  }

  // =====================================================
  // LOAD DOCTOR INFORMATION
  // =====================================================

  Future<void> _loadDoctorInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDoctor = prefs.getString('doctor_info');

    if (savedDoctor != null) {
      final decoded = jsonDecode(savedDoctor);

      setState(() {
        doctorInfo = Map<String, String>.from(decoded);
      });
    }
  }

  // =====================================================
  // SAVE DOCTOR INFORMATION
  // =====================================================

  Future<void> _saveDoctorInfo(
    Map<String, String> doctor,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'doctor_info',
      jsonEncode(doctor),
    );

    setState(() {
      doctorInfo = doctor;
    });
  }

  // =====================================================
  // CALL DOCTOR
  // =====================================================

  Future<void> _callDoctor() async {
    if (doctorInfo == null) return;

    final phone = doctorInfo!['phone'] ?? '';

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
  content: Text(
    appText(
      english: 'Unable to open phone dialer.',
      hindi: 'फ़ोन डायलर खोलने में असमर्थ।',
      marathi: 'फोन डायलर उघडता येत नाही.',
      gujarati: 'ફોન ડાયલર ખોલી શકાયું નથી.',
      telugu: 'ఫోన్ డయలర్‌ను తెరవడం సాధ్యం కాలేదు.',
      tamil: 'தொலைபேசி டயலரைத் திறக்க முடியவில்லை.',
      bengali: 'ফোন ডায়লার খোলা যাচ্ছে না।',
      kannada: 'ಫೋನ್ ಡಯಲರ್ ತೆರೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
      malayalam: 'ഫോൺ ഡയലർ തുറക്കാൻ കഴിഞ്ഞില്ല.',
      punjabi: 'ਫ਼ੋਨ ਡਾਇਲਰ ਖੋਲ੍ਹਣ ਵਿੱਚ ਅਸਮਰੱਥ।',
      selectedLanguage: widget.selectedLanguage,
    ),
  ),
),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
  content: Text(
    appText(
      english: 'Unable to make the call.',
      hindi: 'कॉल करने में असमर्थ।',
      marathi: 'कॉल करता येत नाही.',
      gujarati: 'કૉલ કરી શકાયો નથી.',
      telugu: 'కాల్ చేయడం సాధ్యం కాలేదు.',
      tamil: 'அழைக்க முடியவில்லை.',
      bengali: 'কল করা যাচ্ছে না।',
      kannada: 'ಕರೆ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
      malayalam: 'വിളിക്കാൻ കഴിഞ്ഞില്ല.',
      punjabi: 'ਕਾਲ ਕਰਨ ਵਿੱਚ ਅਸਮਰੱਥ।',
      selectedLanguage: widget.selectedLanguage,
    ),
  ),
),
        );
      }
    }
  }

  // =====================================================
  // ADD / EDIT DOCTOR
  // =====================================================

  void _showDoctorDialog() {
    final nameController = TextEditingController(
      text: doctorInfo?['name'] ?? '',
    );

    final hospitalController = TextEditingController(
      text: doctorInfo?['hospital'] ?? '',
    );

    final specializationController = TextEditingController(
      text: doctorInfo?['specialization'] ?? '',
    );

    final phoneController = TextEditingController(
      text: doctorInfo?['phone'] ?? '',
    );

    final addressController = TextEditingController(
      text: doctorInfo?['address'] ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
title: Text(
  doctorInfo == null
      ? appText(
          english: 'Add My Doctor',
          hindi: 'मेरे डॉक्टर को जोड़ें',
          marathi: 'माझे डॉक्टर जोडा',
          gujarati: 'મારા ડૉક્ટરને ઉમેરો',
          telugu: 'నా డాక్టర్‌ను జోడించండి',
          tamil: 'எனது மருத்துவரைச் சேர்க்கவும்',
          bengali: 'আমার ডাক্তার যোগ করুন',
          kannada: 'ನನ್ನ ವೈದ್ಯರನ್ನು ಸೇರಿಸಿ',
          malayalam: 'എന്റെ ഡോക്ടറെ ചേർക്കുക',
          punjabi: 'ਮੇਰੇ ਡਾਕਟਰ ਨੂੰ ਸ਼ਾਮਲ ਕਰੋ',
          selectedLanguage: widget.selectedLanguage,
        )
      : appText(
          english: 'Edit Doctor Information',
          hindi: 'डॉक्टर की जानकारी संपादित करें',
          marathi: 'डॉक्टरची माहिती संपादित करा',
          gujarati: 'ડૉક્ટરની માહિતી સંપાદિત કરો',
          telugu: 'డాక్టర్ సమాచారాన్ని సవరించండి',
          tamil: 'மருத்துவர் தகவலைத் திருத்தவும்',
          bengali: 'ডাক্তারের তথ্য সম্পাদনা করুন',
          kannada: 'ವೈದ್ಯರ ಮಾಹಿತಿಯನ್ನು ಸಂಪಾದಿಸಿ',
          malayalam: 'ഡോക്ടറുടെ വിവരങ്ങൾ തിരുത്തുക',
          punjabi: 'ਡਾਕਟਰ ਦੀ ਜਾਣਕਾਰੀ ਸੋਧੋ',
          selectedLanguage: widget.selectedLanguage,
        ),
),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DOCTOR NAME
                TextField(
                  controller: nameController,
decoration: InputDecoration(
  labelText: appText(
    english: 'Doctor Name *',
    hindi: 'डॉक्टर का नाम *',
    marathi: 'डॉक्टरचे नाव *',
    gujarati: 'ડૉક્ટરનું નામ *',
    telugu: 'డాక్టర్ పేరు *',
    tamil: 'மருத்துவர் பெயர் *',
    bengali: 'ডাক্তারের নাম *',
    kannada: 'ವೈದ್ಯರ ಹೆಸರು *',
    malayalam: 'ഡോക്ടറുടെ പേര് *',
    punjabi: 'ਡਾਕਟਰ ਦਾ ਨਾਮ *',
    selectedLanguage: widget.selectedLanguage,
  ),
  hintText: appText(
    english: 'Example: Dr. Sharma',
    hindi: 'उदाहरण: डॉ. शर्मा',
    marathi: 'उदाहरण: डॉ. शर्मा',
    gujarati: 'ઉદાહરણ: ડૉ. શર્મા',
    telugu: 'ఉదాహరణ: డా. శర్మ',
    tamil: 'உதாரணம்: டாக்டர் சர்மா',
    bengali: 'উদাহরণ: ডাঃ শর্মা',
    kannada: 'ಉದಾಹರಣೆ: ಡಾ. ಶರ್ಮಾ',
    malayalam: 'ഉദാഹരണം: ഡോ. ശർമ്മ',
    punjabi: 'ਉਦਾਹਰਨ: ਡਾ. ਸ਼ਰਮਾ',
    selectedLanguage: widget.selectedLanguage,
  ),
  prefixIcon: const Icon(Icons.person_rounded),
),
                ),

                const SizedBox(height: 12),

                // HOSPITAL
                TextField(
                  controller: hospitalController,
decoration: InputDecoration(
  labelText: appText(
    english: 'Hospital / Clinic',
    hindi: 'अस्पताल / क्लिनिक',
    marathi: 'रुग्णालय / क्लिनिक',
    gujarati: 'હોસ્પિટલ / ક્લિનિક',
    telugu: 'ఆసుపత్రి / క్లినిక్',
    tamil: 'மருத்துவமனை / கிளினிக்',
    bengali: 'হাসপাতাল / ক্লিনিক',
    kannada: 'ಆಸ್ಪತ್ರೆ / ಕ್ಲಿನಿಕ್',
    malayalam: 'ആശുപത്രി / ക്ലിനിക്',
    punjabi: 'ਹਸਪਤਾਲ / ਕਲੀਨਿਕ',
    selectedLanguage: widget.selectedLanguage,
  ),
  hintText: appText(
    english: 'Example: City Hospital',
    hindi: 'उदाहरण: सिटी अस्पताल',
    marathi: 'उदाहरण: सिटी हॉस्पिटल',
    gujarati: 'ઉદાહરણ: સિટી હોસ્પિટલ',
    telugu: 'ఉదాహరణ: సిటీ హాస్పిటల్',
    tamil: 'உதாரணம்: சிட்டி மருத்துவமனை',
    bengali: 'উদাহরণ: সিটি হাসপাতাল',
    kannada: 'ಉದಾಹರಣೆ: ಸಿಟಿ ಆಸ್ಪತ್ರೆ',
    malayalam: 'ഉദാഹരണം: സിറ്റി ആശുപത്രി',
    punjabi: 'ਉਦਾਹਰਨ: ਸਿਟੀ ਹਸਪਤਾਲ',
    selectedLanguage: widget.selectedLanguage,
  ),
  prefixIcon: const Icon(Icons.local_hospital_rounded),
),
                ),

                const SizedBox(height: 12),

                // SPECIALIZATION
                TextField(
                  controller: specializationController,
decoration: InputDecoration(
  labelText: appText(
    english: 'Specialization',
    hindi: 'विशेषज्ञता',
    marathi: 'विशेषज्ञता',
    gujarati: 'વિશેષતા',
    telugu: 'ప్రత్యేకత',
    tamil: 'சிறப்புப் பிரிவு',
    bengali: 'বিশেষজ্ঞতা',
    kannada: 'ವಿಶೇಷತೆ',
    malayalam: 'സ്പെഷ്യലൈസേഷൻ',
    punjabi: 'ਮਾਹਿਰਤਾ',
    selectedLanguage: widget.selectedLanguage,
  ),
  hintText: appText(
    english: 'Example: Cardiologist',
    hindi: 'उदाहरण: हृदय रोग विशेषज्ञ',
    marathi: 'उदाहरण: हृदयरोग तज्ञ',
    gujarati: 'ઉદાહરણ: હૃદય રોગ નિષ્ણાત',
    telugu: 'ఉదాహరణ: కార్డియాలజిస్ట్',
    tamil: 'உதாரணம்: இதய நோய் நிபுணர்',
    bengali: 'উদাহরণ: হৃদরোগ বিশেষজ্ঞ',
    kannada: 'ಉದಾಹರಣೆ: ಹೃದ್ರೋಗ ತಜ್ಞ',
    malayalam: 'ഉദാഹരണം: കാർഡിയോളജിസ്റ്റ്',
    punjabi: 'ਉਦਾਹਰਨ: ਦਿਲ ਦੇ ਰੋਗਾਂ ਦੇ ਮਾਹਿਰ',
    selectedLanguage: widget.selectedLanguage,
  ),
  prefixIcon: const Icon(Icons.medical_services_rounded),
),
                ),

                const SizedBox(height: 12),

                // PHONE
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
  labelText: appText(
    english: 'Phone Number *',
    hindi: 'फ़ोन नंबर *',
    marathi: 'फोन नंबर *',
    gujarati: 'ફોન નંબર *',
    telugu: 'ఫోన్ నంబర్ *',
    tamil: 'தொலைபேசி எண் *',
    bengali: 'ফোন নম্বর *',
    kannada: 'ಫೋನ್ ಸಂಖ್ಯೆ *',
    malayalam: 'ഫോൺ നമ്പർ *',
    punjabi: 'ਫ਼ੋਨ ਨੰਬਰ *',
    selectedLanguage: widget.selectedLanguage,
  ),
  hintText: appText(
    english: 'Example: 9876543210',
    hindi: 'उदाहरण: 9876543210',
    marathi: 'उदाहरण: 9876543210',
    gujarati: 'ઉદાહરણ: 9876543210',
    telugu: 'ఉదాహరణ: 9876543210',
    tamil: 'உதாரணம்: 9876543210',
    bengali: 'উদাহরণ: 9876543210',
    kannada: 'ಉದಾಹರಣೆ: 9876543210',
    malayalam: 'ഉദാഹരണം: 9876543210',
    punjabi: 'ਉਦਾਹਰਨ: 9876543210',
    selectedLanguage: widget.selectedLanguage,
  ),
  prefixIcon: const Icon(Icons.phone_rounded),
),
                ),

                const SizedBox(height: 12),

                // ADDRESS
                TextField(
                  controller: addressController,
                  maxLines: 2,
decoration: InputDecoration(
  labelText: appText(
    english: 'Clinic Address',
    hindi: 'क्लिनिक का पता',
    marathi: 'क्लिनिकचा पत्ता',
    gujarati: 'ક્લિનિકનું સરનામું',
    telugu: 'క్లినిక్ చిరునామా',
    tamil: 'கிளினிக் முகவரி',
    bengali: 'ক্লিনিকের ঠিকানা',
    kannada: 'ಕ್ಲಿನಿಕ್ ವಿಳಾಸ',
    malayalam: 'ക്ലിനിക് വിലാസം',
    punjabi: 'ਕਲੀਨਿਕ ਦਾ ਪਤਾ',
    selectedLanguage: widget.selectedLanguage,
  ),
  hintText: appText(
    english: 'Enter clinic address',
    hindi: 'क्लिनिक का पता दर्ज करें',
    marathi: 'क्लिनिकचा पत्ता टाका',
    gujarati: 'ક્લિનિકનું સરનામું દાખલ કરો',
    telugu: 'క్లినిక్ చిరునామాను నమోదు చేయండి',
    tamil: 'கிளினிக் முகவரியை உள்ளிடவும்',
    bengali: 'ক্লিনিকের ঠিকানা লিখুন',
    kannada: 'ಕ್ಲಿನಿಕ್ ವಿಳಾಸವನ್ನು ನಮೂದಿಸಿ',
    malayalam: 'ക്ലിനിക് വിലാസം നൽകുക',
    punjabi: 'ਕਲੀਨਿਕ ਦਾ ਪਤਾ ਦਰਜ ਕਰੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
  prefixIcon: const Icon(Icons.location_on_rounded),
),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
child: Text(
  appText(
    english: 'CANCEL',
    hindi: 'रद्द करें',
    marathi: 'रद्द करा',
    gujarati: 'રદ કરો',
    telugu: 'రద్దు చేయండి',
    tamil: 'ரத்து செய்',
    bengali: 'বাতিল করুন',
    kannada: 'ರದ್ದುಮಾಡಿ',
    malayalam: 'റദ്ദാക്കുക',
    punjabi: 'ਰੱਦ ਕਰੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
),
            ),

            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final hospital = hospitalController.text.trim();
                final specialization =
                    specializationController.text.trim();
                final phone = phoneController.text.trim();
                final address = addressController.text.trim();

                // CHECK REQUIRED FIELDS
              
                // CHECK REQUIRED FIELDS
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                      
content: Text(
  appText(
    english: 'Please enter doctor name and phone number.',
    hindi: 'कृपया डॉक्टर का नाम और फ़ोन नंबर दर्ज करें।',
    marathi: 'कृपया डॉक्टरचे नाव आणि फोन नंबर टाका.',
    gujarati: 'કૃપા કરીને ડૉક્ટરનું નામ અને ફોન નંબર દાખલ કરો.',
    telugu: 'దయచేసి డాక్టర్ పేరు మరియు ఫోన్ నంబర్ నమోదు చేయండి.',
    tamil: 'மருத்துவர் பெயர் மற்றும் தொலைபேசி எண்ணை உள்ளிடவும்.',
    bengali: 'দয়া করে ডাক্তারের নাম এবং ফোন নম্বর লিখুন।',
    kannada: 'ದಯವಿಟ್ಟು ವೈದ್ಯರ ಹೆಸರು ಮತ್ತು ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.',
    malayalam: 'ഡോക്ടറുടെ പേരും ഫോൺ നമ്പറും നൽകുക.',
    punjabi: 'ਕਿਰਪਾ ਕਰਕੇ ਡਾਕਟਰ ਦਾ ਨਾਮ ਅਤੇ ਫ਼ੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ।',
    selectedLanguage: widget.selectedLanguage,
  ),
),

                    ),
                  );
                  return;
                }

                // PHONE VALIDATION
                if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                    
content: Text(
  appText(
    english: 'Please enter a valid 10-digit phone number.',
    hindi: 'कृपया सही 10 अंकों का फ़ोन नंबर दर्ज करें।',
    marathi: 'कृपया योग्य 10 अंकी फोन नंबर टाका.',
    gujarati: 'કૃપા કરીને માન્ય 10 અંકનો ફોન નંબર દાખલ કરો.',
    telugu: 'దయచేసి సరైన 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి.',
    tamil: 'சரியான 10 இலக்க தொலைபேசி எண்ணை உள்ளிடவும்.',
    bengali: 'দয়া করে একটি সঠিক ১০ সংখ্যার ফোন নম্বর লিখুন।',
    kannada: 'ದಯವಿಟ್ಟು ಸರಿಯಾದ 10 ಅಂಕಿಗಳ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.',
    malayalam: 'ദയവായി സാധുവായ 10 അക്ക ഫോൺ നമ്പർ നൽകുക.',
    punjabi: 'ਕਿਰਪਾ ਕਰਕੇ ਸਹੀ 10 ਅੰਕਾਂ ਦਾ ਫ਼ੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ।',
    selectedLanguage: widget.selectedLanguage,
  ),
),

                    ),
                  );
                  return;
                }

                final doctor = {
                  'name': name,
                  'hospital': hospital,
                  'specialization': specialization,
                  'phone': phone,
                  'address': address,
                };

                await _saveDoctorInfo(doctor);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  final message = doctorInfo == null
                      ? appText(
                          english: 'Doctor information saved!',
                          hindi: 'डॉक्टर की जानकारी सहेज ली गई है!',
                          marathi: 'डॉक्टरची माहिती जतन केली आहे!',
                          gujarati: 'ડૉક્ટરની માહિતી સાચવવામાં આવી છે!',
                          telugu: 'డాక్టర్ సమాచారం సేవ్ చేయబడింది!',
                          tamil: 'மருத்துவர் தகவல் சேமிக்கப்பட்டது!',
                          bengali: 'ডাক্তারের তথ্য সংরক্ষণ করা হয়েছে!',
                          kannada: 'ವೈದ್ಯರ ಮಾಹಿತಿಯನ್ನು ಉಳಿಸಲಾಗಿದೆ!',
                          malayalam: 'ഡോക്ടറുടെ വിവരങ്ങൾ സംരക്ഷിച്ചു!',
                          punjabi: 'ਡਾਕਟਰ ਦੀ ਜਾਣਕਾਰੀ ਸੇਵ ਕੀਤੀ ਗਈ ਹੈ!',
                          selectedLanguage: widget.selectedLanguage,
                        )
                      : appText(
                          english: 'Doctor information updated!',
                          hindi: 'डॉक्टर की जानकारी अपडेट की गई है!',
                          marathi: 'डॉक्टरची माहिती अपडेट केली आहे!',
                          gujarati: 'ડૉક્ટરની માહિતી અપડેટ કરવામાં આવી છે!',
                          telugu: 'డాక్టర్ సమాచారం నవీకరించబడింది!',
                          tamil: 'மருத்துவர் தகவல் புதுப்பிக்கப்பட்டது!',
                          bengali: 'ডাক্তারের তথ্য আপডেট করা হয়েছে!',
                          kannada: 'ವೈದ್ಯರ ಮಾಹಿತಿಯನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ!',
                          malayalam: 'ഡോക്ടറുടെ വിവരങ്ങൾ അപ്ഡేట్ ചെയ്തു!',
                          punjabi: 'ਡਾਕਟਰ ਦੀ ਜਾਣਕਾਰੀ ਅੱਪਡੇਟ ਕੀਤੀ ਗਈ ਹੈ!',
                          selectedLanguage: widget.selectedLanguage,
                        );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                    ),
                  );
                }

              },
            
child: Text(
  doctorInfo == null
      ? appText(
          english: 'SAVE',
          hindi: 'सहेजें',
          marathi: 'जतन करा',
          gujarati: 'સાચવો',
          telugu: 'సేవ్ చేయండి',
          tamil: 'சேமிக்கவும்',
          bengali: 'সংরক্ষণ করুন',
          kannada: 'ಉಳಿಸಿ',
          malayalam: 'സംരക്ഷിക്കുക',
          punjabi: 'ਸੇਵ ਕਰੋ',
          selectedLanguage: widget.selectedLanguage,
        )
      : appText(
          english: 'SAVE CHANGES',
          hindi: 'बदलाव सहेजें',
          marathi: 'बदल जतन करा',
          gujarati: 'ફેરફારો સાચવો',
          telugu: 'మార్పులను సేవ్ చేయండి',
          tamil: 'மாற்றங்களைச் சேமிக்கவும்',
          bengali: 'পরিবর্তনগুলি সংরক্ষণ করুন',
          kannada: 'ಬದಲಾವಣೆಗಳನ್ನು ಉಳಿಸಿ',
          malayalam: 'മാറ്റങ്ങൾ സംരക്ഷിക്കുക',
          punjabi: 'ਤਬਦੀਲੀਆਂ ਸੇਵ ਕਰੋ',
          selectedLanguage: widget.selectedLanguage,
        ),
),

            ),
          ],
        );
      },
    );
  }


  // =====================================================
  // DELETE DOCTOR
  // =====================================================

  void _deleteDoctor() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
title: Text(
  appText(
    english: 'Delete Doctor Information?',
    hindi: 'डॉक्टर की जानकारी हटाएं?',
    marathi: 'डॉक्टरची माहिती हटवायची?',
    gujarati: 'ડૉક્ટરની માહિતી કાઢી નાખવી છે?',
    telugu: 'డాక్టర్ సమాచారాన్ని తొలగించాలా?',
    tamil: 'மருத்துவர் தகவலை நீக்கவா?',
    bengali: 'ডাক্তারের তথ্য মুছে ফেলবেন?',
    kannada: 'ವೈದ್ಯರ ಮಾಹಿತಿಯನ್ನು ಅಳಿಸಬೇಕೆ?',
    malayalam: 'ഡോക്ടറുടെ വിവരങ്ങൾ ഇല്ലാതാക്കണോ?',
    punjabi: 'ਡਾਕਟਰ ਦੀ ਜਾਣਕਾਰੀ ਮਿਟਾਉਣੀ ਹੈ?',
    selectedLanguage: widget.selectedLanguage,
  ),
),

content: Text(
  appText(
    english: 'Are you sure you want to remove the saved doctor information?',
    hindi: 'क्या आप सहेजी गई डॉक्टर की जानकारी हटाना चाहते हैं?',
    marathi: 'तुम्हाला जतन केलेली डॉक्टरची माहिती हटवायची आहे का?',
    gujarati: 'શું તમે સાચવેલી ડૉક્ટરની માહિતી કાઢી નાખવા માંગો છો?',
    telugu: 'మీరు సేవ్ చేసిన డాక్టర్ సమాచారాన్ని తొలగించాలనుకుంటున్నారా?',
    tamil: 'சேமிக்கப்பட்ட மருத்துவர் தகவலை நீக்க விரும்புகிறீர்களா?',
    bengali: 'আপনি কি সংরক্ষিত ডাক্তারের তথ্য মুছে ফেলতে চান?',
    kannada: 'ಉಳಿಸಿದ ವೈದ್ಯರ ಮಾಹಿತಿಯನ್ನು ಅಳಿಸಲು ನೀವು ಖಚಿತವಾಗಿ ಬಯಸುವಿರಾ?',
    malayalam: 'സംരക്ഷിച്ച ഡോക്ടറുടെ വിവരങ്ങൾ ഇല്ലാതാക്കണോ?',
    punjabi: 'ਕੀ ਤੁਸੀਂ ਸੇਵ ਕੀਤੀ ਡਾਕਟਰ ਦੀ ਜਾਣਕਾਰੀ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
    selectedLanguage: widget.selectedLanguage,
  ),
),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
child: Text(
  appText(
    english: 'CANCEL',
    hindi: 'रद्द करें',
    marathi: 'रद्द करा',
    gujarati: 'રદ કરો',
    telugu: 'రద్దు చేయండి',
    tamil: 'ரத்து செய்',
    bengali: 'বাতিল করুন',
    kannada: 'ರದ್ದುಮಾಡಿ',
    malayalam: 'റദ്ദാക്കുക',
    punjabi: 'ਰੱਦ ਕਰੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
),

         ),
            ElevatedButton(
              onPressed: () async {
                final prefs =
                    await SharedPreferences.getInstance();

                await prefs.remove('doctor_info');

                setState(() {
                  doctorInfo = null;
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
  content: Text(
    appText(
      english: 'Doctor information deleted.',
      hindi: 'डॉक्टर की जानकारी हटा दी गई है।',
      marathi: 'डॉक्टरची माहिती हटवली आहे.',
      gujarati: 'ડૉક્ટરની માહિતી કાઢી નાખવામાં આવી છે.',
      telugu: 'డాక్టర్ సమాచారం తొలగించబడింది.',
      tamil: 'மருத்துவர் தகவல் நீக்கப்பட்டது.',
      bengali: 'ডাক্তারের তথ্য মুছে ফেলা হয়েছে।',
      kannada: 'ವೈದ್ಯರ ಮಾಹಿತಿಯನ್ನು ಅಳಿಸಲಾಗಿದೆ.',
      malayalam: 'ഡോക്ടറുടെ വിവരങ്ങൾ ഇല്ലാതാക്കി.',
      punjabi: 'ਡਾਕਟਰ ਦੀ ਜਾਣਕਾਰੀ ਮਿਟਾ ਦਿੱਤੀ ਗਈ ਹੈ।',
      selectedLanguage: widget.selectedLanguage,
    ),
  ),
),
                  );
                }
              },
child: Text(
  appText(
    english: 'DELETE',
    hindi: 'हटाएं',
    marathi: 'हटवा',
    gujarati: 'કાઢી નાખો',
    telugu: 'తొలగించండి',
    tamil: 'நீக்கு',
    bengali: 'মুছে ফেলুন',
    kannada: 'ಅಳಿಸಿ',
    malayalam: 'ഇല്ലാതാക്കുക',
    punjabi: 'ਮਿਟਾਓ',
    selectedLanguage: widget.selectedLanguage,
  ),
),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // MY DOCTOR CARD
  // =====================================================

  Widget _doctorSection(BuildContext context) {
    if (doctorInfo == null) {
      return _bigActionCard(
  context,
  Icons.person_rounded,
  appText(
    english: 'My Doctor',
    hindi: 'मेरे डॉक्टर',
    marathi: 'माझे डॉक्टर',
    gujarati: 'મારા ડૉક્ટર',
    telugu: 'నా డాక్టర్',
    tamil: 'என் மருத்துவர்',
    bengali: 'আমার ডাক্তার',
    kannada: 'ನನ್ನ ವೈದ್ಯರು',
    malayalam: 'എന്റെ ഡോക്ടർ',
    punjabi: 'ਮੇਰੇ ਡਾਕਟਰ',
    selectedLanguage: widget.selectedLanguage,
  ),
  appText(
    english: 'Save your doctor information',
    hindi: 'अपने डॉक्टर की जानकारी सेव करें',
    marathi: 'तुमच्या डॉक्टरांची माहिती जतन करा',
    gujarati: 'તમારા ડૉક્ટરની માહિતી સાચવો',
    telugu: 'మీ డాక్టర్ సమాచారాన్ని సేవ్ చేయండి',
    tamil: 'உங்கள் மருத்துவர் தகவலைச் சேமிக்கவும்',
    bengali: 'আপনার ডাক্তারের তথ্য সংরক্ষণ করুন',
    kannada: 'ನಿಮ್ಮ ವೈದ್ಯರ ಮಾಹಿತಿಯನ್ನು ಉಳಿಸಿ',
    malayalam: 'നിങ്ങളുടെ ഡോക്ടറുടെ വിവരങ്ങൾ സേവ് ചെയ്യുക',
    punjabi: 'ਆਪਣੇ ਡਾਕਟਰ ਦੀ ਜਾਣਕਾਰੀ ਸੇਵ ਕਰੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
  const Color(0xFF6B8EAD),
  onTap: _showDoctorDialog,
);    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF6B8EAD),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
  appText(
    english: 'My Doctor',
    hindi: 'मेरे डॉक्टर',
    marathi: 'माझे डॉक्टर',
    gujarati: 'મારા ડૉક્ટર',
    telugu: 'నా డాక్టర్',
    tamil: 'எனது மருத்துவர்',
    bengali: 'আমার ডাক্তার',
    kannada: 'ನನ್ನ ವೈದ್ಯರು',
    malayalam: 'എന്റെ ഡോക്ടർ',
    punjabi: 'ਮੇਰੇ ਡਾਕਟਰ',
    selectedLanguage: widget.selectedLanguage,
  ),
  style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        doctorInfo!['name']!,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showDoctorDialog();
                    } else if (value == 'delete') {
                      _deleteDoctor();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 10),
Text(
  appText(
    english: 'Edit',
    hindi: 'संपादित करें',
    marathi: 'संपादित करा',
    gujarati: 'સંપાદિત કરો',
    telugu: 'సవరించండి',
    tamil: 'திருத்தவும்',
    bengali: 'সম্পাদনা করুন',
    kannada: 'ಸಂಪಾದಿಸಿ',
    malayalam: 'തിരുത്തുക',
    punjabi: 'ਸੰਪਾਦਿਤ ਕਰੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
),                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          SizedBox(width: 10),
Text(
  appText(
    english: 'Delete',
    hindi: 'हटाएं',
    marathi: 'हटवा',
    gujarati: 'કાઢી નાખો',
    telugu: 'తొలగించండి',
    tamil: 'நீக்கு',
    bengali: 'মুছে ফেলুন',
    kannada: 'ಅಳಿಸಿ',
    malayalam: 'ഇല്ലാതാക്കുക',
    punjabi: 'ਮਿਟਾਓ',
    selectedLanguage: widget.selectedLanguage,
  ),
),                   ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (doctorInfo!['specialization']!.isNotEmpty)
              _doctorDetail(
                Icons.medical_services_rounded,
                doctorInfo!['specialization']!,
              ),

            if (doctorInfo!['hospital']!.isNotEmpty)
              _doctorDetail(
                Icons.local_hospital_rounded,
                doctorInfo!['hospital']!,
              ),

            if (doctorInfo!['phone']!.isNotEmpty)
              _doctorDetail(
                Icons.phone_rounded,
                doctorInfo!['phone']!,
              ),

            if (doctorInfo!['address']!.isNotEmpty)
              _doctorDetail(
                Icons.location_on_rounded,
                doctorInfo!['address']!,
              ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _callDoctor,
              icon: const Icon(Icons.call_rounded),
              label: Text(
  appText(
    english: 'CALL DOCTOR',
    hindi: 'डॉक्टर को कॉल करें',
    marathi: 'डॉक्टरांना कॉल करा',
    gujarati: 'ડૉક્ટરને કૉલ કરો',
    telugu: 'డాక్టర్‌కు కాల్ చేయండి',
    tamil: 'மருத்துவரை அழைக்கவும்',
    bengali: 'ডাক্তারকে কল করুন',
    kannada: 'ವೈದ್ಯರಿಗೆ ಕರೆ ಮಾಡಿ',
    malayalam: 'ഡോക്ടറെ വിളിക്കുക',
    punjabi: 'ਡਾਕਟਰ ਨੂੰ ਕਾਲ ਕਰੋ',
    selectedLanguage: widget.selectedLanguage,
  ),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // DOCTOR DETAIL ROW
  // =====================================================

  Widget _doctorDetail(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 23,
            color: const Color(0xFF6B8EAD),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return SimplePage(
title: appText(
  english: 'Health',
  hindi: 'स्वास्थ्य',
  marathi: 'आरोग्य',
  gujarati: 'આરોગ્ય',
  telugu: 'ఆరోగ్యం',
  tamil: 'ஆரோக்கியம்',
  bengali: 'স্বাস্থ্য',
  kannada: 'ಆರೋಗ್ಯ',
  malayalam: 'ആരോഗ്യം',
  punjabi: 'ਸਿਹਤ',
  selectedLanguage: widget.selectedLanguage,
),subtitle: appText(
  english: 'Keep your health appointments organized.',
  hindi: 'अपनी स्वास्थ्य नियुक्तियों को व्यवस्थित रखें।',
  marathi: 'तुमच्या आरोग्याच्या भेटी व्यवस्थित ठेवा.',
  gujarati: 'તમારી આરોગ્ય મુલાકાતોને વ્યવસ્થિત રાખો.',
  telugu: 'మీ ఆరోగ్య అపాయింట్‌మెంట్‌లను క్రమబద్ధంగా ఉంచండి.',
  tamil: 'உங்கள் மருத்துவ சந்திப்புகளை ஒழுங்காக வைத்திருங்கள்.',
  bengali: 'আপনার স্বাস্থ্য অ্যাপয়েন্টমেন্টগুলি সংগঠিত রাখুন।',
  kannada: 'ನಿಮ್ಮ ಆರೋಗ್ಯ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್‌ಗಳನ್ನು ವ್ಯವಸ್ಥಿತವಾಗಿ ಇರಿಸಿ.',
  malayalam: 'നിങ്ങളുടെ ആരോഗ്യ അപ്പോയിന്റ്മെന്റുകൾ ക്രമീകരിച്ച് വയ്ക്കുക.',
  punjabi: 'ਆਪਣੀਆਂ ਸਿਹਤ ਮੁਲਾਕਾਤਾਂ ਨੂੰ ਵਿਵਸਥਿਤ ਰੱਖੋ।',
  selectedLanguage: widget.selectedLanguage,
),
      icon: Icons.medical_services_rounded,
      iconColor: const Color(0xFF6B8EAD),
      children: [
        // MY DOCTOR
        _doctorSection(context),

        const SizedBox(height: 10),

        // ADD APPOINTMENT
        _bigActionCard(
          context,
          Icons.calendar_month_rounded,
          appText(
  english: 'Add Appointment',
  hindi: 'अपॉइंटमेंट जोड़ें',
  marathi: 'अपॉइंटमेंट जोडा',
  gujarati: 'મુલાકાત ઉમેરો',
  telugu: 'అపాయింట్‌మెంట్ జోడించండి',
  tamil: 'சந்திப்பைச் சேர்க்கவும்',
  bengali: 'অ্যাপয়েন্টমেন্ট যোগ করুন',
  kannada: 'ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ಸೇರಿಸಿ',
  malayalam: 'അപ്പോയിന്റ്മെന്റ് ചേർക്കുക',
  punjabi: 'ਮੁਲਾਕਾਤ ਸ਼ਾਮਲ ਕਰੋ',
  selectedLanguage: widget.selectedLanguage,
),
appText(
  english: 'Create a doctor appointment reminder',
  hindi: 'डॉक्टर की अपॉइंटमेंट रिमाइंडर बनाएं',
  marathi: 'डॉक्टरच्या अपॉइंटमेंटची रिमाइंडर तयार करा',
  gujarati: 'ડૉક્ટરની મુલાકાત માટે રિમાઇન્ડર બનાવો',
  telugu: 'డాక్టర్ అపాయింట్‌మెంట్ రిమైండర్‌ను సృష్టించండి',
  tamil: 'மருத்துவர் சந்திப்பு நினைவூட்டலை உருவாக்கவும்',
  bengali: 'ডাক্তারের অ্যাপয়েন্টমেন্ট রিমাইন্ডার তৈরি করুন',
  kannada: 'ವೈದ್ಯರ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ಜ್ಞಾಪನೆಯನ್ನು ರಚಿಸಿ',
  malayalam: 'ഡോക്ടറുടെ അപ്പോയിന്റ്മെന്റ് റിമൈൻഡർ സൃഷ്ടിക്കുക',
  punjabi: 'ਡਾਕਟਰ ਦੀ ਮੁਲਾਕਾਤ ਲਈ ਰਿਮਾਈਂਡਰ ਬਣਾਓ',
  selectedLanguage: widget.selectedLanguage,
),
          const Color(0xFF5B7C99),
          onTap: () {
            _showAppointmentDialog(context);
          },
        ),
      ],
    );
  }

  // =====================================================
  // APPOINTMENT DIALOG
  // =====================================================

  void _showAppointmentDialog(BuildContext context) {
    final doctorController = TextEditingController();

   DateTime selectedDate = DateTime.now();
TimeOfDay selectedTime = TimeOfDay.now();

String scheduleType = 'daily';
List<int> selectedDays = [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
title: Text(
  appText(
    english: 'Doctor Appointment',
    hindi: 'डॉक्टर की अपॉइंटमेंट',
    marathi: 'डॉक्टरची अपॉइंटमेंट',
    gujarati: 'ડૉક્ટરની મુલાકાત',
    telugu: 'డాక్టర్ అపాయింట్‌మెంట్',
    tamil: 'மருத்துவர் சந்திப்பு',
    bengali: 'ডাক্তারের অ্যাপয়েন্টমেন্ট',
    kannada: 'ವೈದ್ಯರ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್',
    malayalam: 'ഡോക്ടറുടെ അപ്പോയിന്റ്മെന്റ്',
    punjabi: 'ਡਾਕਟਰ ਦੀ ਮੁਲਾਕਾਤ',
    selectedLanguage: widget.selectedLanguage,
  ),
),              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: doctorController,
                     decoration: InputDecoration(
  labelText: appText(
    english: 'Doctor name',
    hindi: 'डॉक्टर का नाम',
    marathi: 'डॉक्टरचे नाव',
    gujarati: 'ડૉક્ટરનું નામ',
    telugu: 'డాక్టర్ పేరు',
    tamil: 'மருத்துவர் பெயர்',
    bengali: 'ডাক্তারের নাম',
    kannada: 'ವೈದ್ಯರ ಹೆಸರು',
    malayalam: 'ഡോക്ടറുടെ പേര്',
    punjabi: 'ਡਾਕਟਰ ਦਾ ਨਾਮ',
    selectedLanguage: widget.selectedLanguage,
  ),
  prefixIcon: const Icon(Icons.person_rounded),
),
                    ),

                    const SizedBox(height: 12),

                    ListTile(
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                      ),
                      title: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          initialDate: selectedDate,
                        );

                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),

                                        ListTile(
                      leading: const Icon(
                        Icons.access_time_rounded,
                      ),
                      title: Text(
                        selectedTime.format(context),
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );

                        if (time != null) {
                          setDialogState(() {
                            selectedTime = time;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: scheduleType,
                      decoration: InputDecoration(
  labelText: appText(
    english: 'Schedule',
    hindi: 'समय-सारणी',
    marathi: 'वेळापत्रक',
    gujarati: 'સમયપત્રક',
    telugu: 'షెడ్యూల్',
    tamil: 'அட்டவணை',
    bengali: 'সময়সূচি',
    kannada: 'ವೇಳಾಪಟ್ಟಿ',
    malayalam: 'ഷെഡ്യൂൾ',
    punjabi: 'ਸਮਾਂ-ਸਾਰਣੀ',
    selectedLanguage: widget.selectedLanguage,
  ),
                        prefixIcon: Icon(
                          Icons.repeat_rounded,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'daily',
child: Text(
  appText(
    english: 'Every day',
    hindi: 'हर दिन',
    marathi: 'दररोज',
    gujarati: 'દરરોજ',
    telugu: 'ప్రతి రోజు',
    tamil: 'ஒவ்வொரு நாளும்',
    bengali: 'প্রতিদিন',
    kannada: 'ಪ್ರತಿದಿನ',
    malayalam: 'എല്ലാ ദിവസവും',
    punjabi: 'ਹਰ ਰੋਜ਼',
    selectedLanguage: widget.selectedLanguage,
  ),
),                        ),
                        DropdownMenuItem(
  value: 'selectedDays',
  child: Text(
    appText(
      english: 'Selected days',
      hindi: 'चुने हुए दिन',
      marathi: 'निवडलेले दिवस',
      gujarati: 'પસંદ કરેલા દિવસો',
      telugu: 'ఎంచుకున్న రోజులు',
      tamil: 'தேர்ந்தெடுக்கப்பட்ட நாட்கள்',
      bengali: 'নির্বাচিত দিনগুলি',
      kannada: 'ಆಯ್ಕೆ ಮಾಡಿದ ದಿನಗಳು',
      malayalam: 'തിരഞ്ഞെടുത്ത ദിവസങ്ങൾ',
      punjabi: 'ਚੁਣੇ ਹੋਏ ਦਿਨ',
      selectedLanguage: widget.selectedLanguage,
    ),
  ),
),
                        DropdownMenuItem(
                          value: 'once',
                          child: Text(
  appText(
    english: 'Once',
    hindi: 'एक बार',
    marathi: 'एकदा',
    gujarati: 'એકવાર',
    telugu: 'ఒక్కసారి',
    tamil: 'ஒருமுறை',
    bengali: 'একবার',
    kannada: 'ಒಮ್ಮೆ',
    malayalam: 'ഒരിക്കൽ',
    punjabi: 'ਇੱਕ ਵਾਰ',
    selectedLanguage: widget.selectedLanguage,
  ),
),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          scheduleType = value;
                          selectedDays = [];
                        });
                      },
                    ),

                    if (scheduleType == 'selectedDays') ...[
                      const SizedBox(height: 12),

                      Align(
  alignment: Alignment.centerLeft,
  child: Text(
    appText(
      english: 'Select days',
      hindi: 'दिन चुनें',
      marathi: 'दिवस निवडा',
      gujarati: 'દિવસો પસંદ કરો',
      telugu: 'రోజులను ఎంచుకోండి',
      tamil: 'நாட்களைத் தேர்ந்தெடுக்கவும்',
      bengali: 'দিন নির্বাচন করুন',
      kannada: 'ದಿನಗಳನ್ನು ಆಯ್ಕೆಮಾಡಿ',
      malayalam: 'ദിവസങ്ങൾ തിരഞ്ഞെടുക്കുക',
      punjabi: 'ਦਿਨ ਚੁਣੋ',
      selectedLanguage: widget.selectedLanguage,
    ),
    style: const TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),
),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(7, (index) {
                          final dayNumber = index + 1;

                          const dayNames = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];

                          final isSelected =
                              selectedDays.contains(dayNumber);

                          return FilterChip(
                            label: Text(dayNames[index]),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(dayNumber);
                                } else {
                                  selectedDays.remove(dayNumber);
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    if (doctorController.text.trim().isEmpty) {
                      return;
                    }

                    final appointmentDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    widget.addReminder(
                      Reminder(
title: appText(
  english: 'Doctor Appointment',
  hindi: 'डॉक्टर की अपॉइंटमेंट',
  marathi: 'डॉक्टरची अपॉइंटमेंट',
  gujarati: 'ડૉક્ટરની એપોઇન્ટમેન્ટ',
  telugu: 'డాక్టర్ అపాయింట్‌మెంట్',
  tamil: 'மருத்துவர் சந்திப்பு',
  bengali: 'ডাক্তারের অ্যাপয়ింటমেন্ট',
  kannada: 'ವೈದ್ಯರ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್',
  malayalam: 'ഡോക്ടറുടെ അപ്പോയിന്റ്മെന്റ്',
  punjabi: 'ਡਾਕਟਰ ਦੀ ਅਪਾਇੰਟਮੈਂਟ',
  selectedLanguage: widget.selectedLanguage,
),                details:
                            'Doctor: ${doctorController.text.trim()}',
                        type: 'Health',
                        dateTime: appointmentDateTime,
                        scheduleType: scheduleType,
selectedDays: selectedDays,
                      ),
                    );

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Appointment reminder added!',
                        ),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// =====================================================
// FAMILY
// =====================================================

class FamilyPage extends StatefulWidget {
  final Function(Reminder) addReminder;
  final String selectedLanguage;

  const FamilyPage({
    super.key,
    required this.addReminder,
    required this.selectedLanguage,
  });
  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  List<Map<String, String>> familyMembers = [];
  List<Map<String, String>> importantDates = [];

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  // =====================================================
  // LOAD SAVED FAMILY DATA
  // =====================================================

  Future<void> _loadFamilyData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMembers = prefs.getString('family_members');
    final savedDates = prefs.getString('important_dates');

    if (savedMembers != null) {
      final List<dynamic> decodedMembers = jsonDecode(savedMembers);

      familyMembers = decodedMembers
          .map((item) => Map<String, String>.from(item))
          .toList();
    }

    if (savedDates != null) {
      final List<dynamic> decodedDates = jsonDecode(savedDates);

      importantDates = decodedDates
          .map((item) => Map<String, String>.from(item))
          .toList();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // =====================================================
  // SAVE FAMILY DATA
  // =====================================================

  Future<void> _saveFamilyData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'family_members',
      jsonEncode(familyMembers),
    );

    await prefs.setString(
      'important_dates',
      jsonEncode(importantDates),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: appText(
  english: 'My Family',
  hindi: 'मेरा परिवार',
  marathi: 'माझे कुटुंब',
  gujarati: 'મારું પરિવાર',
  telugu: 'నా కుటుంబం',
  tamil: 'என் குடும்பம்',
  bengali: 'আমার পরিবার',
  kannada: 'ನನ್ನ ಕುಟುಂಬ',
  malayalam: 'എന്റെ കുടുംബം',
  punjabi: 'ਮੇਰਾ ਪਰਿਵਾਰ',
  selectedLanguage: widget.selectedLanguage,
),
subtitle: appText(
  english: 'Stay connected with the people you love.',
  hindi: 'अपने प्रियजनों से जुड़े रहें।',
  marathi: 'तुमच्या प्रियजनांशी जोडलेले रहा.',
  gujarati: 'તમારા પ્રિયજનો સાથે જોડાયેલા રહો.',
  telugu: 'మీరు ప్రేమించే వారితో అనుసంధానంగా ఉండండి.',
  tamil: 'நீங்கள் நேசிக்கும் நபர்களுடன் தொடர்பில் இருங்கள்.',
  bengali: 'আপনার প্রিয়জনদের সাথে যোগাযোগ রাখুন।',
  kannada: 'ನೀವು ಪ್ರೀತಿಸುವವರೊಂದಿಗೆ ಸಂಪರ್ಕದಲ್ಲಿರಿ.',
  malayalam: 'നിങ്ങൾ സ്നേഹിക്കുന്നവരുമായി ബന്ധം നിലനിർത്തുക.',
  punjabi: 'ਆਪਣੇ ਪਿਆਰਿਆਂ ਨਾਲ ਜੁੜੇ ਰਹੋ।',
  selectedLanguage: widget.selectedLanguage,
),
      icon: Icons.family_restroom_rounded,
      iconColor: const Color(0xFFB4869F),
      children: [
  // =================================================
  // ADD FAMILY MEMBER
  // =================================================

  _bigActionCard(
    context,
    Icons.person_add_rounded,
    appText(
      english: 'Add Family Member',
      hindi: 'परिवार का सदस्य जोड़ें',
      marathi: 'कुटुंबातील सदस्य जोडा',
      gujarati: 'પરિવારના સભ્યને ઉમેરો',
      telugu: 'కుటుంబ సభ్యుడిని జోడించండి',
      tamil: 'குடும்ப உறுப்பினரைச் சேர்க்கவும்',
      bengali: 'পরিবারের সদস্য যোগ করুন',
      kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಿ',
      malayalam: 'കുടുംബാംഗത്തെ ചേർക്കുക',
      punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਸ਼ਾਮਲ ਕਰੋ',
      selectedLanguage: widget.selectedLanguage,
    ),
    appText(
      english: 'Add a family member',
      hindi: 'परिवार के सदस्य को जोड़ें',
      marathi: 'कुटुंबातील सदस्य जोडा',
      gujarati: 'પરિવારના સભ્યને ઉમેરો',
      telugu: 'కుటుంబ సభ్యుడిని జోడించండి',
      tamil: 'குடும்ப உறுப்பினரைச் சேர்க்கவும்',
      bengali: 'পরিবারের সদস্য যোগ করুন',
      kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಿ',
      malayalam: 'കുടുംബാംഗത്തെ ചേർക്കുക',
      punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਸ਼ਾਮਲ ਕਰੋ',
      selectedLanguage: widget.selectedLanguage,
    ),
    const Color(0xFFB4869F),
    onTap: () {
      _showFamilyMemberDialog(context);
    },
  ),

  // =================================================
  // ADD BIRTHDAY
  // =================================================

  _bigActionCard(
    context,
    Icons.cake_rounded,
    appText(
      english: 'Add Birthday',
      hindi: 'जन्मदिन जोड़ें',
      marathi: 'वाढदिवस जोडा',
      gujarati: 'જન્મદિવસ ઉમેરો',
      telugu: 'పుట్టినరోజును జోడించండి',
      tamil: 'பிறந்தநாளைச் சேர்க்கவும்',
      bengali: 'জন্মদিন যোগ করুন',
      kannada: 'ಹುಟ್ಟುಹಬ್ಬವನ್ನು ಸೇರಿಸಿ',
      malayalam: 'ജന്മദിനം ചേർക്കുക',
      punjabi: 'ਜਨਮਦਿਨ ਸ਼ਾਮਲ ਕਰੋ',
      selectedLanguage: widget.selectedLanguage,
    ),
    appText(
      english: 'Never forget a family member’s birthday',
      hindi: 'परिवार के सदस्य का जन्मदिन कभी न भूलें',
      marathi: 'कुटुंबातील सदस्याचा वाढदिवस कधीही विसरू नका',
      gujarati: 'પરિવારના સભ્યનો જન્મદિવસ ક્યારેય ભૂલશો નહીં',
      telugu: 'కుటుంబ సభ్యుని పుట్టినరోజును ఎప్పటికీ మర్చిపోవద్దు',
      tamil: 'குடும்ப உறுப்பினரின் பிறந்தநாளை ஒருபோதும் மறக்காதீர்கள்',
      bengali: 'পরিবারের সদস্যের জন্মদিন কখনও ভুলবেন না',
      kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರ ಹುಟ್ಟುಹಬ್ಬವನ್ನು ಎಂದಿಗೂ ಮರೆಯಬೇಡಿ',
      malayalam: 'കുടുംബാംഗത്തിന്റെ ജന്മദിനം ഒരിക്കലും മറക്കരുത്',
      punjabi: 'ਪਰਿਵਾਰ ਦੇ ਮੈਂਬਰ ਦਾ ਜਨਮਦਿਨ ਕਦੇ ਨਾ ਭੁੱਲੋ',
      selectedLanguage: widget.selectedLanguage,
    ),
    const Color(0xFFC28B57),
    onTap: () {
      _showBirthdayDialog(context);
    },
  ),

  // =================================================
  // IMPORTANT DATES
  // =================================================

  _bigActionCard(
    context,
    Icons.event_rounded,
    appText(
      english: 'Important Dates',
      hindi: 'महत्वपूर्ण तारीखें',
      marathi: 'महत्त्वाच्या तारखा',
      gujarati: 'મહત્વપૂર્ણ તારીખો',
      telugu: 'ముఖ్యమైన తేదీలు',
      tamil: 'முக்கியமான தேதிகள்',
      bengali: 'গুরুত্বপূর্ণ তারিখ',
      kannada: 'ಪ್ರಮುಖ ದಿನಾಂಕಗಳು',
      malayalam: 'പ്രധാനപ്പെട്ട തീയതികൾ',
      punjabi: 'ਮਹੱਤਵਪੂਰਨ ਤਾਰੀਖਾਂ',
      selectedLanguage: widget.selectedLanguage,
    ),
    appText(
      english: 'Save anniversaries and other important dates.',
      hindi: 'सालगिरह और अन्य महत्वपूर्ण तारीखें सेव करें।',
      marathi: 'वर्धापनदिन आणि इतर महत्त्वाच्या तारखा जतन करा.',
      gujarati: 'વર્ષગાંઠ અને અન્ય મહત્વપૂર્ણ તારીખો સાચવો.',
      telugu: 'వార్షికోత్సవాలు మరియు ఇతర ముఖ్యమైన తేదీలను సేవ్ చేయండి.',
      tamil: 'திருமண நாள்கள் மற்றும் பிற முக்கியமான தேதிகளைச் சேமிக்கவும்.',
      bengali: 'বার্ষিকী এবং অন্যান্য গুরুত্বপূর্ণ তারিখ সংরক্ষণ করুন।',
      kannada: 'ವಾರ್ಷಿಕೋತ್ಸವಗಳು ಮತ್ತು ಇತರ ಪ್ರಮುಖ ದಿನಾಂಕಗಳನ್ನು ಉಳಿಸಿ.',
      malayalam: 'വാർഷികങ്ങളും മറ്റ് പ്രധാനപ്പെട്ട തീയതികളും സേവ് ചെയ്യുക.',
      punjabi: 'ਵਰ੍ਹੇਗੰਢਾਂ ਅਤੇ ਹੋਰ ਮਹੱਤਵਪੂਰਨ ਤਾਰੀਖਾਂ ਨੂੰ ਸੇਵ ਕਰੋ।',
      selectedLanguage: widget.selectedLanguage,
    ),
    const Color(0xFFD95C5C),
    onTap: () {
      _showImportantDateDialog(context);
    },
  ),

  // =================================================
  // FAMILY MEMBERS LIST
  // =================================================

        // =================================================
        // FAMILY MEMBERS LIST
        // =================================================

        if (familyMembers.isNotEmpty) ...[
          const SizedBox(height: 25),

          Text(
  appText(
    english: 'My Family Members',
    hindi: 'मेरे परिवार के सदस्य',
    marathi: 'माझ्या कुटुंबातील सदस्य',
    gujarati: 'મારા પરિવારના સભ્યો',
    telugu: 'నా కుటుంబ సభ్యులు',
    tamil: 'என் குடும்ப உறுப்பினர்கள்',
    bengali: 'আমার পরিবারের সদস্যরা',
    kannada: 'ನನ್ನ ಕುಟುಂಬದ ಸದಸ್ಯರು',
    malayalam: 'എന്റെ കുടുംബാംഗങ്ങൾ',
    punjabi: 'ਮੇਰੇ ਪਰਿਵਾਰ ਦੇ ਮੈਂਬਰ',
    selectedLanguage: widget.selectedLanguage,
  ),
  style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF30485C),
            ),
          ),

          const SizedBox(height: 12),

          ...familyMembers.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final member = entry.value;

              return _familyMemberCard(
                context,
                member,
                index,
              );
            },
          ),
        ],

        // =================================================
        // IMPORTANT DATES LIST
        // =================================================

        if (importantDates.isNotEmpty) ...[
  const SizedBox(height: 25),

  Text(
    appText(
      english: 'Important Dates',
      hindi: 'महत्वपूर्ण तारीखें',
      marathi: 'महत्त्वाच्या तारखा',
      gujarati: 'મહત્વપૂર્ણ તારીખો',
      telugu: 'ముఖ్యమైన తేదీలు',
      tamil: 'முக்கியமான தேதிகள்',
      bengali: 'গুরুত্বপূর্ণ তারিখ',
      kannada: 'ಪ್ರಮುಖ ದಿನಾಂಕಗಳು',
      malayalam: 'പ്രധാനപ്പെട്ട തീയതികൾ',
      punjabi: 'ਮਹੱਤਵਪੂਰਨ ਤਾਰੀਖਾਂ',
      selectedLanguage: widget.selectedLanguage,
    ),
    style: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: Color(0xFF30485C),
    ),
  ),

  const SizedBox(height: 12),

  ...importantDates.asMap().entries.map((entry) {
    final index = entry.key;
    final date = entry.value;

    return _importantDateCard(
      context,
      date,
      index,
    );
  }),
],
      ],
    );
  }

  // =====================================================
  // ADD FAMILY MEMBER DIALOG
  // =====================================================

  void _showFamilyMemberDialog(
  BuildContext context, {
  int? editIndex,
}) {
  final isEditing = editIndex != null;

  final nameController = TextEditingController(
    text: isEditing ? familyMembers[editIndex!]['name'] : '',
  );

  final relationshipController = TextEditingController(
    text: isEditing ? familyMembers[editIndex!]['relationship'] : '',
  );

  final phoneController = TextEditingController(
    text: isEditing ? familyMembers[editIndex!]['phone'] : '',
  );

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          isEditing
              ? appText(
                  english: 'Edit Family Member',
                  hindi: 'परिवार के सदस्य को संपादित करें',
                  marathi: 'कुटुंबातील सदस्य संपादित करा',
                  gujarati: 'પરિવારના સભ્યને સંપાદિત કરો',
                  telugu: 'కుటుంబ సభ్యుడిని సవరించండి',
                  tamil: 'குடும்ப உறுப்பினரைத் திருத்தவும்',
                  bengali: 'পরিবারের সদস্য সম্পাদনা করুন',
                  kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರನ್ನು ಸಂಪಾದಿಸಿ',
                  malayalam: 'കുടുംബാംഗത്തെ തിരുത്തുക',
                  punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਨੂੰ ਸੋਧੋ',
                  selectedLanguage: widget.selectedLanguage,
                )
              : appText(
                  english: 'Add Family Member',
                  hindi: 'परिवार का सदस्य जोड़ें',
                  marathi: 'कुटुंबातील सदस्य जोडा',
                  gujarati: 'પરિવારના સભ્યને ઉમેરો',
                  telugu: 'కుటుంబ సభ్యుడిని జోడించండి',
                  tamil: 'குடும்ப உறுப்பினரைச் சேர்க்கவும்',
                  bengali: 'পরিবারের সদস্য যোগ করুন',
                  kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಿ',
                  malayalam: 'കുടുംബാംഗത്തെ ചേർക്കുക',
                  punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਸ਼ਾਮਲ ਕਰੋ',
                  selectedLanguage: widget.selectedLanguage,
                ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: appText(
                    english: 'Name',
                    hindi: 'नाम',
                    marathi: 'नाव',
                    gujarati: 'નામ',
                    telugu: 'పేరు',
                    tamil: 'பெயர்',
                    bengali: 'নাম',
                    kannada: 'ಹೆಸರು',
                    malayalam: 'പേര്',
                    punjabi: 'ਨਾਮ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: relationshipController,
                decoration: InputDecoration(
                  labelText: appText(
                    english: 'Relationship',
                    hindi: 'रिश्ता',
                    marathi: 'नाते',
                    gujarati: 'સંબંધ',
                    telugu: 'సంబంధం',
                    tamil: 'உறவு',
                    bengali: 'সম্পর্ক',
                    kannada: 'ಸಂಬಂಧ',
                    malayalam: 'ബന്ധം',
                    punjabi: 'ਰਿਸ਼ਤਾ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  hintText: appText(
                    english: 'e.g. Son, Daughter, Brother',
                    hindi: 'जैसे बेटा, बेटी, भाई',
                    marathi: 'उदा. मुलगा, मुलगी, भाऊ',
                    gujarati: 'દા.ત. પુત્ર, પુત્રી, ભાઈ',
                    telugu: 'ఉదా. కుమారుడు, కుమార్తె, సోదరుడు',
                    tamil: 'எ.கா. மகன், மகள், சகோதரர்',
                    bengali: 'যেমন ছেলে, মেয়ে, ভাই',
                    kannada: 'ಉದಾ. ಮಗ, ಮಗಳು, ಸಹೋದರ',
                    malayalam: 'ഉദാ. മകൻ, മകൾ, സഹോദരൻ',
                    punjabi: 'ਜਿਵੇਂ ਪੁੱਤਰ, ਧੀ, ਭਰਾ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  prefixIcon: const Icon(
                    Icons.family_restroom_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: appText(
                    english: 'Phone Number',
                    hindi: 'फ़ोन नंबर',
                    marathi: 'फोन नंबर',
                    gujarati: 'ફોન નંબર',
                    telugu: 'ఫోన్ నంబర్',
                    tamil: 'தொலைபேசி எண்',
                    bengali: 'ফোন নম্বর',
                    kannada: 'ಫೋನ್ ಸಂಖ್ಯೆ',
                    malayalam: 'ഫോൺ നമ്പർ',
                    punjabi: 'ਫੋਨ ਨੰਬਰ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              appText(
                english: 'Cancel',
                hindi: 'रद्द करें',
                marathi: 'रद्द करा',
                gujarati: 'રદ કરો',
                telugu: 'రద్దు చేయండి',
                tamil: 'ரத்துசெய்',
                bengali: 'বাতিল করুন',
                kannada: 'ರದ್ದುಮಾಡಿ',
                malayalam: 'റദ്ദാക്കുക',
                punjabi: 'ਰੱਦ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final relationship =
                  relationshipController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty ||
                  relationship.isEmpty ||
                  phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      appText(
                        english: 'Please fill all the details.',
                        hindi: 'कृपया सभी जानकारी भरें।',
                        marathi: 'कृपया सर्व माहिती भरा.',
                        gujarati: 'કૃપા કરીને બધી માહિતી ભરો.',
                        telugu: 'దయచేసి అన్ని వివరాలను నమోదు చేయండి.',
                        tamil: 'தயவுசெய்து அனைத்து விவரங்களையும் நிரப்பவும்.',
                        bengali: 'অনুগ্রহ করে সমস্ত তথ্য পূরণ করুন।',
                        kannada: 'ದಯವಿಟ್ಟು ಎಲ್ಲಾ ವಿವರಗಳನ್ನು ಭರ್ತಿ ಮಾಡಿ.',
                        malayalam: 'ദയവായി എല്ലാ വിവരങ്ങളും പൂരിപ്പിക്കുക.',
                        punjabi: 'ਕਿਰਪਾ ਕਰਕੇ ਸਾਰੀ ਜਾਣਕਾਰੀ ਭਰੋ।',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                );
                return;
              }

              if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      appText(
                        english:
                            'Please enter a valid 10-digit phone number.',
                        hindi:
                            'कृपया 10 अंकों का सही फ़ोन नंबर दर्ज करें।',
                        marathi:
                            'कृपया 10 अंकी योग्य फोन नंबर प्रविष्ट करा.',
                        gujarati:
                            'કૃપા કરીને 10 અંકનો માન્ય ફોન નંબર દાખલ કરો.',
                        telugu:
                            'దయచేసి చెల్లుబాటు అయ్యే 10 అంకెల ఫోన్ నంబర్‌ను నమోదు చేయండి.',
                        tamil:
                            'தயவுசெய்து சரியான 10 இலக்க தொலைபேசி எண்ணை உள்ளிடவும்.',
                        bengali:
                            'অনুগ্রহ করে একটি বৈধ ১০ সংখ্যার ফোন নম্বর লিখুন।',
                        kannada:
                            'ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ 10 ಅಂಕಿಯ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.',
                        malayalam:
                            'ദയവായി സാധുവായ 10 അക്ക ഫോൺ നമ്പർ നൽകുക.',
                        punjabi:
                            'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ 10 ਅੰਕਾਂ ਦਾ ਫੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ।',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                );
                return;
              }

              final member = {
                'name': name,
                'relationship': relationship,
                'phone': phone,
              };

              setState(() {
                if (isEditing) {
                  familyMembers[editIndex!] = member;
                } else {
                  familyMembers.add(member);
                }
              });

              await _saveFamilyData();

              if (context.mounted) {
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? appText(
                              english: 'Family member updated!',
                              hindi: 'परिवार का सदस्य अपडेट किया गया!',
                              marathi: 'कुटुंबातील सदस्य अपडेट केला!',
                              gujarati: 'પરિવારના સભ્યને અપડેટ કરવામાં આવ્યો!',
                              telugu: 'కుటుంబ సభ్యుడు నవీకరించబడ్డారు!',
                              tamil: 'குடும்ப உறுப்பினர் புதுப்பிக்கப்பட்டார்!',
                              bengali: 'পরিবারের সদস্য আপডেট করা হয়েছে!',
                              kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ!',
                              malayalam: 'കുടുംബാംഗത്തെ അപ്ഡേറ്റ് ചെയ്തു!',
                              punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਨੂੰ ਅੱਪਡੇਟ ਕੀਤਾ ਗਿਆ!',
                              selectedLanguage: widget.selectedLanguage,
                            )
                          : appText(
                              english: 'Family member added!',
                              hindi: 'परिवार का सदस्य जोड़ा गया!',
                              marathi: 'कुटुंबातील सदस्य जोडला!',
                              gujarati: 'પરિવારના સભ્યને ઉમેરવામાં આવ્યો!',
                              telugu: 'కుటుంబ సభ్యుడు జోడించబడ్డారు!',
                              tamil: 'குடும்ப உறுப்பினர் சேர்க்கப்பட்டார்!',
                              bengali: 'পরিবারের সদস্য যোগ করা হয়েছে!',
                              kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರನ್ನು ಸೇರಿಸಲಾಗಿದೆ!',
                              malayalam: 'കുടുംബാംഗത്തെ ചേർത്തു!',
                              punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਸ਼ਾਮਲ ਕੀਤਾ ਗਿਆ!',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                    ),
                  ),
                );
              }
            },
            child: Text(
              isEditing
                  ? appText(
                      english: 'Update',
                      hindi: 'अपडेट करें',
                      marathi: 'अपडेट करा',
                      gujarati: 'અપડેટ કરો',
                      telugu: 'నవీకరించండి',
                      tamil: 'புதுப்பிக்கவும்',
                      bengali: 'আপডেট করুন',
                      kannada: 'ನವೀಕರಿಸಿ',
                      malayalam: 'അപ്ഡേറ്റ് ചെയ്യുക',
                      punjabi: 'ਅੱਪਡੇਟ ਕਰੋ',
                      selectedLanguage: widget.selectedLanguage,
                    )
                  : appText(
                      english: 'Save',
                      hindi: 'सेव करें',
                      marathi: 'जतन करा',
                      gujarati: 'સાચવો',
                      telugu: 'సేవ్ చేయండి',
                      tamil: 'சேமிக்கவும்',
                      bengali: 'সংরক্ষণ করুন',
                      kannada: 'ಉಳಿಸಿ',
                      malayalam: 'സേവ് ചെയ്യുക',
                      punjabi: 'ਸੇਵ ਕਰੋ',
                      selectedLanguage: widget.selectedLanguage,
                    ),
            ),
          ),
        ],
      );
    },
  );
}
  // =====================================================
  // FAMILY MEMBER CARD
  // =====================================================

  Widget _familyMemberCard(
    BuildContext context,
    Map<String, String> member,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    const Color(0xFFB4869F).withValues(alpha: 0.12),
                child: const Icon(
                  Icons.person_rounded,
                  size: 30,
                  color: Color(0xFFB4869F),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      member['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF30485C),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      member['relationship'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF687780),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      member['phone'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF687780),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  _callFamilyMember(
                    context,
                    member['phone'] ?? '',
                  );
                },
                icon: const Icon(
                  Icons.call_rounded,
                  color: Color(0xFF6C9A7A),
                ),
                label: const Text('Call'),
              ),

              IconButton(
                tooltip: 'Edit',
                onPressed: () {
                  _showFamilyMemberDialog(
                    context,
                    editIndex: index,
                  );
                },
                icon: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF5B7C99),
                ),
              ),

              IconButton(
                tooltip: 'Delete',
                onPressed: () {
                  _confirmDeleteFamilyMember(
                    context,
                    index,
                  );
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD95C5C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // CALL FAMILY MEMBER
  // =====================================================

Future<void> _callFamilyMember(
  BuildContext context,
  String phone,
) async {
  final shouldCall = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          appText(
            english: 'Call Family Member?',
            hindi: 'क्या आप परिवार के सदस्य को कॉल करना चाहते हैं?',
            marathi: 'कुटुंबातील सदस्याला कॉल करायचा आहे का?',
            gujarati: 'શું તમે પરિવારના સભ્યને કૉલ કરવા માંગો છો?',
            telugu: 'మీరు కుటుంబ సభ్యునికి కాల్ చేయాలనుకుంటున్నారా?',
            tamil: 'குடும்ப உறுப்பினரை அழைக்க விரும்புகிறீர்களா?',
            bengali: 'আপনি কি পরিবারের সদস্যকে কল করতে চান?',
            kannada: 'ನೀವು ಕುಟುಂಬದ ಸದಸ್ಯರಿಗೆ ಕರೆ ಮಾಡಲು ಬಯಸುವಿರಾ?',
            malayalam: 'കുടുംബാംഗത്തെ വിളിക്കണോ?',
            punjabi: 'ਕੀ ਤੁਸੀਂ ਪਰਿਵਾਰ ਦੇ ਮੈਂਬਰ ਨੂੰ ਕਾਲ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
            selectedLanguage: widget.selectedLanguage,
          ),
        ),
        content: Text(
          '${appText(
            english: 'Do you want to call',
            hindi: 'क्या आप कॉल करना चाहते हैं',
            marathi: 'तुम्हाला कॉल करायचा आहे का',
            gujarati: 'શું તમે કૉલ કરવા માંગો છો',
            telugu: 'మీరు కాల్ చేయాలనుకుంటున్నారా',
            tamil: 'நீங்கள் அழைக்க விரும்புகிறீர்களா',
            bengali: 'আপনি কি কল করতে চান',
            kannada: 'ನೀವು ಕರೆ ಮಾಡಲು ಬಯಸುವಿರಾ',
            malayalam: 'വിളിക്കണോ',
            punjabi: 'ਕੀ ਤੁਸੀਂ ਕਾਲ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ',
            selectedLanguage: widget.selectedLanguage,
          )} $phone?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: Text(
              appText(
                english: 'Cancel',
                hindi: 'रद्द करें',
                marathi: 'रद्द करा',
                gujarati: 'રદ કરો',
                telugu: 'రద్దు చేయండి',
                tamil: 'ரத்து செய்',
                bengali: 'বাতিল করুন',
                kannada: 'ರದ್ದುಮಾಡಿ',
                malayalam: 'റദ്ദാക്കുക',
                punjabi: 'ਰੱਦ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: Text(
              appText(
                english: 'Call',
                hindi: 'कॉल करें',
                marathi: 'कॉल करा',
                gujarati: 'કૉલ કરો',
                telugu: 'కాల్ చేయండి',
                tamil: 'அழைக்கவும்',
                bengali: 'কল করুন',
                kannada: 'ಕರೆ ಮಾಡಿ',
                malayalam: 'വിളിക്കുക',
                punjabi: 'ਕਾਲ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (shouldCall != true) {
    return;
  }

  final uri = Uri(
    scheme: 'tel',
    path: phone,
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}
  // =====================================================
  // DELETE FAMILY MEMBER
  // =====================================================

  void _confirmDeleteFamilyMember(
    BuildContext context,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Family Member?'),
          content: Text(
            'Remove ${familyMembers[index]['name']} from your family list?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  familyMembers.removeAt(index);
                });

                await _saveFamilyData();

                if (context.mounted) {
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Family member deleted.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // ADD BIRTHDAY
  // =====================================================

  void _showBirthdayDialog(BuildContext context) {
  final nameController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              appText(
                english: 'Add Birthday',
                hindi: 'जन्मदिन जोड़ें',
                marathi: 'वाढदिवस जोडा',
                gujarati: 'જન્મદિવસ ઉમેરો',
                telugu: 'పుట్టినరోజును జోడించండి',
                tamil: 'பிறந்தநாளைச் சேர்க்கவும்',
                bengali: 'জন্মদিন যোগ করুন',
                kannada: 'ಹುಟ್ಟುಹಬ್ಬವನ್ನು ಸೇರಿಸಿ',
                malayalam: 'ജന്മദിനം ചേർക്കുക',
                punjabi: 'ਜਨਮਦਿਨ ਸ਼ਾਮਲ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: appText(
                      english: 'Family member name',
                      hindi: 'परिवार के सदस्य का नाम',
                      marathi: 'कुटुंबातील सदस्याचे नाव',
                      gujarati: 'પરિવારના સભ્યનું નામ',
                      telugu: 'కుటుంబ సభ్యుని పేరు',
                      tamil: 'குடும்ப உறுப்பினரின் பெயர்',
                      bengali: 'পরিবারের সদস্যের নাম',
                      kannada: 'ಕುಟುಂಬದ ಸದಸ್ಯರ ಹೆಸರು',
                      malayalam: 'കുടുംബാംഗത്തിന്റെ പേര്',
                      punjabi: 'ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਦਾ ਨਾਮ',
                      selectedLanguage: widget.selectedLanguage,
                    ),
                    prefixIcon: const Icon(
                      Icons.person_rounded,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                ListTile(
                  leading: const Icon(
                    Icons.cake_rounded,
                  ),
                  title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  subtitle: Text(
                    appText(
                      english: 'Select birthday',
                      hindi: 'जन्मदिन चुनें',
                      marathi: 'वाढदिवस निवडा',
                      gujarati: 'જન્મદિવસ પસંદ કરો',
                      telugu: 'పుట్టినరోజును ఎంచుకోండి',
                      tamil: 'பிறந்தநாளைத் தேர்ந்தெடுக்கவும்',
                      bengali: 'জন্মদিন নির্বাচন করুন',
                      kannada: 'ಹುಟ್ಟುಹಬ್ಬವನ್ನು ಆಯ್ಕೆಮಾಡಿ',
                      malayalam: 'ജന്മദിനം തിരഞ്ഞെടുക്കുക',
                      punjabi: 'ਜਨਮਦਿਨ ਚੁਣੋ',
                      selectedLanguage: widget.selectedLanguage,
                    ),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2100),
                      initialDate: selectedDate,
                    );

                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
              ],
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  appText(
                    english: 'Cancel',
                    hindi: 'रद्द करें',
                    marathi: 'रद्द करा',
                    gujarati: 'રદ કરો',
                    telugu: 'రద్దు చేయండి',
                    tamil: 'ரத்து செய்',
                    bengali: 'বাতিল করুন',
                    kannada: 'ರದ್ದುಮಾಡಿ',
                    malayalam: 'റദ്ദാക്കുക',
                    punjabi: 'ਰੱਦ ਕਰੋ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          appText(
                            english: 'Please enter the family member name.',
                            hindi: 'कृपया परिवार के सदस्य का नाम दर्ज करें।',
                            marathi: 'कृपया कुटुंबातील सदस्याचे नाव प्रविष्ट करा.',
                            gujarati: 'કૃપા કરીને પરિવારના સભ્યનું નામ દાખલ કરો.',
                            telugu: 'దయచేసి కుటుంబ సభ్యుని పేరును నమోదు చేయండి.',
                            tamil: 'குடும்ப உறுப்பினரின் பெயரை உள்ளிடவும்.',
                            bengali: 'অনুগ্রহ করে পরিবারের সদস্যের নাম লিখুন।',
                            kannada: 'ದಯವಿಟ್ಟು ಕುಟುಂಬದ ಸದಸ್ಯರ ಹೆಸರನ್ನು ನಮೂದಿಸಿ.',
                            malayalam: 'കുടുംബാംഗത്തിന്റെ പേര് നൽകുക.',
                            punjabi: 'ਕਿਰਪਾ ਕਰਕੇ ਪਰਿਵਾਰਕ ਮੈਂਬਰ ਦਾ ਨਾਮ ਦਰਜ ਕਰੋ।',
                            selectedLanguage: widget.selectedLanguage,
                          ),
                        ),
                      ),
                    );
                    return;
                  }

                  DateTime birthday = DateTime(
                    DateTime.now().year,
                    selectedDate.month,
                    selectedDate.day,
                  );

                  if (birthday.isBefore(DateTime.now())) {
                    birthday = DateTime(
                      DateTime.now().year + 1,
                      selectedDate.month,
                      selectedDate.day,
                    );
                  }

                  widget.addReminder(
                    Reminder(
                      title:
                          '${nameController.text.trim()}\'s Birthday',
                      details: 'Family birthday',
                      type: 'Birthday',
                      dateTime: birthday,
                    ),
                  );

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        appText(
                          english: 'Birthday reminder added!',
                          hindi: 'जन्मदिन की याद दिलाने वाली सूचना जोड़ दी गई!',
                          marathi: 'वाढदिवसाची आठवण जोडली गेली!',
                          gujarati: 'જન્મદિવસનું રિમાઇન્ડર ઉમેરવામાં આવ્યું!',
                          telugu: 'పుట్టినరోజు రిమైండర్ జోడించబడింది!',
                          tamil: 'பிறந்தநாள் நினைவூட்டல் சேர்க்கப்பட்டது!',
                          bengali: 'জন্মদিনের রিমাইন্ডার যোগ করা হয়েছে!',
                          kannada: 'ಹುಟ್ಟುಹಬ್ಬದ ಜ್ಞಾಪನೆಯನ್ನು ಸೇರಿಸಲಾಗಿದೆ!',
                          malayalam: 'ജന്മദിന റിമൈൻഡർ ചേർത്തു!',
                          punjabi: 'ਜਨਮਦਿਨ ਰਿਮਾਈਂਡਰ ਸ਼ਾਮਲ ਕੀਤਾ ਗਿਆ!',
                          selectedLanguage: widget.selectedLanguage,
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  appText(
                    english: 'Save',
                    hindi: 'सेव करें',
                    marathi: 'जतन करा',
                    gujarati: 'સાચવો',
                    telugu: 'సేవ్ చేయండి',
                    tamil: 'சேமிக்கவும்',
                    bengali: 'সংরক্ষণ করুন',
                    kannada: 'ಉಳಿಸಿ',
                    malayalam: 'സേവ് ചെയ്യുക',
                    punjabi: 'ਸੇਵ ਕਰੋ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
  // =====================================================
  // ADD IMPORTANT DATE
  // =====================================================

void _showImportantDateDialog(BuildContext context) {
  final titleController = TextEditingController();
  final notesController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              appText(
                english: 'Important Date',
                hindi: 'महत्वपूर्ण तारीख',
                marathi: 'महत्त्वाची तारीख',
                gujarati: 'મહત્વપૂર્ણ તારીખ',
                telugu: 'ముఖ్యమైన తేదీ',
                tamil: 'முக்கியமான தேதி',
                bengali: 'গুরুত্বপূর্ণ তারিখ',
                kannada: 'ಪ್ರಮುಖ ದಿನಾಂಕ',
                malayalam: 'പ്രധാനപ്പെട്ട തീയതി',
                punjabi: 'ਮਹੱਤਵਪੂਰਨ ਤਾਰੀਖ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),

            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: appText(
                        english: 'Event name',
                        hindi: 'कार्यक्रम का नाम',
                        marathi: 'कार्यक्रमाचे नाव',
                        gujarati: 'ઇવેન્ટનું નામ',
                        telugu: 'ఈవెంట్ పేరు',
                        tamil: 'நிகழ்வின் பெயர்',
                        bengali: 'অনুষ্ঠানের নাম',
                        kannada: 'ಕಾರ್ಯಕ್ರಮದ ಹೆಸರು',
                        malayalam: 'ഇവന്റിന്റെ പേര്',
                        punjabi: 'ਇਵੈਂਟ ਦਾ ਨਾਮ',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                      hintText: appText(
                        english: 'Example: Anniversary',
                        hindi: 'उदाहरण: सालगिरह',
                        marathi: 'उदाहरण: वर्धापनदिन',
                        gujarati: 'ઉદાહરણ: વર્ષગાંઠ',
                        telugu: 'ఉదాహరణ: వార్షికోత్సవం',
                        tamil: 'உதாரணம்: திருமண நாள்',
                        bengali: 'উদাহরণ: বার্ষিকী',
                        kannada: 'ಉದಾಹರಣೆ: ವಾರ್ಷಿಕೋತ್ಸವ',
                        malayalam: 'ഉദാഹരണം: വാർഷികം',
                        punjabi: 'ਉਦਾਹਰਨ: ਵਰ੍ਹੇਗੰਢ',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                      prefixIcon: const Icon(
                        Icons.event_rounded,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: appText(
                        english: 'Notes',
                        hindi: 'नोट्स',
                        marathi: 'नोंदी',
                        gujarati: 'નોંધ',
                        telugu: 'గమనికలు',
                        tamil: 'குறிப்புகள்',
                        bengali: 'নোট',
                        kannada: 'ಟಿಪ್ಪಣಿಗಳು',
                        malayalam: 'കുറിപ്പുകൾ',
                        punjabi: 'ਨੋਟਸ',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                      hintText: appText(
                        english: 'Add some details',
                        hindi: 'कुछ विवरण जोड़ें',
                        marathi: 'काही तपशील जोडा',
                        gujarati: 'કેટલીક વિગતો ઉમેરો',
                        telugu: 'కొన్ని వివరాలను జోడించండి',
                        tamil: 'சில விவரங்களைச் சேர்க்கவும்',
                        bengali: 'কিছু বিবরণ যোগ করুন',
                        kannada: 'ಕೆಲವು ವಿವರಗಳನ್ನು ಸೇರಿಸಿ',
                        malayalam: 'ചില വിശദാംശങ്ങൾ ചേർക്കുക',
                        punjabi: 'ਕੁਝ ਵੇਰਵੇ ਸ਼ਾਮਲ ਕਰੋ',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                      prefixIcon: const Icon(
                        Icons.notes_rounded,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ListTile(
                    leading: const Icon(
                      Icons.calendar_month_rounded,
                    ),
                    title: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                    subtitle: Text(
                      appText(
                        english: 'Select date',
                        hindi: 'तारीख चुनें',
                        marathi: 'तारीख निवडा',
                        gujarati: 'તારીખ પસંદ કરો',
                        telugu: 'తేదీని ఎంచుకోండి',
                        tamil: 'தேதியைத் தேர்ந்தெடுக்கவும்',
                        bengali: 'তারিখ নির্বাচন করুন',
                        kannada: 'ದಿನಾಂಕವನ್ನು ಆಯ್ಕೆಮಾಡಿ',
                        malayalam: 'തീയതി തിരഞ്ഞെടുക്കുക',
                        punjabi: 'ਤਾਰੀਖ ਚੁਣੋ',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        locale: Locale(
                          widget.selectedLanguage == 'English'
                              ? 'en'
                              : widget.selectedLanguage == 'Hindi'
                                  ? 'hi'
                                  : widget.selectedLanguage == 'Marathi'
                                      ? 'mr'
                                      : widget.selectedLanguage == 'Gujarati'
                                          ? 'gu'
                                          : widget.selectedLanguage == 'Telugu'
                                              ? 'te'
                                              : widget.selectedLanguage == 'Tamil'
                                                  ? 'ta'
                                                  : widget.selectedLanguage == 'Bengali'
                                                      ? 'bn'
                                                      : widget.selectedLanguage == 'Kannada'
                                                          ? 'kn'
                                                          : widget.selectedLanguage == 'Malayalam'
                                                              ? 'ml'
                                                              : 'pa',
                        ),
                        firstDate: DateTime(1950),
                        lastDate: DateTime(2100),
                        initialDate: selectedDate,
                      );

                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  appText(
                    english: 'Cancel',
                    hindi: 'रद्द करें',
                    marathi: 'रद्द करा',
                    gujarati: 'રદ કરો',
                    telugu: 'రద్దు చేయండి',
                    tamil: 'ரத்து செய்',
                    bengali: 'বাতিল করুন',
                    kannada: 'ರದ್ದುಮಾಡಿ',
                    malayalam: 'റദ്ദാക്കുക',
                    punjabi: 'ਰੱਦ ਕਰੋ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),
              ),

              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          appText(
                            english: 'Please enter an event name.',
                            hindi: 'कृपया कार्यक्रम का नाम दर्ज करें।',
                            marathi: 'कृपया कार्यक्रमाचे नाव प्रविष्ट करा.',
                            gujarati: 'કૃપા કરીને ઇવેન્ટનું નામ દાખલ કરો.',
                            telugu: 'దయచేసి ఈవెంట్ పేరును నమోదు చేయండి.',
                            tamil: 'நிகழ்வின் பெயரை உள்ளிடவும்.',
                            bengali: 'অনুগ্রহ করে অনুষ্ঠানের নাম লিখুন।',
                            kannada: 'ದಯವಿಟ್ಟು ಕಾರ್ಯಕ್ರಮದ ಹೆಸರನ್ನು ನಮೂದಿಸಿ.',
                            malayalam: 'ഇവന്റിന്റെ പേര് നൽകുക.',
                            punjabi: 'ਕਿਰਪਾ ਕਰਕੇ ਇਵੈਂਟ ਦਾ ਨਾਮ ਦਰਜ ਕਰੋ।',
                            selectedLanguage: widget.selectedLanguage,
                          ),
                        ),
                      ),
                    );
                    return;
                  }

                  final event = {
                    'title': titleController.text.trim(),
                    'notes': notesController.text.trim(),
                    'date':
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  };

                  setState(() {
                    importantDates.add(event);
                  });

                  await _saveFamilyData();

                  widget.addReminder(
                    Reminder(
                      title: titleController.text.trim(),
                      details:
                          notesController.text.trim().isEmpty
                              ? 'Important date'
                              : notesController.text.trim(),
                      type: 'Important Date',
                      dateTime: selectedDate,
                    ),
                  );

                  if (context.mounted) {
                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          appText(
                            english: 'Important date saved!',
                            hindi: 'महत्वपूर्ण तारीख सेव हो गई!',
                            marathi: 'महत्त्वाची तारीख जतन झाली!',
                            gujarati: 'મહત્વપૂર્ણ તારીખ સાચવવામાં આવી!',
                            telugu: 'ముఖ్యమైన తేదీ సేవ్ చేయబడింది!',
                            tamil: 'முக்கியமான தேதி சேமிக்கப்பட்டது!',
                            bengali: 'গুরুত্বপূর্ণ তারিখ সংরক্ষণ করা হয়েছে!',
                            kannada: 'ಪ್ರಮುಖ ದಿನಾಂಕವನ್ನು ಉಳಿಸಲಾಗಿದೆ!',
                            malayalam: 'പ്രധാനപ്പെട്ട തീയതി സേവ് ചെയ്തു!',
                            punjabi: 'ਮਹੱਤਵਪੂਰਨ ਤਾਰੀਖ ਸੇਵ ਹੋ ਗਈ!',
                            selectedLanguage: widget.selectedLanguage,
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  appText(
                    english: 'Save',
                    hindi: 'सेव करें',
                    marathi: 'जतन करा',
                    gujarati: 'સાચવો',
                    telugu: 'సేవ్ చేయండి',
                    tamil: 'சேமிக்கவும்',
                    bengali: 'সংরক্ষণ করুন',
                    kannada: 'ಉಳಿಸಿ',
                    malayalam: 'സേവ് ചെയ്യുക',
                    punjabi: 'ਸੇਵ ਕਰੋ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
  // =====================================================
  // IMPORTANT DATE CARD
  // =====================================================

  Widget _importantDateCard(
    BuildContext context,
    Map<String, String> date,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor:
                const Color(0xFFD95C5C).withValues(alpha: 0.12),
            child: const Icon(
              Icons.event_rounded,
              size: 30,
              color: Color(0xFFD95C5C),
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  date['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF30485C),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  date['date'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD95C5C),
                  ),
                ),

                if ((date['notes'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    date['notes'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF687780),
                    ),
                  ),
                ],
              ],
            ),
          ),

          IconButton(
            tooltip: 'Delete',
            onPressed: () {
              _confirmDeleteImportantDate(
                context,
                index,
              );
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFD95C5C),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DELETE IMPORTANT DATE
  // =====================================================

void _confirmDeleteImportantDate(
  BuildContext context,
  int index,
) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          appText(
            english: 'Delete Important Date?',
            hindi: 'महत्वपूर्ण तारीख हटाएं?',
            marathi: 'महत्त्वाची तारीख हटवायची?',
            gujarati: 'મહત્વપૂર્ણ તારીખ કાઢી નાખવી છે?',
            telugu: 'ముఖ్యమైన తేదీని తొలగించాలా?',
            tamil: 'முக்கியமான தேதியை நீக்கவா?',
            bengali: 'গুরুত্বপূর্ণ তারিখ মুছে ফেলবেন?',
            kannada: 'ಪ್ರಮುಖ ದಿನಾಂಕವನ್ನು ಅಳಿಸಬೇಕೇ?',
            malayalam: 'പ്രധാനപ്പെട്ട തീയതി ഇല്ലാതാക്കണോ?',
            punjabi: 'ਮਹੱਤਵਪੂਰਨ ਤਾਰੀਖ ਮਿਟਾਉਣੀ ਹੈ?',
            selectedLanguage: widget.selectedLanguage,
          ),
        ),
        content: Text(
          '${appText(
            english: 'Delete',
            hindi: 'हटाएं',
            marathi: 'हटवा',
            gujarati: 'કાઢી નાખો',
            telugu: 'తొలగించండి',
            tamil: 'நீக்கு',
            bengali: 'মুছুন',
            kannada: 'ಅಳಿಸಿ',
            malayalam: 'ഇല്ലാതാക്കുക',
            punjabi: 'ਮਿਟਾਓ',
            selectedLanguage: widget.selectedLanguage,
          )} "${importantDates[index]['title']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              appText(
                english: 'Cancel',
                hindi: 'रद्द करें',
                marathi: 'रद्द करा',
                gujarati: 'રદ કરો',
                telugu: 'రద్దు చేయండి',
                tamil: 'ரத்து செய்',
                bengali: 'বাতিল করুন',
                kannada: 'ರದ್ದುಮಾಡಿ',
                malayalam: 'റദ്ദാക്കുക',
                punjabi: 'ਰੱਦ ਕਰੋ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              setState(() {
                importantDates.removeAt(index);
              });

              await _saveFamilyData();

              if (context.mounted) {
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      appText(
                        english: 'Important date deleted.',
                        hindi: 'महत्वपूर्ण तारीख हटा दी गई।',
                        marathi: 'महत्त्वाची तारीख हटवली आहे.',
                        gujarati: 'મહત્વપૂર્ણ તારીખ કાઢી નાખવામાં આવી.',
                        telugu: 'ముఖ్యమైన తేదీ తొలగించబడింది.',
                        tamil: 'முக்கியமான தேதி நீக்கப்பட்டது.',
                        bengali: 'গুরুত্বপূর্ণ তারিখ মুছে ফেলা হয়েছে।',
                        kannada: 'ಪ್ರಮುಖ ದಿನಾಂಕವನ್ನು ಅಳಿಸಲಾಗಿದೆ.',
                        malayalam: 'പ്രധാനപ്പെട്ട തീയതി ഇല്ലാതാക്കി.',
                        punjabi: 'ਮਹੱਤਵਪੂਰਨ ਤਾਰੀਖ ਮਿਟਾ ਦਿੱਤੀ ਗਈ ਹੈ।',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                );
              }
            },
            child: Text(
              appText(
                english: 'Delete',
                hindi: 'हटाएं',
                marathi: 'हटवा',
                gujarati: 'કાઢી નાખો',
                telugu: 'తొలగించండి',
                tamil: 'நீக்கு',
                bengali: 'মুছুন',
                kannada: 'ಅಳಿಸಿ',
                malayalam: 'ഇല്ലാതാക്കുക',
                punjabi: 'ਮਿਟਾਓ',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          ),
        ],
      );
    },
  );
}   

  // =====================================================
  // BIG ACTION CARD
  // =====================================================

  Widget _bigActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: color,
              ),
            ),

            const SizedBox(width: 17),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF30485C),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF687780),
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xFF89949B),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// LEARN APPS
// =====================================================

class LearnAppsPage extends StatelessWidget {
  final String selectedLanguage;

  const LearnAppsPage({
    super.key,
    required this.selectedLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return SimplePage(
title: appText(
  english: 'Learn Apps',
  hindi: 'ऐप्स सीखें',
  marathi: 'अॅप्स शिका',
  gujarati: 'એપ્સ શીખો',
  telugu: 'యాప్‌లను నేర్చుకోండి',
  tamil: 'ஆப்களை கற்றுக்கொள்ளுங்கள்',
  bengali: 'অ্যাপ শিখুন',
  kannada: 'ಆ್ಯಪ್‌ಗಳನ್ನು ಕಲಿಯಿರಿ',
  malayalam: 'ആപ്പുകൾ പഠിക്കൂ',
  punjabi: 'ਐਪਸ ਸਿੱਖੋ',
  selectedLanguage: selectedLanguage,
),
subtitle: appText(
  english: 'Learn popular apps step by step.',
  hindi: 'लोकप्रिय ऐप्स को चरण-दर-चरण सीखें।',
  marathi: 'लोकप्रिय अॅप्स चरण-दर-चरण शिका.',
  gujarati: 'લોકપ્રિય એપ્સને પગલું-દર-પગલું શીખો.',
  telugu: 'ప్రసిద్ధ యాప్‌లను దశలవారీగా నేర్చుకోండి.',
  tamil: 'பிரபலமான ஆப்களை படிப்படியாக கற்றுக்கொள்ளுங்கள்.',
  bengali: 'জনপ্রিয় অ্যাপগুলি ধাপে ধাপে শিখুন।',
  kannada: 'ಜನಪ್ರಿಯ ಆ್ಯಪ್‌ಗಳನ್ನು ಹಂತ ಹಂತವಾಗಿ ಕಲಿಯಿರಿ.',
  malayalam: 'ജനപ്രിയ ആപ്പുകൾ ഘട്ടം ഘട്ടമായി പഠിക്കൂ.',
  punjabi: 'ਪ੍ਰਸਿੱਧ ਐਪਸ ਨੂੰ ਕਦਮ-ਦਰ-ਕਦਮ ਸਿੱਖੋ।',
  selectedLanguage: selectedLanguage,
),
      icon: Icons.smartphone_rounded,
      iconColor: const Color(0xFF8A7BA8),
      children: [
       _infoCard(
  Icons.chat_rounded,
  appText(
    english: 'WhatsApp',
    hindi: 'व्हाट्सऐप',
    marathi: 'व्हॉट्सअॅप',
    gujarati: 'વોટ્સએપ',
    telugu: 'వాట్సాప్',
    tamil: 'வாட்ஸ்அப்',
    bengali: 'হোয়াটসঅ্যাপ',
    kannada: 'ವಾಟ್ಸಾಪ್',
    malayalam: 'വാട്സ്ആപ്പ്',
    punjabi: 'ਵਟਸਐਪ',
    selectedLanguage: selectedLanguage,
  ),
  appText(
    english: 'Learn messages, calls, photos and video calls.',
    hindi: 'मैसेज, कॉल, फोटो और वीडियो कॉल सीखें।',
    marathi: 'मेसेज, कॉल, फोटो आणि व्हिडिओ कॉल शिका.',
    gujarati: 'મેસેજ, કૉલ, ફોટા અને વિડિયો કૉલ શીખો.',
    telugu: 'మెసేజ్‌లు, కాల్స్, ఫోటోలు మరియు వీడియో కాల్స్ నేర్చుకోండి.',
    tamil: 'செய்திகள், அழைப்புகள், புகைப்படங்கள் மற்றும் வீடியோ அழைப்புகளை கற்றுக்கொள்ளுங்கள்.',
    bengali: 'মেসেজ, কল, ছবি এবং ভিডিও কল সম্পর্কে শিখুন।',
    kannada: 'ಸಂದೇಶಗಳು, ಕರೆಗಳು, ಫೋಟೋಗಳು ಮತ್ತು ವೀಡಿಯೊ ಕರೆಗಳನ್ನು ಕಲಿಯಿರಿ.',
    malayalam: 'മെസേജുകൾ, കോളുകൾ, ഫോട്ടോകൾ, വീഡിയോ കോളുകൾ എന്നിവ പഠിക്കൂ.',
    punjabi: 'ਮੈਸੇਜ, ਕਾਲ, ਫੋਟੋਆਂ ਅਤੇ ਵੀਡੀਓ ਕਾਲਾਂ ਬਾਰੇ ਸਿੱਖੋ।',
    selectedLanguage: selectedLanguage,
  ),
  const Color(0xFF6C9A7A),
  onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WhatsAppTutorialPage(
        selectedLanguage: selectedLanguage,
      ),
    ),
  );
},
),
        _infoCard(
          Icons.play_circle_fill_rounded,
          appText(
  english: 'YouTube',
  hindi: 'यूट्यूब',
  marathi: 'यूट्यूब',
  gujarati: 'યૂટ્યુબ',
  telugu: 'యూట్యూబ్',
  tamil: 'யூடியூப்',
  bengali: 'ইউটিউব',
  kannada: 'ಯೂಟ್ಯೂಬ್',
  malayalam: 'യൂട്യൂബ്',
  punjabi: 'ਯੂਟਿਊਬ',
  selectedLanguage: selectedLanguage,
),
          appText(
  english: 'Learn how to search, watch and control videos.',
  hindi: 'वीडियो खोजना, देखना और नियंत्रित करना सीखें।',
  marathi: 'व्हिडिओ शोधणे, पाहणे आणि नियंत्रित करणे शिका.',
  gujarati: 'વિડિઓ શોધવા, જોવા અને નિયંત્રિત કરવાનું શીખો.',
  telugu: 'వీడియోలను వెతకడం, చూడడం మరియు నియంత్రించడం నేర్చుకోండి.',
  tamil: 'வீடியோக்களைத் தேடுவது, பார்ப்பது மற்றும் கட்டுப்படுத்துவது எப்படி என்பதை கற்றுக்கொள்ளுங்கள்.',
  bengali: 'ভিডিও খোঁজা, দেখা এবং নিয়ন্ত্রণ করা শিখুন।',
  kannada: 'ವೀಡಿಯೊಗಳನ್ನು ಹುಡುಕುವುದು, ನೋಡುವುದು ಮತ್ತು ನಿಯಂತ್ರಿಸುವುದನ್ನು ಕಲಿಯಿರಿ.',
  malayalam: 'വീഡിയോകൾ തിരയാനും കാണാനും നിയന്ത്രിക്കാനും പഠിക്കൂ.',
  punjabi: 'ਵੀਡੀਓ ਖੋਜਣਾ, ਦੇਖਣਾ ਅਤੇ ਕੰਟਰੋਲ ਕਰਨਾ ਸਿੱਖੋ।',
  selectedLanguage: selectedLanguage,
),
          const Color(0xFFD95C5C),
        ),
        _infoCard(
          Icons.people_rounded,
          appText(
  english: 'Facebook',
  hindi: 'फेसबुक',
  marathi: 'फेसबुक',
  gujarati: 'ફેસબુક',
  telugu: 'ఫేస్‌బుక్',
  tamil: 'ஃபேஸ்புக்',
  bengali: 'ফেসবুক',
  kannada: 'ಫೇಸ್‌ಬುಕ್',
  malayalam: 'ഫേസ്ബുക്ക്',
  punjabi: 'ਫੇਸਬੁੱਕ',
  selectedLanguage: selectedLanguage,
),
          appText(
  english: 'Learn posts, friends, photos and messages.',
  hindi: 'पोस्ट, दोस्त, फोटो और मैसेज के बारे में सीखें।',
  marathi: 'पोस्ट, मित्र, फोटो आणि मेसेज याबद्दल शिका.',
  gujarati: 'પોસ્ટ, મિત્રો, ફોટા અને મેસેજ વિશે શીખો.',
  telugu: 'పోస్ట్‌లు, స్నేహితులు, ఫోటోలు మరియు మెసేజ్‌లను నేర్చుకోండి.',
  tamil: 'பதிவுகள், நண்பர்கள், புகைப்படங்கள் மற்றும் செய்திகளைப் பற்றி கற்றுக்கொள்ளுங்கள்.',
  bengali: 'পোস্ট, বন্ধু, ছবি এবং মেসেজ সম্পর্কে শিখুন।',
  kannada: 'ಪೋಸ್ಟ್‌ಗಳು, ಸ್ನೇಹಿತರು, ಫೋಟೋಗಳು ಮತ್ತು ಸಂದೇಶಗಳ ಬಗ್ಗೆ ಕಲಿಯಿರಿ.',
  malayalam: 'പോസ്റ്റുകൾ, സുഹൃത്തുക്കൾ, ഫോട്ടോകൾ, മെസേജുകൾ എന്നിവ പഠിക്കൂ.',
  punjabi: 'ਪੋਸਟਾਂ, ਦੋਸਤਾਂ, ਫੋਟੋਆਂ ਅਤੇ ਮੈਸੇਜਾਂ ਬਾਰੇ ਸਿੱਖੋ।',
  selectedLanguage: selectedLanguage,
),
          const Color(0xFF5B7C99),
        ),
        _infoCard(
          Icons.language_rounded,
          appText(
  english: 'Choose Language',
  hindi: 'भाषा चुनें',
  marathi: 'भाषा निवडा',
  gujarati: 'ભાષા પસંદ કરો',
  telugu: 'భాషను ఎంచుకోండి',
  tamil: 'மொழியைத் தேர்ந்தெடுக்கவும்',
  bengali: 'ভাষা নির্বাচন করুন',
  kannada: 'ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ',
  malayalam: 'ഭാഷ തിരഞ്ഞെടുക്കുക',
  punjabi: 'ਭਾਸ਼ਾ ਚੁਣੋ',
  selectedLanguage: selectedLanguage,
),
appText(
  english: 'English • Hindi • Marathi',
  hindi: 'अंग्रेज़ी • हिंदी • मराठी',
  marathi: 'इंग्रजी • हिंदी • मराठी',
  gujarati: 'અંગ્રેજી • હિન્દી • મરાઠી',
  telugu: 'ఇంగ్లీష్ • హిందీ • మరాఠీ',
  tamil: 'ஆங்கிலம் • இந்தி • மராத்தி',
  bengali: 'ইংরেজি • হিন্দি • মারাঠি',
  kannada: 'ಇಂಗ್ಲಿಷ್ • ಹಿಂದಿ • ಮರಾಠಿ',
  malayalam: 'ഇംഗ്ലീഷ് • ഹിന്ദി • മറാത്തി',
  punjabi: 'ਅੰਗਰੇਜ਼ੀ • ਹਿੰਦੀ • ਮਰਾਠੀ',
  selectedLanguage: selectedLanguage,
),
          const Color(0xFF8A7BA8),
        ),
      ],
    );
  }
}

// =====================================================
// REMINDERS PAGE
// =====================================================

class RemindersPage extends StatefulWidget {
  final List<Reminder> reminders;
  final Function(Reminder) deleteReminder;
  final Function(Reminder, Reminder) editReminder;
final Function(Reminder) toggleTaken;
final String selectedLanguage;

  const RemindersPage({
    super.key,
    required this.reminders,
    required this.deleteReminder,
    required this.editReminder,
    required this.toggleTaken,
required this.selectedLanguage,
  });

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.reminders.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F5F0),
        appBar: AppBar(
title: Text(
  appText(
    english: 'My Reminders',
    hindi: 'मेरे रिमाइंडर',
    marathi: 'माझे रिमाइंडर',
    gujarati: 'મારા રિમાઇન્ડર્સ',
    telugu: 'నా రిమైండర్లు',
    tamil: 'என் நினைவூட்டல்கள்',
    bengali: 'আমার রিমাইন্ডার',
    kannada: 'ನನ್ನ ಜ್ಞಾಪನೆಗಳು',
    malayalam: 'എന്റെ റിമൈൻഡറുകൾ',
    punjabi: 'ਮੇਰੇ ਰਿਮਾਈਂਡਰ',
    selectedLanguage: widget.selectedLanguage,
  ),
  style: const TextStyle(
    fontWeight: FontWeight.bold,
    color: Color(0xFF263B4A),
  ),
),

          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 80,
                  color: Color(0xFF89949B),
                ),
                SizedBox(height: 20),
Text(
  appText(
    english: 'No reminders yet',
    hindi: 'अभी कोई रिमाइंडर नहीं है',
    marathi: 'अजून कोणतेही रिमाइंडर नाहीत',
    gujarati: 'હજુ સુધી કોઈ રિમાઇન્ડર નથી',
    telugu: 'ఇంకా రిమైండర్లు లేవు',
    tamil: 'இன்னும் நினைவூட்டல்கள் இல்லை',
    bengali: 'এখনও কোনো রিমাইন্ডার নেই',
    kannada: 'ಇನ್ನೂ ಯಾವುದೇ ಜ್ಞಾಪನೆಗಳಿಲ್ಲ',
    malayalam: 'ഇതുവരെ റിമൈൻഡറുകളൊന്നുമില്ല',
    punjabi: 'ਅਜੇ ਕੋਈ ਰਿਮਾਈਂਡਰ ਨਹੀਂ ਹੈ',
    selectedLanguage: widget.selectedLanguage,
  ),
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF30485C),
  ),
),
                    
                SizedBox(height: 10),
                Text(
  appText(
    english: 'Add a medicine, birthday or doctor appointment.',
    hindi: 'दवा, जन्मदिन या डॉक्टर की अपॉइंटमेंट जोड़ें।',
    marathi: 'औषध, वाढदिवस किंवा डॉक्टरची अपॉइंटमेंट जोडा.',
    gujarati: 'દવા, જન્મદિવસ અથવા ડૉક્ટરની મુલાકાત ઉમેરો.',
    telugu: 'మందు, పుట్టినరోజు లేదా డాక్టర్ అపాయింట్‌మెంట్‌ను జోడించండి.',
    tamil: 'மருந்து, பிறந்தநாள் அல்லது மருத்துவர் சந்திப்பைச் சேர்க்கவும்.',
    bengali: 'ওষুধ, জন্মদিন বা ডাক্তারের অ্যাপয়েন্টমেন্ট যোগ করুন।',
    kannada: 'ಔಷಧಿ, ಹುಟ್ಟುಹಬ್ಬ ಅಥವಾ ವೈದ್ಯರ ಅಪಾಯಿಂಟ್‌ಮೆಂಟ್ ಸೇರಿಸಿ.',
    malayalam: 'മരുന്ന്, ജന്മദിനം അല്ലെങ്കിൽ ഡോക്ടറുടെ അപ്പോയിന്റ്മെന്റ് ചേർക്കുക.',
    punjabi: 'ਦਵਾਈ, ਜਨਮਦਿਨ ਜਾਂ ਡਾਕਟਰ ਦੀ ਅਪਾਇੰਟਮੈਂਟ ਸ਼ਾਮਲ ਕਰੋ।',
    selectedLanguage: widget.selectedLanguage,
  ),
  textAlign: TextAlign.center,
  style: const TextStyle(
    fontSize: 17,
    color: Color(0xFF687780),
  ),
),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: const Text(
          'My Reminders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF263B4A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(22),
        itemCount: widget.reminders.length,
        itemBuilder: (context, index) {
          final reminder = widget.reminders[index];

          return _reminderCard(
            context,
            reminder,
          );
        },
      ),
    );
  }

  Widget _reminderCard(
    BuildContext context,
    Reminder reminder,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor:
                    _reminderColor(reminder.type).withValues(alpha: 0.12),
                child: Icon(
                  _reminderIcon(reminder.type),
                  color: _reminderColor(reminder.type),
                  size: 32,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: reminder.isTaken
                            ? Colors.grey
                            : const Color(0xFF30485C),
                        decoration: reminder.isTaken
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      reminder.details,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF687780),
                      ),
                    ),

                    const SizedBox(height: 7),

// DATE & TIME
Text(
  '${reminder.dateTime.day}/${reminder.dateTime.month}/${reminder.dateTime.year}  •  ${TimeOfDay.fromDateTime(reminder.dateTime).format(context)}',
  style: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF5B7C99),
  ),
),

const SizedBox(height: 5),

// SCHEDULE
Text(
  _getScheduleText(reminder),
  style: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6C9A7A),
  ),
),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // TAKEN BUTTON
              if (reminder.type == 'Medicine')
                TextButton.icon(
                  onPressed: () {
                    widget.toggleTaken(reminder);

                    setState(() {});
                  },
                  icon: Icon(
                    reminder.isTaken
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: const Color(0xFF6C9A7A),
                  ),
                  label: Text(
                    reminder.isTaken ? 'Taken' : 'Mark Taken',
                  ),
                ),

              // EDIT BUTTON
              IconButton(
                tooltip: 'Edit',
                onPressed: () {
                  _editReminderDialog(
                    context,
                    reminder,
                  );
                },
                icon: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF5B7C99),
                ),
              ),

              // DELETE BUTTON
              IconButton(
tooltip: appText(
  english: 'Delete',
  hindi: 'हटाएं',
  marathi: 'हटवा',
  gujarati: 'કાઢી નાખો',
  telugu: 'తొలగించండి',
  tamil: 'நீக்கு',
  bengali: 'মুছুন',
  kannada: 'ಅಳಿಸಿ',
  malayalam: 'ഇല്ലാതാക്കുക',
  punjabi: 'ਮਿਟਾਓ',
  selectedLanguage: widget.selectedLanguage,
),                onPressed: () {
                  _confirmDelete(
                    context,
                    reminder,
                  );
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD95C5C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DELETE CONFIRMATION
  // =====================================================

  void _confirmDelete(
    BuildContext context,
    Reminder reminder,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Reminder?'),
          content: Text(
            'Are you sure you want to delete "${reminder.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD95C5C),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // ACTUAL DELETE
                widget.deleteReminder(reminder);

                Navigator.pop(dialogContext);

                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder deleted successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // EDIT REMINDER
  // =====================================================
String _getScheduleText(Reminder reminder) {
  if (reminder.scheduleType == 'daily') {
    return '🔁 Every day';
  }

  if (reminder.scheduleType == 'once') {
    return '📌 Once';
  }

  if (reminder.scheduleType == 'selectedDays') {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    if (reminder.selectedDays.isEmpty) {
      return '📅 Selected days';
    }

    final selectedDayNames = reminder.selectedDays
        .where((day) => day >= 1 && day <= 7)
        .map((day) => days[day - 1])
        .toList();

    return '📅 ${selectedDayNames.join(', ')}';
  }

  return '🔁 Every day';
}

  void _editReminderDialog(
    BuildContext context,
    Reminder reminder,
  ) {
    final titleController =
        TextEditingController(text: reminder.title);

    final detailsController =
        TextEditingController(text: reminder.details);

    DateTime selectedDate = reminder.dateTime;

    TimeOfDay selectedTime =
        TimeOfDay.fromDateTime(reminder.dateTime);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Reminder'),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        prefixIcon:
                            Icon(Icons.description_rounded),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ListTile(
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                      ),
                      title: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: selectedDate,
                        );

                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),

                    ListTile(
                      leading: const Icon(
                        Icons.access_time_rounded,
                      ),
                      title: Text(
                        selectedTime.format(context),
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );

                        if (time != null) {
                          setDialogState(() {
                            selectedTime = time;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      return;
                    }

                    final newDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final updatedReminder = Reminder(
                      title: titleController.text.trim(),
                      details: detailsController.text.trim(),
                      type: reminder.type,
                      dateTime: newDateTime,
                      isTaken: reminder.isTaken,
                    );

                    widget.editReminder(
                      reminder,
                      updatedReminder,
                    );

                    Navigator.pop(dialogContext);

                    setState(() {});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Reminder updated successfully'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _reminderColor(String type) {
    switch (type) {
      case 'Medicine':
        return const Color(0xFF6C9A7A);

      case 'Birthday':
        return const Color(0xFFB4869F);

      case 'Health':
        return const Color(0xFF6B8EAD);

      default:
        return const Color(0xFFC28B57);
    }
  }

  IconData _reminderIcon(String type) {
    switch (type) {
      case 'Medicine':
        return Icons.medication_rounded;

      case 'Birthday':
        return Icons.cake_rounded;

      case 'Health':
        return Icons.medical_services_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }
}


Widget _bigActionCard(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
  Color color, {
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 34,
              color: color,
            ),
          ),

          const SizedBox(width: 17),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF30485C),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF687780),
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 18,
            color: Color(0xFF89949B),
          ),
        ],
      ),
    ),
  );
}
// =====================================================
// INFO CARD
// =====================================================

Widget _infoCard(
  IconData icon,
  String title,
  String subtitle,
  Color color, {
  VoidCallback? onTap,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          blurRadius: 10,
          offset: const Offset(0, 4),
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ],
    ),
    child: InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(22),
  child: Row(
    children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            icon,
            size: 32,
            color: color,
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF30485C),
                ),
              ),

              const SizedBox(height: 5),

              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF687780),
                ),
              ),
            ],
          ),
        ),

        const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 18,
          color: Color(0xFF89949B),
               ),
      ],
    ),
  ),
);
}
// =====================================================
// WHATSAPP TUTORIAL PAGE
// =====================================================

class WhatsAppTutorialPage extends StatefulWidget {
  final String selectedLanguage;

  const WhatsAppTutorialPage({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<WhatsAppTutorialPage> createState() =>
      _WhatsAppTutorialPageState();
}

class _WhatsAppTutorialPageState
    extends State<WhatsAppTutorialPage> {
  int currentStep = 0;

  final List<Map<String, String>> steps = [
    {
      'title': 'Open WhatsApp',
      'description': 'Tap the WhatsApp icon to open the app.',
    },
    {
      'title': 'Send a Message',
      'description': 'Choose a contact, type your message and tap Send.',
    },
    {
      'title': 'Make a Voice Call',
      'description': 'Open a contact and tap the phone icon.',
    },
    {
      'title': 'Make a Video Call',
      'description': 'Open a contact and tap the video camera icon.',
    },
    {
      'title': 'Send a Photo',
      'description': 'Tap the camera or attachment icon and choose a photo.',
    },
    {
      'title': 'Play a Voice Message',
      'description': 'Tap the play button to listen to a voice message.',
    },
  ];
    String getStepTitle(int step) {
    switch (step) {
      case 0:
        return appText(
          english: 'Open WhatsApp',
          hindi: 'व्हाट्सऐप खोलें',
          marathi: 'व्हॉट्सअॅप उघडा',
          gujarati: 'વોટ્સએપ ખોલો',
          telugu: 'వాట్సాప్ తెరవండి',
          tamil: 'வாட்ஸ்அப்பைத் திறக்கவும்',
          bengali: 'হোয়াটসঅ্যাপ খুলুন',
          kannada: 'ವಾಟ್ಸಾಪ್ ತೆರೆಯಿರಿ',
          malayalam: 'വാട്സ്ആപ്പ് തുറക്കുക',
          punjabi: 'ਵਟਸਐਪ ਖੋਲ੍ਹੋ',
          selectedLanguage: widget.selectedLanguage,
        );

      case 1:
        return appText(
          english: 'Send a Message',
          hindi: 'मैसेज भेजें',
          marathi: 'मेसेज पाठवा',
          gujarati: 'મેસેજ મોકલો',
          telugu: 'మెసేజ్ పంపండి',
          tamil: 'செய்தி அனுப்பவும்',
          bengali: 'মেসেজ পাঠান',
          kannada: 'ಸಂದೇಶ ಕಳುಹಿಸಿ',
          malayalam: 'മെസേജ് അയയ്ക്കുക',
          punjabi: 'ਮੈਸੇਜ ਭੇਜੋ',
          selectedLanguage: widget.selectedLanguage,
        );

      case 2:
        return appText(
          english: 'Make a Voice Call',
          hindi: 'वॉइस कॉल करें',
          marathi: 'व्हॉइस कॉल करा',
          gujarati: 'વૉઇસ કૉલ કરો',
          telugu: 'వాయిస్ కాల్ చేయండి',
          tamil: 'குரல் அழைப்பு செய்யவும்',
          bengali: 'ভয়েস কল করুন',
          kannada: 'ವಾಯ್ಸ್ ಕರೆ ಮಾಡಿ',
          malayalam: 'വോയ്സ് കോൾ ചെയ്യുക',
          punjabi: 'ਵੌਇਸ ਕਾਲ ਕਰੋ',
          selectedLanguage: widget.selectedLanguage,
        );

      case 3:
        return appText(
          english: 'Make a Video Call',
          hindi: 'वीडियो कॉल करें',
          marathi: 'व्हिडिओ कॉल करा',
          gujarati: 'વિડિયો કૉલ કરો',
          telugu: 'వీడియో కాల్ చేయండి',
          tamil: 'வீடியோ அழைப்பு செய்யவும்',
          bengali: 'ভিডিও কল করুন',
          kannada: 'ವೀಡಿಯೊ ಕರೆ ಮಾಡಿ',
          malayalam: 'വീഡിയോ കോൾ ചെയ്യുക',
          punjabi: 'ਵੀਡੀਓ ਕਾਲ ਕਰੋ',
          selectedLanguage: widget.selectedLanguage,
        );

      case 4:
        return appText(
          english: 'Send a Photo',
          hindi: 'फोटो भेजें',
          marathi: 'फोटो पाठवा',
          gujarati: 'ફોટો મોકલો',
          telugu: 'ఫోటో పంపండి',
          tamil: 'புகைப்படம் அனுப்பவும்',
          bengali: 'ছবি পাঠান',
          kannada: 'ಫೋಟೋ ಕಳುಹಿಸಿ',
          malayalam: 'ഫോട്ടോ അയയ്ക്കുക',
          punjabi: 'ਫੋਟੋ ਭੇਜੋ',
          selectedLanguage: widget.selectedLanguage,
        );

      case 5:
        return appText(
          english: 'Play a Voice Message',
          hindi: 'वॉइस मैसेज चलाएं',
          marathi: 'व्हॉइस मेसेज प्ले करा',
          gujarati: 'વૉઇસ મેસેજ ચલાવો',
          telugu: 'వాయిస్ మెసేజ్ ప్లే చేయండి',
          tamil: 'குரல் செய்தியை இயக்கவும்',
          bengali: 'ভয়েস মেসেজ চালান',
          kannada: 'ವಾಯ್ಸ್ ಮೆಸೇಜ್ ಪ್ಲೇ ಮಾಡಿ',
          malayalam: 'വോയ്സ് മെസേജ് പ്ലേ ചെയ്യുക',
          punjabi: 'ਵੌਇਸ ਮੈਸੇਜ ਚਲਾਓ',
          selectedLanguage: widget.selectedLanguage,
        );

      default:
        return '';
    }
  }
    String getStepDescription(int step) {
    switch (step) {
      case 0:
        return appText(
          english: 'Tap the WhatsApp icon to open the app.',
          hindi: 'ऐप खोलने के लिए व्हाट्सऐप आइकन पर टैप करें।',
          marathi: 'अॅप उघडण्यासाठी व्हॉट्सअॅप आयकॉनवर टॅप करा.',
          gujarati: 'એપ ખોલવા માટે વોટ્સએપ આઇકન પર ટેપ કરો.',
          telugu: 'యాప్‌ను తెరవడానికి వాట్సాప్ ఐకాన్‌పై ట్యాప్ చేయండి.',
          tamil: 'ஆப்பைத் திறக்க வாட்ஸ்அப் ஐகானைத் தட்டவும்.',
          bengali: 'অ্যাপটি খুলতে হোয়াটসঅ্যাপ আইকনে ট্যাপ করুন।',
          kannada: 'ಆ್ಯಪ್ ತೆರೆಯಲು ವಾಟ್ಸಾಪ್ ಐಕಾನ್ ಮೇಲೆ ಟ್ಯಾಪ್ ಮಾಡಿ.',
          malayalam: 'ആപ്പ് തുറക്കാൻ വാട്സ്ആപ്പ് ഐക്കണിൽ ടാപ്പ് ചെയ്യുക.',
          punjabi: 'ਐਪ ਖੋਲ੍ਹਣ ਲਈ ਵਟਸਐਪ ਆਈਕਨ ਤੇ ਟੈਪ ਕਰੋ।',
          selectedLanguage: widget.selectedLanguage,
        );

      case 1:
        return appText(
          english: 'Choose a contact, type your message and tap Send.',
          hindi: 'किसी संपर्क को चुनें, अपना मैसेज लिखें और भेजें पर टैप करें।',
          marathi: 'संपर्क निवडा, तुमचा मेसेज टाइप करा आणि पाठवा वर टॅप करा.',
          gujarati: 'સંપર્ક પસંદ કરો, તમારો મેસેજ લખો અને મોકલો પર ટેપ કરો.',
          telugu: 'ఒక కాంటాక్ట్‌ను ఎంచుకుని, మీ మెసేజ్ టైప్ చేసి పంపండి.',
          tamil: 'ஒரு தொடர்பைத் தேர்ந்தெடுத்து, உங்கள் செய்தியைத் தட்டச்சு செய்து அனுப்பவும்.',
          bengali: 'একটি পরিচিতি বেছে নিয়ে, আপনার মেসেজ লিখে পাঠান।',
          kannada: 'ಸಂಪರ್ಕವನ್ನು ಆಯ್ಕೆ ಮಾಡಿ, ನಿಮ್ಮ ಸಂದೇಶವನ್ನು ಟೈಪ್ ಮಾಡಿ ಮತ್ತು ಕಳುಹಿಸಿ.',
          malayalam: 'ഒരു കോൺടാക്ട് തിരഞ്ഞെടുക്കുക, മെസേജ് ടൈപ്പ് ചെയ്ത് അയയ്ക്കുക.',
          punjabi: 'ਕਿਸੇ ਸੰਪਰਕ ਨੂੰ ਚੁਣੋ, ਆਪਣਾ ਮੈਸੇਜ ਲਿਖੋ ਅਤੇ ਭੇਜੋ ਤੇ ਟੈਪ ਕਰੋ।',
          selectedLanguage: widget.selectedLanguage,
        );

      case 2:
        return appText(
          english: 'Open a contact and tap the phone icon.',
          hindi: 'संपर्क खोलें और फोन आइकन पर टैप करें।',
          marathi: 'संपर्क उघडा आणि फोन आयकॉनवर टॅप करा.',
          gujarati: 'સંપર્ક ખોલો અને ફોન આઇકન પર ટેપ કરો.',
          telugu: 'కాంటాక్ట్‌ను తెరిచి ఫోన్ ఐకాన్‌పై ట్యాప్ చేయండి.',
          tamil: 'ஒரு தொடர்பைத் திறந்து தொலைபேசி ஐகானைத் தட்டவும்.',
          bengali: 'একটি পরিচিতি খুলে ফোন আইকনে ট্যাপ করুন।',
          kannada: 'ಸಂಪರ್ಕವನ್ನು ತೆರೆಯಿರಿ ಮತ್ತು ಫೋನ್ ಐಕಾನ್ ಮೇಲೆ ಟ್ಯಾಪ್ ಮಾಡಿ.',
          malayalam: 'ഒരു കോൺടാക്ട് തുറന്ന് ഫോൺ ഐക്കണിൽ ടാപ്പ് ചെയ്യുക.',
          punjabi: 'ਸੰਪਰਕ ਖੋਲ੍ਹੋ ਅਤੇ ਫੋਨ ਆਈਕਨ ਤੇ ਟੈਪ ਕਰੋ।',
          selectedLanguage: widget.selectedLanguage,
        );

      case 3:
        return appText(
          english: 'Open a contact and tap the video camera icon.',
          hindi: 'संपर्क खोलें और वीडियो कैमरा आइकन पर टैप करें।',
          marathi: 'संपर्क उघडा आणि व्हिडिओ कॅमेरा आयकॉनवर टॅप करा.',
          gujarati: 'સંપર્ક ખોલો અને વિડિયો કેમેરા આઇકન પર ટેપ કરો.',
          telugu: 'కాంటాక్ట్‌ను తెరిచి వీడియో కెమెరా ఐకాన్‌పై ట్యాప్ చేయండి.',
          tamil: 'ஒரு தொடர்பைத் திறந்து வீடியோ கேமரா ஐகானைத் தட்டவும்.',
          bengali: 'একটি পরিচিতি খুলে ভিডিও ক্যামেরা আইকনে ট্যাপ করুন।',
          kannada: 'ಸಂಪರ್ಕವನ್ನು ತೆರೆಯಿರಿ ಮತ್ತು ವೀಡಿಯೊ ಕ್ಯಾಮೆರಾ ಐಕಾನ್ ಮೇಲೆ ಟ್ಯಾಪ್ ಮಾಡಿ.',
          malayalam: 'ഒരു കോൺടാക്ട് തുറന്ന് വീഡിയോ ക്യാമറ ഐക്കണിൽ ടാപ്പ് ചെയ്യുക.',
          punjabi: 'ਸੰਪਰਕ ਖੋਲ੍ਹੋ ਅਤੇ ਵੀਡੀਓ ਕੈਮਰਾ ਆਈਕਨ ਤੇ ਟੈਪ ਕਰੋ।',
          selectedLanguage: widget.selectedLanguage,
        );

      case 4:
        return appText(
          english: 'Tap the camera or attachment icon and choose a photo.',
          hindi: 'कैमरा या अटैचमेंट आइकन पर टैप करें और फोटो चुनें।',
          marathi: 'कॅमेरा किंवा अटॅचमेंट आयकॉनवर टॅप करा आणि फोटो निवडा.',
          gujarati: 'કેમેરા અથવા એટેચમેન્ટ આઇકન પર ટેપ કરો અને ફોટો પસંદ કરો.',
          telugu: 'కెమెరా లేదా అటాచ్‌మెంట్ ఐకాన్‌పై ట్యాప్ చేసి ఫోటోను ఎంచుకోండి.',
          tamil: 'கேமரா அல்லது இணைப்பு ஐகானைத் தட்டி புகைப்படத்தைத் தேர்ந்தெடுக்கவும்.',
          bengali: 'ক্যামেরা বা অ্যাটাচমেন্ট আইকনে ট্যাপ করে একটি ছবি বেছে নিন।',
          kannada: 'ಕ್ಯಾಮೆರಾ ಅಥವಾ ಅಟ್ಯಾಚ್‌ಮೆಂಟ್ ಐಕಾನ್ ಮೇಲೆ ಟ್ಯಾಪ್ ಮಾಡಿ ಫೋಟೋ ಆಯ್ಕೆಮಾಡಿ.',
          malayalam: 'ക്യാമറ അല്ലെങ്കിൽ അറ്റാച്ച്മെന്റ് ഐക്കണിൽ ടാപ്പ് ചെയ്ത് ഒരു ഫോട്ടോ തിരഞ്ഞെടുക്കുക.',
          punjabi: 'ਕੈਮਰਾ ਜਾਂ ਅਟੈਚਮੈਂਟ ਆਈਕਨ ਤੇ ਟੈਪ ਕਰੋ ਅਤੇ ਫੋਟੋ ਚੁਣੋ।',
          selectedLanguage: widget.selectedLanguage,
        );

      case 5:
        return appText(
          english: 'Tap the play button to listen to a voice message.',
          hindi: 'वॉइस मैसेज सुनने के लिए प्ले बटन पर टैप करें।',
          marathi: 'व्हॉइस मेसेज ऐकण्यासाठी प्ले बटणावर टॅप करा.',
          gujarati: 'વૉઇસ મેસેજ સાંભળવા માટે પ્લે બટન પર ટેપ કરો.',
          telugu: 'వాయిస్ మెసేజ్ వినడానికి ప్లే బటన్‌పై ట్యాప్ చేయండి.',
          tamil: 'குரல் செய்தியைக் கேட்க ப்ளே பொத்தானைத் தட்டவும்.',
          bengali: 'ভয়েস মেসেজ শুনতে প্লে বোতামে ট্যাপ করুন।',
          kannada: 'ವಾಯ್ಸ್ ಮೆಸೇಜ್ ಕೇಳಲು ಪ್ಲೇ ಬಟನ್ ಮೇಲೆ ಟ್ಯಾಪ್ ಮಾಡಿ.',
          malayalam: 'വോയ്സ് മെസേജ് കേൾക്കാൻ പ്ലേ ബട്ടണിൽ ടാപ്പ് ചെയ്യുക.',
          punjabi: 'ਵੌਇਸ ਮੈਸੇਜ ਸੁਣਨ ਲਈ ਪਲੇ ਬਟਨ ਤੇ ਟੈਪ ਕਰੋ।',
          selectedLanguage: widget.selectedLanguage,
        );

      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStep];
    final stepTitle = getStepTitle(currentStep);
    final stepDescription = getStepDescription(currentStep);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),

      appBar: AppBar(
        title: Text(
          appText(
            english: 'WhatsApp Tutorial',
            hindi: 'व्हाट्सऐप ट्यूटोरियल',
            marathi: 'व्हॉट्सअॅप ट्यूटोरियल',
            gujarati: 'વોટ્સએપ ટ્યુટોરિયલ',
            telugu: 'వాట్సాప్ ట్యుటోరియల్',
            tamil: 'வாட்ஸ்அப் பயிற்சி',
            bengali: 'হোয়াটসঅ্যাপ টিউটোরিয়াল',
            kannada: 'ವಾಟ್ಸಾಪ್ ಟ್ಯುಟೋರಿಯಲ್',
            malayalam: 'വാട്സ്ആപ്പ് ട്യൂട്ടോറിയൽ',
            punjabi: 'ਵਟਸਐਪ ਟਿਊਟੋਰਿਅਲ',
            selectedLanguage: widget.selectedLanguage,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            Text(
              '${currentStep + 1} / ${steps.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF687780),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(25),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ],
              ),

              child: Column(
                children: [
                  const Icon(
                    Icons.chat_rounded,
                    size: 70,
                    color: Color(0xFF6C9A7A),
                  ),

                  const SizedBox(height: 25),

                  Text(
                   stepTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF30485C),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    stepDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      height: 1.5,
                      color: Color(0xFF687780),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: currentStep > 0
                        ? () {
                            setState(() {
                              currentStep--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      appText(
                        english: 'Previous',
                        hindi: 'पिछला',
                        marathi: 'मागील',
                        gujarati: 'પાછલું',
                        telugu: 'మునుపటి',
                        tamil: 'முந்தையது',
                        bengali: 'আগের',
                        kannada: 'ಹಿಂದಿನದು',
                        malayalam: 'മുമ്പത്തേത്',
                        punjabi: 'ਪਿਛਲਾ',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: currentStep < steps.length - 1
                        ? () {
                            setState(() {
                              currentStep++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      appText(
                        english: 'Next',
                        hindi: 'अगला',
                        marathi: 'पुढील',
                        gujarati: 'આગળ',
                        telugu: 'తదుపరి',
                        tamil: 'அடுத்து',
                        bengali: 'পরবর্তী',
                        kannada: 'ಮುಂದಿನದು',
                        malayalam: 'അടുത്തത്',
                        punjabi: 'ਅਗਲਾ',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}