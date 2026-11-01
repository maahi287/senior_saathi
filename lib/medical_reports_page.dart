import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'main.dart';
import 'medical_models.dart';
import 'document_viewer_page.dart';

class MedicalReportsPage extends StatefulWidget {
  final String selectedLanguage;

  const MedicalReportsPage({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<MedicalReportsPage> createState() => _MedicalReportsPageState();
}

class _MedicalReportsPageState extends State<MedicalReportsPage> {
  List<MedicalReport> _reports = [];
  bool _isLoading = true;
  String _selectedCategoryFilter = 'All';

  final List<String> _categories = [
    'Blood Test',
    'Urine Test',
    'X-Ray',
    'Scan / MRI',
    'ECG',
    'Diabetes Test',
    'Thyroid Test',
    'Other Report',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await MedicalStorageService.loadReports();
    if (!mounted) return;
    setState(() {
      _reports = list;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'blood test':
        return const Color(0xFFD95C5C); // Red
      case 'urine test':
        return const Color(0xFFE08B38); // Orange
      case 'x-ray':
        return const Color(0xFF5B7C99); // Blue
      case 'scan / mri':
        return const Color(0xFF6B52AE); // Purple
      case 'ecg':
        return const Color(0xFFD81B60); // Pink
      case 'diabetes test':
        return const Color(0xFF43A047); // Green
      case 'thyroid test':
        return const Color(0xFF00ACC1); // Teal
      default:
        return const Color(0xFF687780); // Gray
    }
  }

  // --- UPLOAD / EDIT DIALOG ---

  Future<void> _showUploadDialog({MedicalReport? existing}) async {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final labController = TextEditingController(text: existing?.labName ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    String selectedCategory = existing?.category ?? _categories.first;
    DateTime selectedDate = existing?.testDate ?? DateTime.now();
    PlatformFile? pickedFile;
    Uint8List? pickedBytes;
    String? existingFileName = existing?.fileName;
    String? existingFileType = existing?.fileType;
    String? existingBase64 = existing?.base64Data;
    int existingFileSize = existing?.fileSize ?? 0;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasFile = pickedFile != null || (isEditing && existingBase64 != null && existingBase64.isNotEmpty);
            final currentFileName = pickedFile != null ? pickedFile!.name : (existingFileName ?? '');

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.assignment_rounded, color: Color(0xFF6C9A7A), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? appText(
                              english: 'Edit Medical Report',
                              hindi: 'मेडिकल रिपोर्ट संपादित करें',
                              marathi: 'वैद्यकीय अहवाल संपादित करा',
                              gujarati: 'તબીબી અહેવાલ સંપાદિત કરો',
                              telugu: 'వైద్య నివేదికను సవరించండి',
                              tamil: 'மருத்துவ அறிக்கையைத் திருத்தவும்',
                              bengali: 'মেডিকেল রিপোর্ট সম্পাদনা করুন',
                              kannada: 'ವೈದ್ಯಕೀಯ ವರದಿಯನ್ನು ಸಂಪಾದಿಸಿ',
                              malayalam: 'മെഡിക്കൽ റിപ്പോർട്ട് തിരുത്തുക',
                              punjabi: 'ਮੈਡੀਕਲ ਰਿਪੋਰਟ ਸੋਧੋ',
                              selectedLanguage: widget.selectedLanguage,
                            )
                          : appText(
                              english: 'Upload Medical Report',
                              hindi: 'मेडिकल रिपोर्ट अपलोड करें',
                              marathi: 'वैद्यकीय अहवाल अपलोड करा',
                              gujarati: 'તબીબી અહેવાલ અપલોડ કરો',
                              telugu: 'వైద్య నివేదికను అప్‌లోడ్ చేయండి',
                              tamil: 'மருத்துவ அறிக்கையைப் பதிவேற்றவும்',
                              bengali: 'মেডিকেল রিপোর্ট আপলোড করুন',
                              kannada: 'ವೈದ್ಯಕೀಯ ವರದಿ ಅಪ್‌ಲೋಡ್ ಮಾಡಿ',
                              malayalam: 'മെഡിക്കൽ റിപ്പോർട്ട് അപ്‌ലോഡ് ചെയ്യുക',
                              punjabi: 'ਮੈਡੀਕਲ ਰਿਪੋਰਟ ਅੱਪਲੋਡ ਕਰੋ',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF263B4A)),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // FILE PICKER
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: hasFile ? const Color(0xFF6C9A7A) : const Color(0xFF5B7C99).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                hasFile ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                                size: 44,
                                color: hasFile ? const Color(0xFF6C9A7A) : const Color(0xFF5B7C99),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hasFile
                                    ? currentFileName
                                    : appText(
                                        english: 'Select Report File (PDF or Photo)',
                                        hindi: 'रिपोर्ट फ़ाइल चुनें (पीडीएफ या फ़ोटो)',
                                        marathi: 'अहवाल फाइल निवडा (पीडीएफ किंवा फोटो)',
                                        gujarati: 'અહેવાલ ફાઇલ પસંદ કરો (પીડીએફ અથવા ફોટો)',
                                        telugu: 'నివేదిక ఫైల్ ఎంచుకోండి (పిడిఎఫ్ లేదా ఫోటో)',
                                        tamil: 'அறிக்கைக் கோப்பைத் தேர்ந்தெடுக்கவும் (PDF அல்லது புகைப்படம்)',
                                        bengali: 'রিপোর্ট ফাইল নির্বাচন করুন (পিডিএফ বা ছবি)',
                                        kannada: 'ವರದಿ ಫೈಲ್ ಆಯ್ಕೆಮಾಡಿ (ಪಿಡಿಎಫ್ ಅಥವಾ ಫೋಟೋ)',
                                        malayalam: 'റിപ്പോർട്ട് ഫയൽ തിരഞ്ഞെടുക്കുക (പിഡിഎഫ് അല്ലെങ്കിൽ ഫോട്ടോ)',
                                        punjabi: 'ਰਿਪੋਰਟ ਫ਼ਾਈਲ ਚੁਣੋ (ਪੀਡੀਐਫ ਜਾਂ ਫ਼ੋਟੋ)',
                                        selectedLanguage: widget.selectedLanguage,
                                      ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: hasFile ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 15,
                                  color: hasFile ? const Color(0xFF30485C) : const Color(0xFF687780),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    final result = await FilePicker.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                                    );

                                    if (result.isNotEmpty) {
                                      final file = result.first;
                                      final bytes = await file.readAsBytes();
                                      setDialogState(() {
                                        pickedFile = file;
                                        pickedBytes = bytes;
                                      });
                                    }
                                  } catch (err) {
                                    debugPrint('Picker error: $err');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B7C99),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.file_present_rounded, size: 20),
                                label: Text(
                                  hasFile
                                      ? appText(
                                          english: 'Change File',
                                          hindi: 'फ़ाइल बदलें',
                                          marathi: 'फाइल बदला',
                                          gujarati: 'ફાઇલ બદલો',
                                          telugu: 'ఫైల్ మార్చండి',
                                          tamil: 'கோப்பை மாற்றவும்',
                                          bengali: 'ফাইল পরিবর্তন করুন',
                                          kannada: 'ಫೈಲ್ ಬದಲಾಯಿಸಿ',
                                          malayalam: 'ഫയൽ മാറ്റുക',
                                          punjabi: 'ਫਾਈਲ ਬਦਲੋ',
                                          selectedLanguage: widget.selectedLanguage,
                                        )
                                      : appText(
                                          english: 'Choose File',
                                          hindi: 'फ़ाइल चुनें',
                                          marathi: 'फाइल निवडा',
                                          gujarati: 'ફાઇલ પસંદ કરો',
                                          telugu: 'ఫైల్ ఎంచుకోండి',
                                          tamil: 'கோப்பைத் தேர்ந்தெடுக்கவும்',
                                          bengali: 'ফাইল চয়ন করুন',
                                          kannada: 'ಫೈಲ್ ಆಯ್ಕೆಮಾಡಿ',
                                          malayalam: 'ഫയൽ തിരഞ്ഞെടുക്കുക',
                                          punjabi: 'ਫਾਈਲ ਚੁਣੋ',
                                          selectedLanguage: widget.selectedLanguage,
                                        ),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // REPORT TITLE
                        TextFormField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: '${appText(
                              english: 'Report Title',
                              hindi: 'रिपोर्ट का शीर्षक',
                              marathi: 'अहवालाचे नाव',
                              gujarati: 'અહેવાલ શીર્ષક',
                              telugu: 'నివేదిక శీర్షిక',
                              tamil: 'அறிக்கை தலைப்பு',
                              bengali: 'রিপোর্ট শিরোনাম',
                              kannada: 'ವರದಿ ಶೀರ್ಷಿಕೆ',
                              malayalam: 'റിപ്പോർട്ട് തലക്കെട്ട്',
                              punjabi: 'ਰਿਪੋਰਟ ਦਾ ਸਿਰਲੇਖ',
                              selectedLanguage: widget.selectedLanguage,
                            )} *',
                            hintText: 'e.g. Lipid Profile & Cholesterol',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF5B7C99)),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a title' : null,
                        ),

                        const SizedBox(height: 14),

                        // CATEGORY SELECTOR
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: InputDecoration(
                            labelText: appText(
                              english: 'Test Category',
                              hindi: 'परीक्षण श्रेणी',
                              marathi: 'चाचणी श्रेणी',
                              gujarati: 'ટેસ્ટ શ્રેણી',
                              telugu: 'పరీక్ష వర్గం',
                              tamil: 'சோதனை வகை',
                              bengali: 'পরীক্ষার বিভাগ',
                              kannada: 'ಪರೀಕ್ಷಾ ವರ್ಗ',
                              malayalam: 'പരിശോധനാ വിഭാഗം',
                              punjabi: 'ਟੈਸਟ ਸ਼੍ਰੇਣੀ',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.category_rounded, color: Color(0xFF5B7C99)),
                          ),
                          items: _categories.map((c) {
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(c),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),

                        const SizedBox(height: 14),

                        // LAB / HOSPITAL NAME
                        TextFormField(
                          controller: labController,
                          decoration: InputDecoration(
                            labelText: appText(
                              english: 'Laboratory / Hospital Name',
                              hindi: 'प्रयोगशाला / अस्पताल का नाम',
                              marathi: 'प्रयोगशाळा / रुग्णालयाचे नाव',
                              gujarati: 'પ્રયોગશાળા / હોસ્પિટલનું નામ',
                              telugu: 'ప్రయోగశాల / ఆసుపత్రి పేరు',
                              tamil: 'ஆய்வகம் / மருத்துவமனை பெயர்',
                              bengali: 'ল্যাবরেটরি / হাসপাতালের নাম',
                              kannada: 'ಪ್ರಯೋಗಾಲಯ / ಆಸ್ಪತ್ರೆ ಹೆಸರು',
                              malayalam: 'ലബോറട്ടറി / ആശുപത്രി പേര്',
                              punjabi: 'ਲੈਬਾਰਟਰੀ / ਹਸਪਤਾਲ ਦਾ ਨਾਮ',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                            hintText: 'e.g. Dr. Lal PathLabs',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.biotech_rounded, color: Color(0xFF5B7C99)),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // TEST DATE PICKER TILE
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: Color(0xFF5B7C99)),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appText(
                                        english: 'Test Date',
                                        hindi: 'परीक्षण दिनांक',
                                        marathi: 'चाचणी तारीख',
                                        gujarati: 'ટેસ્ટ તારીખ',
                                        telugu: 'పరీక్ష తేదీ',
                                        tamil: 'சோதனை தேதி',
                                        bengali: 'পরীক্ষার তারিখ',
                                        kannada: 'ಪರೀಕ್ಷಾ ದಿನಾಂಕ',
                                        malayalam: 'പരിശോധനാ തീയതി',
                                        punjabi: 'ਟੈਸਟ ਦੀ ਮਿਤੀ',
                                        selectedLanguage: widget.selectedLanguage,
                                      ),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF687780)),
                                    ),
                                    Text(
                                      _formatDate(selectedDate),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF263B4A)),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.edit_calendar_rounded, color: Color(0xFF5B7C99)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // NOTES / VALUES
                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: appText(
                              english: 'Notes / Key Results (Optional)',
                              hindi: 'नोट्स / मुख्य परिणाम (वैकल्पिक)',
                              marathi: 'नोंदी / मुख्य निकाल (पर्यायी)',
                              gujarati: 'નોંધો / મુખ્ય પરિણામો (વૈકલ્પિક)',
                              telugu: 'గమనికలు / ముఖ్య ఫలితాలు (ఐచ్ఛికం)',
                              tamil: 'குறிப்புகள் / முக்கிய முடிவுகள் (விருப்பத்தேர்வு)',
                              bengali: 'নোট / মূল ফলাফল (ঐচ্ছিক)',
                              kannada: 'ಟಿಪ್ಪಣಿಗಳು / ಪ್ರಮುಖ ಫಲಿತಾಂಶಗಳು (ಐಚ್ಛಿಕ)',
                              malayalam: 'കുറിപ്പുകൾ / പ്രധാന ഫലങ്ങൾ (ഓപ്ഷണൽ)',
                              punjabi: 'ਨੋਟਸ / ਮੁੱਖ ਨਤੀਜੇ (ਵਿਕਲਪਿਕ)',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                            hintText: 'e.g. Fasting sugar: 105, HbA1c: 6.2%',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF5B7C99)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    appText(
                      english: 'Cancel',
                      hindi: 'रद्द करें',
                      marathi: 'रद्द करा',
                      gujarati: 'રદ કરો',
                      telugu: 'రద్దు చేయండి',
                      tamil: 'ரத்து செய்',
                      bengali: 'বাতিল',
                      kannada: 'ರದ್ದುಮಾಡಿ',
                      malayalam: 'റദ്ദാക്കുക',
                      punjabi: 'ਰੱਦ ਕਰੋ',
                      selectedLanguage: widget.selectedLanguage,
                    ),
                    style: const TextStyle(fontSize: 16, color: Color(0xFF687780)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C9A7A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (!hasFile) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a photo or PDF of the report')),
                      );
                      return;
                    }

                    String finalBase64 = existingBase64 ?? '';
                    String finalName = existingFileName ?? 'medical_report';
                    String finalType = existingFileType ?? 'image';
                    int finalSize = existingFileSize;

                    if (pickedFile != null && pickedBytes != null) {
                      finalBase64 = base64Encode(pickedBytes!);
                      finalName = pickedFile!.name;
                      final ext = pickedFile!.extension?.toLowerCase() ?? '';
                      finalType = ext == 'pdf' ? 'pdf' : 'image';
                      finalSize = pickedBytes!.length;
                    }

                    final item = MedicalReport(
                      id: existing?.id,
                      title: titleController.text.trim(),
                      category: selectedCategory,
                      testDate: selectedDate,
                      labName: labController.text.trim(),
                      notes: notesController.text.trim(),
                      fileName: finalName,
                      fileType: finalType,
                      base64Data: finalBase64,
                      fileSize: finalSize,
                    );

                    await MedicalStorageService.saveReport(item);
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);
                    _loadData();
                  },
                  child: Text(
                    appText(
                      english: isEditing ? 'Save Changes' : 'Upload',
                      hindi: isEditing ? 'बदलाव सहेजें' : 'अपलोड करें',
                      marathi: isEditing ? 'बदल जतन करा' : 'अपलोड करा',
                      gujarati: isEditing ? 'ફેરફારો સાચવો' : 'અપલોડ કરો',
                      telugu: isEditing ? 'మార్పులను సేవ్ చేయండి' : 'అప్‌లోడ్ చేయండి',
                      tamil: isEditing ? 'மாற்றங்களைச் சேமிக்கவும்' : 'பதிவேற்றவும்',
                      bengali: isEditing ? 'পরিবর্তন সংরক্ষণ করুন' : 'আপলোড করুন',
                      kannada: isEditing ? 'ಬದಲಾವಣೆಗಳನ್ನು ಉಳಿಸಿ' : 'ಅಪ್‌ಲೋಡ್ ಮಾಡಿ',
                      malayalam: isEditing ? 'മാറ്റങ്ങൾ സംരക്ഷിക്കുക' : 'അപ്‌ലോഡ് ചെയ്യുക',
                      punjabi: isEditing ? 'ਤਬਦੀਲੀਆਂ ਸੰਭਾਲੋ' : 'ਅੱਪਲੋਡ ਕਰੋ',
                      selectedLanguage: widget.selectedLanguage,
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DELETE CONFIRMATION ---

  Future<void> _confirmDelete(MedicalReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD95C5C), size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  appText(
                    english: 'Delete Medical Report?',
                    hindi: 'मेडिकल रिपोर्ट हटाएं?',
                    marathi: 'वैद्यकीय अहवाल हटवायचा?',
                    gujarati: 'તબીબી અહેવાલ કાઢી નાખો?',
                    telugu: 'వైద్య నివేదికను తొలగించాలా?',
                    tamil: 'மருத்துவ அறிக்கையை நீக்கவா?',
                    bengali: 'মেডিকেল রিপোর্ট মুছে ফেলবেন?',
                    kannada: 'ವೈದ್ಯಕೀಯ ವರದಿ ಅಳಿಸಬೇಕೇ?',
                    malayalam: 'മെഡിക്കൽ റിപ്പോർട്ട് ഇല്ലാതാക്കണോ?',
                    punjabi: 'ਮੈਡੀਕਲ ਰਿਪੋਰਟ ਹਟਾਓ?',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                ),
              ),
            ],
          ),
          content: Text(
            appText(
              english: 'Are you sure you want to permanently delete "${report.title}"? This cannot be undone.',
              hindi: 'क्या आप निश्चित रूप से "${report.title}" को हमेशा के लिए हटाना चाहते हैं? इसे वापस नहीं लाया जा सकता।',
              marathi: 'तुम्हाला नक्की "${report.title}" कायमचे हटवायचे आहे का? ही कृती पूर्ववत करता येणार नाही.',
              gujarati: 'શું તમે ખરેખર "${report.title}" ને કાયમ માટે કાઢી નાખવા માંગો છો?',
              telugu: 'మీరు నిజంగా "${report.title}" ను శాశ్వతంగా తొలగించాలనుకుంటున్నారా?',
              tamil: '"${report.title}" ஐ நிரந்தரமாக நீக்க விரும்புகிறீர்களா?',
              bengali: 'আপনি কি নিশ্চিত যে আপনি "${report.title}" স্থায়ীভাবে মুছে ফেলতে চান?',
              kannada: 'ನೀವು ನಿಜವಾಗಿಯೂ "${report.title}" ಅನ್ನು ಶಾಶ್ವತವಾಗಿ ಅಳಿಸಲು ಬಯಸುವಿರಾ?',
              malayalam: '"${report.title}" ശാശ്വതമായി ഇല്ലാതാക്കാൻ നിങ്ങൾ തീർച്ചയായും ആഗ്രഹിക്കുന്നുണ്ടോ?',
              punjabi: 'ਕੀ ਤੁਸੀਂ ਵਾਕਈ "${report.title}" ਨੂੰ ਪੱਕੇ ਤੌਰ \'ਤੇ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
              selectedLanguage: widget.selectedLanguage,
            ),
            style: const TextStyle(fontSize: 16, color: Color(0xFF40596D)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontSize: 16, color: Color(0xFF687780))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD95C5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await MedicalStorageService.deleteReport(report.id);
      _loadData();
    }
  }

  void _openViewer(MedicalReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerPage(
          title: report.title,
          subtitle: '${report.category} • ${report.labName}',
          fileName: report.fileName,
          fileType: report.fileType,
          base64Data: report.base64Data,
          dateStr: _formatDate(report.testDate),
          notes: report.notes,
          selectedLanguage: widget.selectedLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _reports.where((r) {
      if (_selectedCategoryFilter == 'All') return true;
      return r.category.toLowerCase() == _selectedCategoryFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF30485C), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          appText(
            english: 'My Medical Reports',
            hindi: 'मेरी मेडिकल रिपोर्ट',
            marathi: 'माझे वैद्यकीय अहवाल',
            gujarati: 'મારા તબીબી અહેવાલો',
            telugu: 'నా వైద్య నివేదికలు',
            tamil: 'என் மருத்துவ அறிக்கைகள்',
            bengali: 'আমার মেডিকেল রিপোর্ট',
            kannada: 'ನನ್ನ ವೈದ್ಯಕೀಯ ವರದಿಗಳು',
            malayalam: 'എന്റെ മെഡിക്കൽ റിപ്പോർട്ടുകൾ',
            punjabi: 'ਮੇਰੀਆਂ ਮੈਡੀਕਲ ਰਿਪੋਰਟਾਂ',
            selectedLanguage: widget.selectedLanguage,
          ),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF263B4A),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        ..._categories.map((c) => _buildFilterChip(c)),
                      ],
                    ),
                  ),

                  // Reports List or Empty State
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildReportCard(item);
                            },
                          ),
                  ),

                  // Floating-style Bottom Upload Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: () => _showUploadDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C9A7A),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.note_add_rounded, size: 24),
                        label: Text(
                          appText(
                            english: 'Upload Medical Report',
                            hindi: 'मेडिकल रिपोर्ट अपलोड करें',
                            marathi: 'वैद्यकीय अहवाल अपलोड करा',
                            gujarati: 'તબીબી અહેવાલ અપલોડ કરો',
                            telugu: 'వైద్య నివేదికను అప్‌లోడ్ చేయండి',
                            tamil: 'மருத்துவ அறிக்கையைப் பதிவேற்றவும்',
                            bengali: 'মেডিকেল রিপোর্ট আপলোড করুন',
                            kannada: 'ವೈದ್ಯಕೀಯ ವರದಿ ಅಪ್‌ಲೋಡ್ ಮಾಡಿ',
                            malayalam: 'മെഡിക്കൽ റിപ്പോർട്ട് അപ്‌ലോഡ് ചെയ്യുക',
                            punjabi: 'ਮੈਡੀਕਲ ਰਿਪੋਰਟ ਅੱਪਲੋਡ ਕਰੋ',
                            selectedLanguage: widget.selectedLanguage,
                          ),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedCategoryFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label == 'All'
              ? appText(
                  english: 'All Reports',
                  hindi: 'सभी रिपोर्ट',
                  marathi: 'सर्व अहवाल',
                  gujarati: 'બધા અહેવાલો',
                  telugu: 'అన్ని నివేదికలు',
                  tamil: 'அனைத்து அறிக்கைகளும்',
                  bengali: 'সমস্ত রিপোর্ট',
                  kannada: 'ಎಲ್ಲಾ ವರದಿಗಳು',
                  malayalam: 'എല്ലാ റിപ്പോർട്ടുകളും',
                  punjabi: 'ਸਾਰੀਆਂ ਰਿਪੋਰਟਾਂ',
                  selectedLanguage: widget.selectedLanguage,
                )
              : label,
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF6C9A7A),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF40596D),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 14,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF6C9A7A) : const Color(0xFFD9E3EA),
          ),
        ),
        onSelected: (selected) {
          setState(() {
            _selectedCategoryFilter = label;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_rounded,
                size: 70,
                color: Color(0xFF6C9A7A),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              appText(
                english: 'No Medical Reports Yet',
                hindi: 'अभी कोई मेडिकल रिपोर्ट नहीं है',
                marathi: 'अद्याप कोणतेही वैद्यकीय अहवाल नाहीत',
                gujarati: 'હજી સુધી કોઈ તબીબી અહેવાલ નથી',
                telugu: 'ఇంకా వైద్య నివేదికలు లేవు',
                tamil: 'மருத்துவ அறிக்கைகள் எதுவும் இல்லை',
                bengali: 'এখনো কোনো মেডিকেল রিপোর্ট নেই',
                kannada: 'ಇನ್ನೂ ಯಾವುದೇ ವೈದ್ಯಕೀಯ ವರದಿಗಳಿಲ್ಲ',
                malayalam: 'ഇതുവരെ മെഡിക്കൽ റിപ്പോർട്ടുകളൊന്നും ഇല്ല',
                punjabi: 'ਅਜੇ ਕੋਈ ਮੈਡੀਕਲ ਰਿਪੋਰਟ ਨਹੀਂ ਹੈ',
                selectedLanguage: widget.selectedLanguage,
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263B4A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appText(
                english: 'Store your blood tests, X-rays, ECGs, and scans safely in one place for doctor visits.',
                hindi: 'डॉक्टर से मिलने के लिए अपने ब्लड टेस्ट, एक्स-रे, ईसीजी और स्कैन एक ही स्थान पर सुरक्षित रखें।',
                marathi: 'डॉक्टरांच्या भेटीसाठी तुमचे रक्त तपासणी, एक्स-रे, ईसीजी आणि स्कॅन एकाच ठिकाणी सुरक्षित ठेवा.',
                gujarati: 'તમારા બ્લડ ટેસ્ટ, એક્સ-રે, ઇસીજી અને સ્કેન સુરક્ષિત રાખો.',
                telugu: 'మీ రక్త పరీక్షలు, ఎక్స్-రేలు, ఇసిజి మరియు స్కాన్‌లను ఒకే చోట భద్రపరుచుకోండి.',
                tamil: 'மருத்துவ சந்திப்புகளுக்காக உங்கள் இரத்தப் பரிசோதனைகள், எக்ஸ்-ரே, ஈசிஜி ஆகியவற்றை ஒரே இடத்தில் பாதுகாக்கவும்.',
                bengali: 'ডাক্তারের পরিদর্শনের জন্য আপনার রক্ত পরীক্ষা, এক্স-রে ও স্ক্যান নিরাপদে সংরক্ষণ করুন।',
                kannada: 'ವೈದ್ಯರ ಭೇಟಿಗಾಗಿ ನಿಮ್ಮ ರಕ್ತ ಪರೀಕ್ಷೆಗಳು, ಎಕ್ಸ್-ರೇಗಳು ಮತ್ತು ಇಸಿಜಿಯನ್ನು ಒಂದೇ ಸ್ಥಳದಲ್ಲಿ ಸುರಕ್ಷಿತವಾಗಿರಿಸಿ.',
                malayalam: 'നിങ്ങളുടെ രക്തപരിശോധനകൾ, എക്സ്-റേകൾ, ഇസിജി എന്നിവ ഒരിടത്ത് സുരക്ഷിതമായി സൂക്ഷിക്കുക.',
                punjabi: 'ਡਾਕਟਰ ਨੂੰ ਦਿਖਾਉਣ ਲਈ ਆਪਣੇ ਬਲੱਡ ਟੈਸਟ, ਐਕਸ-ਰੇ ਅਤੇ ਈਸੀਜੀ ਇੱਕੋ ਥਾਂ ਸੁਰੱਖਿਅਤ ਰੱਖੋ।',
                selectedLanguage: widget.selectedLanguage,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF687780),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(MedicalReport item) {
    final catColor = _getCategoryColor(item.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openViewer(item),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        color: catColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: catColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF263B4A),
                            ),
                          ),
                          if (item.labName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.labName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF687780),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF687780)),
                      onSelected: (val) {
                        if (val == 'view') {
                          _openViewer(item);
                        } else if (val == 'edit') {
                          _showUploadDialog(existing: item);
                        } else if (val == 'delete') {
                          _confirmDelete(item);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_rounded, color: Color(0xFF5B7C99)), SizedBox(width: 10), Text('View / Read')])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, color: Color(0xFF5B7C99)), SizedBox(width: 10), Text('Edit Details')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, color: Color(0xFFD95C5C)), SizedBox(width: 10), Text('Delete')])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF687780)),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(item.testDate),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF687780), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F6F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.isPdf ? 'PDF • ${item.fileSizeFormatted}' : 'IMAGE • ${item.fileSizeFormatted}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5B7C99),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
