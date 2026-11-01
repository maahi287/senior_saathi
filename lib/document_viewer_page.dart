import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class DocumentViewerPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final String fileName;
  final String fileType; // 'image' or 'pdf'
  final String base64Data;
  final String dateStr;
  final String notes;
  final String selectedLanguage;

  const DocumentViewerPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.fileType,
    required this.base64Data,
    required this.dateStr,
    required this.notes,
    required this.selectedLanguage,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  bool get _isPdf => widget.fileType.toLowerCase() == 'pdf';
  bool get _isImage => widget.fileType.toLowerCase() == 'image';

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale + 0.3).clamp(1.0, 4.0);
      _transformController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale - 0.3).clamp(1.0, 4.0);
      _transformController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _openPdf() async {
    try {
      final uri = Uri.parse('data:application/pdf;base64,${widget.base64Data}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                english: 'Could not open PDF viewer. Please ensure a PDF reader is installed.',
                hindi: 'पीडीएफ व्यूअर खोलने में असमर्थ।',
                marathi: 'पीडीएफ व्ह्यूअर उघडता आले नाही.',
                gujarati: 'પીડીએફ વ્યૂઅર ખોલી શકાયું નથી.',
                telugu: 'పిడిఎఫ్ వ్యూయర్‌ను తెరవడం సాధ్యం కాలేదు.',
                tamil: 'PDF வியூவரைத் திறக்க முடியவில்லை.',
                bengali: 'পিডিএফ ভিউয়ার খোলা যাচ্ছে না।',
                kannada: 'ಪಿಡಿಎಫ್ ವೀಕ್ಷಕವನ್ನು ತೆರೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
                malayalam: 'പിഡിഎഫ് വ്യൂവർ തുറക്കാൻ കഴിഞ്ഞില്ല.',
                punjabi: 'ਪੀਡੀਐਫ ਵਿਊਅਰ ਖੋਲ੍ਹਿਆ ਨਹੀਂ ਜਾ ਸਕਿਆ।',
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
            backgroundColor: const Color(0xFFD95C5C),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF30485C), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF263B4A),
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: Color(0xFF687780),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_isImage) ...[
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded, color: Color(0xFF5B7C99), size: 28),
              tooltip: 'Zoom In',
              onPressed: _zoomIn,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded, color: Color(0xFF5B7C99), size: 28),
              tooltip: 'Zoom Out',
              onPressed: _zoomOut,
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFF5B7C99), size: 28),
              tooltip: 'Reset Zoom',
              onPressed: _resetZoom,
            ),
          ],
          if (_isPdf)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF5B7C99), size: 28),
              tooltip: 'Open in Browser/Viewer',
              onPressed: _openPdf,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: const Color(0xFFE7F0F5),
              child: Row(
                children: [
                  Icon(
                    _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: _isPdf ? const Color(0xFFD95C5C) : const Color(0xFF5B7C99),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fileName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF30485C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${appText(
                            english: 'Date',
                            hindi: 'दिनांक',
                            marathi: 'तारीख',
                            gujarati: 'તારીખ',
                            telugu: 'తేదీ',
                            tamil: 'தேதி',
                            bengali: 'তারিখ',
                            kannada: 'ದಿನಾಂಕ',
                            malayalam: 'തീയതി',
                            punjabi: 'ਮਿਤੀ',
                            selectedLanguage: widget.selectedLanguage,
                          )}: ${widget.dateStr}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF687780),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Document Display Area
            Expanded(
              child: _isImage
                  ? _buildImagePreview()
                  : _buildPdfPreview(),
            ),

            // Optional Notes Footer
            if (widget.notes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appText(
                        english: 'Doctor / Lab Notes:',
                        hindi: 'डॉक्टर / लैब नोट्स:',
                        marathi: 'डॉक्टर / लॅब नोट्स:',
                        gujarati: 'ડૉક્ટર / લેબ નોંધો:',
                        telugu: 'డాక్టర్ / ల్యాబ్ నోట్స్:',
                        tamil: 'மருத்துவர் / ஆய்வக குறிப்புகள்:',
                        bengali: 'ডাক্তার / ল্যাব নোট:',
                        kannada: 'ವೈದ್ಯರ / ಲ್ಯಾಬ್ ಟಿಪ್ಪಣಿಗಳು:',
                        malayalam: 'ഡോക്ടർ / ലാബ് കുറിപ്പുകൾ:',
                        punjabi: 'ਡਾਕਟਰ / ਲੈਬ ਨੋਟਸ:',
                        selectedLanguage: widget.selectedLanguage,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF30485C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.notes,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF40596D), height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (widget.base64Data.isEmpty) {
      return Center(
        child: Text(
          appText(
            english: 'No image data available',
            hindi: 'कोई छवि डेटा उपलब्ध नहीं है',
            marathi: 'कोणतीही प्रतिमा डेटा उपलब्ध नाही',
            gujarati: 'કોઈ ઇમેજ ડેટા ઉપલબ્ધ નથી',
            telugu: 'చిత్ర డేటా అందుబాటులో లేదు',
            tamil: 'படத் தரவு எதுவும் கிடைக்கவில்லை',
            bengali: 'কোনো ইমেজ ডেটা উপলব্ধ নেই',
            kannada: 'ಯಾವುದೇ ಚಿತ್ರ ಡೇಟಾ ಲಭ್ಯವಿಲ್ಲ',
            malayalam: 'ചിത്ര ഡാറ്റ ലഭ്യമല്ല',
            punjabi: 'ਕੋਈ ਚਿੱਤਰ ਡੇਟਾ ਉਪਲਬਧ ਨਹੀਂ ਹੈ',
            selectedLanguage: widget.selectedLanguage,
          ),
          style: const TextStyle(fontSize: 16, color: Color(0xFF687780)),
        ),
      );
    }

    try {
      final bytes = base64Decode(widget.base64Data);
      return Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image_rounded, size: 70, color: Color(0xFFD95C5C)),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pinch_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    appText(
                      english: 'Pinch or use buttons above to Zoom',
                      hindi: 'ज़ूम करने के लिए पिंच करें या ऊपर दिए गए बटन दबाएं',
                      marathi: 'झूम करण्यासाठी पिंच करा किंवा वरील बटणे वापरा',
                      gujarati: 'ઝૂમ કરવા માટે પિંચ કરો અથવા ઉપરના બટનો વાપરો',
                      telugu: 'జూమ్ చేయడానికి పించ్ చేయండి లేదా పై బటన్లను ఉపయోగించండి',
                      tamil: 'பெரிதாக்க விரல்களால் விரிவுபடுத்தவும் அல்லது பொத்தான்களைப் பயன்படுத்தவும்',
                      bengali: 'জুম করতে পিঞ্চ করুন বা উপরের বোতামগুলি ব্যবহার করুন',
                      kannada: 'ಜೂಮ್ ಮಾಡಲು ಪಿಂಚ್ ಮಾಡಿ ಅಥವಾ ಮೇಲಿನ ಬಟನ್‌ಗಳನ್ನು ಬಳಸಿ',
                      malayalam: 'വലുതാക്കാൻ വിരലുകൾ ഉപയോഗിക്കുക',
                      punjabi: 'ਜ਼ੂਮ ਕਰਨ ਲਈ ਪਿੰਚ ਕਰੋ ਜਾਂ ਉੱਪਰਲੇ ਬਟਨ ਵਰਤੋ',
                      selectedLanguage: widget.selectedLanguage,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      return Center(
        child: Text('Error decoding image: $e'),
      );
    }
  }

  Widget _buildPdfPreview() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFCDD2), width: 3),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 80,
                color: Color(0xFFD95C5C),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263B4A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              appText(
                english: 'PDF Document Ready to View',
                hindi: 'पीडीएफ दस्तावेज़ देखने के लिए तैयार है',
                marathi: 'पीडीएफ दस्तऐवज पाहण्यासाठी तयार आहे',
                gujarati: 'પીડીએફ દસ્તાવેજ જોવા માટે તૈયાર છે',
                telugu: 'పిడిఎఫ్ పత్రం వీక్షించడానికి సిద్ధంగా ఉంది',
                tamil: 'PDF ஆவணம் பார்க்க தயாராக உள்ளது',
                bengali: 'পিডিএফ নথি দেখার জন্য প্রস্তুত',
                kannada: 'ಪಿಡಿಎಫ್ ದಾಖಲೆ ವೀಕ್ಷಿಸಲು ಸಿದ್ಧವಾಗಿದೆ',
                malayalam: 'പിഡിഎഫ് പ്രമാണം കാണാൻ തയ്യാറാണ്',
                punjabi: 'ਪੀਡੀਐਫ ਦਸਤਾਵੇਜ਼ ਦੇਖਣ ਲਈ ਤਿਆਰ ਹੈ',
                selectedLanguage: widget.selectedLanguage,
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF687780),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _openPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B7C99),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 26),
                label: Text(
                  appText(
                    english: 'Open Full PDF Document',
                    hindi: 'पूरा पीडीएफ दस्तावेज़ खोलें',
                    marathi: 'संपूर्ण पीडीएफ दस्तऐवज उघडा',
                    gujarati: 'સંપૂર્ણ પીડીએફ દસ્તાવેજ ખોલો',
                    telugu: 'పూర్తి పిడిఎఫ్ పత్రాన్ని తెరవండి',
                    tamil: 'முழு PDF ஆவணத்தைத் திறக்கவும்',
                    bengali: 'সম্পূর্ণ পিডিএফ নথি খুলুন',
                    kannada: 'ಸಂಪೂರ್ಣ ಪಿಡಿಎಫ್ ದಾಖಲೆಯನ್ನು ತೆರೆಯಿರಿ',
                    malayalam: 'മുഴുവൻ പിഡിഎഫ് പ്രമാണവും തുറക്കുക',
                    punjabi: 'ਪੂਰਾ ਪੀਡੀਐਫ ਦਸਤਾਵੇਜ਼ ਖੋਲ੍ਹੋ',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF5B7C99), size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appText(
                        english: 'Tip: You can zoom, rotate, download, and print this PDF once opened.',
                        hindi: 'सुझाव: खुलने के बाद आप इस पीडीएफ को ज़ूम, घुमा, डाउनलोड और प्रिंट कर सकते हैं।',
                        marathi: 'टीप: उघडल्यानंतर तुम्ही ही पीडीएफ झूम, फिरवू, डाउनलोड आणि प्रिंट करू शकता.',
                        gujarati: 'ટિપ: ખોલ્યા પછી તમે આ પીડીએફને ઝૂમ, ફેરવી, ડાઉનલોડ અને પ્રિન્ટ કરી શકો છો.',
                        telugu: 'చిట్కా: తెరిచిన తర్వాత మీరు ఈ పిడిఎఫ్‌ను జూమ్ చేయవచ్చు, డౌన్‌లోడ్ చేయవచ్చు మరియు ముద్రించవచ్చు.',
                        tamil: 'குறிப்பு: திறந்ததும் இந்த PDF-ஐ பெரிதாக்கலாம், பதிவிறக்கலாம் மற்றும் அச்சிடலாம்.',
                        bengali: 'টিপ: খোলার পর আপনি এই পিডিএফ জুম, ডাউনলোড ও প্রিন্ট করতে পারবেন।',
                        kannada: 'ಸಲಹೆ: ತೆರೆದ ನಂತರ ನೀವು ಈ ಪಿಡಿಎಫ್ ಅನ್ನು ಜೂಮ್ ಮಾಡಬಹುದು, ಡೌನ್‌ಲೋಡ್ ಮಾಡಬಹುದು ಮತ್ತು ಮುದ್ರಿಸಬಹುದು.',
                        malayalam: 'സൂചന: തുറന്ന ശേഷം നിങ്ങൾക്ക് ഈ പിഡിഎഫ് വലുതാക്കാനും ഡൗൺലോഡ് ചെയ്യാനും പ്രിന്റ് ചെയ്യാനും കഴിയും.',
                        punjabi: 'ਸੁਝਾਅ: ਖੋਲ੍ਹਣ ਤੋਂ ਬਾਅਦ ਤੁਸੀਂ ਇਸ ਪੀਡੀਐਫ ਨੂੰ ਜ਼ੂਮ, ਡਾਊਨਲੋਡ ਅਤੇ ਪ੍ਰਿੰਟ ਕਰ ਸਕਦੇ ਹੋ।',
                        selectedLanguage: widget.selectedLanguage,
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
    );
  }
}
