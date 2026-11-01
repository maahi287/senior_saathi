import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'voice_assistant_service.dart';
import 'voice_assistant_widget.dart';

enum AppGuideType { whatsApp, youTube, facebook }

// =====================================================
// DATA MODELS FOR APP LEARNING
// =====================================================

class AppTutorialStep {
  final String title;
  final String description;
  final IconData stepIcon;
  final String tip;
  final String actionPrompt;

  const AppTutorialStep({
    required this.title,
    required this.description,
    required this.stepIcon,
    required this.tip,
    this.actionPrompt = '',
  });
}

class AppTutorialTopic {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final String badgeText;
  final List<AppTutorialStep> steps;
  final String practiceType; // 'message', 'voice_note', 'video_call', 'youtube_search', 'youtube_controls', 'fb_reaction', 'fb_comment'

  const AppTutorialTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.badgeText,
    required this.steps,
    required this.practiceType,
  });
}

// =====================================================
// APP LEARNING HUB PAGE
// =====================================================

class AppLearningHubPage extends StatefulWidget {
  final String selectedLanguage;
  final AppGuideType initialApp;

  const AppLearningHubPage({
    super.key,
    required this.selectedLanguage,
    this.initialApp = AppGuideType.whatsApp,
  });

  @override
  State<AppLearningHubPage> createState() => _AppLearningHubPageState();
}

