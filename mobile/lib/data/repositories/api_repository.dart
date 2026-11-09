import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';

class ApiRepository {
  final ApiClient _client;

  ApiRepository(this._client);

  // Authentication
  Future<UserModel> login(String email, String password) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final data = response.data['data'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAccessToken, data['accessToken']);
    await prefs.setString(AppConstants.keyRefreshToken, data['refreshToken']);
    await prefs.setString(AppConstants.keyUserRole, data['user']['role']);
    await prefs.setString(AppConstants.keyUserName, data['user']['name']);
    await prefs.setString(AppConstants.keyUserEmail, data['user']['email']);
    await prefs.setString(AppConstants.keyUserId, data['user']['id']);
    if (data['user']['technicianId'] != null) {
      await prefs.setString(AppConstants.keyTechnicianId, data['user']['technicianId']);
    }

    return UserModel.fromJson(data['user']);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _client.dio.get('/dashboard/stats');
    return res.data['data'];
  }

  // Booking Requests
  Future<List<BookingRequestModel>> getBookingRequests({String? status, String? search}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final res = await _client.dio.get('/booking-requests', queryParameters: query);
    final items = res.data['data']['items'] as List;
    return items.map((i) => BookingRequestModel.fromJson(i)).toList();
  }

  // Approve Booking Request
  Future<void> approveBookingRequest({
    required String requestId,
    required String technicianId,
    required String scheduledDate,
    required String timeSlot,
    double? estimatedAmount,
    String? notes,
  }) async {
    await _client.dio.post('/booking-requests/$requestId/approve', data: {
      'technicianId': technicianId,
      'scheduledDate': scheduledDate,
      'timeSlot': timeSlot,
      if (estimatedAmount != null) 'estimatedAmount': estimatedAmount,
      if (notes != null) 'notes': notes,
    });
  }

  // Propose Alternative Slot
  Future<void> proposeAlternativeSlot({
    required String requestId,
    required String proposedDate,
    required String proposedTimeSlot,
    String? reason,
  }) async {
    await _client.dio.post('/booking-requests/$requestId/propose-slot', data: {
      'proposedDate': proposedDate,
      'proposedTimeSlot': proposedTimeSlot,
      if (reason != null) 'reason': reason,
    });
  }

  // Reject Booking Request
  Future<void> rejectBookingRequest({
    required String requestId,
    required String reason,
  }) async {
    await _client.dio.post('/booking-requests/$requestId/reject', data: {
      'rejectionReason': reason,
    });
  }

  // Put Booking Request On Hold
  Future<void> putBookingOnHold({
    required String requestId,
    required String reason,
  }) async {
    await _client.dio.post('/booking-requests/$requestId/hold', data: {
      'reason': reason,
    });
  }

  // Service Jobs
  Future<List<ServiceJobModel>> getServiceJobs({String? status, String? date}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (date != null && date.isNotEmpty) query['date'] = date;

    final res = await _client.dio.get('/service-jobs', queryParameters: query);
    final items = res.data['data'] as List;
    return items.map((i) => ServiceJobModel.fromJson(i)).toList();
  }

  // Create Incident Ticket / Booking Request (Staff & Admin)
  Future<void> createTicket({
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String addressLine,
    required String area,
    required String pincode,
    required String serviceTypeId,
    required String complaint,
    String priority = 'MEDIUM',
    String? acBrand,
    String? acType,
    double? acTonnage,
    double? latitude,
    double? longitude,
    String? locationLink,
    required String preferredDate,
    required String preferredTimeSlot,
  }) async {
    await _client.dio.post('/booking-requests', data: {
      'customerName': customerName,
      'customerPhone': customerPhone,
      if (customerEmail != null) 'customerEmail': customerEmail,
      'addressLine': addressLine,
      'area': area,
      'pincode': pincode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationLink != null && locationLink.trim().isNotEmpty) 'locationLink': locationLink.trim(),
      'serviceTypeId': serviceTypeId,
      'complaint': complaint,
      'priority': priority,
      if (acBrand != null) 'acBrand': acBrand,
      if (acType != null) 'acType': acType,
      if (acTonnage != null) 'acTonnage': acTonnage,
      'preferredDate': preferredDate,
      'preferredTimeSlot': preferredTimeSlot,
    });
  }

  // Update customer exact location (via Google Maps link or coordinates from technician)
  Future<Map<String, dynamic>> updateJobCustomerLocation({
    required String jobId,
    String? locationLink,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _client.dio.post('/service-jobs/$jobId/customer-location', data: {
      if (locationLink != null && locationLink.trim().isNotEmpty) 'locationLink': locationLink.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return res.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> updateBookingRequestCustomerLocation({
    required String requestId,
    String? locationLink,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _client.dio.post('/booking-requests/$requestId/customer-location', data: {
      if (locationLink != null && locationLink.trim().isNotEmpty) 'locationLink': locationLink.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return res.data['data'] ?? {};
  }

  // Reassign confirmed booking / service job to another technician by Admin
  Future<Map<String, dynamic>> reassignBookingRequest({
    required String requestId,
    required String newTechnicianId,
    String? reason,
  }) async {
    final res = await _client.dio.post('/booking-requests/$requestId/reassign', data: {
      'newTechnicianId': newTechnicianId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return res.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> reassignJob({
    required String jobId,
    required String newTechnicianId,
    String? reason,
  }) async {
    final res = await _client.dio.post('/service-jobs/$jobId/reassign', data: {
      'newTechnicianId': newTechnicianId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return res.data['data'] ?? {};
  }

  // Verify Customer Closure OTP to complete ticket
  Future<void> verifyClosureOtp({
    required String jobId,
    required String otp,
    String? diagnosis,
    String? resolutionNotes,
  }) async {
    await _client.dio.post('/service-jobs/$jobId/verify-closure-otp', data: {
      'otp': otp,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
    });
  }

  // Update Job Status
  Future<void> updateJobStatus({
    required String jobId,
    required String status,
    String? diagnosis,
    String? resolutionNotes,
  }) async {
    await _client.dio.patch('/service-jobs/$jobId/status', data: {
      'status': status,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
    });
  }

  // Check off checklist item
  Future<void> toggleChecklistItem({
    required String jobId,
    required String itemId,
    required bool isChecked,
    String? notes,
  }) async {
    await _client.dio.patch('/service-jobs/$jobId/checklist/$itemId', data: {
      'isChecked': isChecked,
      if (notes != null) 'notes': notes,
    });
  }

  // Consume spare part
  Future<void> consumePartForJob({
    required String jobId,
    required String partId,
    required int quantity,
  }) async {
    await _client.dio.post('/service-jobs/$jobId/consume-part', data: {
      'partId': partId,
      'quantity': quantity,
    });
  }

  // Technicians List
  Future<List<Map<String, dynamic>>> getTechnicians({String? date}) async {
    final res = await _client.dio.get('/dashboard/technicians', queryParameters: {
      if (date != null) 'date': date,
    });
    return List<Map<String, dynamic>>.from(res.data['data']);
  }

  // Inventory Parts
  Future<List<InventoryPartModel>> getInventoryParts({bool? lowStockOnly}) async {
    final res = await _client.dio.get('/inventory', queryParameters: {
      if (lowStockOnly == true) 'lowStockOnly': 'true',
    });
    final items = res.data['data'] as List;
    return items.map((i) => InventoryPartModel.fromJson(i)).toList();
  }

  // Invoices
  Future<List<InvoiceModel>> getInvoices({String? status}) async {
    final res = await _client.dio.get('/billing/invoices', queryParameters: {
      if (status != null) 'status': status,
    });
    final items = res.data['data'] as List;
    return items.map((i) => InvoiceModel.fromJson(i)).toList();
  }

  // Record Payment
  Future<void> recordPayment({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
  }) async {
    await _client.dio.post('/billing/payments', data: {
      'invoiceId': invoiceId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
    });
  }

  // Edit Booking Request (Admin & Staff)
  Future<void> updateBookingRequest({
    required String requestId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? addressLine,
    String? area,
    String? pincode,
    String? serviceTypeId,
    String? complaint,
    String? priority,
    String? acBrand,
    String? acType,
    double? acTonnage,
    String? preferredDate,
    String? preferredTimeSlot,
  }) async {
    await _client.dio.put('/booking-requests/$requestId', data: {
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (addressLine != null) 'addressLine': addressLine,
      if (area != null) 'area': area,
      if (pincode != null) 'pincode': pincode,
      if (serviceTypeId != null) 'serviceTypeId': serviceTypeId,
      if (complaint != null) 'complaint': complaint,
      if (priority != null) 'priority': priority,
      if (acBrand != null) 'acBrand': acBrand,
      if (acType != null) 'acType': acType,
      if (acTonnage != null) 'acTonnage': acTonnage,
      if (preferredDate != null) 'preferredDate': preferredDate,
      if (preferredTimeSlot != null) 'preferredTimeSlot': preferredTimeSlot,
    });
  }

  // Delete Booking Request (Admin)
  Future<void> deleteBookingRequest(String requestId) async {
    await _client.dio.delete('/booking-requests/$requestId');
  }

  // Request Customer Closure OTP (supports optional alternate phone)
  Future<Map<String, dynamic>> requestClosureOtp(String jobId, {String? alternatePhone}) async {
    final res = await _client.dio.post('/service-jobs/$jobId/request-closure-otp', data: {
      if (alternatePhone != null && alternatePhone.trim().isNotEmpty) 'alternatePhone': alternatePhone.trim(),
    });
    return res.data['data'] ?? {};
  }

  // --- Live Google Map Tracking (Swiggy / Zepto Style) ---
  Future<Map<String, dynamic>> getJobTracking(String jobId) async {
    final res = await _client.dio.get('/service-jobs/$jobId/tracking');
    return res.data['data'] ?? {};
  }

  Future<void> updateJobLiveLocation(String jobId, double latitude, double longitude) async {
    await _client.dio.post('/service-jobs/$jobId/tracking/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // --- Technician Management & Location ---
  Future<List<Map<String, dynamic>>> getAllTechnicians() async {
    final res = await _client.dio.get('/technicians');
    return List<Map<String, dynamic>>.from(res.data['data']);
  }

  Future<void> createTechnician({
    required String name,
    required String email,
    required String password,
    required String phone,
    List<String> skills = const ['SPLIT', 'WINDOW'],
    List<String> serviceAreas = const ['Chennai Central'],
    int maxDailyJobs = 4,
  }) async {
    await _client.dio.post('/technicians', data: {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'skills': skills,
      'serviceAreas': serviceAreas,
      'maxDailyJobs': maxDailyJobs,
    });
  }

  Future<void> deleteTechnician(String technicianId) async {
    await _client.dio.delete('/technicians/$technicianId');
  }

  Future<void> setTechnicianAvailability({
    required bool isOnline,
    double? latitude,
    double? longitude,
    String? technicianId,
  }) async {
    await _client.dio.patch('/technicians/availability', data: {
      'isOnline': isOnline,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    }, queryParameters: {
      if (technicianId != null) 'technicianId': technicianId,
    });
  }

  Future<void> pingTechnicianLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _client.dio.post('/technicians/location', data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<List<Map<String, dynamic>>> getLiveTechnicianLocations() async {
    final res = await _client.dio.get('/technicians/live-locations');
    return List<Map<String, dynamic>>.from(res.data['data']);
  }

  // --- Attendance & Timesheets ---
  Future<Map<String, dynamic>> clockIn({double? latitude, double? longitude, String? notes}) async {
    final res = await _client.dio.post('/attendance/clock-in', data: {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
    });
    return res.data['data'];
  }

  Future<Map<String, dynamic>> clockOut({double? latitude, double? longitude, String? notes}) async {
    final res = await _client.dio.post('/attendance/clock-out', data: {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
    });
    return res.data['data'];
  }

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final res = await _client.dio.get('/attendance/today');
    return res.data['data'];
  }

  Future<Map<String, dynamic>> getAttendanceReport({
    String? startDate,
    String? endDate,
    String? technicianId,
  }) async {
    final res = await _client.dio.get('/attendance/report', queryParameters: {
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (technicianId != null) 'technicianId': technicianId,
    });
    final data = res.data['data'];
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is List) {
      return {'logs': List<Map<String, dynamic>>.from(data), 'consolidated': <Map<String, dynamic>>[]};
    }
    return {'logs': <Map<String, dynamic>>[], 'consolidated': <Map<String, dynamic>>[]};
  }

  // --- Clients 360 & Management ---
  Future<List<Map<String, dynamic>>> getClients({String? search, int page = 1, int limit = 20}) async {
    final res = await _client.dio.get('/clients', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return List<Map<String, dynamic>>.from(res.data['data']['items']);
  }

  Future<Map<String, dynamic>> getClient360(String clientId) async {
    final res = await _client.dio.get('/clients/$clientId/360');
    return res.data['data'];
  }

  Future<void> updateClient({
    required String clientId,
    String? name,
    String? phone,
    String? email,
  }) async {
    await _client.dio.put('/clients/$clientId', data: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    });
  }

  // Update Technician details (Admin)
  Future<void> updateTechnician({
    required String technicianId,
    String? name,
    String? phone,
    List<String>? skills,
    List<String>? serviceAreas,
    int? maxDailyJobs,
  }) async {
    await _client.dio.put('/technicians/$technicianId', data: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (skills != null) 'skills': skills,
      if (serviceAreas != null) 'serviceAreas': serviceAreas,
      if (maxDailyJobs != null) 'maxDailyJobs': maxDailyJobs,
    });
  }

  // Fetch fresh current user profile
  Future<UserModel> getMe() async {
    final res = await _client.dio.get('/auth/me');
    return UserModel.fromJson(res.data['data']);
  }

  // Update current user profile
  Future<UserModel> updateProfile({String? name, String? phone, String? avatarUrl}) async {
    final res = await _client.dio.put('/auth/me', data: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return UserModel.fromJson(res.data['data']);
  }

  // --- Inventory Management (Admin & Accountant) ---
  Future<void> updateInventoryPart({
    required String id,
    String? sku,
    String? name,
    String? category,
    double? unitPrice,
    double? sellingPrice,
    int? currentStock,
    int? minStockAlertLevel,
    String? supplierName,
  }) async {
    await _client.dio.put('/inventory/$id', data: {
      if (sku != null) 'sku': sku,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (unitPrice != null) 'unitPrice': unitPrice,
      if (sellingPrice != null) 'sellingPrice': sellingPrice,
      if (currentStock != null) 'currentStock': currentStock,
      if (minStockAlertLevel != null) 'minStockAlertLevel': minStockAlertLevel,
      if (supplierName != null) 'supplierName': supplierName,
    });
  }

  Future<void> createInventoryPart({
    required String sku,
    required String name,
    required String category,
    required double unitPrice,
    required double sellingPrice,
    int currentStock = 0,
    int minStockAlertLevel = 5,
    String? supplierName,
  }) async {
    await _client.dio.post('/inventory', data: {
      'sku': sku,
      'name': name,
      'category': category,
      'unitPrice': unitPrice,
      'sellingPrice': sellingPrice,
      'currentStock': currentStock,
      'minStockAlertLevel': minStockAlertLevel,
      if (supplierName != null && supplierName.isNotEmpty) 'supplierName': supplierName,
    });
  }

  Future<void> deleteInventoryPart(String id) async {
    await _client.dio.delete('/inventory/$id');
  }

  // --- User Management (Admin Only) ---
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final res = await _client.dio.get('/users');
    return List<Map<String, dynamic>>.from(res.data['data']);
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? avatarUrl,
    List<String>? skills,
    List<String>? serviceAreas,
    int? maxDailyJobs,
  }) async {
    await _client.dio.post('/users', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (skills != null) 'skills': skills,
      if (serviceAreas != null) 'serviceAreas': serviceAreas,
      if (maxDailyJobs != null) 'maxDailyJobs': maxDailyJobs,
    });
  }

  Future<void> deleteUser(String userId) async {
    await _client.dio.delete('/users/$userId');
  }

  // --- Individual Technician Detailed Reports ---
  Future<Map<String, dynamic>> getTechnicianReport(String techId) async {
    final res = await _client.dio.get('/technicians/$techId/report');
    return res.data['data'] ?? {};
  }

  /// Resolves an internal API URL (like localhost or 127.0.0.1) to an externally reachable LAN IP
  /// so that mobile browsers, download managers, and PDF viewers on physical devices can connect.
  String resolveExternalUrl(String url) {
    return url
        .replaceFirst('://127.0.0.1', '://${AppConstants.lanHost}')
        .replaceFirst('://localhost', '://${AppConstants.lanHost}');
  }

  Future<String> getTechnicianReportPdfUrl(String techId) async {
    final base = await _client.getBaseUrl();
    final token = await _client.getAccessToken();
    final url = (token != null && token.isNotEmpty)
        ? '$base/technicians/$techId/report/pdf?token=$token'
        : '$base/technicians/$techId/report/pdf';
    return resolveExternalUrl(url);
  }

  Future<String> getInvoicePdfUrl(String invoiceId) async {
    final base = await _client.getBaseUrl();
    final token = await _client.getAccessToken();
    final url = (token != null && token.isNotEmpty)
        ? '$base/billing/invoices/$invoiceId/pdf?token=$token'
        : '$base/billing/invoices/$invoiceId/pdf';
    return resolveExternalUrl(url);
  }

  // --- Customized Billing, Settlement & Financial Consolidation ---
  Future<Map<String, dynamic>> getConsolBillingSummary() async {
    final res = await _client.dio.get('/billing/consol-summary');
    return res.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> createCustomInvoice({
    String? customerId,
    String? serviceJobId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    required List<Map<String, dynamic>> items,
    double discount = 0,
    double taxRate = 18.0,
    String? dueDate,
    String? notes,
    double? upfrontSettlementAmount,
    double? paidAmount,
    String? paymentMethod,
    String? referenceNumber,
    bool allowDuplicate = false,
    bool replaceExisting = false,
  }) async {
    final effectiveSettlement = paidAmount ?? upfrontSettlementAmount;
    final res = await _client.dio.post('/billing/invoices/custom', data: {
      if (customerId != null) 'customerId': customerId,
      if (serviceJobId != null) 'serviceJobId': serviceJobId,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (customerAddress != null) 'customerAddress': customerAddress,
      'items': items,
      'discount': discount,
      'taxRate': taxRate,
      if (dueDate != null) 'dueDate': dueDate,
      if (notes != null) 'notes': notes,
      if (effectiveSettlement != null) 'upfrontSettlementAmount': effectiveSettlement,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
      'allowDuplicate': allowDuplicate,
      'replaceExisting': replaceExisting,
    });
    return res.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> recordSettlement({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    final res = await _client.dio.post('/billing/invoices/$invoiceId/settlement', data: {
      'amount': amount,
      'paymentMethod': paymentMethod,
      if (referenceNumber != null && referenceNumber.isNotEmpty) 'referenceNumber': referenceNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res.data['data'] ?? {};
  }

  // --- Expense Tracker ---
  Future<Map<String, dynamic>> getExpenses({String? category, String? userId}) async {
    final res = await _client.dio.get('/billing/expenses', queryParameters: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
    });
    final data = res.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'items': data ?? [], 'summary': {}};
  }

  Future<Map<String, dynamic>> createExpense({
    required String category,
    required double amount,
    required String description,
    String? expenseDate,
    String? targetUserId,
  }) async {
    final res = await _client.dio.post('/billing/expenses', data: {
      'category': category,
      'amount': amount,
      'description': description,
      if (expenseDate != null) 'expenseDate': expenseDate,
      if (targetUserId != null) 'targetUserId': targetUserId,
    });
    return res.data['data'] ?? {};
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.dio.delete('/billing/expenses/$expenseId');
  }

  // Generate Invoice from Job (with duplicate check support)
  Future<void> generateInvoiceFromJob({
    required String jobId,
    double discount = 0,
    double taxRate = 18.0,
    bool allowDuplicate = false,
    bool replaceExisting = false,
  }) async {
    await _client.dio.post('/billing/invoices/generate-from-job', data: {
      'jobId': jobId,
      'discount': discount,
      'taxRate': taxRate,
      'allowDuplicate': allowDuplicate,
      'replaceExisting': replaceExisting,
    });
  }

  // Check if invoice already exists for a service job
  Future<Map<String, dynamic>> checkJobInvoice(String jobId) async {
    final res = await _client.dio.get('/billing/invoices/check-job/$jobId');
    return res.data;
  }

  // Delete invoice (cascades items & payments)
  Future<void> deleteInvoice(String invoiceId) async {
    await _client.dio.delete('/billing/invoices/$invoiceId');
  }

  // --- Field Service Reports (FSR) ---
  Future<List<FieldServiceReportModel>> getFieldServiceReports({
    String? search,
    String? reportType,
    String? serviceJobId,
  }) async {
    final res = await _client.dio.get('/service-reports', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (reportType != null && reportType != 'ALL') 'reportType': reportType,
      if (serviceJobId != null) 'serviceJobId': serviceJobId,
    });
    final items = res.data['data']?['items'] as List? ?? [];
    return items.map((json) => FieldServiceReportModel.fromJson(json)).toList();
  }

  Future<FieldServiceReportModel> getFieldServiceReport(String id) async {
    final res = await _client.dio.get('/service-reports/$id');
    return FieldServiceReportModel.fromJson(res.data['data']);
  }

  Future<FieldServiceReportModel> createFieldServiceReport({
    String? serviceJobId,
    String? reportNumber,
    String reportType = 'DO_AND_CHARGE_REPAIR',
    required String customerName,
    required String customerAddress,
    String? contactPhone,
    String? personCalling,
    String? serviceEngineerName,
    String? complaintDate,
    String? attendingDate,
    String? modelNumber,
    String? indoorSerialNo,
    String? outdoorSerialNo,
    String? errorCode,
    String? runningCurrent,
    String? suctionPressure,
    String? dischargePressure,
    String? roomTemperature,
    String? voltage,
    String? equip1Details,
    String? equip2Details,
    required String observations,
    String? suggestions,
    String? customerSignName,
  }) async {
    final res = await _client.dio.post('/service-reports', data: {
      if (serviceJobId != null) 'serviceJobId': serviceJobId,
      if (reportNumber != null && reportNumber.isNotEmpty) 'reportNumber': reportNumber,
      'reportType': reportType,
      'customerName': customerName,
      'customerAddress': customerAddress,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (personCalling != null) 'personCalling': personCalling,
      if (serviceEngineerName != null) 'serviceEngineerName': serviceEngineerName,
      if (complaintDate != null) 'complaintDate': complaintDate,
      if (attendingDate != null) 'attendingDate': attendingDate,
      if (modelNumber != null) 'modelNumber': modelNumber,
      if (indoorSerialNo != null) 'indoorSerialNo': indoorSerialNo,
      if (outdoorSerialNo != null) 'outdoorSerialNo': outdoorSerialNo,
      if (errorCode != null) 'errorCode': errorCode,
      if (runningCurrent != null) 'runningCurrent': runningCurrent,
      if (suctionPressure != null) 'suctionPressure': suctionPressure,
      if (dischargePressure != null) 'dischargePressure': dischargePressure,
      if (roomTemperature != null) 'roomTemperature': roomTemperature,
      if (voltage != null) 'voltage': voltage,
      if (equip1Details != null) 'equip1Details': equip1Details,
      if (equip2Details != null) 'equip2Details': equip2Details,
      'observations': observations,
      if (suggestions != null) 'suggestions': suggestions,
      if (customerSignName != null) 'customerSignName': customerSignName,
    });
    return FieldServiceReportModel.fromJson(res.data['data']);
  }

  Future<void> deleteFieldServiceReport(String id) async {
    await _client.dio.delete('/service-reports/$id');
  }

  Future<String> getFieldServiceReportPdfUrl(String id) async {
    final base = await _client.getBaseUrl();
    final token = await _client.getAccessToken();
    final url = (token != null && token.isNotEmpty)
        ? '$base/service-reports/$id/pdf?token=$token'
        : '$base/service-reports/$id/pdf';
    return resolveExternalUrl(url);
  }

  // Forgot Password: Request OTP
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await _client.dio.post('/auth/forgot-password', data: {
      'email': email,
    });
    return res.data;
  }

  // Reset Password: Submit OTP and new password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final res = await _client.dio.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
    return res.data;
  }
}
