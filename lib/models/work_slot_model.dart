class WorkSlotModel {
  final String id;
  final String name;
  final String? description;
  final String startTime; // Format: "HH:mm" (e.g., "08:00")
  final String endTime; // Format: "HH:mm" (e.g., "17:00")
  final bool isActive;
  final Map<String, dynamic> raw;

  WorkSlotModel({
    required this.id,
    required this.name,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.raw,
  });

  // Format time for display (e.g., "08:00 - 17:00")
  String get timeRange => '$startTime - $endTime';

  // Format time for display with label (e.g., "08:00 - 17:00 (Ca sáng)")
  String get displayText => description != null && description!.isNotEmpty
      ? '$timeRange ($description)'
      : timeRange;

  factory WorkSlotModel.fromJson(Map<String, dynamic> json) {
    return WorkSlotModel(
      id: json['id']?.toString() ?? 
          json['workSlotId']?.toString() ?? 
          json['slotId']?.toString() ?? 
          '',
      name: json['name']?.toString() ?? 
            json['slotName']?.toString() ?? 
            'Slot',
      description: json['description']?.toString(),
      startTime: json['startTime']?.toString() ?? 
                 json['start']?.toString() ?? 
                 json['from']?.toString() ?? 
                 '08:00',
      endTime: json['endTime']?.toString() ?? 
               json['end']?.toString() ?? 
               json['to']?.toString() ?? 
               '17:00',
      isActive: json['isActive'] as bool? ?? 
                (json['active'] as bool?) ?? 
                true,
      raw: json,
    );
  }

  // Helper method to create DateTime from date and this slot's start time
  // Returns UTC DateTime to ensure consistency
  DateTime createDateTime(DateTime date) {
    final timeParts = startTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 8;
    final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
    
    // Create DateTime in UTC to ensure consistency across timezones
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }
}

