// ignore_for_file: constant_identifier_names

import 'package:equatable/equatable.dart';

enum ReturnInspectionGrade {
  aExcellent('A_EXCELLENT', 'A (Excellent)'),
  bGood('B_GOOD', 'B (Good)'),
  cFair('C_FAIR', 'C (Fair)'),
  dDamaged('D_DAMAGED', 'D (Damaged)');

  final String code;
  final String displayName;

  const ReturnInspectionGrade(this.code, this.displayName);

  static const ReturnInspectionGrade A_EXCELLENT = ReturnInspectionGrade.aExcellent;
  static const ReturnInspectionGrade B_GOOD = ReturnInspectionGrade.bGood;
  static const ReturnInspectionGrade C_FAIR = ReturnInspectionGrade.cFair;
  static const ReturnInspectionGrade D_DAMAGED = ReturnInspectionGrade.dDamaged;

  static ReturnInspectionGrade fromString(String value) {
    final upper = value.toUpperCase().trim();
    for (final grade in ReturnInspectionGrade.values) {
      if (grade.code == upper || grade.name.toUpperCase() == upper) {
        return grade;
      }
    }
    return ReturnInspectionGrade.aExcellent;
  }
}

class ReturnInspection extends Equatable {
  final String inspectionId;
  final String leaseId;
  final String assetId;
  final DateTime inspectionDate;
  final ReturnInspectionGrade overallGrade;
  final Map<String, String> photoPaths;

  const ReturnInspection({
    required this.inspectionId,
    required this.leaseId,
    required this.assetId,
    required this.inspectionDate,
    required this.overallGrade,
    this.photoPaths = const {},
  });

  ReturnInspection copyWith({
    String? inspectionId,
    String? leaseId,
    String? assetId,
    DateTime? inspectionDate,
    ReturnInspectionGrade? overallGrade,
    Map<String, String>? photoPaths,
  }) {
    return ReturnInspection(
      inspectionId: inspectionId ?? this.inspectionId,
      leaseId: leaseId ?? this.leaseId,
      assetId: assetId ?? this.assetId,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      overallGrade: overallGrade ?? this.overallGrade,
      photoPaths: photoPaths ?? this.photoPaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inspection_id': inspectionId,
      'lease_id': leaseId,
      'asset_id': assetId,
      'inspection_date': inspectionDate.toIso8601String(),
      'overall_grade': overallGrade.code,
      'photo_paths': photoPaths,
    };
  }

  factory ReturnInspection.fromJson(Map<String, dynamic> json) {
    return ReturnInspection(
      inspectionId: json['inspection_id'] as String? ?? json['id'] as String? ?? '',
      leaseId: json['lease_id'] as String? ?? '',
      assetId: json['asset_id'] as String? ?? '',
      inspectionDate: json['inspection_date'] != null
          ? DateTime.parse(json['inspection_date'] as String)
          : DateTime.now(),
      overallGrade: ReturnInspectionGrade.fromString(
        json['overall_grade'] as String? ?? 'A_EXCELLENT',
      ),
      photoPaths: json['photo_paths'] != null
          ? Map<String, String>.from(json['photo_paths'] as Map)
          : const {},
    );
  }

  @override
  List<Object?> get props => [
        inspectionId,
        leaseId,
        assetId,
        inspectionDate,
        overallGrade,
        photoPaths,
      ];
}
