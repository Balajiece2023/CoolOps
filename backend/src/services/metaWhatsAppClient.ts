import { config } from '../config';
import { prisma } from '../prisma';

export interface WhatsAppTextMessage {
  to: string;
  body: string;
}

export class MetaWhatsAppClient {
  /**
   * Sends a text message through Meta Graph API or Mock logger
   */
  async sendTextMessage(to: string, text: string): Promise<{ success: boolean; messageId?: string; error?: string }> {
    const cleanPhone = to.replace(/[^0-9]/g, '');

    if (!config.metaWhatsApp.enabled || !config.metaWhatsApp.accessToken || !config.metaWhatsApp.phoneNumberId) {
      console.log(`[WhatsApp-SIMULATOR] -> ${cleanPhone}: "${text}"`);
      const mockId = `wamid.MOCK_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
      return { success: true, messageId: mockId };
    }

    try {
      const url = `https://graph.facebook.com/${config.metaWhatsApp.apiVersion}/${config.metaWhatsApp.phoneNumberId}/messages`;
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${config.metaWhatsApp.accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: cleanPhone,
          type: 'text',
          text: { preview_url: false, body: text }
        })
      });

      const data: any = await response.json();
      if (!response.ok) {
        console.error('[Meta WhatsApp API Error]', data);
        return { success: false, error: data?.error?.message || 'Meta API returned error' };
      }

      const messageId = data?.messages?.[0]?.id;
      return { success: true, messageId };
    } catch (err: any) {
      console.error('[Meta WhatsApp Exception]', err);
      return { success: false, error: err.message };
    }
  }

  /**
   * Sends an approved Meta message template (required when initiating conversation outside 24h window)
   */
  async sendTemplateMessage(to: string, templateName: string, languageCode: string, components: any[]) {
    const cleanPhone = to.replace(/[^0-9]/g, '');

    if (!config.metaWhatsApp.enabled) {
      console.log(`[WhatsApp-SIMULATOR-TEMPLATE] -> ${cleanPhone}: template="${templateName}" [${languageCode}]`);
      return { success: true, messageId: `wamid.MOCK_TPL_${Date.now()}` };
    }

    try {
      const url = `https://graph.facebook.com/${config.metaWhatsApp.apiVersion}/${config.metaWhatsApp.phoneNumberId}/messages`;
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${config.metaWhatsApp.accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: cleanPhone,
          type: 'template',
          template: {
            name: templateName,
            language: { code: languageCode },
            components
          }
        })
      });

      const data: any = await response.json();
      if (!response.ok) {
        return { success: false, error: data?.error?.message || 'Meta Template API error' };
      }
      return { success: true, messageId: data?.messages?.[0]?.id };
    } catch (err: any) {
      return { success: false, error: err.message };
    }
  }
}

export const metaWhatsAppClient = new MetaWhatsAppClient();
