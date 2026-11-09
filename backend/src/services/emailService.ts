import nodemailer, { Transporter } from 'nodemailer';
import { config } from '../config';

export interface SendEmailOptions {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

export class EmailService {
  private transporter: Transporter | null = null;

  constructor() {
    this.initTransporter();
  }

  private initTransporter() {
    const { host, port, secure, user, pass } = config.smtp;

    if (host && user && pass) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure,
        auth: { user, pass },
        tls: {
          rejectUnauthorized: false
        }
      });
      console.log(`📧 [EMAIL-SERVICE] Configured with live SMTP server: ${host}:${port}`);
    } else {
      // In development or when SMTP credentials are not yet specified,
      // use JSON / stream transport to log email contents safely without crashing
      this.transporter = nodemailer.createTransport({
        jsonTransport: true
      });
      console.log('📧 [EMAIL-SERVICE] Operating in simulated dev mode (set SMTP_HOST, SMTP_USER, SMTP_PASS in .env for live outbound emails)');
    }
  }

  /**
   * General method to send an email via Nodemailer
   */
  async sendMail(options: SendEmailOptions): Promise<{ success: boolean; messageId?: string; error?: string }> {
    try {
      if (!this.transporter) {
        this.initTransporter();
      }

      const fromAddress = config.smtp.from || '"Caring Cool Tech" <support@caringcooltech.com>';

      const info = await this.transporter!.sendMail({
        from: fromAddress,
        to: options.to,
        subject: options.subject,
        text: options.text || options.subject,
        html: options.html
      });

      console.log(`✉️ [EMAIL-SENT] To: ${options.to} | Subject: "${options.subject}" | ID: ${info.messageId}`);

      if (info.message) {
        // Log in dev simulation mode
        console.log(`📋 [EMAIL-PAYLOAD]:\n${info.message}`);
      }

      return { success: true, messageId: info.messageId };
    } catch (err: any) {
      console.error(`❌ [EMAIL-ERROR] Failed to send email to ${options.to}:`, err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Sends 6-digit OTP to Technician / User for Password Reset
   */
  async sendTechnicianPasswordResetOtp(params: {
    to: string;
    name: string;
    otp: string;
  }): Promise<{ success: boolean; messageId?: string; error?: string }> {
    const { to, name, otp } = params;

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Caring Cool Tech - Password Reset OTP</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; color: #1e293b; }
    .container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 14px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
    .header { background: #0284c7; padding: 24px 20px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 20px; letter-spacing: 0.5px; font-weight: 700; }
    .header p { margin: 4px 0 0 0; font-size: 12px; color: #e0f2fe; }
    .content { padding: 28px 24px; }
    .greeting { font-size: 15px; font-weight: 600; margin-bottom: 12px; }
    .otp-box { background: #f0fdf4; border: 2px dashed #22c55e; border-radius: 10px; padding: 18px; text-align: center; margin: 24px 0; }
    .otp-title { font-size: 12px; color: #15803d; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px; }
    .otp-code { font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #0f172a; font-family: 'Courier New', Courier, monospace; margin: 0; }
    .info-text { font-size: 13px; line-height: 1.6; color: #475569; margin: 12px 0; }
    .warning { background: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px 14px; border-radius: 4px; font-size: 12px; color: #92400e; margin-top: 20px; }
    .footer { background: #f8fafc; padding: 16px 24px; text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #e2e8f0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>CARING COOL TECH</h1>
      <p>Official Service & Maintenance Management Portal</p>
    </div>
    <div class="content">
      <div class="greeting">Hello ${name || 'Technician'},</div>
      <p class="info-text">
        We received a request to reset the password for your Caring Cool Tech account (<strong>${to}</strong>).
      </p>
      <p class="info-text">
        Use the following One-Time Password (OTP) in the mobile app to verify your identity and set a new password:
      </p>

      <div class="otp-box">
        <div class="otp-title">Your Verification Code</div>
        <div class="otp-code">${otp}</div>
      </div>

      <div class="warning">
        ⚠️ <strong>Security Notice:</strong> This OTP is valid for <strong>10 minutes</strong>. Never share this code with anyone. Caring Cool Tech staff will never ask for your password or OTP.
      </div>

      <p class="info-text" style="margin-top: 18px;">
        If you did not request this password reset, please disregard this email or report to the admin immediately.
      </p>
    </div>
    <div class="footer">
      &copy; ${new Date().getFullYear()} Caring Cool Tech. All rights reserved.<br>
      Puducherry &bull; Contact: 96776 86561 / 99766 88166
    </div>
  </div>
</body>
</html>
    `;

    return await this.sendMail({
      to,
      subject: `Caring Cool Tech - Password Reset OTP (${otp})`,
      text: `Hello ${name || 'Technician'},\n\nYour Caring Cool Tech password reset OTP is: ${otp}\nThis code is valid for 10 minutes.\n\nIf you did not request this, please ignore this email.`,
      html
    });
  }

  /**
   * Sends 6-digit Customer Closure OTP via email
   */
  async sendCustomerClosureOtpEmail(params: {
    to: string;
    customerName: string;
    jobNumber: string;
    otp: string;
    technicianName?: string;
  }): Promise<{ success: boolean; messageId?: string; error?: string }> {
    const { to, customerName, jobNumber, otp, technicianName } = params;

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Caring Cool Tech - Service Completion OTP</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; color: #1e293b; }
    .container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 14px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
    .header { background: #0284c7; padding: 22px 20px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 20px; letter-spacing: 0.5px; font-weight: 700; }
    .header p { margin: 4px 0 0 0; font-size: 12px; color: #e0f2fe; }
    .content { padding: 26px 24px; }
    .greeting { font-size: 15px; font-weight: 600; margin-bottom: 12px; }
    .otp-box { background: #eff6ff; border: 2px dashed #0284c7; border-radius: 10px; padding: 18px; text-align: center; margin: 22px 0; }
    .otp-title { font-size: 12px; color: #0369a1; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px; }
    .otp-code { font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #0284c7; font-family: 'Courier New', Courier, monospace; margin: 0; }
    .info-text { font-size: 13px; line-height: 1.6; color: #475569; margin: 12px 0; }
    .warning { background: #f0fdf4; border-left: 4px solid #16a34a; padding: 12px 14px; border-radius: 4px; font-size: 12px; color: #166534; margin-top: 18px; }
    .footer { background: #f8fafc; padding: 16px 24px; text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #e2e8f0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>CARING COOL TECH</h1>
      <p>Customer Service Completion Verification</p>
    </div>
    <div class="content">
      <div class="greeting">Dear ${customerName},</div>
      <p class="info-text">
        Our Service Engineer <strong>${technicianName || 'our technician'}</strong> has attended to your AC service job <strong>#${jobNumber}</strong>.
      </p>
      <p class="info-text">
        Please inspect the cooling, cleaning, and performance of your AC unit. Once you are fully satisfied with the service delivered, please share the following completion OTP with the technician to officially close the ticket:
      </p>

      <div class="otp-box">
        <div class="otp-title">Customer Closure OTP</div>
        <div class="otp-code">${otp}</div>
      </div>

      <div class="warning">
        ✅ <strong>Important:</strong> Only share this OTP with the technician after your AC service has been successfully completed and tested. Valid for 15 minutes.
      </div>
    </div>
    <div class="footer">
      Thank you for choosing Caring Cool Tech!<br>
      For any feedback or queries, call us: 96776 86561 / 99766 88166
    </div>
  </div>
</body>
</html>
    `;

    return await this.sendMail({
      to,
      subject: `Caring Cool Tech AC Service Completion OTP: ${otp} (Job #${jobNumber})`,
      text: `Dear ${customerName},\n\nYour AC service job #${jobNumber} has been completed. Your verification OTP is: ${otp}\nValid for 15 minutes. Share with technician only after service is completed.\n\nThank you,\nCaring Cool Tech`,
      html
    });
  }
}

export const emailService = new EmailService();
