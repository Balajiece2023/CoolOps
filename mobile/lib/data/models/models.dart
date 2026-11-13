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
  final String? avatarUrl;
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
    this.avatarUrl,
    this.technicianId,
    this.isOnline = false,
    this.currentLatitude,
    this.currentLongitude,
  });

  UserModel copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    bool? isOnline,
    double? currentLatitude,
    double? currentLongitude,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      technicianId: technicianId,
      isOnline: isOnline ?? this.isOnline,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final tech = json['technician'] as Map<String, dynamic>?;
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: parseUserRole(json['role']),
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
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
  final String? pincode;
  final String priority;
  final bool isStaffCreated;
  final String? acBrand;
  final String? acType;
  final double? acTonnage;
  final String preferredDate;
  final String preferredTimeSlot;
  final String status;
  final String? rejectionReason;
  final String? holdReason;
  final String? proposedSlot;
  final double? latitude;
  final double? longitude;
  final String? locationLink;

  BookingRequestModel({
    required this.id,
    required this.referenceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.complaint,
    required this.address,
    required this.area,
    this.pincode,
    this.priority = 'MEDIUM',
    this.isStaffCreated = false,
    this.acBrand,
    this.acType,
    this.acTonnage,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.status,
    this.rejectionReason,
    this.holdReason,
    this.proposedSlot,
    this.latitude,
    this.longitude,
    this.locationLink,
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
      pincode: addressObj['pincode'],
      latitude: (addressObj['latitude'] as num?)?.toDouble() ?? (json['latitude'] as num?)?.toDouble(),
      longitude: (addressObj['longitude'] as num?)?.toDouble() ?? (json['longitude'] as num?)?.toDouble(),
      locationLink: json['locationLink'] ?? addressObj['locationLink'],
      priority: json['priority'] ?? 'MEDIUM',
      isStaffCreated: json['isStaffCreated'] ?? false,
      acBrand: json['acBrand'],
      acType: json['acType'],
      acTonnage: (json['acTonnage'] as num?)?.toDouble(),
      preferredDate: json['preferredDate'] != null ? json['preferredDate'].toString().split('T')[0] : '',
      preferredTimeSlot: json['preferredTimeSlot'] ?? '',
      status: json['status'] ?? 'PENDING_APPROVAL',
      rejectionReason: json['rejectionReason'],
      holdReason: json['holdReason'],
      proposedSlot: json['proposedTimeSlot'],
    );
  }
}

class ServiceJobModel {
  final String id;
  final String jobNumber;
  final String status;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String address;
  final String serviceName;
  final String? serviceDescription;
  final String scheduledDate;
  final String timeSlot;
  final bool isOtpVerified;
  final String? acDetails;
  final String? diagnosis;
  final String? notes;
  final List<ChecklistItemModel> checklist;
  final List<JobPartModel> parts;
  final double? latitude;
  final double? longitude;
  final String? locationLink;

  ServiceJobModel({
    required this.id,
    required this.jobNumber,
    required this.status,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.address,
    required this.serviceName,
    this.serviceDescription,
    required this.scheduledDate,
    required this.timeSlot,
    this.isOtpVerified = false,
    this.acDetails,
    this.diagnosis,
    this.notes,
    required this.checklist,
    required this.parts,
    this.latitude,
    this.longitude,
    this.locationLink,
  });

