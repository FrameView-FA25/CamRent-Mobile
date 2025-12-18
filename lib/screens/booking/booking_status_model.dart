
class BookingStatusModel {
  final String status;
  final String statusText;

  BookingStatusModel({
    required this.status,
    required this.statusText,
  });

  factory BookingStatusModel.fromJson(Map<String, dynamic> json) {
    return BookingStatusModel(
      status: json['status']?.toString() ?? '',
      statusText: json['statusText']?.toString() ?? json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'statusText': statusText,
    };
  }

  // Helper method to get Vietnamese status text
  String get displayText {
    switch (status) {
      case 'PendingApproval':
        return 'Chờ duyệt';
      case 'Draft':
        return 'Nháp';
      case 'Confirmed':
        return 'Đã xác nhận';
      case 'PickedUp':
        return 'Đã nhận';
      case 'Returned':
        return 'Đã trả';
      case 'Completed':
        return 'Hoàn thành';
      case 'Cancelled':
        return 'Đã hủy';
      case 'Overdue':
        return 'Quá hạn';
      default:
        return statusText.isNotEmpty ? statusText : status;
    }
  }
}