class _AppLearningHubPageState extends State<AppLearningHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialApp.index,
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _launchApp(String urlString, String fallbackWeb) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse(fallbackWeb);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      final webUri = Uri.parse(fallbackWeb);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: Text(
          _t(
            english: 'Senior App Academy',
            hindi: 'सीनियर ऐप एकेडमी',
            marathi: 'सीनियर अॅप अकादमी',
            gujarati: 'સીનિયર એપ એકેડમી',
            telugu: 'సీనియర్ యాప్ అకాడమీ',
            tamil: 'சீனியர் ஆப் அகாடமி',
            bengali: 'সিনিয়র অ্যাপ একাডেমি',
            kannada: 'ಹಿರಿಯ ಆ್ಯಪ್ ಅಕಾಡೆಮಿ',
            malayalam: 'സീനിയർ ആപ്പ് അക്കാദമി',
            punjabi: 'ਸੀਨੀਅਰ ਐਪ ਅਕੈਡਮੀ',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8F5F0),
        foregroundColor: const Color(0xFF30485C),
        elevation: 0,
        actions: [
          SpeakerIconButton(
            textToRead: _t(
              english:
                  'Senior App Academy. Choose WhatsApp, YouTube, or Facebook to learn features step by step.',
              hindi:
                  'सीनियर ऐप एकेडमी। व्हाट्सऐप, यूट्यूब या फेसबुक को चरण दर चरण सीखने के लिए कोई भी विषय चुनें।',
            ),
            selectedLanguage: widget.selectedLanguage,
            size: 26,
            color: _getCurrentThemeColor(),
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF30485C),
          unselectedLabelColor: Colors.black45,
          indicatorColor: _getCurrentThemeColor(),
          indicatorWeight: 4,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(
              icon: Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              text: 'WhatsApp',
            ),
            Tab(
              icon: Icon(Icons.play_circle_fill_rounded,
                  color: Color(0xFFCC181E)),
              text: 'YouTube',
            ),
            Tab(
              icon: Icon(Icons.people_rounded, color: Color(0xFF1877F2)),
              text: 'Facebook',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppGuideList(AppGuideType.whatsApp),
          _buildAppGuideList(AppGuideType.youTube),
          _buildAppGuideList(AppGuideType.facebook),
        ],
      ),
      bottomNavigationBar: VoiceAssistantSpeakingBanner(
        selectedLanguage: widget.selectedLanguage,
      ),
    );
  }

  Color _getCurrentThemeColor() {
    switch (_tabController.index) {
      case 0:
        return const Color(0xFF25D366);
      case 1:
        return const Color(0xFFCC181E);
      case 2:
        return const Color(0xFF1877F2);
      default:
        return const Color(0xFF5B7C99);
    }
  }

  Widget _buildAppGuideList(AppGuideType type) {
    final List<AppTutorialTopic> topics = _getTopicsForApp(type);
    final String appName = _getAppName(type);
    final Color appColor = _getAppColor(type);
    final String appDesc = _getAppDescription(type);
    final IconData appIcon = _getAppIcon(type);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      children: [
        // App Overview Hero Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: appColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: appColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(appIcon, color: appColor, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: appColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appDesc,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Open App Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openRealApp(type),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    '${_t(english: 'Open', hindi: 'खोलें')} $appName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appColor,
                    side: BorderSide(color: appColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t(
                english: 'Choose What to Learn',
                hindi: 'चुनें कि क्या सीखना है',
                marathi: 'काय शिकायचे ते निवडा',
                gujarati: 'શું શીખવું છે તે પસંદ કરો',
                telugu: 'ఏమి నేర్చుకోవాలో ఎంచుకోండి',
                tamil: 'என்ன கற்க வேண்டும் என்பதைத் தேர்ந்தெடுக்கவும்',
                bengali: 'কী শিখবেন তা বেছে নিন',
                kannada: 'ಏನು ಕಲಿಯಬೇಕೆಂದು ಆಯ್ಕೆಮಾಡಿ',
                malayalam: 'എന്ത് പഠിക്കണമെന്ന് തിരഞ്ഞെടുക്കുക',
                punjabi: 'ਕੀ ਸਿੱਖਣਾ ਹੈ ਚੁਣੋ',
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF30485C),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: appColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${topics.length} ${_t(english: 'Guides', hindi: 'पाठ')}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: appColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // List of Topics
        ...topics.map((topic) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppDetailTutorialPage(
                      topic: topic,
                      selectedLanguage: widget.selectedLanguage,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: topic.themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(topic.icon,
                            color: topic.themeColor, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  topic.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF30485C),
                                  ),
                                ),
                              ),
                              if (topic.badgeText.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: topic.themeColor
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    topic.badgeText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: topic.themeColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topic.subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${topic.steps.length} ${_t(english: 'easy steps', hindi: 'सरल चरण')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: topic.themeColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.touch_app_rounded,
                                  size: 14, color: Colors.black45),
                              const SizedBox(width: 4),
                              Text(
                                _t(
                                    english: 'Interactive Practice',
                                    hindi: 'अभ्यास उपलब्ध'),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: Colors.black26),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Helpful Safety Banner for Seniors
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD166)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_rounded,
                  color: Color(0xFFD48806), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        english: 'Golden Safety Rule for Seniors',
                        hindi: 'बुजुर्गों के लिए सुनहरा सुरक्षा नियम',
                        marathi: 'ज्येष्ठांसाठी सुवर्ण सुरक्षा नियम',
                        gujarati: 'વરિષ્ઠ લોકો માટે સુવર્ણ સુરક્ષા નિયમ',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF874D00),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        english:
                            'Never share your Bank OTP, PIN, or password with anyone on WhatsApp, YouTube, or Facebook. Senior Saathi will always keep you safe.',
                        hindi:
                            'व्हाट्सऐप, यूट्यूब या फेसबुक पर कभी भी अपना बैंक ओटीपी, पिन या पासवर्ड किसी के साथ साझा न करें।',
                        marathi:
                            'व्हॉट्सअॅप, यूट्यूब किंवा फेसबुकवर तुमचा बँक ओटीपी, पिन किंवा पासवर्ड कोणाशीही शेअर करू नका.',
                        gujarati:
                            'વોટ્સએપ, યુટ્યુબ અથવા ફેસબુક પર ક્યારેય તમારો બેંક ઓટીપી, પિન કે પાસવર્ડ કોઈની સાથે શેર કરશો નહીં.',
                      ),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF613400), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openRealApp(AppGuideType type) {
    switch (type) {
      case AppGuideType.whatsApp:
        _launchApp('whatsapp://', 'https://web.whatsapp.com');
        break;
      case AppGuideType.youTube:
        _launchApp('vnd.youtube://', 'https://www.youtube.com');
        break;
      case AppGuideType.facebook:
        _launchApp('fb://', 'https://www.facebook.com');
        break;
    }
  }

  String _getAppName(AppGuideType type) {
    switch (type) {
      case AppGuideType.whatsApp:
        return 'WhatsApp';
      case AppGuideType.youTube:
        return 'YouTube';
      case AppGuideType.facebook:
        return 'Facebook';
    }
  }

  Color _getAppColor(AppGuideType type) {
    switch (type) {
      case AppGuideType.whatsApp:
        return const Color(0xFF25D366);
      case AppGuideType.youTube:
        return const Color(0xFFCC181E);
      case AppGuideType.facebook:
        return const Color(0xFF1877F2);
    }
  }

  IconData _getAppIcon(AppGuideType type) {
    switch (type) {
      case AppGuideType.whatsApp:
        return Icons.chat_rounded;
      case AppGuideType.youTube:
        return Icons.play_circle_fill_rounded;
      case AppGuideType.facebook:
        return Icons.people_rounded;
    }
  }

  String _getAppDescription(AppGuideType type) {
    switch (type) {
      case AppGuideType.whatsApp:
        return _t(
          english: 'Free video calls, voice messages, and family chats.',
          hindi: 'मुफ्त वीडियो कॉल, वॉइस संदेश और पारिवारिक बातचीत।',
        );
      case AppGuideType.youTube:
        return _t(
          english: 'Watch bhajans, news, old melodies, and health tips.',
          hindi: 'भजन, समाचार, पुराने गीत और स्वास्थ्य संबंधी सुझाव देखें।',
        );
      case AppGuideType.facebook:
        return _t(
          english: 'Connect with family relatives, see photos, and festival wishes.',
          hindi: 'परिजनों से जुड़ें, तस्वीरें देखें और त्योहारों की शुभकामनाएं भेजें।',
        );
    }
  }

  // =====================================================
  // TUTORIAL TOPICS DATABASE
  // =====================================================
  List<AppTutorialTopic> _getTopicsForApp(AppGuideType type) {
    switch (type) {
      case AppGuideType.whatsApp:
        return [
          AppTutorialTopic(
            id: 'wa_voice_note',
            title: _t(english: 'Send Voice Message', hindi: 'बोलकर मैसेज भेजें'),
            subtitle: _t(
              english: 'No typing needed! Just speak and send your voice.',
              hindi: 'लिखने की जरूरत नहीं! बस बोलें और अपनी आवाज भेजें।',
            ),
            icon: Icons.mic_rounded,
            themeColor: const Color(0xFF25D366),
            badgeText: _t(english: 'Easiest', hindi: 'सबसे आसान'),
            practiceType: 'voice_note',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Open Contact Chat', hindi: 'परिजन का चैट खोलें'),
                description: _t(
                  english: 'Tap the name of your son, daughter, or friend from your WhatsApp chat list.',
                  hindi: 'अपनी व्हाट्सऐप सूची में से अपने बेटे, बेटी या मित्र के नाम पर टैप करें।',
                ),
                stepIcon: Icons.chat_bubble_outline_rounded,
                tip: _t(
                  english: 'Look at their picture on the left to easily recognize them.',
                  hindi: 'उन्हें आसानी से पहचानने के लिए बाईं ओर उनकी तस्वीर देखें।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Press and Hold the Mic 🎙️', hindi: 'माइक बटन दबाकर रखें 🎙️'),
                description: _t(
                  english: 'Look at the bottom right corner for the green microphone icon. Press and hold your finger on it.',
                  hindi: 'नीचे दाएं कोने में हरे माइक्रोफ़ोन आइकन पर अपनी उंगली दबाकर रखें।',
                ),
                stepIcon: Icons.mic_rounded,
                tip: _t(
                  english: 'Do not lift your finger until you finish speaking!',
                  hindi: 'जब तक आप बोल न लें, अपनी उंगली न उठाएं!',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Release to Send', hindi: 'भेजने के लिए उंगली उठाएं'),
                description: _t(
                  english: 'When you are done speaking, simply lift your finger. Your voice message will fly away immediately!',
                  hindi: 'बोलना समाप्त होने पर उंगली उठा लें। आपका वॉइस मैसेज तुरंत चला जाएगा!',
                ),
                stepIcon: Icons.send_rounded,
                tip: _t(
                  english: 'If you made a speaking mistake, slide your finger left to cancel.',
                  hindi: 'यदि आपसे बोलने में गलती हो जाए, तो उंगली को बाईं ओर खिसकाकर रद्द कर दें।',
                ),
              ),
            ],
          ),
          AppTutorialTopic(
            id: 'wa_video_call',
            title: _t(english: 'Make a Free Video Call', hindi: 'मुफ्त वीडियो कॉल करें'),
            subtitle: _t(
              english: 'See face-to-face with your children and grandchildren.',
              hindi: 'अपने बच्चों और पोते-पोतियों से आमने-सामने बात करें।',
            ),
            icon: Icons.videocam_rounded,
            themeColor: const Color(0xFF1EBE5D),
            badgeText: _t(english: 'Family Favorite', hindi: 'परिवार की पसंद'),
            practiceType: 'video_call',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Open the Chat', hindi: 'चैट खोलें'),
                description: _t(
                  english: 'Tap on the family member you want to talk to.',
                  hindi: 'जिस परिजन से बात करनी है, उनके चैट पर टैप करें।',
                ),
                stepIcon: Icons.person_rounded,
                tip: _t(
                  english: 'Make sure your home Wi-Fi or mobile data is turned on.',
                  hindi: 'सुनिश्चित करें कि आपका वाई-फाई या मोबाइल डेटा चालू है।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Tap Video Camera Icon', hindi: 'वीडियो कैमरा आइकन पर टैप करें'),
                description: _t(
                  english: 'Look at the top-right bar of the screen. Tap the small video camera icon.',
                  hindi: 'स्क्रीन के ऊपर दाईं ओर देखें। छोटे वीडियो कैमरा आइकन पर टैप करें।',
                ),
                stepIcon: Icons.videocam_outlined,
                tip: _t(
                  english: 'Hold the phone at eye level so they can see your warm smile.',
                  hindi: 'फोन को चेहरे के सामने रखें ताकि वे आपको स्पष्ट देख सकें।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Ending the Call', hindi: 'कॉल समाप्त करना'),
                description: _t(
                  english: 'When your lovely conversation ends, tap the round RED button at the bottom to hang up.',
                  hindi: 'बातचीत समाप्त होने पर कॉल काटने के लिए नीचे लाल बटन दबाएं।',
                ),
                stepIcon: Icons.call_end_rounded,
                tip: _t(
                  english: 'Red button always means Stop/Hang up in calls.',
                  hindi: 'कॉल में लाल बटन का अर्थ हमेशा समाप्त करना होता है।',
                ),
              ),
            ],
          ),
          AppTutorialTopic(
            id: 'wa_send_photo',
            title: _t(english: 'Send Photos & Pictures', hindi: 'तस्वीरें और फोटो भेजें'),
            subtitle: _t(
              english: 'Share temple, festival, and happy moments with family.',
              hindi: 'मंदिर, त्योहार और खुशियों की तस्वीरें अपनों को भेजें।',
            ),
            icon: Icons.photo_camera_rounded,
            themeColor: const Color(0xFF25D366),
            badgeText: _t(english: 'Popular', hindi: 'लोकप्रिय'),
            practiceType: 'message',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Tap the Attachment Icon', hindi: 'पिन या कैमरा आइकन दबाएं'),
                description: _t(
                  english: 'Inside any chat, look at the message bar. Tap the paperclip 📎 or camera 📷 icon.',
                  hindi: 'चैट में नीचे पेपरक्लिप 📎 या कैमरा 📷 आइकन पर टैप करें।',
                ),
                stepIcon: Icons.attach_file_rounded,
                tip: _t(
                  english: 'Paperclip lets you choose old saved photos from Gallery.',
                  hindi: 'पेपरक्लिप से आप गैलरी में रखी पुरानी तस्वीरें चुन सकते हैं।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Select the Photo', hindi: 'फोटो चुनें'),
                description: _t(
                  english: 'Tap "Gallery", then tap the photo you want to share.',
                  hindi: '"गैलरी" पर टैप करें, फिर जो फोटो भेजनी है उस पर टैप करें।',
                ),
                stepIcon: Icons.photo_library_rounded,
                tip: _t(
                  english: 'You can tap on multiple photos to send together.',
                  hindi: 'आप एक साथ कई फोटो पर टिक करके भेज सकते हैं।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Tap Green Arrow ➤', hindi: 'हरा तीर ➤ दबाएं'),
                description: _t(
                  english: 'Tap the round green arrow button at the bottom right to send.',
                  hindi: 'भेजने के लिए नीचे दाएं कोने में गोल हरे तीर पर टैप करें।',
                ),
                stepIcon: Icons.send_rounded,
                tip: _t(
                  english: 'You can also type a warm blessing message below the photo before sending.',
                  hindi: 'फोटो के नीचे आप कोई छोटा संदेश भी लिख सकते हैं।',
                ),
              ),
            ],
          ),
          AppTutorialTopic(
            id: 'wa_safety_block',
            title: _t(english: 'Block Unknown Numbers & Scams', hindi: 'अज्ञात नंबर और फ्रॉड ब्लॉक करें'),
            subtitle: _t(
              english: 'Keep your WhatsApp peaceful and safe from strangers.',
              hindi: 'अजनबियों और फालतू संदेशों से खुद को सुरक्षित रखें।',
            ),
            icon: Icons.block_rounded,
            themeColor: Colors.redAccent,
            badgeText: _t(english: 'Safety First', hindi: 'सुरक्षा जरूरी'),
            practiceType: 'message',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Spotting Unknown Numbers', hindi: 'अज्ञात नंबर पहचानना'),
                description: _t(
                  english: 'If you receive a message from a number you do not recognize offering prizes or asking for money, DO NOT REPLY.',
                  hindi: 'यदि किसी अनजान नंबर से कोई इनाम का झांसा दे या पैसे मांगे, तो कोई उत्तर न दें।',
                ),
                stepIcon: Icons.warning_amber_rounded,
                tip: _t(
                  english: 'Banks and government never ask for money or OTP on WhatsApp.',
                  hindi: 'बैंक या सरकार कभी व्हाट्सऐप पर पैसे या ओटीपी नहीं मांगते।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Tap the 3 Dots ⋮', hindi: 'तीन बिंदुओं ⋮ पर टैप करें'),
                description: _t(
                  english: 'Open the suspicious chat and tap the three dots in the top right corner.',
                  hindi: 'उस चैट को खोलें और ऊपर दाईं ओर तीन बिंदुओं पर टैप करें।',
                ),
                stepIcon: Icons.more_vert_rounded,
                tip: _t(
                  english: 'This menu opens options for that chat.',
                  hindi: 'यह मेनू उस चैट के विकल्प खोलता है।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Select More -> Block', hindi: '"More" -> "Block" चुनें'),
                description: _t(
                  english: 'Tap "More", then tap "Block" and confirm. That stranger can never message or call you again!',
                  hindi: '"More" पर टैप करें, फिर "Block" दबाएं। वह व्यक्ति आपको कभी दोबारा मैसेज नहीं कर पाएगा।',
                ),
                stepIcon: Icons.block_rounded,
                tip: _t(
                  english: 'You can also tell your family member to help verify suspicious numbers.',
                  hindi: 'किसी भी संदेहास्पद नंबर के लिए अपने बच्चों की मदद लें।',
                ),
              ),
            ],
          ),
        ];

      case AppGuideType.youTube:
        return [
          AppTutorialTopic(
            id: 'yt_voice_search',
            title: _t(english: 'Voice Search for Bhajans & News', hindi: 'बोलकर भजन और समाचार खोजें'),
            subtitle: _t(
              english: 'Just speak what you want to watch without typing.',
              hindi: 'बिना लिखे बस मुंह से बोलें कि आप क्या देखना चाहते हैं।',
            ),
            icon: Icons.keyboard_voice_rounded,
            themeColor: const Color(0xFFCC181E),
            badgeText: _t(english: 'Most Useful', hindi: 'सबसे उपयोगी'),
            practiceType: 'youtube_search',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Open YouTube', hindi: 'यूट्यूब खोलें'),
                description: _t(
                  english: 'Tap the red YouTube app icon on your phone.',
                  hindi: 'अपने फोन पर लाल रंग के यूट्यूब ऐप पर टैप करें।',
                ),
                stepIcon: Icons.play_circle_filled_rounded,
                tip: _t(
                  english: 'YouTube is completely free to watch videos.',
                  hindi: 'यूट्यूब पर वीडियो देखना पूरी तरह निशुल्क है।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Tap the Microphone 🎙️', hindi: 'माइक 🎙️ पर टैप करें'),
                description: _t(
                  english: 'Look at the top right, next to the magnifying glass search bar. Tap the small microphone icon.',
                  hindi: 'ऊपर दाईं ओर खोज पट्टी के बगल में छोटे माइक आइकन पर टैप करें।',
                ),
                stepIcon: Icons.mic_rounded,
                tip: _t(
                  english: 'A circle will appear saying "Listening...".',
                  hindi: 'एक गोल घेरा दिखेगा जिसपर "सुन रहे हैं..." लिखा होगा।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Speak Clearly', hindi: 'स्पष्ट आवाज में बोलें'),
                description: _t(
                  english: 'Say: "Krishna Bhajan", "Kishore Kumar Songs", "Morning News", or "Yoga for Seniors".',
                  hindi: 'बोलें: "कृष्ण भजन", "पुराने हिंदी गाने", "आज की ताजा खबरें" या "बुजुर्गों के लिए योग"।',
                ),
                stepIcon: Icons.record_voice_over_rounded,
                tip: _t(
                  english: 'Videos will appear instantly. Tap any video to start playing!',
                  hindi: 'वीडियो की सूची तुरंत आ जाएगी। जो पसंद हो उसपर टैप करें!',
                ),
              ),
            ],
          ),
          AppTutorialTopic(
            id: 'yt_controls_rewind',
            title: _t(english: 'Rewind, Pause & Full Screen', hindi: 'पीछे करना, रोकना और बड़ी स्क्रीन'),
            subtitle: _t(
              english: 'Master video controls like a remote control.',
              hindi: 'रिमोट की तरह वीडियो को आसानी से नियंत्रित करना सीखें।',
            ),
            icon: Icons.replay_10_rounded,
            themeColor: const Color(0xFFCC181E),
            badgeText: _t(english: 'Essential', hindi: 'अनिवार्य'),
            practiceType: 'youtube_controls',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Double Tap to Rewind (10s Back)', hindi: '10 सेकंड पीछे करने के लिए दो बार टैप'),
                description: _t(
                  english: 'Missed a dialogue or devotional line? Quickly double-tap with your finger on the LEFT side of the video.',
                  hindi: 'कोई बात छूट गई? वीडियो के बाईं तरफ जल्दी से दो बार टैप करें। यह 10 सेकंड पीछे हो जाएगा।',
                ),
                stepIcon: Icons.replay_10_rounded,
                tip: _t(
                  english: 'Double-tapping the RIGHT side jumps 10 seconds ahead!',
                  hindi: 'दाईं तरफ दो बार टैप करने से 10 सेकंड आगे चला जाता है!',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Pause and Play', hindi: 'रोकना और चलाना'),
                description: _t(
                  english: 'Tap once anywhere on the video. Tap the II pause symbol to pause, and ▶ to play again.',
                  hindi: 'वीडियो पर एक बार टैप करें। बीच में रुकने के लिए II और चलाने के लिए ▶ दबाएं।',
                ),
                stepIcon: Icons.pause_circle_filled_rounded,
                tip: _t(
                  english: 'Helpful if the doorbell rings or someone calls you.',
                  hindi: 'दरवाजे की घंटी बजे तो वीडियो को रोक लें, बाद में वहीं से देख सकते हैं।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Cinema Full Screen ⛶', hindi: 'बड़ा पर्दा (फुल स्क्रीन) ⛶'),
                description: _t(
                  english: 'Tap the small square box at the bottom right corner of the video. The video will fill your entire phone screen!',
                  hindi: 'वीडियो के नीचे दाएं कोने में छोटे चौकोर डिब्बे ⛶ पर टैप करें। पूरा फोन स्क्रीन टीवी जैसा बन जाएगा!',
                ),
                stepIcon: Icons.fullscreen_rounded,
                tip: _t(
                  english: 'Turn your phone horizontally (sideways) for best viewing.',
                  hindi: 'फोन को आड़ा घुमा लें ताकि तस्वीर बड़ी और साफ दिखे।',
                ),
              ),
            ],
          ),
          AppTutorialTopic(
            id: 'yt_save_data',
            title: _t(english: 'Save Videos for Later & Save Data', hindi: 'बाद में देखने के लिए सहेजें और डेटा बचाएं'),
            subtitle: _t(
              english: 'Collect your favorite discourses and save mobile balance.',
              hindi: 'अपने पसंदीदा प्रवचन सुरक्षित रखें और इंटरनेट डेटा बचाएं।',
            ),
            icon: Icons.bookmark_add_rounded,
            themeColor: const Color(0xFFE53935),
            badgeText: _t(english: 'Data Saver', hindi: 'डेटा बचत'),
            practiceType: 'youtube_controls',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Save to Watch Later', hindi: 'बाद में देखने के लिए सहेजें'),
                description: _t(
                  english: 'Below any video, swipe the buttons and tap "Save" or "Watch Later".',
                  hindi: 'वीडियो के नीचे "Save" या "Watch Later" बटन पर टैप करें।',
                ),
                stepIcon: Icons.bookmark_border_rounded,
                tip: _t(
                  english: 'You can find saved videos anytime in the "You" or "Library" tab at the bottom.',
                  hindi: 'नीचे "Library" या "You" में ये वीडियो हमेशा सुरक्षित रहेंगे।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Turn on Data Saver', hindi: 'डेटा सेवर चालू करें'),
                description: _t(
                  english: 'Tap the Gear icon ⚙️ on the video -> Quality -> Data Saver.',
                  hindi: 'वीडियो पर गियर आइकन ⚙️ -> Quality -> Data Saver चुनें।',
                ),
                stepIcon: Icons.settings_outlined,
                tip: _t(
                  english: 'This ensures your daily mobile internet quota does not run out quickly.',
                  hindi: 'इससे आपका दैनिक मोबाइल इंटरनेट डेटा जल्दी खत्म नहीं होगा।',
                ),
              ),
            ],
          ),
        ];

      case AppGuideType.facebook:
        return [
          AppTutorialTopic(
            id: 'fb_feed_like',
            title: _t(english: 'View Family Posts & Send Love', hindi: 'पारिवारिक पोस्ट देखें और प्यार भेजें'),
            subtitle: _t(
              english: 'See photos of relatives and bless them with reactions.',
              hindi: 'रिश्तेदारों की तस्वीरें देखें और उन्हें लाइक और दिल भेजें।',
            ),
            icon: Icons.favorite_rounded,
            themeColor: const Color(0xFF1877F2),
            badgeText: _t(english: 'Heartwarming', hindi: 'दिलचस्प'),
            practiceType: 'fb_reaction',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Scroll the News Feed', hindi: 'न्यूज फीड को ऊपर-नीचे सरकाएं'),
                description: _t(
                  english: 'Gently slide your finger up on the screen to see photos shared by family members and friends.',
                  hindi: 'स्क्रीन पर उंगली को धीरे से ऊपर खिसकाएं। परिजनों द्वारा साझा की गई तस्वीरें दिखेंगी।',
                ),
                stepIcon: Icons.swipe_vertical_rounded,
                tip: _t(
                  english: 'Tap any photo to view it full screen, then press Back to return.',
                  hindi: 'फोटो को बड़ा देखने के लिए उसपर टैप करें, फिर वापस आने के लिए बैक दबाएं।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Like with Heart ❤️ or Care 🥰', hindi: 'दिल ❤️ या केयर 🥰 रिएक्शन दें'),
                description: _t(
                  english: 'Below any photo, tap "Like" 👍. Or hold your finger on Like to see Heart ❤️ and Care 🥰 reactions!',
                  hindi: 'फोटो के नीचे "Like" पर टैप करें। या उंगली दबाकर रखें ताकि दिल ❤️ और प्यार 🥰 चुन सकें।',
                ),
                stepIcon: Icons.thumb_up_alt_rounded,
                tip: _t(
                  english: 'Your loved ones will receive a joyful notification that you liked their post.',
                  hindi: 'आपके परिजनों को खुशी होगी कि आपने उनकी तस्वीर पसंद की।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Write a Blessing Comment', hindi: 'शुभकामना या आशीर्वाद लिखें'),
                description: _t(
                  english: 'Tap the "Comment" speech bubble 💬, type a blessing like "God bless you beta" and tap the blue arrow.',
                  hindi: '"Comment" 💬 पर टैप करें, अपना आशीर्वाद लिखें और नीला तीर दबाएं।',
                ),
                stepIcon: Icons.comment_rounded,
                tip: _t(
                  english: 'Even two kind words bring a big smile to your grandchildren.',
                  hindi: 'दो मीठे शब्द आपके बच्चों के चेहरे पर मुस्कान ला देते हैं।',
                ),
              ),
            ],
          ),
          AppTutorialTopic(
            id: 'fb_find_friends',
            title: _t(english: 'Find Childhood & Family Friends', hindi: 'पुराने दोस्त और रिश्तेदार खोजें'),
            subtitle: _t(
              english: 'Reconnect with old schoolmates, colleagues, and cousins.',
              hindi: 'अपने पुराने स्कूल के मित्रों और रिश्तेदारों को ढूंढें।',
            ),
            icon: Icons.person_search_rounded,
            themeColor: const Color(0xFF1877F2),
            badgeText: _t(english: 'Reunion', hindi: 'पुनर्मिलन'),
            practiceType: 'fb_reaction',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Tap the Search Glass 🔍', hindi: 'सर्च ग्लास 🔍 पर टैप करें'),
                description: _t(
                  english: 'Tap the magnifying glass icon at the top right of the Facebook app.',
                  hindi: 'फेसबुक में ऊपर दाईं ओर सर्च (लेंस) आइकन पर टैप करें।',
                ),
                stepIcon: Icons.search_rounded,
                tip: _t(
                  english: 'Type their full name and hometown or school name.',
                  hindi: 'उनका पूरा नाम और शहर का नाम लिखें।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Tap "Add Friend" 👤+', hindi: '"Add Friend" 👤+ पर टैप करें'),
                description: _t(
                  english: 'When you recognize their photo, tap the blue "Add Friend" button.',
                  hindi: 'उनकी फोटो देखकर पहचानने पर नीले "Add Friend" बटन पर टैप करें।',
                ),
                stepIcon: Icons.person_add_rounded,
                tip: _t(
                  english: 'Only add people you know personally in real life for safety.',
                  hindi: 'सुरक्षा के लिए केवल उन्हीं को जोड़ें जिन्हें आप व्यक्तिगत रूप से जानते हैं।',
                ),
              ),
            ],
          ),
          AppTutorialTopic(
            id: 'fb_safety',
            title: _t(english: 'Privacy & Security on Facebook', hindi: 'फेसबुक पर प्राइवेसी और सुरक्षा'),
            subtitle: _t(
              english: 'Essential safety rules to keep your account safe.',
              hindi: 'अपने खाते को सुरक्षित रखने के जरूरी नियम।',
            ),
            icon: Icons.shield_rounded,
            themeColor: Colors.deepOrange,
            badgeText: _t(english: 'Must Read', hindi: 'जरूरी पढ़ें'),
            practiceType: 'fb_reaction',
            steps: [
              AppTutorialStep(
                title: _t(english: 'Beware of Unknown Friend Requests', hindi: 'अजनबी फ्रेंड रिक्वेस्ट से सावधान'),
                description: _t(
                  english: 'If someone you do not know sends a friend request, tap "Delete / Decline".',
                  hindi: 'यदि कोई अनजान व्यक्ति फ्रेंड रिक्वेस्ट भेजे, तो "Delete" या "Decline" दबाएं।',
                ),
                stepIcon: Icons.person_remove_rounded,
                tip: _t(
                  english: 'Scammers sometimes pretend to be military officers or lottery winners.',
                  hindi: 'धोखेबाज कभी-कभी सेना अधिकारी या लॉटरी विजेता बनकर झांसा देते हैं।',
                ),
              ),
              AppTutorialStep(
                title: _t(english: 'Never Share Sensitive Information', hindi: 'गोपनीय जानकारी कभी न दें'),
                description: _t(
                  english: 'Never post your home address, phone number, or travel dates publicly.',
                  hindi: 'घर का पता, फोन नंबर या यात्रा का विवरण कभी फेसबुक पर सार्वजनिक न करें।',
                ),
                stepIcon: Icons.lock_outline_rounded,
                tip: _t(
                  english: 'Keep your memories shared only with "Friends" rather than "Public".',
                  hindi: 'अपनी पोस्ट को "Public" के बजाय केवल "Friends" तक सीमित रखें।',
                ),
              ),
            ],
          ),
        ];
    }
  }
}

