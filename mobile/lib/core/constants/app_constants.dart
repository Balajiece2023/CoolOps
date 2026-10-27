class AppConstants {
  // Configurable base URL. Supports reverse port forwarding (127.0.0.1:4000) and current LAN IP (192.168.1.7:4000)
  static const String defaultApiUrl = 'http://127.0.0.1:4000/api/v1';
  static const String lanApiUrl = 'http://192.168.1.7:4000/api/v1';
  static const String companyName = 'FrostPro AC Solutions';
  static const String currencySymbol = '₹';

  // Storage Keys
  static const String keyAccessToken = 'auth_access_token';
  static const String keyRefreshToken = 'auth_refresh_token';
  static const String keyUserRole = 'auth_user_role';
  static const String keyUserName = 'auth_user_name';
  static const String keyUserEmail = 'auth_user_email';
  static const String keyUserId = 'auth_user_id';
  static const String keyTechnicianId = 'auth_technician_id';
  static const String keyCustomApiUrl = 'config_custom_api_url';
}
