import * as dotenv from 'dotenv';
dotenv.config();

export const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '4000', 10),
  apiPrefix: process.env.API_PREFIX || '/api/v1',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  business: {
    name: process.env.BUSINESS_NAME || 'Caring Cool Tech',
    timezone: process.env.BUSINESS_TIMEZONE || 'Asia/Kolkata',
    workStartHour: parseInt(process.env.BUSINESS_WORK_START_HOUR || '8', 10),
    workEndHour: parseInt(process.env.BUSINESS_WORK_END_HOUR || '20', 10),
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'dev-jwt-access-secret-minimum-32-chars-long-12345',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev-jwt-refresh-secret-minimum-32-chars-long-67890',
    accessExpiry: process.env.JWT_ACCESS_EXPIRY || '15m',
    refreshExpiry: process.env.JWT_REFRESH_EXPIRY || '7d',
  },
  metaWhatsApp: {
    enabled: process.env.META_WHATSAPP_ENABLED === 'true',
    apiVersion: process.env.META_WHATSAPP_API_VERSION || 'v21.0',
    phoneNumberId: process.env.META_WHATSAPP_PHONE_NUMBER_ID || '',
    wabaId: process.env.META_WHATSAPP_WABA_ID || '',
    accessToken: process.env.META_WHATSAPP_ACCESS_TOKEN || '',
    verifyToken: process.env.META_WHATSAPP_WEBHOOK_VERIFY_TOKEN || 'frostpro_meta_verify_token_2026',
    appSecret: process.env.META_WHATSAPP_APP_SECRET || 'meta_app_secret_placeholder',
  },
  storage: {
    uploadDir: process.env.UPLOAD_DIR || './uploads',
    maxUploadSizeMb: parseInt(process.env.MAX_UPLOAD_SIZE_MB || '10', 10),
  },
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || '"Caring Cool Tech" <support@caringcooltech.com>'
  },
  openSms: {
    apiUrl: process.env.OPENSMS_API_URL || process.env.SMS_GATEWAY_URL || 'https://opensms.wansaw.com/v1/sms/send',
    apiKey: process.env.OPENSMS_API_KEY || process.env.SMS_GATEWAY_API_KEY || 'osk_FEwEv_6iV8Q56CxtmtbJ-5DI-Nf7zYpoc9P_FkaWnGk'
  },
  smsGateway: {
    url: process.env.SMS_GATEWAY_URL || 'https://opensms.wansaw.com/v1/sms/send',
    apiKey: process.env.SMS_GATEWAY_API_KEY || 'osk_FEwEv_6iV8Q56CxtmtbJ-5DI-Nf7zYpoc9P_FkaWnGk',
    senderId: process.env.SMS_SENDER_ID || 'COOLTC'
  }
};
