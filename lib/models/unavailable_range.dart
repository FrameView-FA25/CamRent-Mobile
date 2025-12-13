class UnavailableRange {
  final String bookingId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  UnavailableRange({
    required this.bookingId,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory UnavailableRange.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) {
        throw FormatException('Date value is null');
      }
      if (dateValue is DateTime) {
        return dateValue;
      }
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      throw FormatException('Invalid date format: $dateValue');
    }

    return UnavailableRange(
      bookingId: json['bookingId']?.toString() ?? '',
      startDate: parseDate(json['startUtc'] ?? json['startDate'] ?? json['start'] ?? json['from']),
      endDate: parseDate(json['endUtc'] ?? json['endDate'] ?? json['end'] ?? json['to']),
      status: json['status']?.toString() ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'startUtc': startDate.toIso8601String(),
      'endUtc': endDate.toIso8601String(),
      'status': status,
    };
  }

  /// Format date range for display
  String get displayText {
    final start = '${startDate.day}/${startDate.month}/${startDate.year}';
    final end = '${endDate.day}/${endDate.month}/${endDate.year}';
    return '$start - $end';
  }

  /// Check if a date is within this range
  bool contains(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(endDate.add(const Duration(days: 1)));
  }
}

