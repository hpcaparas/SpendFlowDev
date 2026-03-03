import 'package:flutter/foundation.dart';

@immutable
class ApprovalStatusDto {
  const ApprovalStatusDto({
    required this.id,
    required this.code,
    this.description,
    this.statusType,
  });

  final int id;
  final String code;
  final String? description;
  final String? statusType;

  factory ApprovalStatusDto.fromJson(Map<String, dynamic> json) {
    return ApprovalStatusDto(
      id: (json['id'] as num).toInt(),
      code: (json['code'] as String?) ?? 'N/A',
      description: json['description'] as String?,
      statusType: json['statusType'] as String?,
    );
  }
}

@immutable
class PendingApprovalDto {
  const PendingApprovalDto({
    required this.id,
    required this.visaApplicationId,
    required this.sequenceOrder,
    this.approver,
    this.applicantName,
    this.department,
    this.type,
    this.priceWithTax,
    this.remarks,
    this.imageFilename,
    this.status,
  });

  final int id; // approval id
  final int visaApplicationId;
  final int sequenceOrder;

  final String? approver;
  final String? applicantName;
  final String? department;
  final String? type;
  final double? priceWithTax;
  final String? remarks;
  final String? imageFilename;

  final ApprovalStatusDto? status;

  factory PendingApprovalDto.fromJson(Map<String, dynamic> json) {
    return PendingApprovalDto(
      id: (json['id'] as num).toInt(),
      visaApplicationId: (json['visaApplicationId'] as num?)?.toInt() ?? 0,
      sequenceOrder: (json['sequenceOrder'] as num?)?.toInt() ?? 0,
      approver: json['approver']?.toString(),
      applicantName: json['applicantName']?.toString(),
      department: json['department']?.toString(),
      type: json['type']?.toString(),
      priceWithTax: (json['priceWithTax'] as num?)?.toDouble(),
      remarks: json['remarks']?.toString(),
      imageFilename: json['imageFilename']?.toString(),
      status: json['status'] is Map<String, dynamic>
          ? ApprovalStatusDto.fromJson(json['status'] as Map<String, dynamic>)
          : null,
    );
  }
}