// =====================================================
// DETAIL TUTORIAL VIEWER WITH INTERACTIVE PRACTICE
// =====================================================

class AppDetailTutorialPage extends StatefulWidget {
  final AppTutorialTopic topic;
  final String selectedLanguage;

  const AppDetailTutorialPage({
    super.key,
    required this.topic,
    required this.selectedLanguage,
  });

  @override
  State<AppDetailTutorialPage> createState() => _AppDetailTutorialPageState();
}

class _AppDetailTutorialPageState extends State<AppDetailTutorialPage> {
  int _currentStepIndex = 0;

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

  void _openInteractivePractice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InteractivePracticeSheet(
        practiceType: widget.topic.practiceType,
        selectedLanguage: widget.selectedLanguage,
        themeColor: widget.topic.themeColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.topic.steps[_currentStepIndex];
    final totalSteps = widget.topic.steps.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: Text(
          widget.topic.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8F5F0),
        foregroundColor: const Color(0xFF30485C),
        elevation: 0,
        actions: [
          SpeakerIconButton(
            textToRead:
                '${widget.topic.title}. ${_t(english: "Step", hindi: "चरण")} ${_currentStepIndex + 1}. ${step.title}. ${step.description}. ${step.tip}',
            selectedLanguage: widget.selectedLanguage,
            size: 28,
            color: widget.topic.themeColor,
          ),
          IconButton(
            tooltip: _t(english: 'Try Practice', hindi: 'अभ्यास करें'),
            icon: Icon(Icons.sports_esports_rounded,
                color: widget.topic.themeColor, size: 28),
            onPressed: _openInteractivePractice,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: List.generate(totalSteps, (index) {
                  final isCompleted = index <= _currentStepIndex;
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? widget.topic.themeColor
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Step Counter
            Text(
              '${_t(english: 'Step', hindi: 'चरण')} ${_currentStepIndex + 1} ${_t(english: 'of', hindi: 'का')} $totalSteps',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 10),

            // Main Step Content Card
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Step Hero Icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: widget.topic.themeColor
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              step.stepIcon,
                              color: widget.topic.themeColor,
                              size: 54,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Step Title with Voice Assistant
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  step.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF30485C),
                                  ),
                                ),
                              ),
                              SpeakerIconButton(
                                textToRead:
                                    '${step.title}. ${step.description}. ${step.tip}',
                                selectedLanguage: widget.selectedLanguage,
                                size: 28,
                                color: widget.topic.themeColor,
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Step Description
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.5,
                              color: Color(0xFF556575),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Senior Tip Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F7F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFB5E2C4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_rounded,
                                    color: Color(0xFF2E7D32), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t(
                                          english: 'Senior Friendly Tip',
                                          hindi: 'बुजुर्गों के लिए सुझाव',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        step.tip,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1B5E20),
                                          height: 1.3,
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

                    const SizedBox(height: 16),

                    // Try Interactive Practice Button
                    ElevatedButton.icon(
                      onPressed: _openInteractivePractice,
                      icon: const Icon(Icons.touch_app_rounded, size: 20),
                      label: Text(
                        _t(
                          english: 'Try Interactive Practice Here',
                          hindi: 'यहाँ बिना डर के अभ्यास करें',
                          marathi: 'येथे सराव करून पहा',
                          gujarati: 'અહીં પ્રેક્ટિસ કરવાનો પ્રયાસ કરો',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.topic.themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: Row(
                children: [
                  // Previous Step Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentStepIndex > 0
                          ? () => setState(() => _currentStepIndex--)
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(
                        _t(english: 'Previous', hindi: 'पिछला'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Next Step / Finish Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_currentStepIndex < totalSteps - 1) {
                          setState(() => _currentStepIndex++);
                        } else {
                          // Tutorial Completed!
                          _showCelebrationDialog();
                        }
                      },
                      icon: Icon(
                        _currentStepIndex < totalSteps - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_circle_rounded,
                      ),
                      label: Text(
                        _currentStepIndex < totalSteps - 1
                            ? _t(english: 'Next', hindi: 'अगला')
                            : _t(english: 'Completed!', hindi: 'पूरा हुआ!'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30485C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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

  void _showCelebrationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 10),
            Text(
              _t(
                english: 'Congratulations!',
                hindi: 'बहुत-बहुत बधाई!',
                marathi: 'अभिनंदन!',
                gujarati: 'અભિનંદન!',
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF30485C),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _t(
                english: 'You have mastered this feature! Try practicing it now in the real app or continue learning.',
                hindi: 'आपने यह सीख लिया है! अब आप इसे आत्मविश्वास के साथ इस्तेमाल कर सकते हैं।',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.topic.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                _t(english: 'Awesome! Back to Guides', hindi: 'बहुत खूब! वापस जाएं'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// INTERACTIVE PRACTICE SANDBOX MODAL
// =====================================================

class _InteractivePracticeSheet extends StatefulWidget {
  final String practiceType;
  final String selectedLanguage;
  final Color themeColor;

  const _InteractivePracticeSheet({
    required this.practiceType,
    required this.selectedLanguage,
    required this.themeColor,
  });

  @override
  State<_InteractivePracticeSheet> createState() =>
      _InteractivePracticeSheetState();
}

class _InteractivePracticeSheetState extends State<_InteractivePracticeSheet> {
  bool _isHoldingMic = false;
  bool _isSuccess = false;
  String _simulatedText = '';
  bool _isLiked = false;
  String _selectedReaction = '👍';
  bool _isPlayingVideo = false;

  String _t({
    required String english,
    required String hindi,
  }) {
    return appText(
      english: english,
      hindi: hindi,
      marathi: hindi,
      gujarati: hindi,
      telugu: english,
      tamil: english,
      bengali: hindi,
      kannada: english,
      malayalam: english,
      punjabi: hindi,
      selectedLanguage: widget.selectedLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.themeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sports_esports_rounded,
                          color: widget.themeColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _t(
                        english: 'Interactive Practice Sandbox',
                        hindi: 'सुरक्षित अभ्यास बॉक्स',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF30485C),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                english:
                    'This is a pressure-free simulator. Nothing is sent to real people, so feel free to tap and try!',
                hindi:
                    'यह एक सुरक्षित अभ्यास है। यहाँ कुछ भी असली लोगों को नहीं भेजा जाता, इसलिए निडर होकर अभ्यास करें!',
              ),
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),

            // Sandbox Content based on type
            _buildSandboxContent(),

            const SizedBox(height: 16),

            if (_isSuccess)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t(
                          english: '🎉 Fantastic! You did it correctly!',
                          hindi: '🎉 बहुत बढ़िया! आपने बिल्कुल सही किया!',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t(english: 'Done Practicing', hindi: 'अभ्यास पूरा हुआ')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSandboxContent() {
    switch (widget.practiceType) {
      case 'voice_note':
        return Column(
          children: [
            Text(
              _t(
                english: '👉 Press and hold the green microphone below to record:',
                hindi: '👉 नीचे हरे माइक को दबाकर रखें और बोलें:',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTapDown: (_) {
                setState(() {
                  _isHoldingMic = true;
                  _isSuccess = false;
                });
              },
              onTapUp: (_) {
                setState(() {
                  _isHoldingMic = false;
                  _isSuccess = true;
                });
              },
              onTapCancel: () {
                setState(() => _isHoldingMic = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isHoldingMic ? 90 : 76,
                height: _isHoldingMic ? 90 : 76,
                decoration: BoxDecoration(
                  color: _isHoldingMic
                      ? Colors.red
                      : const Color(0xFF25D366),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isHoldingMic ? Colors.red : const Color(0xFF25D366))
                          .withValues(alpha: 0.4),
                      blurRadius: _isHoldingMic ? 20 : 8,
                    ),
                  ],
                ),
                child: Icon(
                  _isHoldingMic ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isHoldingMic
                  ? '🔴 ${_t(english: 'Recording your voice... Release when done', hindi: 'आवाज रिकॉर्ड हो रही है... पूरा होने पर छोड़ें')}'
                  : _t(english: 'Hold finger here', hindi: 'यहाँ उंगली दबाकर रखें'),
              style: TextStyle(
                color: _isHoldingMic ? Colors.red : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case 'youtube_search':
        return Column(
          children: [
            Text(
              _t(
                english: '👉 Tap the Mic to practice voice search:',
                hindi: '👉 बोलकर खोजने के लिए माइक पर टैप करें:',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _simulatedText.isEmpty
                          ? _t(english: 'Search YouTube...', hindi: 'यूट्यूब पर खोजें...')
                          : _simulatedText,
                      style: TextStyle(
                        color: _simulatedText.isEmpty
                            ? Colors.black38
                            : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic, color: Color(0xFFCC181E)),
                    onPressed: () {
                      setState(() {
                        _simulatedText = _t(
                          english: 'Krishna Bhajan & Old Melodies',
                          hindi: 'श्री कृष्ण भजन और पुराने गीत',
                        );
                        _isSuccess = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        );

      case 'youtube_controls':
        return Column(
          children: [
            Text(
              _t(
                english: '👉 Tap video screen to pause/play or double-tap left to rewind:',
                hindi: '👉 वीडियो को रोकने/चलाने के लिए टैप करें:',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                setState(() {
                  _isPlayingVideo = !_isPlayingVideo;
                  _isSuccess = true;
                });
              },
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    _isPlayingVideo
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isPlayingVideo
                  ? _t(english: 'Playing Video ▶', hindi: 'वीडियो चल रहा है ▶')
                  : _t(english: 'Paused II', hindi: 'वीडियो रुका हुआ है II'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );

      case 'fb_reaction':
      default:
        return Column(
          children: [
            Text(
              _t(
                english: '👉 Practice sending Love ❤️ or Care 🥰 to a post:',
                hindi: '👉 पोस्ट पर प्यार ❤️ या केयर 🥰 भेजने का अभ्यास करें:',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['👍', '❤️', '🥰', '🙏'].map((emoji) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedReaction = emoji;
                        _isLiked = true;
                        _isSuccess = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedReaction == emoji && _isLiked
                            ? const Color(0xFF1877F2).withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedReaction == emoji && _isLiked
                              ? const Color(0xFF1877F2)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
    }
  }
}
