import 'dart:convert';

import 'package:intl/intl.dart';

class WaterUsageHistoryEntry {
  const WaterUsageHistoryEntry({
    required this.createdAt,
    required this.deviceName,
    required this.amount,
    required this.orderNum,
    this.durationSeconds,
    this.durationLabel,
    this.legacyText,
  });

  final DateTime createdAt;
  final String deviceName;
  final double amount;
  final String orderNum;
  final int? durationSeconds;
  final String? durationLabel;
  final String? legacyText;

  String get formattedAmount => amount.toStringAsFixed(2);

  String get formattedDate => DateFormat('MM-dd HH:mm').format(createdAt);

  String get formattedDuration {
    final label = durationLabel?.trim() ?? '';
    if (label.isNotEmpty) {
      return label;
    }
    if (durationSeconds == null) {
      return '--';
    }

    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes}\u5206${seconds}\u79d2';
  }

  String get displayDeviceName {
    final name = _normalizeDisplayDeviceName(deviceName.trim());
    return name.isEmpty ? '\u672a\u547d\u540d\u8bbe\u5907' : name;
  }

  DateTime get minutePrecisionTime => DateTime(
    createdAt.year,
    createdAt.month,
    createdAt.day,
    createdAt.hour,
    createdAt.minute,
  );

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'deviceName': deviceName,
      'amount': amount,
      'orderNum': orderNum,
      'durationSeconds': durationSeconds,
      'durationLabel': durationLabel,
      'legacyText': legacyText,
    };
  }

  WaterUsageHistoryEntry copyWith({
    DateTime? createdAt,
    String? deviceName,
    double? amount,
    String? orderNum,
    int? durationSeconds,
    String? durationLabel,
    String? legacyText,
    bool clearDuration = false,
  }) {
    return WaterUsageHistoryEntry(
      createdAt: createdAt ?? this.createdAt,
      deviceName: deviceName ?? this.deviceName,
      amount: amount ?? this.amount,
      orderNum: orderNum ?? this.orderNum,
      durationSeconds: clearDuration
          ? null
          : (durationSeconds ?? this.durationSeconds),
      durationLabel: clearDuration ? null : (durationLabel ?? this.durationLabel),
      legacyText: legacyText ?? this.legacyText,
    );
  }

  factory WaterUsageHistoryEntry.fromStorage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return WaterUsageHistoryEntry.fromJson(decoded);
      }
      if (decoded is Map) {
        return WaterUsageHistoryEntry.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Keep backward compatibility with legacy plain-text cache.
    }

    return WaterUsageHistoryEntry.fromLegacyText(raw);
  }

  factory WaterUsageHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WaterUsageHistoryEntry(
      createdAt:
          _parseStoredDateTime(json['createdAt']) ??
          _parseServerDateTime(json['payTypeStr']) ??
          DateTime.now(),
      deviceName:
          json['deviceName']?.toString() ??
          json['displayDeviceName']?.toString() ??
          '',
      amount:
          _parseAmount(json['amount']) ??
          _parseAmount(json['expAmountStr']) ??
          0,
      orderNum: json['orderNum']?.toString() ?? json['id']?.toString() ?? '',
      durationSeconds: _parseDurationSeconds(
        json['durationSeconds'] ?? json['formattedDuration'],
      ),
      durationLabel: _normalizeDurationLabel(
        json['durationLabel'] ?? json['formattedDuration'],
      ),
      legacyText: json['legacyText']?.toString(),
    );
  }

  factory WaterUsageHistoryEntry.fromLegacyText(String raw) {
    final trimmed = raw.trim();
    return WaterUsageHistoryEntry(
      createdAt: _parseHistoryDate(trimmed) ?? DateTime.now(),
      deviceName: _parseLegacyDeviceName(trimmed),
      amount: _parseAmount(trimmed) ?? 0,
      orderNum: '',
      durationSeconds: _parseDurationSeconds(trimmed),
      legacyText: trimmed,
    );
  }

  factory WaterUsageHistoryEntry.fromServerBill(Map<String, dynamic> json) {
    return WaterUsageHistoryEntry(
      createdAt:
          _parseServerDateTime(json['payTypeStr'] ?? json['createTime']) ??
          DateTime.now(),
      deviceName: _buildCompactDeviceName(
        time: (json['time'] ?? json['deviceName'] ?? json['deviceInfName'] ?? '')
            .toString(),
        title: (json['title'] ?? '').toString(),
      ),
      amount:
          _parseAmount(
            json['expAmountStr']
                ?.toString()
                .replaceAll('\u5143', '')
                .trim(),
          ) ??
          _parseAmount(json['expAmount']) ??
          0,
      orderNum: json['orderNum']?.toString() ?? json['id']?.toString() ?? '',
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
    if (text.isEmpty || text == '--') {
      return null;
    }

    final minuteSecondMatch = RegExp(
      r'(\d+)\s*\u5206\s*(\d+)\s*\u79d2',
    ).firstMatch(text);
    if (minuteSecondMatch != null) {
      final minutes = int.tryParse(minuteSecondMatch.group(1)!) ?? 0;
      final seconds = int.tryParse(minuteSecondMatch.group(2)!) ?? 0;
      return minutes * 60 + seconds;
    }

    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    if (clockMatch != null) {
      final minutes = int.tryParse(clockMatch.group(1)!) ?? 0;
      final seconds = int.tryParse(clockMatch.group(2)!) ?? 0;
      return minutes * 60 + seconds;
    }

    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  static String? _normalizeDurationLabel(Object? raw) {
    if (raw == null) {
      return null;
    }

    final text = raw.toString().trim();
    if (text.isEmpty || text == '--') {
      return null;
    }
    return text;
  }

  static DateTime? _parseStoredDateTime(Object? raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }

  static DateTime? _parseHistoryDate(String raw) {
    final match = RegExp(r'(\d{2}-\d{2}\s\d{2}:\d{2})').firstMatch(raw);
    if (match == null) {
      return null;
    }

    final year = DateTime.now().year;
    try {
      return DateFormat('yyyy-MM-dd HH:mm').parseStrict(
        '$year-${match.group(1)!}',
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseServerDateTime(Object? raw) {
    if (raw == null) {
      return null;
    }

    final text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    final normalized = text.replaceAll('/', '-');
    final withYear = RegExp(r'^\d{4}-').hasMatch(normalized)
        ? normalized
        : '${DateTime.now().year}-$normalized';

    for (final pattern in const ['yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm']) {
      try {
        return DateFormat(pattern).parseStrict(withYear);
      } catch (_) {
        // Try the next known server format.
      }
    }
    return null;
  }

  static String _buildCompactDeviceName({
    required String time,
    required String title,
  }) {
    final source = time.trim();
    final roomMatch = RegExp(r'(\d+)\s*$').firstMatch(source);
    final roomNumber = roomMatch?.group(1) ?? _compactRoomFallback(source);
    final normalizedTitle = _normalizeBillTitle(title);

    if (roomNumber.isEmpty) {
      return normalizedTitle;
    }
    return '$roomNumber$normalizedTitle';
  }

  static String _compactRoomFallback(String value) {
    final segments = value.split('-').map((item) => item.trim()).toList();
    if (segments.isEmpty) {
      return '';
    }
    return segments.last.replaceAll(RegExp(r'\s+'), '');
  }

  static String _normalizeBillTitle(String rawTitle) {
    final title = rawTitle.trim();
    if (title.contains('\u6d17\u6d74') ||
        title.contains('\u70ed\u6c34') ||
        title.contains('\u8bbe\u5907\u7528\u6c34')) {
      return '\u70ed\u6c34';
    }
    if (title.contains('\u996e')) {
      return '\u76f4\u996e';
    }
    return title;
  }

  static String _parseLegacyDeviceName(String raw) {
    final bracketMatch = RegExp(r'\(([^()]*)\)').firstMatch(raw);
    if (bracketMatch == null) {
      return '';
    }

    final content = bracketMatch.group(1)!.trim();
    final withoutDuration = content
        .replaceAll(
          RegExp(
            r'\u7528\u65f6[:\uff1a]?\s*\d+(?::|\u5206)\d+(?:\u79d2)?',
          ),
          '',
        )
        .trim();
    return withoutDuration;
  }

  static String _normalizeDisplayDeviceName(String raw) {
    return raw
        .replaceFirst(RegExp(r'^[12]-'), '')
        .replaceAll(RegExp('hot\$', caseSensitive: false), '\u70ed\u6c34')
        .replaceAll(RegExp('cold\$', caseSensitive: false), '\u76f4\u996e')
        .replaceAll(RegExp('drink\$', caseSensitive: false), '\u76f4\u996e')
        .replaceAll('\u76f4\u996e\u6c34', '\u76f4\u996e')
        .trim();
  }
}
