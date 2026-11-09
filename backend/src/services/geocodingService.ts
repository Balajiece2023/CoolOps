/**
 * High-Accuracy Geocoding & Location Link Service for Caring Cool Tech
 * Strictly resolves customer location from:
 * 1. Explicit GPS coordinates
 * 2. Exact address lookup via OpenStreetMap Nominatim
 * 3. Exact Google Maps / WhatsApp location link provided by technician or customer
 *
 * NOTE: As per strict operational rules, we NEVER guess or assume arbitrary coordinates
 * if the address cannot be resolved. Instead, we request the exact Google Maps location link
 * from the technician/customer.
 */

export interface GeocodeQuery {
  addressLine?: string;
  area?: string;
  pincode?: string;
  city?: string;
  latitude?: number | null;
  longitude?: number | null;
  locationLink?: string | null;
}

export class GeocodingService {
  /**
   * Resolves coordinates from an exact address or location link.
   * Returns null if location cannot be accurately determined from address,
   * prompting the technician/admin to provide an exact Google Maps location link.
   */
  async resolveCoordinates(query: GeocodeQuery): Promise<{ lat: number; lng: number; source: string } | null> {
    // 1. If explicit valid GPS coordinates are provided, use them directly
    if (query.latitude && query.longitude && !isNaN(query.latitude) && !isNaN(query.longitude)) {
      if (query.latitude >= 8.0 && query.latitude <= 37.0 && query.longitude >= 68.0 && query.longitude <= 97.0) {
        return {
          lat: Number(query.latitude.toFixed(6)),
          lng: Number(query.longitude.toFixed(6)),
          source: 'EXPLICIT_GPS'
        };
      }
    }

    // 2. If a Google Maps / WhatsApp location link is provided, parse and resolve it
    if (query.locationLink && query.locationLink.trim()) {
      const fromLink = await this.resolveLocationFromLink(query.locationLink.trim());
      if (fromLink) {
        return {
          lat: fromLink.lat,
          lng: fromLink.lng,
          source: 'LOCATION_LINK'
        };
      }
    }

    const pincode = (query.pincode || '').trim().replace(/[^0-9]/g, '');
    const area = (query.area || '').trim();
    const addressLine = (query.addressLine || '').trim();
    const city = (query.city || '').trim();

    // If no address info is provided, cannot fetch
    if (!addressLine && !area && !pincode) {
      return null;
    }

    // 3. Try OpenStreetMap Nominatim Geocoding API based on exact address provided
    const searchQueries: string[] = [];
    if (addressLine && area && pincode) {
      searchQueries.push(`${addressLine}, ${area}, ${pincode}, India`);
    }
    if (addressLine && pincode) {
      searchQueries.push(`${addressLine}, ${pincode}, India`);
    }
    if (area && pincode) {
      searchQueries.push(`${area}, ${pincode}, India`);
    }
    if (addressLine && area) {
      searchQueries.push(`${addressLine}, ${area}, ${city || 'Tamil Nadu'}, India`);
    }

    for (const q of searchQueries) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 4000);