  factory ServiceJobModel.fromJson(Map<String, dynamic> json) {
    final booking = json['booking'] ?? {};
    final customer = booking['customer'] ?? {};
    final addressObj = booking['address'] ?? {};
    final service = booking['serviceType'] ?? {};
    final bookingReq = booking['bookingRequest'] ?? {};
    final ac = json['acUnit'];

    // Map admin service description & customer requirements
    final rawDesc = booking['notes'] ?? bookingReq['complaint'] ?? json['diagnosis'] ?? service['description'];
    final desc = (rawDesc != null && rawDesc.toString().trim().isNotEmpty) ? rawDesc.toString().trim() : null;

    final rawChecklist = json['checklistItems'] as List? ?? [];
    final rawParts = json['partsConsumed'] as List? ?? [];

    return ServiceJobModel(
      id: json['id'] ?? '',
      jobNumber: json['jobNumber'] ?? '',
      status: json['status'] ?? 'PENDING',
      customerId: customer['id'],
      customerName: customer['name'] ?? 'Customer',
      customerPhone: customer['phone'] ?? '',
      customerEmail: customer['email'],
      address: '${addressObj['addressLine'] ?? ''}, ${addressObj['area'] ?? ''}',
      serviceName: service['nameEn'] ?? 'AC Service',
      serviceDescription: desc,
      scheduledDate: booking['scheduledDate'] != null ? booking['scheduledDate'].toString().split('T')[0] : '',
      timeSlot: booking['timeSlot'] ?? '',
      isOtpVerified: json['isOtpVerified'] ?? false,
      acDetails: ac != null ? '${ac['brand']} ${ac['unitType']} (${ac['tonnage']}T)' : null,
      diagnosis: json['diagnosis'],
      notes: json['resolutionNotes'],
      checklist: rawChecklist.map((c) => ChecklistItemModel.fromJson(c)).toList(),
      parts: rawParts.map((p) => JobPartModel.fromJson(p)).toList(),
      latitude: (addressObj['latitude'] as num?)?.toDouble() ?? (bookingReq['latitude'] as num?)?.toDouble(),
      longitude: (addressObj['longitude'] as num?)?.toDouble() ?? (bookingReq['longitude'] as num?)?.toDouble(),
      locationLink: addressObj['locationLink'] ?? bookingReq['locationLink'],
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
  bool get isPaid => status == 'PAID' || balanceDue <= 0.001;
  bool get isPartiallyPaid => status == 'PARTIALLY_PAID' || (paidAmount > 0 && balanceDue > 0.001);
  bool get isOnHold => !isPaid && !isPartiallyPaid;
}

class FieldServiceReportModel {
  final String id;
  final String reportNumber;
  final String? serviceJobId;
  final String? jobNumber;
  final String? technicianId;
  final String reportType;
  final String customerName;
  final String customerAddress;
  final String? contactPhone;
  final String? personCalling;
  final String dealerName;
  final String dealerAddress;
  final String dealerPhone;
  final String dealerEmail;
  final String serviceEngineerName;
  final String? complaintDate;
  final String attendingDate;
  final String? modelNumber;
  final String? indoorSerialNo;
  final String? outdoorSerialNo;
  final String? errorCode;
  final String? runningCurrent;
  final String? suctionPressure;
  final String? dischargePressure;
  final String? roomTemperature;
  final String? voltage;
  final String? equip1Details;
  final String? equip2Details;
  // Final Test Measurements (As applicable)
  final String? powerServoStab;
  final String? voltageNEarth;
  final String? voltageL1N;
  final String? voltageL2N;
  final String? voltageL3N;
  final String? voltageL1L2;
  final String? voltageL2L3;
  final String? voltageL3L1;
  final String? pressSuc;
  final String? pressDis;
  final String? compCurrent;
  final String? unitCurrents;
  final String? roomTemp;
  final String? supplyAirTemp;
  final String? returnAirTemp;
  final String? ambientTemp;
  final String observations;
  final String? suggestions;
  final String? customerSignName;
  final String createdAt;

  FieldServiceReportModel({
    required this.id,
    required this.reportNumber,
    this.serviceJobId,
    this.jobNumber,
    this.technicianId,
    required this.reportType,
    required this.customerName,
    required this.customerAddress,
    this.contactPhone,
    this.personCalling,
    required this.dealerName,
    required this.dealerAddress,
    required this.dealerPhone,
    required this.dealerEmail,
    required this.serviceEngineerName,
    this.complaintDate,
    required this.attendingDate,
    this.modelNumber,
    this.indoorSerialNo,
    this.outdoorSerialNo,
    this.errorCode,
    this.runningCurrent,
    this.suctionPressure,
    this.dischargePressure,
    this.roomTemperature,
    this.voltage,
    this.equip1Details,
    this.equip2Details,
    this.powerServoStab,
    this.voltageNEarth,
    this.voltageL1N,
    this.voltageL2N,
    this.voltageL3N,
    this.voltageL1L2,
    this.voltageL2L3,
    this.voltageL3L1,
    this.pressSuc,
    this.pressDis,
    this.compCurrent,
    this.unitCurrents,
    this.roomTemp,
    this.supplyAirTemp,
    this.returnAirTemp,
    this.ambientTemp,
    required this.observations,
    this.suggestions,
    this.customerSignName,
    required this.createdAt,
  });

  factory FieldServiceReportModel.fromJson(Map<String, dynamic> json) {
    return FieldServiceReportModel(
      id: json['id'] ?? '',
      reportNumber: json['reportNumber'] ?? '',
      serviceJobId: json['serviceJobId'],
      jobNumber: json['serviceJob']?['jobNumber'],
      technicianId: json['technicianId'],
      reportType: json['reportType'] ?? 'DO_AND_CHARGE_REPAIR',
      customerName: json['customerName'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      contactPhone: json['contactPhone'],
      personCalling: json['personCalling'],
      dealerName: json['dealerName'] ?? 'CARING COOL TECH',
      dealerAddress: json['dealerAddress'] ?? '',
      dealerPhone: json['dealerPhone'] ?? '',
      dealerEmail: json['dealerEmail'] ?? '',
      serviceEngineerName: json['serviceEngineerName'] ?? '',
      complaintDate: json['complaintDate'] != null ? json['complaintDate'].toString().split('T')[0] : null,
      attendingDate: json['attendingDate'] != null ? json['attendingDate'].toString().split('T')[0] : '',
      modelNumber: json['modelNumber'],
      indoorSerialNo: json['indoorSerialNo'],
      outdoorSerialNo: json['outdoorSerialNo'],
      errorCode: json['errorCode'],
      runningCurrent: json['runningCurrent'],
      suctionPressure: json['suctionPressure'],
      dischargePressure: json['dischargePressure'],
      roomTemperature: json['roomTemperature'],
      voltage: json['voltage'],
      equip1Details: json['equip1Details'],
      equip2Details: json['equip2Details'],
      powerServoStab: json['powerServoStab'],
      voltageNEarth: json['voltageNEarth'],
      voltageL1N: json['voltageL1N'],
      voltageL2N: json['voltageL2N'],
      voltageL3N: json['voltageL3N'],
      voltageL1L2: json['voltageL1L2'],
      voltageL2L3: json['voltageL2L3'],
      voltageL3L1: json['voltageL3L1'],
      pressSuc: json['pressSuc'],
      pressDis: json['pressDis'],
      compCurrent: json['compCurrent'],
      unitCurrents: json['unitCurrents'],
      roomTemp: json['roomTemp'],
      supplyAirTemp: json['supplyAirTemp'],
      returnAirTemp: json['returnAirTemp'],
      ambientTemp: json['ambientTemp'],
      observations: json['observations'] ?? '',
      suggestions: json['suggestions'],
      customerSignName: json['customerSignName'],
      createdAt: json['createdAt'] != null ? json['createdAt'].toString().split('T')[0] : '',
    );
  }

  String get reportTypeFormatted {
    switch (reportType) {
      case 'COMMISSIONING':
        return 'Commissioning';
      case 'WARRANTY':
        return 'Warranty';
      case 'MAIN_CONTACT':
      case 'MAINTENANCE_CONTRACT':
        return 'Main Contact (AMC)';
      case 'DO_AND_CHARGE_REPAIR':
      default:
        return 'Do & Charge Repair';
    }
  }
}
