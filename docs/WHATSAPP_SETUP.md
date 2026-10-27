# Meta WhatsApp Business Cloud API Configuration Guide

This guide walks you through setting up official Meta WhatsApp Cloud API credentials for production, registering your phone number, configuring webhooks with HMAC-SHA256 signature verification, and understanding Meta messaging windows and charges.

---

## 1. Prerequisites on Meta for Developers
1. Register as a Meta Developer at [developers.facebook.com](https://developers.facebook.com/).
2. Create an App with App Type: **Business**.
3. Under Add Products to Your App, click **Set Up** next to **WhatsApp**.

---

## 2. Credentials Needed in `.env`

Update your [backend/.env](file:///e:/ACService/backend/.env) with the following values:

| Variable | Description | Where to Find in Meta Portal |
| :--- | :--- | :--- |
| `META_WHATSAPP_ENABLED` | Set to `true` to make live API calls. Set `false` to use local simulator. | Local config |
| `META_WHATSAPP_API_VERSION` | Meta Graph API Version (e.g. `v21.0`) | Graph API Explorer |
| `META_WHATSAPP_PHONE_NUMBER_ID` | Identification number for your business WhatsApp number | WhatsApp > API Setup > Phone Number ID |
| `META_WHATSAPP_WABA_ID` | WhatsApp Business Account ID | WhatsApp > API Setup > WhatsApp Business Account ID |
| `META_WHATSAPP_ACCESS_TOKEN` | System User Permanent Access Token with `whatsapp_business_messaging` permissions | Business Manager > System Users > Generate New Token |
| `META_WHATSAPP_WEBHOOK_VERIFY_TOKEN` | Custom secret string you create (e.g. `frostpro_meta_verify_token_2026`) | You define this when subscribing webhook in Meta |
| `META_WHATSAPP_APP_SECRET` | Used for X-Hub-Signature-256 HMAC verification | App Settings > Basic > App Secret |

---

## 3. Registering Your Dedicated WhatsApp Business Phone Number
- A phone number registered on Meta Cloud API **cannot** be simultaneously active on the consumer WhatsApp or standard WhatsApp Business mobile app.
- If you have an existing phone number, you must delete that account in the WhatsApp app on your phone before registering it on Meta Cloud API.
- In Meta App Dashboard, navigate to **WhatsApp > Configuration > Phone Numbers**, click **Add Phone Number**, verify via SMS/Voice OTP, and configure your Business Profile (Logo, Business Hours, Address).

---

## 4. Webhook Subscription & Verification
1. Deploy your backend with a valid public HTTPS URL (using cloud hosting, reverse proxy, or ngrok for staging: `https://yourdomain.com/webhooks/whatsapp`).
2. In Meta App Dashboard, navigate to **WhatsApp > Configuration > Webhook**.
3. Click **Edit**:
   - **Callback URL:** `https://yourdomain.com/webhooks/whatsapp`
   - **Verify Token:** The exact value of `META_WHATSAPP_WEBHOOK_VERIFY_TOKEN` in your `.env`.
4. Click **Verify and Save**. Meta will send a `GET` request with challenge parameters. The backend responds with `hub.challenge` after validating the verify token.
5. In **Webhook Fields**, click **Manage** and subscribe to:
   - `messages` (inbound customer messages)
   - `message_template_status_update`

---

## 5. 24-Hour Customer Service Window & Meta Message Templates
1. **Inbound Window (Free/Service):** When a customer messages your company WhatsApp number, a **24-hour customer service window** opens. During this 24-hour window, the bot can send free-form text messages (bilingual Tamil/English flow).
2. **Outside the 24-Hour Window (Business-Initiated):**
   - You **cannot** send free-form text messages.
   - You **must** send pre-approved Meta Message Templates.
3. Example Approved Template for Appointment Confirmation:
   - **Template Name:** `service_appointment_confirmation`
   - **Category:** Utility
   - **Language:** English (`en_US`) / Tamil (`ta`)
   - **Body:** `Hello {{1}}, your FrostPro AC Service booking {{2}} is confirmed for {{3}} with technician {{4}}. Our team will reach you on schedule.`

---

## 6. Meta Provider Conversation Charges
- Meta charges per 24-hour conversation window based on category and country code (India Country Code `+91`):
  - **Service Conversations (Customer-initiated):** Low rate (~₹0.30 - ₹0.40 per 24h conversation).
  - **Utility Conversations (Confirmations, reminders):** (~₹0.12 - ₹0.15 per conversation).
  - **Marketing Conversations:** Higher tier rate (~₹0.80 per conversation).
- First 1,000 service conversations each month are free for the WhatsApp Business Account.

---

## 7. Built-in Testing Without Live Meta Credentials
If you do not have Meta credentials yet, FrostPro includes a complete built-in simulator:
```bash
POST http://localhost:4000/webhooks/whatsapp/simulate
Content-Type: application/json

{
  "phone": "+919840012345",
  "message": "1"
}
```
This lets you test the full conversational state machine (English and Tamil) and verify booking creation in `PENDING_APPROVAL` status immediately.