        const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(q)}&limit=1&countrycodes=in`;
        const res = await fetch(url, {
          headers: { 'User-Agent': 'CaringCoolTechApp/1.0 (support@caringcooltech.com)' },
          signal: controller.signal
        });
        clearTimeout(timeoutId);

        if (res.ok) {
          const data: any = await res.json();
          if (Array.isArray(data) && data.length > 0 && data[0].lat && data[0].lon) {
            const lat = parseFloat(data[0].lat);
            const lng = parseFloat(data[0].lon);
            if (!isNaN(lat) && !isNaN(lng) && lat >= 8.0 && lat <= 37.0 && lng >= 68.0 && lng <= 97.0) {
              console.log(`📍 [GEOCODING] Found real address location for "${q}": (${lat}, ${lng})`);
              return {
                lat: Number(lat.toFixed(6)),
                lng: Number(lng.toFixed(6)),
                source: `NOMINATIM (${q})`
              };
            }
          }
        }
      } catch (err: any) {
        console.warn(`[GEOCODING] Search error for "${q}":`, err?.message);
      }
    }

    // DO NOT assume or guess coordinates. If exact address cannot be found on map, return null.
    // The system will ask the technician/admin for the exact Google Maps location link.
    console.log(`⚠️ [GEOCODING] Address "${addressLine}, ${area}" could not be auto-located. Awaiting technician location link.`);
    return null;
  }

  /**
   * Resolves exact latitude and longitude from any Google Maps or WhatsApp location link
   * Handles:
   * - Google Maps shortened URLs: https://maps.app.goo.gl/xxx or https://goo.gl/maps/xxx
   * - Direct Google Maps URLs with @lat,lng or q=lat,lng
   * - WhatsApp location URLs: https://maps.google.com/maps?q=loc:lat,lng
   * - Plain comma-separated coordinates: "11.9320, 79.8280"
   */
  async resolveLocationFromLink(link: string): Promise<{ lat: number; lng: number } | null> {
    if (!link || typeof link !== 'string') return null;
    let text = link.trim();

    // 1. Check if raw coordinates string was passed: e.g. "11.9320, 79.8280" or "11.9320,79.8280"
    const rawCoordsMatch = text.match(/^(-?\d{1,2}\.\d+)[,\s]+(-?\d{1,3}\.\d+)$/);
    if (rawCoordsMatch) {
      const lat = parseFloat(rawCoordsMatch[1]);
      const lng = parseFloat(rawCoordsMatch[2]);
      if (this.isValidCoord(lat, lng)) {
        return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
      }
    }

    // 2. If it's a shortened Google Maps URL, follow HTTP redirect to expand
    if (text.includes('maps.app.goo.gl') || text.includes('goo.gl/maps')) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);
        const res = await fetch(text, {
          method: 'GET',
          redirect: 'follow',
          signal: controller.signal,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          }
        });
        clearTimeout(timeoutId);
        if (res.url && res.url !== text) {
          text = res.url;
        }
      } catch (e: any) {
        console.warn('[GEOCODING] Failed expanding shortened maps URL:', e?.message);
      }
    }

    // 3. Extract @lat,lng from URL path: e.g. /@11.932034,79.828012,17z
    const atMatch = text.match(/@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)/);
    if (atMatch) {
      const lat = parseFloat(atMatch[1]);
      const lng = parseFloat(atMatch[2]);
      if (this.isValidCoord(lat, lng)) {
        return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
      }
    }

    // 4. Extract q= or query= or ll= or loc:lat,lng
    const queryMatch = text.match(/[?&](?:q|query|ll|destination)=(?:loc:)?(-?\d{1,2}\.\d+)[,+ ]+(-?\d{1,3}\.\d+)/i);
    if (queryMatch) {
      const lat = parseFloat(queryMatch[1]);
      const lng = parseFloat(queryMatch[2]);
      if (this.isValidCoord(lat, lng)) {
        return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
      }
    }

    // 5. WhatsApp location format: maps?q=loc:11.9320,79.8280
    const locMatch = text.match(/loc:(-?\d{1,2}\.\d+)[,+ ]+(-?\d{1,3}\.\d+)/i);
    if (locMatch) {
      const lat = parseFloat(locMatch[1]);
      const lng = parseFloat(locMatch[2]);
      if (this.isValidCoord(lat, lng)) {
        return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
      }
    }

    // 6. Generic regex in any part of URL
    const generalMatch = text.match(/(-?\d{1,2}\.\d{4,})[,\s]+(-?\d{1,3}\.\d{4,})/);
    if (generalMatch) {
      const lat = parseFloat(generalMatch[1]);
      const lng = parseFloat(generalMatch[2]);
      if (this.isValidCoord(lat, lng)) {
        return { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
      }
    }

    return null;
  }

  private isValidCoord(lat: number, lng: number): boolean {
    return !isNaN(lat) && !isNaN(lng) && lat >= 8.0 && lat <= 37.0 && lng >= 68.0 && lng <= 97.0;
  }
}

export const geocodingService = new GeocodingService();
