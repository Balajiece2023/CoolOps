class AppConstants {
  // Production Railway backend API URL (default) & local dev fallback presets
  static const String productionApiUrl = 'https://coolops-production.up.railway.app/api/v1';
  static const String lanHost = '10.94.143.144';
  static const String lanPort = '4000';
  static const String lanApiUrl = 'http://10.94.143.144:4000/api/v1';
  static const String usbApiUrl = 'http://127.0.0.1:4000/api/v1';
  static const String defaultApiUrl = productionApiUrl;
  static const String companyName = 'Caring Cool Tech';
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
