enum UserRole {
  admin,
  bookingStaff,
  technician,
  accountant,
}

UserRole parseUserRole(String? role) {
  switch (role?.toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    case 'BOOKING_STAFF':
      return UserRole.bookingStaff;
    case 'TECHNICIAN':
      return UserRole.technician;
    case 'ACCOUNTANT':
      return UserRole.accountant;
    default:
      return UserRole.technician;
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? phone;
  final String? technicianId;
  final bool isOnline;
  final double? currentLatitude;
  final double? currentLongitude;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.technicianId,
    this.isOnline = false,
    this.currentLatitude,
    this.currentLongitude,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final tech = json['technician'] as Map<String, dynamic>?;
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: parseUserRole(json['role']),
      phone: json['phone'],
      technicianId: json['technicianId'] ?? tech?['id'],
      isOnline: tech?['isOnline'] == true,
      currentLatitude: (tech?['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (tech?['currentLongitude'] as num?)?.toDouble(),
    );
  }
}

class BookingRequestModel {
  final String id;
  final String referenceNumber;
  final String customerName;
  final String customerPhone;
  final String serviceName;
  final String complaint;
  final String address;
  final String area;
  final String priority;
  final bool isStaffCreated;
  final String? acBrand;
  final String? acType;
  final double? acTonnage;
  final String preferredDate;
  final String preferredTimeSlot;
  final String status;
  final String? rejectionReason;
  final String? proposedSlot;

  BookingRequestModel({
    required this.id,
    required this.referenceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.complaint,
    required this.address,
    required this.area,
    this.priority = 'MEDIUM',
    this.isStaffCreated = false,
    this.acBrand,
    this.acType,
    this.acTonnage,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.status,
    this.rejectionReason,
    this.proposedSlot,
  });

  factory BookingRequestModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] ?? {};
    final addressObj = json['address'] ?? {};
    final serviceObj = json['serviceType'] ?? {};

    return BookingRequestModel(
      id: json['id'] ?? '',
      referenceNumber: json['referenceNumber'] ?? '',
      customerName: customer['name'] ?? 'Guest Customer',
      customerPhone: customer['phone'] ?? '',
      serviceName: serviceObj['nameEn'] ?? 'AC Service',
      complaint: json['complaint'] ?? '',
      address: addressObj['addressLine'] ?? '',
      area: addressObj['area'] ?? '',
      priority: json['priority'] ?? 'MEDIUM',
      isStaffCreated: json['isStaffCreated'] ?? false,
      acBrand: json['acBrand'],
      acType: json['acType'],
      acTonnage: (json['acTonnage'] as num?)?.toDouble(),
      preferredDate: json['preferredDate'] != null ? json['preferredDate'].toString().split('T')[0] : '',
      preferredTimeSlot: json['preferredTimeSlot'] ?? '',
      status: json['status'] ?? 'PENDING_APPROVAL',
      rejectionReason: json['rejectionReason'],
      proposedSlot: json['proposedTimeSlot'],
    );
  }
}

class ServiceJobModel {
  final String id;
  final String jobNumber;
  final String status;
  final String customerName;
  final String customerPhone;
  final String address;
  final String serviceName;
  final String scheduledDate;
  final String timeSlot;
  final bool isOtpVerified;
  final String? acDetails;
  final String? diagnosis;
  final String? notes;
  final List<ChecklistItemModel> checklist;
  final List<JobPartModel> parts;

  ServiceJobModel({
    required this.id,
    required this.jobNumber,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.serviceName,
    required this.scheduledDate,
    required this.timeSlot,
    this.isOtpVerified = false,
    this.acDetails,
    this.diagnosis,
    this.notes,
    required this.checklist,
    required this.parts,
  });

  factory ServiceJobModel.fromJson(Map<String, dynamic> json) {
    final booking = json['booking'] ?? {};
    final customer = booking['customer'] ?? {};
    final addressObj = booking['address'] ?? {};
    final service = booking['serviceType'] ?? {};
    final ac = json['acUnit'];

    final rawChecklist = json['checklistItems'] as List? ?? [];
    final rawParts = json['partsConsumed'] as List? ?? [];

    return ServiceJobModel(
      id: json['id'] ?? '',
      jobNumber: json['jobNumber'] ?? '',
      status: json['status'] ?? 'PENDING',
      customerName: customer['name'] ?? 'Customer',
      customerPhone: customer['phone'] ?? '',
      address: '${addressObj['addressLine'] ?? ''}, ${addressObj['area'] ?? ''}',
      serviceName: service['nameEn'] ?? 'AC Service',
      scheduledDate: booking['scheduledDate'] != null ? booking['scheduledDate'].toString().split('T')[0] : '',
      timeSlot: booking['timeSlot'] ?? '',
      isOtpVerified: json['isOtpVerified'] ?? false,
      acDetails: ac != null ? '${ac['brand']} ${ac['unitType']} (${ac['tonnage']}T)' : null,
      diagnosis: json['diagnosis'],
      notes: json['resolutionNotes'],
      checklist: rawChecklist.map((c) => ChecklistItemModel.fromJson(c)).toList(),
      parts: rawParts.map((p) => JobPartModel.fromJson(p)).toList(),
    );
  }
}

class ChecklistItemModel {
  final String id;
  final String taskName;
  final bool isChecked;

  ChecklistItemModel({
    required this.id,
    required this.taskName,
    required this.isChecked,
  });

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'] ?? '',
      taskName: json['taskName'] ?? '',
      isChecked: json['isChecked'] ?? false,
    );
  }
}

class JobPartModel {
  final String id;
  final String partName;
  final int quantity;
  final double unitPrice;

  JobPartModel({
    required this.id,
    required this.partName,
    required this.quantity,
    required this.unitPrice,
  });

  factory JobPartModel.fromJson(Map<String, dynamic> json) {
    return JobPartModel(
      id: json['id'] ?? '',
      partName: json['part']?['name'] ?? 'Spare Part',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InventoryPartModel {
  final String id;
  final String sku;
  final String name;
  final String category;
  final double unitPrice;
  final double sellingPrice;
  final int currentStock;
  final int minAlert;
  final String? supplier;

  InventoryPartModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minAlert,
    this.supplier,
  });

  factory InventoryPartModel.fromJson(Map<String, dynamic> json) {
    return InventoryPartModel(
      id: json['id'] ?? '',
      sku: json['sku'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      currentStock: json['currentStock'] ?? 0,
      minAlert: json['minStockAlertLevel'] ?? 5,
      supplier: json['supplierName'],
    );
  }

  bool get isLowStock => currentStock <= minAlert;
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final String dueDate;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    required this.dueDate,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      customerName: json['customer']?['name'] ?? 'Customer',
      customerPhone: json['customer']?['phone'] ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'ISSUED',
      dueDate: json['dueDate'] != null ? json['dueDate'].toString().split('T')[0] : '',
    );
  }

  double get balanceDue => (totalAmount - paidAmount) > 0 ? (totalAmount - paidAmount) : 0;
}
