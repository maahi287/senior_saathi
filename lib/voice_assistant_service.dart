import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'main.dart';

class VoiceAssistantService {
  static final VoiceAssistantService instance = VoiceAssistantService._internal();

  factory VoiceAssistantService() => instance;

  VoiceAssistantService._internal() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> currentTextNotifier = ValueNotifier<String>('');

  bool get isSpeaking => isSpeakingNotifier.value;

  Future<void> _initTts() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setSpeechRate(0.42); // Calm, clear pace for seniors
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        isSpeakingNotifier.value = true;
      });

      _flutterTts.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
        currentTextNotifier.value = '';
      });

      _flutterTts.setCancelHandler(() {
        isSpeakingNotifier.value = false;
        currentTextNotifier.value = '';
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        isSpeakingNotifier.value = false;
        currentTextNotifier.value = '';
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize FlutterTts: $e');
    }
  }

  /// Map app languages to standard BCP-47 TTS locale codes
  static String getLocaleCode(String language) {
    switch (language) {
      case AppLanguage.hindi:
        return 'hi-IN';
      case AppLanguage.marathi:
        return 'mr-IN';
      case AppLanguage.gujarati:
        return 'gu-IN';
      case AppLanguage.telugu:
        return 'te-IN';
      case AppLanguage.tamil:
        return 'ta-IN';
      case AppLanguage.bengali:
        return 'bn-IN';
      case AppLanguage.kannada:
        return 'kn-IN';
      case AppLanguage.malayalam:
        return 'ml-IN';
      case AppLanguage.punjabi:
        return 'pa-IN';
      default:
        return 'en-IN';
    }
  }

  /// Speaks text aloud in the designated language
  Future<void> speak(String text, {required String selectedLanguage}) async {
    if (text.trim().isEmpty) return;

    try {
      if (!_isInitialized) {
        await _initTts();
      }

      // Stop previous utterance
      await _flutterTts.stop();

      final locale = getLocaleCode(selectedLanguage);

      try {
        await _flutterTts.setLanguage(locale);
      } catch (_) {
        // Fallback to Hindi or English if regional engine is missing
        try {
          await _flutterTts.setLanguage('hi-IN');
        } catch (_) {
          await _flutterTts.setLanguage('en-IN');
        }
      }

      currentTextNotifier.value = text;
      isSpeakingNotifier.value = true;

      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error in speak: $e');
      isSpeakingNotifier.value = false;
      currentTextNotifier.value = '';
    }
  }

  /// Stop reading
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    } finally {
      isSpeakingNotifier.value = false;
      currentTextNotifier.value = '';
    }
  }

  /// Explains a core feature in the senior's language
  Future<void> explainFeature(String featureKey, {required String selectedLanguage}) async {
    String explanation = '';
    switch (featureKey) {
      case 'medicines':
        explanation = appText(
          english: 'Medicines Section. Here you can see your daily medicine reminders. You can add new pills, set timings, and mark them as taken.',
          hindi: 'दवाइयां अनुभाग। यहाँ आप अपनी दैनिक दवाइयों के रिमाइंडर्स देख सकते हैं। आप नई दवा जोड़ सकते हैं और गोली लेने के बाद उसे टिक कर सकते हैं।',
          marathi: 'औषधे विभाग. येथे तुम्ही तुमची दैनंदिन औषधे पाहू शकता आणि वेळेवर औषध घेतल्याची नोंद करू शकता.',
          gujarati: 'દવાઓ વિભાગ. અહીં તમે તમારી દૈનિક દવાઓની યાદી જોઈ શકો છો અને દવા લીધા પછી નિશાન કરી શકો છો.',
          telugu: 'మందుల విభాగం. ఇక్కడ మీరు మీ రోజువారీ మందుల రిమైండర్‌లను చూడవచ్చు.',
          tamil: 'மருந்துகள் பிரிவு. இங்கே உங்கள் தினசரி மருந்து நினைவூட்டல்களைப் பார்க்கலாம்.',
          bengali: 'ওষুধের বিভাগ। এখানে আপনি আপনার দৈনন্দিন ওষুধের তালিকা দেখতে পাবেন।',
          kannada: 'ಔಷಧಿಗಳ ವಿಭಾಗ. ಇಲ್ಲಿ ನಿಮ್ಮ ದೈನಂದಿನ ಔಷಧಿ ಜ್ಞಾಪನೆಗಳನ್ನು ನೋಡಬಹುದು.',
          malayalam: 'മരുന്നുകളുടെ വിഭാഗം. ഇവിടെ നിങ്ങളുടെ ദൈനംദിന മരുന്ന് ഓർമ്മപ്പെടുത്തലുകൾ കാണാം.',
          punjabi: 'ਦਵਾਈਆਂ ਦਾ ਭਾਗ। ਇੱਥੇ ਤੁਸੀਂ ਆਪਣੀਆਂ ਰੋਜ਼ਾਨਾ ਦੀਆਂ ਦਵਾਈਆਂ ਦੇ ਰੀਮਾਈਂਡਰ ਦੇਖ ਸਕਦੇ ਹੋ।',
          selectedLanguage: selectedLanguage,
        );
        break;

      case 'emergency':
        explanation = appText(
          english: 'Emergency SOS. Tap this button to immediately alert your family and dial 112 emergency helpline with your live GPS location.',
          hindi: 'आपातकालीन एसओएस। अपने परिवार को तुरंत सूचित करने और अपनी लाइव लोकेशन के साथ राष्ट्रीय आपातकालीन 112 नंबर मिलाने के लिए यहाँ दबाएं।',
          marathi: 'आणीबाणी एसओएस. कुटुंबाला त्वरित अलर्ट करण्यासाठी आणि 112 नंबरवर संपर्क साधण्यासाठी येथे टॅप करा.',
          gujarati: 'ઇમરજન્સી એસઓએસ. પરિવારને તાત્કાલિક જાણ કરવા અને 112 નંબર ડાયલ કરવા અહીં ટેપ કરો.',
          telugu: 'అత్యవసర SOS. కుటుంబ సభ్యులకు వెంటనే సమాచారం ఇవ్వడానికి ఇక్కడ నొక్కండి.',
          tamil: 'அவசர SOS. குடும்பத்தினருக்கு உடனடியாக தகவல் தெரிவிக்க இங்கே தட்டவும்.',
          bengali: 'জরুরি এসওএস। পরিবারকে দ্রুত সতর্ক করতে এবং ১১২ নম্বরে কল করতে এখানে ট্যাপ করুন।',
          kannada: 'ತುರ್ತು SOS. ಕುಟುಂಬಕ್ಕೆ ತಕ್ಷಣವೇ ಮಾಹಿತಿ ನೀಡಲು ಇಲ್ಲಿ ಒತ್ತಿರಿ.',
          malayalam: 'അടിയന്തര SOS. കുടുംബാംഗങ്ങളെ ഉടൻ അറിയിക്കാൻ ഇവിടെ ടാപ്പ് ചെയ്യുക.',
          punjabi: 'ਐਮਰਜੈਂਸੀ SOS। ਪਰਿਵਾਰ ਨੂੰ ਤੁਰੰਤ ਸੂਚਿਤ ਕਰਨ ਲਈ ਇੱਥੇ ਟੈਪ ਕਰੋ।',
          selectedLanguage: selectedLanguage,
        );
        break;

      case 'location':
        explanation = appText(
          english: 'My Location and Live Tracking. Here you can see your live position on OpenStreetMap, check your distance, and share your path with trusted family members.',
          hindi: 'मेरी लोकेशन और लाइव ट्रैकिंग। यहाँ आप ओपन-स्ट्रीट-मैप पर अपना स्थान देख सकते हैं और परिजनों के साथ लाइव लोकेशन शेयर कर सकते हैं।',
          marathi: 'माझे स्थान आणि लाइव्ह ट्रॅकिंग. येथे तुम्ही नकाशावर तुमचे स्थान पाहू शकता आणि कुटुंबासह शेअर करू शकता.',
          gujarati: 'મારું સ્થાન અને લાઇવ ટ્રેકિંગ. અહીં તમે નકશા પર તમારું સ્થાન જોઈ શકો છો.',
          telugu: 'నా స్థానం మరియు లైవ్ ట్రాకింగ్. ఇక్కడ మీరు మ్యాప్‌లో మీ స్థానాన్ని చూడవచ్చు.',
          tamil: 'எனது இருப்பிடம் மற்றும் நேரலை கண்காணிப்பு. இங்கே நீங்கள் வரைபடத்தில் உங்கள் இருப்பிடத்தைப் பார்க்கலாம்.',
          bengali: 'আমার অবস্থান ও লাইভ ট্র্যাকিং। এখানে আপনি ম্যাপে আপনার অবস্থান দেখতে পাবেন।',
          kannada: 'ನನ್ನ ಸ್ಥಳ ಮತ್ತು ಲೈವ್ ಟ್ರ್ಯಾಕಿಂಗ್. ಇಲ್ಲಿ ನೀವು ನಕ್ಷೆಯಲ್ಲಿ ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ನೋಡಬಹುದು.',
          malayalam: 'എന്റെ സ്ഥലവും ലൈവ് ട്രാക്കിംഗും. ഇവിടെ നിങ്ങൾക്ക് മാപ്പിൽ നിങ്ങളുടെ സ്ഥലം കാണാം.',
          punjabi: 'ਮੇਰੀ ਲੋਕੇਸ਼ਨ ਅਤੇ ਲਾਈਵ ਟ੍ਰੈਕਿੰਗ। ਇੱਥੇ ਤੁਸੀਂ ਨਕਸ਼ੇ ਤੇ ਆਪਣਾ ਸਥਾਨ ਦੇਖ ਸਕਦੇ ਹੋ।',
          selectedLanguage: selectedLanguage,
        );
        break;

      case 'learn_apps':
        explanation = appText(
          english: 'Learn Apps Academy. Simple step-by-step guides with practice lessons for WhatsApp voice messages, YouTube devotional songs, and Facebook family photos.',
          hindi: 'ऐप्स सीखें एकेडमी। व्हाट्सऐप पर बोलकर मैसेज भेजना, यूट्यूब पर भजन खोजना और फेसबुक पर परिजनों की फोटो देखना आसान चरणों में सीखें।',
          marathi: 'अॅप्स शिका अकादमी. व्हॉट्सअॅप, यूट्यूब आणि फेसबुक सोप्या पद्धतीने शिकण्यासाठी येथे या.',
          gujarati: 'એપ્સ શીખો એકેડેમી. વોટ્સએપ, યુટ્યુબ અને ફેસબુક સરળતાથી શીખો.',
          telugu: 'యాప్స్ అకాడమీ. వాట్సాప్, యూట్యూబ్ మరియు ఫేస్‌బుక్‌లను సులభంగా నేర్చుకోండి.',
          tamil: 'ஆப்ஸ் அகாடமி. வாட்ஸ்அப், யூடியூப் மற்றும் ஃபேஸ்புக்கை எளிதாகக் கற்றுக்கொள்ளுங்கள்.',
          bengali: 'অ্যাপস একাডেমি। হোয়াটসঅ্যাপ, ইউটিউব ও ফেসবুক সহজে শিখুন।',
          kannada: 'ಆ್ಯಪ್ಸ್ ಅಕಾಡೆಮಿ. ವಾಟ್ಸಾಪ್, ಯೂಟ್ಯೂಬ್ ಮತ್ತು ಫೇಸ್‌ಬುಕ್ ಕಲಿಯಿರಿ.',
          malayalam: 'ആപ്പ്സ് അക്കാദമി. വാട്സ്ആപ്പ്, യൂട്യൂബ്, ഫേസ്ബുക്ക് എന്നിവ എളുപ്പത്തിൽ പഠിക്കൂ.',
          punjabi: 'ਐਪਸ ਅਕੈਡਮੀ। ਵਟਸਐਪ, ਯੂਟਿਊਬ ਅਤੇ ਫੇਸਬੁੱਕ ਆਸਾਨੀ ਨਾਲ ਸਿੱਖੋ।',
          selectedLanguage: selectedLanguage,
        );
        break;

      default:
        explanation = appText(
          english: 'Senior Saathi is your personal elder companion for medicines, safety, tracking, and family care.',
          hindi: 'सीनियर साथी बुजुर्गों का अपना सच्चा डिजिटल साथी है, जो दवाइयों, सुरक्षा और परिवार की देखरेख में मदद करता है।',
          marathi: 'सीनियर साथी हा ज्येष्ठांचा विश्वासू डिजिटल सोबती आहे.',
          gujarati: 'સીનિયર સાથી વરિષ્ઠ લોકોનો વિશ્વસનીય ડિજિટલ સાથી છે.',
          telugu: 'సీనియర్ సాథీ పెద్దల విశ్వసనీయ డిజిటల్ స్నేహితుడు.',
          tamil: 'சீனியர் சாதி முதியோர்களுக்கான நம்பகமான டிஜிட்டல் தோழன்.',
          bengali: 'সিনিয়র সাথী প্রবীণদের বিশ্বস্ত ডিজিটাল সঙ্গী।',
          kannada: 'ಹಿರಿಯ ಸಾಥಿ ಹಿರಿಯರ ವಿಶ್ವಾಸಾರ್ಹ ಡಿಜಿಟಲ್ ಒಡನಾಡಿ.',
          malayalam: 'സീനിയർ സാഥി മുതിർന്നവരുടെ വിശ്വസ്ത ഡിജിറ്റൽ കൂട്ടുകാരനാണ്.',
          punjabi: 'ਸੀਨੀਅਰ ਸਾਥੀ ਬਜ਼ੁਰਗਾਂ ਦਾ ਭਰੋਸੇਮੰਦ ਸਾਥੀ ਹੈ।',
          selectedLanguage: selectedLanguage,
        );
    }

    await speak(explanation, selectedLanguage: selectedLanguage);
  }
}
