import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'main.dart';
import 'medical_models.dart';
import 'document_viewer_page.dart';

class PrescriptionsPage extends StatefulWidget {
  final String selectedLanguage;

  const PrescriptionsPage({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<PrescriptionsPage> createState() => _PrescriptionsPageState();
}

class _PrescriptionsPageState extends State<PrescriptionsPage> {
  List<Prescription> _prescriptions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await MedicalStorageService.loadPrescriptions();
    if (!mounted) return;
    setState(() {
      _prescriptions = list;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // --- UPLOAD / ADD PRESCRIPTION ---

  Future<void> _showUploadDialog({Prescription? existing}) async {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final doctorController = TextEditingController(text: existing?.doctorName ?? '');
    final hospitalController = TextEditingController(text: existing?.hospitalName ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    DateTime selectedDate = existing?.date ?? DateTime.now();
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
                      color: const Color(0xFFE7F0F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF5B7C99), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? appText(
                              english: 'Edit Prescription',
                              hindi: 'प्रिस्क्रिप्शन संपादित करें',
                              marathi: 'प्रिस्क्रिप्शन संपादित करा',
                              gujarati: 'પ્રિસ્ક્રિપ્શન સંપાદિત કરો',
                              telugu: 'ప్రిస్క్రిప్షన్ సవరించండి',
                              tamil: 'மருந்துச் சீட்டைத் திருத்தவும்',
                              bengali: 'প্রেসক্রিপশন সম্পাদনা করুন',
                              kannada: 'ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ಸಂಪಾದಿಸಿ',
                              malayalam: 'കുറിപ്പടി തിരുത്തുക',
                              punjabi: 'ਨੁਸਖ਼ਾ ਸੋਧੋ',
                              selectedLanguage: widget.selectedLanguage,
                            )
                          : appText(
                              english: 'Upload Prescription',
                              hindi: 'प्रिस्क्रिप्शन अपलोड करें',
                              marathi: 'प्रिस्क्रिप्शन अपलोड करा',
                              gujarati: 'પ્રિસ્ક્રિપ્શન અપલોડ કરો',
                              telugu: 'ప్రిస్క్రిప్షన్ అప్‌లోడ్ చేయండి',
                              tamil: 'மருந்துச் சீட்டைப் பதிவேற்றவும்',
                              bengali: 'প্রেসক্রিপশন আপলোড করুন',
                              kannada: 'ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ಅಪ್‌ಲೋಡ್ ಮಾಡಿ',
                              malayalam: 'കുറിപ്പടി അപ്‌ലോഡ് ചെയ്യുക',
                              punjabi: 'ਨੁਸਖ਼ਾ ਅੱਪਲੋਡ ਕਰੋ',
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
                        // FILE PICKER BUTTON / PREVIEW
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
                                        english: 'Select Prescription (Photo or PDF)',
                                        hindi: 'प्रिस्क्रिप्शन चुनें (फ़ोटो या पीडीएफ)',
                                        marathi: 'प्रिस्क्रिप्शन निवडा (फोटो किंवा पीडीएफ)',
                                        gujarati: 'પ્રિસ્ક્રિપ્શન પસંદ કરો (ફોટો અથવા પીડીએફ)',
                                        telugu: 'ప్రిస్క్రిప్షన్ ఎంచుకోండి (ఫోటో లేదా పిడిఎఫ్)',
                                        tamil: 'மருந்துச் சீட்டைத் தேர்ந்தெடுக்கவும் (புகைப்படம் அல்லது PDF)',
                                        bengali: 'প্রেসক্রিপশন নির্বাচন করুন (ছবি বা পিডিএফ)',
                                        kannada: 'ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ಆಯ್ಕೆಮಾಡಿ (ಫೋಟೋ ಅಥವಾ ಪಿಡಿಎಫ್)',
                                        malayalam: 'കുറിപ്പടി തിരഞ്ഞെടുക്കുക (ഫോട്ടോ അല്ലെങ്കിൽ പിഡിഎഫ്)',
                                        punjabi: 'ਨੁਸਖ਼ਾ ਚੁਣੋ (ਫ਼ੋਟੋ ਜਾਂ ਪੀਡੀਐਫ)',
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

                        // TITLE
                        TextFormField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: '${appText(
                              english: 'Prescription Title',
                              hindi: 'प्रिस्क्रिप्शन का शीर्षक',
                              marathi: 'प्रिस्क्रिप्शनचे नाव',
                              gujarati: 'પ્રિસ્ક્રિપ્શન શીર્ષક',
                              telugu: 'ప్రిస్క్రిప్షన్ శీర్షిక',
                              tamil: 'மருந்துச் சீட்டு தலைப்பு',
                              bengali: 'প্রেসক্রিপশন শিরোনাম',
                              kannada: 'ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ಶೀರ್ಷಿಕೆ',
                              malayalam: 'കുറിപ്പടി തലക്കെട്ട്',
                              punjabi: 'ਨੁਸਖ਼ੇ ਦਾ ਸਿਰਲੇਖ',
                              selectedLanguage: widget.selectedLanguage,
                            )} *',
                            hintText: 'e.g. Blood Pressure Medicines',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF5B7C99)),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a title' : null,
                        ),

                        const SizedBox(height: 14),

                        // DOCTOR NAME
                        TextFormField(
                          controller: doctorController,
                          decoration: InputDecoration(
                            labelText: '${appText(
                              english: 'Doctor\'s Name',
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
                            )} *',
                            hintText: 'e.g. Dr. Rajesh Gupta',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF5B7C99)),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter doctor\'s name' : null,
                        ),

                        const SizedBox(height: 14),

                        // HOSPITAL / CLINIC
                        TextFormField(
                          controller: hospitalController,
                          decoration: InputDecoration(
                            labelText: appText(
                              english: 'Hospital / Clinic Name',
                              hindi: 'अस्पताल / क्लिनिक का नाम',
                              marathi: 'रुग्णालय / क्लिनिकचे नाव',
                              gujarati: 'હોસ્પિટલ / ક્લિનિકનું નામ',
                              telugu: 'ఆసుపత్రి / క్లినిక్ పేరు',
                              tamil: 'மருத்துவமனை / கிளினிக் பெயர்',
                              bengali: 'হাসপাতাল / ক্লিনিকের নাম',
                              kannada: 'ಆಸ್ಪತ್ರೆ / ಕ್ಲಿನಿಕ್ ಹೆಸರು',
                              malayalam: 'ആശുപത്രി / ക്ലിനിക്ക് പേര്',
                              punjabi: 'ਹਸਪਤਾਲ / ਕਲੀਨਿਕ ਦਾ ਨਾਮ',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                            hintText: 'e.g. City Care Hospital',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.local_hospital_outlined, color: Color(0xFF5B7C99)),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // DATE PICKER TILE
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
                                        english: 'Prescription Date',
                                        hindi: 'प्रिस्क्रिप्शन दिनांक',
                                        marathi: 'प्रिस्क्रिप्शन तारीख',
                                        gujarati: 'પ્રિસ્ક્રિપ્શન તારીખ',
                                        telugu: 'ప్రిస్క్రిప్షన్ తేదీ',
                                        tamil: 'மருந்துச் சீட்டு தேதி',
                                        bengali: 'প্রেসক্রিপশন তারিখ',
                                        kannada: 'ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ದಿನಾಂಕ',
                                        malayalam: 'കുറിപ്പടി തീയതി',
                                        punjabi: 'ਨੁਸਖ਼ੇ ਦੀ ਮਿਤੀ',
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

                        // NOTES
                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: appText(
                              english: 'Notes / Instructions (Optional)',
                              hindi: 'नोट्स / निर्देश (वैकल्पिक)',
                              marathi: 'नोंदी / सूचना (पर्यायी)',
                              gujarati: 'નોંધો / સૂચનાઓ (વૈકલ્પિક)',
                              telugu: 'గమనికలు / సూచనలు (ఐచ్ఛికం)',
                              tamil: 'குறிப்புகள் / வழிமுறைகள் (விருப்பத்தேர்வு)',
                              bengali: 'নোট / নির্দেশাবলী (ঐচ্ছিক)',
                              kannada: 'ಟಿಪ್ಪಣಿಗಳು / ಸೂಚನೆಗಳು (ಐಚ್ಛಿಕ)',
                              malayalam: 'കുറിപ്പുകൾ / നിർദ്ദേശങ്ങൾ (ഓപ്ഷണൽ)',
                              punjabi: 'ਨੋਟਸ / ਹਦਾਇਤਾਂ (ਵਿਕਲਪਿਕ)',
                              selectedLanguage: widget.selectedLanguage,
                            ),
                            hintText: 'e.g. 1 tablet after meals for 30 days',
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
                    backgroundColor: const Color(0xFF5B7C99),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (!hasFile) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a photo or PDF of the prescription')),
                      );
                      return;
                    }

                    String finalBase64 = existingBase64 ?? '';
                    String finalName = existingFileName ?? 'prescription';
                    String finalType = existingFileType ?? 'image';
                    int finalSize = existingFileSize;

                    if (pickedFile != null && pickedBytes != null) {
                      finalBase64 = base64Encode(pickedBytes!);
                      finalName = pickedFile!.name;
                      final ext = pickedFile!.extension?.toLowerCase() ?? '';
                      finalType = ext == 'pdf' ? 'pdf' : 'image';
                      finalSize = pickedBytes!.length;
                    }

                    final item = Prescription(
                      id: existing?.id,
                      title: titleController.text.trim(),
                      doctorName: doctorController.text.trim(),
                      hospitalName: hospitalController.text.trim(),
                      date: selectedDate,
                      notes: notesController.text.trim(),
                      fileName: finalName,
                      fileType: finalType,
                      base64Data: finalBase64,
                      fileSize: finalSize,
                    );

                    await MedicalStorageService.savePrescription(item);
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

  Future<void> _confirmDelete(Prescription prescription) async {
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
                    english: 'Delete Prescription?',
                    hindi: 'प्रिस्क्रिप्शन हटाएं?',
                    marathi: 'प्रिस्क्रिप्शन हटवायचे?',
                    gujarati: 'પ્રિસ્ક્રિપ્શન કાઢી નાખો?',
                    telugu: 'ప్రిస్క్రిప్షన్‌ను తొలగించాలా?',
                    tamil: 'மருந்துச் சீட்டை நீக்கவா?',
                    bengali: 'প্রেসক্রিপশন মুছে ফেলবেন?',
                    kannada: 'ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ಅಳಿಸಬೇಕೇ?',
                    malayalam: 'കുറിപ്പടി ഇല്ലാതാക്കണോ?',
                    punjabi: 'ਨੁਸਖ਼ਾ ਹਟਾਓ?',
                    selectedLanguage: widget.selectedLanguage,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                ),
              ),
            ],
          ),
          content: Text(
            appText(
              english: 'Are you sure you want to permanently delete "${prescription.title}"? This cannot be undone.',
              hindi: 'क्या आप निश्चित रूप से "${prescription.title}" को हमेशा के लिए हटाना चाहते हैं? इसे वापस नहीं लाया जा सकता।',
              marathi: 'तुम्हाला नक्की "${prescription.title}" कायमचे हटवायचे आहे का? ही कृती पूर्ववत करता येणार नाही.',
              gujarati: 'શું તમે ખરેખર "${prescription.title}" ને કાયમ માટે કાઢી નાખવા માંગો છો?',
              telugu: 'మీరు నిజంగా "${prescription.title}" ను శాశ్వతంగా తొలగించాలనుకుంటున్నారా?',
              tamil: '"${prescription.title}" ஐ நிரந்தரமாக நீக்க விரும்புகிறீர்களா?',
              bengali: 'আপনি কি নিশ্চিত যে আপনি "${prescription.title}" স্থায়ীভাবে মুছে ফেলতে চান?',
              kannada: 'ನೀವು ನಿಜವಾಗಿಯೂ "${prescription.title}" ಅನ್ನು ಶಾಶ್ವತವಾಗಿ ಅಳಿಸಲು ಬಯಸುವಿರಾ?',
              malayalam: '"${prescription.title}" ശാശ്വതമായി ഇല്ലാതാക്കാൻ നിങ്ങൾ തീർച്ചയായും ആഗ്രഹിക്കുന്നുണ്ടോ?',
              punjabi: 'ਕੀ ਤੁਸੀਂ ਵਾਕਈ "${prescription.title}" ਨੂੰ ਪੱਕੇ ਤੌਰ \'ਤੇ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
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
      await MedicalStorageService.deletePrescription(prescription.id);
      _loadData();
    }
  }

  void _openViewer(Prescription prescription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerPage(
          title: prescription.title,
          subtitle: '${prescription.doctorName} • ${prescription.hospitalName}',
          fileName: prescription.fileName,
          fileType: prescription.fileType,
          base64Data: prescription.base64Data,
          dateStr: _formatDate(prescription.date),
          notes: prescription.notes,
          selectedLanguage: widget.selectedLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _prescriptions.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          p.doctorName.toLowerCase().contains(q) ||
          p.hospitalName.toLowerCase().contains(q);
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
            english: 'My Prescriptions',
            hindi: 'मेरे प्रिस्क्रिप्शन',
            marathi: 'माझे प्रिस्क्रिप्शन',
            gujarati: 'મારા પ્રિસ્ક્રિપ્શન',
            telugu: 'నా ప్రిస్క్రిప్షన్‌లు',
            tamil: 'என் மருந்துச் சீட்டுகள்',
            bengali: 'আমার প্রেসক্রিপশন',
            kannada: 'ನನ್ನ ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್‌ಗಳು',
            malayalam: 'എന്റെ കുറിപ്പടികൾ',
            punjabi: 'ਮੇਰੇ ਨੁਸਖ਼ੇ',
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
                  // Search Bar
                  if (_prescriptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: appText(
                            english: 'Search by doctor or title...',
                            hindi: 'डॉक्टर या शीर्षक से खोजें...',
                            marathi: 'डॉक्टर किंवा शीर्षकानुसार शोधा...',
                            gujarati: 'ડૉક્ટર અથવા શીર્ષક દ્વારા શોધો...',
                            telugu: 'డాక్టర్ లేదా శీర్షిక ద్వారా శోధించండి...',
                            tamil: 'மருத்துவர் அல்லது தலைப்பு மூலம் தேடுங்கள்...',
                            bengali: 'ডাক্তার বা শিরোনাম দিয়ে অনুসন্ধান করুন...',
                            kannada: 'ವೈದ್ಯರು ಅಥವಾ ಶೀರ್ಷಿಕೆಯ ಮೂಲಕ ಹುಡುಕಿ...',
                            malayalam: 'ഡോക്ടർ അല്ലെങ്കിൽ തലക്കെട്ട് പ്രകാരം തിരയുക...',
                            punjabi: 'ਡਾਕਟਰ ਜਾਂ ਸਿਰਲੇਖ ਦੁਆਰਾ ਖੋਜੋ...',
                            selectedLanguage: widget.selectedLanguage,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5B7C99)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFD9E3EA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFD9E3EA)),
                          ),
                        ),
                      ),
                    ),

                  // Prescriptions List or Empty State
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildPrescriptionCard(item);
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
                          backgroundColor: const Color(0xFF5B7C99),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 24),
                        label: Text(
                          appText(
                            english: 'Upload New Prescription',
                            hindi: 'नया प्रिस्क्रिप्शन अपलोड करें',
                            marathi: 'नवीन प्रिस्क्रिप्शन अपलोड करा',
                            gujarati: 'નવું પ્રિસ્ક્રિપ્શન અપલોડ કરો',
                            telugu: 'కొత్త ప్రిస్క్రిప్షన్ అప్‌లోడ్ చేయండి',
                            tamil: 'புதிய மருந்துச் சீட்டைப் பதிவேற்றவும்',
                            bengali: 'নতুন প্রেসক্রিপশন আপলোড করুন',
                            kannada: 'ಹೊಸ ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ಅಪ್‌ಲೋಡ್ ಮಾಡಿ',
                            malayalam: 'പുതിയ കുറിപ്പടി അപ്‌ലോഡ് ചെയ്യുക',
                            punjabi: 'ਨਵਾਂ ਨੁਸਖ਼ਾ ਅੱਪਲੋਡ ਕਰੋ',
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
                color: Color(0xFFE7F0F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 70,
                color: Color(0xFF5B7C99),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              appText(
                english: 'No Prescriptions Yet',
                hindi: 'अभी कोई प्रिस्क्रिप्शन नहीं है',
                marathi: 'अद्याप कोणतेही प्रिस्क्रिप्शन नाही',
                gujarati: 'હજી સુધી કોઈ પ્રિસ્ક્રિપ્શન નથી',
                telugu: 'ఇంకా ప్రిస్క్రిప్షన్‌లు లేవు',
                tamil: 'மருந்துச் சீட்டுகள் எதுவும் இல்லை',
                bengali: 'এখনো কোনো প্রেসক্রিপশন নেই',
                kannada: 'ಇನ್ನೂ ಯಾವುದೇ ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್‌ಗಳಿಲ್ಲ',
                malayalam: 'ഇതുവരെ കുറിപ്പടികളൊന്നും ഇല്ല',
                punjabi: 'ਅਜੇ ਕੋਈ ਨੁਸਖ਼ਾ ਨਹੀਂ ਹੈ',
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
                english: 'Take a photo or upload a PDF of your doctor\'s prescription to keep it safe and accessible.',
                hindi: 'अपने डॉक्टर के प्रिस्क्रिप्शन की फ़ोटो लें या पीडीएफ अपलोड करें ताकि वह सुरक्षित और आसानी से मिल सके।',
                marathi: 'तुमच्या डॉक्टरच्या प्रिस्क्रिप्शनचा फोटो घ्या किंवा पीडीएफ अपलोड करा जेणेकरून ते सुरक्षित राहील.',
                gujarati: 'તમારા ડૉક્ટરના પ્રિસ્ક્રિપ્શનનો ફોટો લો અથવા પીડીએફ અપલોડ કરો.',
                telugu: 'మీ డాక్టర్ ప్రిస్క్రిప్షన్ యొక్క ఫోటో తీయండి లేదా పిడిఎఫ్ అప్‌లోడ్ చేయండి.',
                tamil: 'உங்கள் மருத்துவரின் மருந்துச் சீட்டைப் புகைப்படம் எடுக்கவும் அல்லது PDF-ஐப் பதிவேற்றவும்.',
                bengali: 'আপনার ডাক্তারের প্রেসক্রিপশনের ছবি তুলুন বা পিডিএফ আপলোড করুন।',
                kannada: 'ನಿಮ್ಮ ವೈದ್ಯರ ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್‌ನ ಫೋಟೋ ತೆಗೆದುಕೊಳ್ಳಿ ಅಥವಾ ಪಿಡಿಎಫ್ ಅಪ್‌ಲೋಡ್ ಮಾಡಿ.',
                malayalam: 'നിങ്ങളുടെ ഡോക്ടറുടെ കുറിപ്പടിയുടെ ഫോട്ടോ എടുക്കുക അല്ലെങ്കിൽ പിഡിഎഫ് അപ്‌ലോഡ് ചെയ്യുക.',
                punjabi: 'ਆਪਣੇ ਡਾਕਟਰ ਦੇ ਨੁਸਖ਼ੇ ਦੀ ਫ਼ੋਟੋ ਲਓ ਜਾਂ ਪੀਡੀਐਫ ਅੱਪਲੋਡ ਕਰੋ।',
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

  Widget _buildPrescriptionCard(Prescription item) {
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
                        color: item.isPdf ? const Color(0xFFFFEBEE) : const Color(0xFFE7F0F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        color: item.isPdf ? const Color(0xFFD95C5C) : const Color(0xFF5B7C99),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF263B4A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.doctorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5B7C99),
                            ),
                          ),
                          if (item.hospitalName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.hospitalName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF687780),
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
                          _formatDate(item.date),
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
