import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================
// PRESCRIPTION MODEL
// =====================================================

class Prescription {
  final String id;
  String title;
  String doctorName;
  String hospitalName;
  DateTime date;
  String notes;
  String fileName;
  String fileType; // 'image' or 'pdf'
  String base64Data;
  int fileSize; // in bytes

  Prescription({
    String? id,
    required this.title,
    required this.doctorName,
    required this.hospitalName,
    required this.date,
    this.notes = '',
    required this.fileName,
    required this.fileType,
    required this.base64Data,
    this.fileSize = 0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  bool get isPdf => fileType.toLowerCase() == 'pdf';
  bool get isImage => fileType.toLowerCase() == 'image';

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'doctorName': doctorName,
      'hospitalName': hospitalName,
      'date': date.toIso8601String(),
      'notes': notes,
      'fileName': fileName,
      'fileType': fileType,
      'base64Data': base64Data,
      'fileSize': fileSize,
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Prescription',
      doctorName: map['doctorName'] as String? ?? '',
      hospitalName: map['hospitalName'] as String? ?? '',
      date: map['date'] != null ? DateTime.tryParse(map['date'] as String) ?? DateTime.now() : DateTime.now(),
      notes: map['notes'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'document',
      fileType: map['fileType'] as String? ?? 'image',
      base64Data: map['base64Data'] as String? ?? '',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
    );
  }
}

// =====================================================
// MEDICAL REPORT MODEL
// =====================================================

class MedicalReport {
  final String id;
  String title;
  String category;
  DateTime testDate;
  String labName;
  String notes;
  String fileName;
  String fileType; // 'image' or 'pdf'
  String base64Data;
  int fileSize; // in bytes

  MedicalReport({
    String? id,
    required this.title,
    required this.category,
    required this.testDate,
    required this.labName,
    this.notes = '',
    required this.fileName,
    required this.fileType,
    required this.base64Data,
    this.fileSize = 0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  bool get isPdf => fileType.toLowerCase() == 'pdf';
  bool get isImage => fileType.toLowerCase() == 'image';

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'testDate': testDate.toIso8601String(),
      'labName': labName,
      'notes': notes,
      'fileName': fileName,
      'fileType': fileType,
      'base64Data': base64Data,
      'fileSize': fileSize,
    };
  }

  factory MedicalReport.fromMap(Map<String, dynamic> map) {
    return MedicalReport(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Medical Report',
      category: map['category'] as String? ?? 'General Test',
      testDate: map['testDate'] != null ? DateTime.tryParse(map['testDate'] as String) ?? DateTime.now() : DateTime.now(),
      labName: map['labName'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'document',
      fileType: map['fileType'] as String? ?? 'image',
      base64Data: map['base64Data'] as String? ?? '',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
    );
  }
}

// =====================================================
// STORAGE SERVICE
// =====================================================

class MedicalStorageService {
  static const String _prescriptionsKey = 'senior_saathi_prescriptions_list';
  static const String _reportsKey = 'senior_saathi_medical_reports_list';

  // --- PRESCRIPTIONS ---

  static Future<List<Prescription>> loadPrescriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prescriptionsKey);
      if (savedJson == null || savedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(savedJson);
      final list = decoded
          .map((item) => Prescription.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      // Sort most recent first
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      debugPrint('Error loading prescriptions: $e');
      return [];
    }
  }

  static Future<bool> savePrescription(Prescription prescription) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await loadPrescriptions();

      final index = list.indexWhere((p) => p.id == prescription.id);
      if (index != -1) {
        list[index] = prescription;
      } else {
        list.insert(0, prescription);
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      final encoded = jsonEncode(list.map((p) => p.toMap()).toList());
      return await prefs.setString(_prescriptionsKey, encoded);
    } catch (e) {
      debugPrint('Error saving prescription: $e');
      return false;
    }
  }

  static Future<bool> deletePrescription(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await loadPrescriptions();
      list.removeWhere((p) => p.id == id);
      final encoded = jsonEncode(list.map((p) => p.toMap()).toList());
      return await prefs.setString(_prescriptionsKey, encoded);
    } catch (e) {
      debugPrint('Error deleting prescription: $e');
      return false;
    }
  }

  // --- MEDICAL REPORTS ---

  static Future<List<MedicalReport>> loadReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_reportsKey);
      if (savedJson == null || savedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(savedJson);
      final list = decoded
          .map((item) => MedicalReport.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      // Sort most recent first
      list.sort((a, b) => b.testDate.compareTo(a.testDate));
      return list;
    } catch (e) {
      debugPrint('Error loading reports: $e');
      return [];
    }
  }

  static Future<bool> saveReport(MedicalReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await loadReports();

      final index = list.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        list[index] = report;
      } else {
        list.insert(0, report);
      }

      list.sort((a, b) => b.testDate.compareTo(a.testDate));
      final encoded = jsonEncode(list.map((r) => r.toMap()).toList());
      return await prefs.setString(_reportsKey, encoded);
    } catch (e) {
      debugPrint('Error saving report: $e');
      return false;
    }
  }

  static Future<bool> deleteReport(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await loadReports();
      list.removeWhere((r) => r.id == id);
      final encoded = jsonEncode(list.map((r) => r.toMap()).toList());
      return await prefs.setString(_reportsKey, encoded);
    } catch (e) {
      debugPrint('Error deleting report: $e');
      return false;
    }
  }
}
