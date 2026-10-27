import 'package:dio/dio.dart';
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

  Future<List<Map<String, dynamic>>> getAttendanceReport({
    String? startDate,
    String? endDate,
    String? technicianId,
  }) async {
    final res = await _client.dio.get('/attendance/report', queryParameters: {
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (technicianId != null) 'technicianId': technicianId,
    });
    return List<Map<String, dynamic>>.from(res.data['data']);
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
  Future<UserModel> updateProfile({String? name, String? phone}) async {
    final res = await _client.dio.put('/auth/me', data: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
    });
    return UserModel.fromJson(res.data['data']);
  }

  // Generate Invoice from Job
  Future<void> generateInvoiceFromJob({
    required String jobId,
    double discount = 0,
    double taxRate = 18.0,
  }) async {
    await _client.dio.post('/billing/invoices/generate-from-job', data: {
      'jobId': jobId,
      'discount': discount,
      'taxRate': taxRate,
    });
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
