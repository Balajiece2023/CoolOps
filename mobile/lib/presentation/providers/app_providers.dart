import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/api_repository.dart';
import '../../data/models/models.dart';

// Providers
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final apiRepositoryProvider = Provider<ApiRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiRepository(client);
});

// Current User State Provider (Riverpod 3 Notifier)
class AuthNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() => null;

  void setUser(UserModel user) {
    state = user;
  }

  Future<void> logout() async {
    final repo = ref.read(apiRepositoryProvider);
    await repo.logout();
    state = null;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, UserModel?>(() {
  return AuthNotifier();
});

// Dashboard Stats Provider
final dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(apiRepositoryProvider);
  return repo.getDashboardStats();
});

// Booking Requests Provider
final bookingRequestsProvider = FutureProvider.family.autoDispose<List<BookingRequestModel>, String?>((ref, status) async {
  final repo = ref.watch(apiRepositoryProvider);
  return repo.getBookingRequests(status: status);
});

// Service Jobs Provider
final serviceJobsProvider = FutureProvider.family.autoDispose<List<ServiceJobModel>, String?>((ref, status) async {
  final repo = ref.watch(apiRepositoryProvider);
  return repo.getServiceJobs(status: status);
});

// Inventory Parts Provider
final inventoryPartsProvider = FutureProvider.family.autoDispose<List<InventoryPartModel>, bool?>((ref, lowStock) async {
  final repo = ref.watch(apiRepositoryProvider);
  return repo.getInventoryParts(lowStockOnly: lowStock);
});

// Invoices Provider
final invoicesProvider = FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final repo = ref.watch(apiRepositoryProvider);
  return repo.getInvoices();
});

// Technicians List Provider
final techniciansListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(apiRepositoryProvider);
  return repo.getTechnicians();
});

// Theme Mode Provider (Light / Dark)
class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() => false; // false = light, true = dark

  void toggleTheme() {
    state = !state;
  }

  void setDark(bool isDark) {
    state = isDark;
  }
}

final isDarkModeProvider = NotifierProvider<ThemeNotifier, bool>(() {
  return ThemeNotifier();
});

