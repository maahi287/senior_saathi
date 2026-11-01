import 'package:flutter/material.dart';
import 'voice_assistant_service.dart';
import 'main.dart';

// =====================================================
// 1-TAP INLINE SPEAKER ICON BUTTON
// =====================================================

class SpeakerIconButton extends StatelessWidget {
  final String textToRead;
  final String selectedLanguage;
  final double size;
  final Color? color;

  const SpeakerIconButton({
    super.key,
    required this.textToRead,
    required this.selectedLanguage,
    this.size = 22,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceAssistantService.instance.isSpeakingNotifier,
      builder: (context, isSpeaking, child) {
        final currentText = VoiceAssistantService.instance.currentTextNotifier.value;
        final isThisSpeaking = isSpeaking && currentText == textToRead;

        return Tooltip(
          message: isThisSpeaking ? 'Stop speaking' : 'Read aloud in your language',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                if (isThisSpeaking) {
                  VoiceAssistantService.instance.stop();
                } else {
                  VoiceAssistantService.instance.speak(
                    textToRead,
                    selectedLanguage: selectedLanguage,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isThisSpeaking
                      ? Icons.stop_circle_rounded
                      : Icons.volume_up_rounded,
                  size: size,
                  color: isThisSpeaking
                      ? Colors.red
                      : (color ?? const Color(0xFF5B7C99)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =====================================================
// VOICE ASSISTANT FLOATING BUTTON
// =====================================================

class VoiceAssistantFloatingButton extends StatelessWidget {
  final String selectedLanguage;
  final String? screenTitle;
  final String? screenSummary;
  final List<String>? screenDetails;

  const VoiceAssistantFloatingButton({
    super.key,
    required this.selectedLanguage,
    this.screenTitle,
    this.screenSummary,
    this.screenDetails,
  });

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
      selectedLanguage: selectedLanguage,
    );
  }

  void _readEntireScreen(BuildContext context) {
    final buffer = StringBuffer();
    if (screenTitle != null && screenTitle!.isNotEmpty) {
      buffer.writeln(screenTitle);
    }
    if (screenSummary != null && screenSummary!.isNotEmpty) {
      buffer.writeln(screenSummary);
    }
    if (screenDetails != null && screenDetails!.isNotEmpty) {
      for (final item in screenDetails!) {
        buffer.writeln(item);
      }
    }

    final fullText = buffer.toString().trim();
    if (fullText.isNotEmpty) {
      VoiceAssistantService.instance.speak(
        fullText,
        selectedLanguage: selectedLanguage,
      );
    }
  }

  void _showVoiceMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B7C99).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.record_voice_over_rounded,
                          color: Color(0xFF5B7C99), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(
                              english: 'Senior Saathi Voice Assistant',
                              hindi: 'सीनियर साथी वाणी सहायक',
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF30485C),
                            ),
                          ),
                          Text(
                            _t(
                              english: 'Listen to everything read aloud clearly',
                              hindi: 'स्क्रीन की सारी जानकारी बोलकर सुनें',
                            ),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF6C9A7A),
                    child: Icon(Icons.volume_up_rounded, color: Colors.white),
                  ),
                  title: Text(
                    _t(
                      english: 'Read This Screen Aloud',
                      hindi: 'यह स्क्रीन पढ़कर सुनाएं',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _t(
                      english: 'Reads title, details and actions in your language',
                      hindi: 'आपकी भाषा में शीर्षक और विवरण पढ़कर सुनाएगा',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _readEntireScreen(context);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF8A7BA8),
                    child: Icon(Icons.lightbulb_rounded, color: Colors.white),
                  ),
                  title: Text(
                    _t(
                      english: 'Explain App Features',
                      hindi: 'ऐप के मुख्य फीचर्स समझाइए',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _t(
                      english: 'Medicines, Emergency, Location and Learning',
                      hindi: 'दवाइयां, इमरजेंसी, लोकेशन और ऐप्स की जानकारी',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    VoiceAssistantService.instance.explainFeature(
                      'learn_apps',
                      selectedLanguage: selectedLanguage,
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable:
                      VoiceAssistantService.instance.isSpeakingNotifier,
                  builder: (context, isSpeaking, child) {
                    if (!isSpeaking) return const SizedBox.shrink();
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Icon(Icons.stop_rounded, color: Colors.white),
                      ),
                      title: Text(
                        _t(
                          english: 'Stop Speaking',
                          hindi: 'बोलना रोकें',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      onTap: () {
                        VoiceAssistantService.instance.stop();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceAssistantService.instance.isSpeakingNotifier,
      builder: (context, isSpeaking, child) {
        return FloatingActionButton.extended(
          heroTag: 'voice_assistant_fab_${DateTime.now().microsecondsSinceEpoch}',
          onPressed: () {
            if (isSpeaking) {
              VoiceAssistantService.instance.stop();
            } else {
              if (screenSummary != null || screenTitle != null) {
                _readEntireScreen(context);
              } else {
                _showVoiceMenu(context);
              }
            }
          },
          backgroundColor:
              isSpeaking ? Colors.red.shade700 : const Color(0xFF5B7C99),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: Icon(
            isSpeaking ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded,
            size: 24,
          ),
          label: Text(
            isSpeaking
                ? _t(english: 'Stop Voice', hindi: 'रोकें')
                : _t(english: 'Voice Help', hindi: 'सुनें'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        );
      },
    );
  }
}

// =====================================================
// PERSISTENT AUDIO PLAYING BANNER
// =====================================================

class VoiceAssistantSpeakingBanner extends StatelessWidget {
  final String selectedLanguage;

  const VoiceAssistantSpeakingBanner({
    super.key,
    required this.selectedLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceAssistantService.instance.isSpeakingNotifier,
      builder: (context, isSpeaking, child) {
        if (!isSpeaking) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF30485C),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: Colors.greenAccent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable:
                      VoiceAssistantService.instance.currentTextNotifier,
                  builder: (context, text, _) {
                    return Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => VoiceAssistantService.instance.stop(),
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
