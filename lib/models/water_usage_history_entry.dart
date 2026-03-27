import 'dart:convert';

import 'package:intl/intl.dart';

class WaterUsageHistoryEntry {
  const WaterUsageHistoryEntry({
    required this.createdAt,
    required this.deviceName,
    required this.amount,
    required this.durationSeconds,
    required this.orderNum,
    this.legacyText,
  });

  final DateTime createdAt;
  final String deviceName;
  final double amount;
  final int durationSeconds;
  final String orderNum;
  final String? legacyText;

  String get formattedAmount => amount.toStringAsFixed(2);

  String get formattedDate => DateFormat('MM-dd HH:mm').format(createdAt);

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}分${seconds}秒';
  }

  String get displayDeviceName =>
      deviceName.trim().isEmpty ? '未命名设备' : deviceName.trim();

  String get detailText {
    if (legacyText != null && legacyText!.trim().isNotEmpty) {
      return legacyText!.trim();
    }
    return '$displayDeviceName  用水时长：$formattedDuration';
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'deviceName': deviceName,
      'amount': amount,
      'durationSeconds': durationSeconds,
      'orderNum': orderNum,
      'legacyText': legacyText,
    };
  }

  factory WaterUsageHistoryEntry.fromStorage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return WaterUsageHistoryEntry.fromJson(decoded);
      }
      if (decoded is Map) {
        return WaterUsageHistoryEntry.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // Fallback to legacy text parsing.
    }
    return WaterUsageHistoryEntry.fromLegacyText(raw);
  }

  factory WaterUsageHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WaterUsageHistoryEntry(
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      deviceName: json['deviceName']?.toString() ?? '',
      amount: _parseAmount(json['amount']) ?? 0,
      durationSeconds: _parseDurationSeconds(json['durationSeconds']) ?? 0,
      orderNum: json['orderNum']?.toString() ?? '',
      legacyText: json['legacyText']?.toString(),
    );
  }

  factory WaterUsageHistoryEntry.fromLegacyText(String raw) {
    final trimmed = raw.trim();
    final dateMatch = RegExp(r'(\d{2}-\d{2}\s\d{2}:\d{2})').firstMatch(trimmed);
    DateTime createdAt = DateTime.now();
    if (dateMatch != null) {
      final year = DateTime.now().year;
      final parsed = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).parse('$year-${dateMatch.group(1)!}', true);
      createdAt = parsed.toLocal();
    }

    return WaterUsageHistoryEntry(
      createdAt: createdAt,
      deviceName: '',
      amount: _parseAmount(trimmed) ?? 0,
      durationSeconds: _parseDurationSeconds(trimmed) ?? 0,
      orderNum: '',
      legacyText: trimmed,
    );
  }

  static double? _parseAmount(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return raw.toDouble();
    }

    final normalized = raw.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(normalized);
  }

  static int? _parseDurationSeconds(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      return raw.round();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    final minuteSecondMatch = RegExp(r'(\d+)\s*分\s*(\d+)\s*秒').firstMatch(text);
    if (minuteSecondMatch != null) {
      final minutes = int.tryParse(minuteSecondMatch.group(1)!) ?? 0;
      final seconds = int.tryParse(minuteSecondMatch.group(2)!) ?? 0;
      return minutes * 60 + seconds;
    }

    final colonMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    if (colonMatch != null) {
      final minutes = int.tryParse(colonMatch.group(1)!) ?? 0;
      final seconds = int.tryParse(colonMatch.group(2)!) ?? 0;
      return minutes * 60 + seconds;
    }

    final numeric = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    return numeric;
  }
}
