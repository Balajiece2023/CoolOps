import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { serviceJobWorkflowService } from '../services/serviceJobWorkflowService';
import { geocodingService } from '../services/geocodingService';
import { JobStatus, Role } from '@prisma/client';

export const serviceJobsRouter = Router();

serviceJobsRouter.use(authenticate);

// Get list of jobs (Technicians see only their own jobs; Admin/Staff see all)
serviceJobsRouter.get('/', async (req: Request, res: Response) => {
  const { status, date } = req.query;
  const user = req.user!;

  const whereClause: any = {};

  // Least-privilege: technician can only access their assigned jobs
  if (user.role === Role.TECHNICIAN) {
    if (!user.technicianId) {
      return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
    }
    whereClause.technicianId = user.technicianId;
  }

  if (status) {
    whereClause.status = status as JobStatus;
  }

  if (date) {
    const d = new Date(String(date));
    d.setUTCHours(0, 0, 0, 0);
    const nextD = new Date(d);
    nextD.setDate(d.getDate() + 1);

    whereClause.booking = {
      scheduledDate: { gte: d, lt: nextD }
    };
  }

  const jobs = await prisma.serviceJob.findMany({
    where: whereClause,
    include: {
      booking: {
        include: {
          customer: true,
          address: true,
          serviceType: true,
          bookingRequest: true
        }
      },
      acUnit: true,
      technician: { include: { user: true } },
      checklistItems: true,
      attachments: true,
      partsConsumed: { include: { part: true } }
    },
    orderBy: { createdAt: 'desc' }
  });

  return res.json({ success: true, data: jobs });
});

// Get job details
serviceJobsRouter.get('/:id', async (req: Request, res: Response) => {
  const job = await prisma.serviceJob.findUnique({
    where: { id: req.params.id },
    include: {
      booking: {
        include: {
          customer: true,
          address: true,
          serviceType: true,
          bookingRequest: true
        }
      },
      acUnit: true,
      technician: { include: { user: true } },
      checklistItems: true,
      attachments: true,
      partsConsumed: { include: { part: true } },
      invoices: { include: { payments: true } }
    }
  });

  if (!job) {
    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Service job not found' } });
  }

  // Authorization check
  if (req.user!.role === Role.TECHNICIAN && job.technicianId !== req.user!.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'You can only view your assigned jobs' } });
  }

  return res.json({ success: true, data: job });
});

// Comprehensive Regional Geocoding coordinates mapping for location tracking (Puducherry & Chennai)
const REGIONAL_COORDINATES: Record<string, { lat: number; lng: number }> = {
  // Puducherry Hub & Areas
  'puducherry': { lat: 11.9416, lng: 79.8083 },
  'pondicherry': { lat: 11.9416, lng: 79.8083 },
  'valarampet': { lat: 11.9325, lng: 79.8150 },
  'white town': { lat: 11.9333, lng: 79.8333 },
  'heritage town': { lat: 11.9370, lng: 79.8290 },
  'lawspet': { lat: 11.9610, lng: 79.8120 },
  'saravanan nagar': { lat: 11.9540, lng: 79.8050 },
  'kottakuppam': { lat: 11.9750, lng: 79.8350 },
  'villianur': { lat: 11.9160, lng: 79.7550 },
  'ariankuppam': { lat: 11.8980, lng: 79.8080 },
  'kalapet': { lat: 12.0300, lng: 79.8650 },
  'jmr': { lat: 11.9380, lng: 79.8210 },
  'mudaliarpet': { lat: 11.9210, lng: 79.8130 },
  'gorimedu': { lat: 11.9720, lng: 79.7990 },
  'thavalakuppam': { lat: 11.8700, lng: 79.7900 },
  'auroville': { lat: 11.9800, lng: 79.8200 },

  // Chennai Areas
  'adyar': { lat: 13.0012, lng: 80.2565 },
  'besant nagar': { lat: 12.9996, lng: 80.2707 },
  'thiruvanmiyur': { lat: 12.9830, lng: 80.2594 },
  'omr': { lat: 12.9010, lng: 80.2279 },
  'sholinganallur': { lat: 12.9010, lng: 80.2279 },
  'navalur': { lat: 12.8457, lng: 80.2268 },
  'siruseri': { lat: 12.8335, lng: 80.2185 },
  'anna nagar': { lat: 13.0850, lng: 80.2101 },
  'kilpauk': { lat: 13.0784, lng: 80.2412 },
  'mogappair': { lat: 13.0837, lng: 80.1750 },
  't. nagar': { lat: 13.0418, lng: 80.2341 },
  't nagar': { lat: 13.0418, lng: 80.2341 },
  'nungambakkam': { lat: 13.0569, lng: 80.2425 },
  'kodambakkam': { lat: 13.0524, lng: 80.2209 },
  'alwarpet': { lat: 13.0334, lng: 80.2514 },
  'velachery': { lat: 12.9815, lng: 80.2180 },
  'madipakkam': { lat: 12.9647, lng: 80.1961 },
  'tambaram': { lat: 12.9249, lng: 80.1000 },
  'chromepet': { lat: 12.9516, lng: 80.1462 },
  'porur': { lat: 13.0382, lng: 80.1565 },
  'valasaravakkam': { lat: 13.0403, lng: 80.1723 },
  'guindy': { lat: 13.0067, lng: 80.2025 },
  'mylapore': { lat: 13.0368, lng: 80.2676 },
  'mandaveli': { lat: 13.0280, lng: 80.2610 },
  'egmore': { lat: 13.0732, lng: 80.2609 },
  'central': { lat: 13.0827, lng: 80.2707 },
  'perambur': { lat: 13.1118, lng: 80.2425 }
};

function getCoordinatesForArea(area: string = '', addressLine: string = '', city: string = ''): { lat: number; lng: number } {
  const normalized = (area + ' ' + addressLine + ' ' + city).toLowerCase();
  for (const [key, coords] of Object.entries(REGIONAL_COORDINATES)) {
    if (normalized.includes(key)) {
      // Add deterministic micro-spread based on character hash so different streets in the same area show unique positions
      let hash = 0;
      for (let i = 0; i < addressLine.length; i++) hash = (hash * 31 + addressLine.charCodeAt(i)) % 1000;
      const microLat = ((hash % 100) - 50) * 0.00012;
      const microLng = (((hash / 10) % 100) - 50) * 0.00012;
      return { lat: Number((coords.lat + microLat).toFixed(6)), lng: Number((coords.lng + microLng).toFixed(6)) };
    }
  }

  // Default to Caring Cool Tech HQ (Puducherry)
  return { lat: 11.9416, lng: 79.8083 };
}

function calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
}

function generateRouteWaypoints(start: { lat: number; lng: number }, end: { lat: number; lng: number }, steps = 10) {
  const points = [];
  for (let i = 0; i <= steps; i++) {
    const ratio = i / steps;
    // Add micro-curvature to emulate realistic city road routes (like Swiggy / Zepto)
    const curve = Math.sin(ratio * Math.PI) * 0.0035;
    const lat = start.lat + (end.lat - start.lat) * ratio + curve;
    const lng = start.lng + (end.lng - start.lng) * ratio - (curve * 0.4);
    points.push({ lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) });
  }
  return points;
}

// 7. Swiggy/Zepto-style Live Location Tracking Endpoint
serviceJobsRouter.get('/:id/tracking', async (req: Request, res: Response) => {
  let job = await prisma.serviceJob.findUnique({
    where: { id: req.params.id },
    include: {
      booking: {
        include: {
          customer: true,
          address: true,
          serviceType: true,
          bookingRequest: true
        }
      },
      acUnit: true,
      technician: { include: { user: true } }
    }
  });

  // If not found by Job ID directly, search by bookingId, jobNumber, or bookingRequestId
  if (!job) {
    job = await prisma.serviceJob.findFirst({
      where: {
        OR: [
          { bookingId: req.params.id },
          { jobNumber: req.params.id },
          { booking: { bookingRequestId: req.params.id } }
        ]
      },
      include: {
        booking: {
          include: {
            customer: true,
            address: true,
            serviceType: true,
            bookingRequest: true
          }
        },
        acUnit: true,
        technician: { include: { user: true } }
      }
    });
  }

  // If still no confirmed job, check if this is an unassigned or pending BookingRequest
  if (!job) {
    const bReq = await prisma.bookingRequest.findUnique({
      where: { id: req.params.id },
      include: {
        address: true,
        customer: true,
        serviceType: true
      }
    });

    if (bReq) {
      let resolved = (bReq.latitude && bReq.longitude)
        ? { lat: bReq.latitude, lng: bReq.longitude }
        : (bReq.address?.latitude && bReq.address?.longitude)
        ? { lat: bReq.address.latitude, lng: bReq.address.longitude }
        : null;

      if (!resolved) {
        const geoResult = await geocodingService.resolveCoordinates({
          addressLine: bReq.address?.addressLine,
          area: bReq.address?.area,
          city: bReq.address?.city,
          pincode: bReq.address?.pincode,
          locationLink: (bReq as any).locationLink || (bReq.address as any)?.locationLink
        });
        if (geoResult) {
          resolved = { lat: geoResult.lat, lng: geoResult.lng };
          if (bReq.addressId) {
            prisma.customerAddress.update({
              where: { id: bReq.addressId },
              data: { latitude: resolved.lat, longitude: resolved.lng }
            }).catch(() => {});
          }
        }
      }

      const hasExactCustomerLocation = !!resolved;
      const techLat = resolved ? Number((resolved.lat + 0.012).toFixed(6)) : 11.9416;
      const techLng = resolved ? Number((resolved.lng - 0.009).toFixed(6)) : 79.8083;
      const waypoints = resolved ? generateRouteWaypoints({ lat: techLat, lng: techLng }, resolved, 10) : [];

      return res.json({
        success: true,
        data: {
          jobId: bReq.id,
          jobNumber: bReq.referenceNumber,
          status: 'PENDING_APPROVAL',
          isOtpVerified: false,
          hasExactCustomerLocation,
          needsLocationLink: !hasExactCustomerLocation,
          technician: {
            id: 'unassigned',
            name: 'Awaiting Field Technician Assignment',
            phone: '+91 96776 86561',
            completedJobs: 0,
            currentLatitude: techLat,
            currentLongitude: techLng,
            lastLocationAt: new Date(),
            isOnline: true,
            heading: 0
          },
          customer: {
            name: bReq.customer.name,
            phone: bReq.customer.phone,
            addressLine: bReq.address?.addressLine || 'Address',
            area: bReq.address?.area || 'Puducherry',
            city: bReq.address?.city || 'Puducherry',
            pincode: bReq.address?.pincode || '',
            latitude: resolved?.lat ?? null,
            longitude: resolved?.lng ?? null,
            locationLink: (bReq as any).locationLink || (bReq.address as any)?.locationLink || null
          },
          route: {
            distanceKm: resolved ? 2.1 : null,
            durationMinutes: resolved ? 8 : null,
            statusDescription: !hasExactCustomerLocation
              ? 'Customer exact location pending. Please provide Google Maps link.'
              : 'Ticket logged. Ready for admin assignment to nearest technician.',
            trafficCondition: 'SMOOTH',
            waypoints
          },
          service: {
            serviceName: bReq.serviceType.nameEn,
            acDetails: `${bReq.acBrand || 'Split AC'} (${bReq.acTonnage || 1.5}T)`,
            scheduledDate: bReq.preferredDate,
            timeSlot: bReq.preferredTimeSlot
          }
        }
      });
    }

    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Service job or booking not found' } });
  }

  // Resolve customer destination coordinates (strictly from address or technician provided link)
  const customerArea = job.booking.address?.area || '';
  const customerAddressLine = job.booking.address?.addressLine || '';
  const customerCity = job.booking.address?.city || '';
  const customerPincode = job.booking.address?.pincode || '';
  const addrAny = job.booking.address as any;
  const bookingReqAny = job.booking.bookingRequest as any;
  let destCoords: { lat: number; lng: number } | null = null;

  if (addrAny?.latitude && addrAny?.longitude && !isNaN(Number(addrAny.latitude)) && !isNaN(Number(addrAny.longitude))) {
    destCoords = { lat: Number(addrAny.latitude), lng: Number(addrAny.longitude) };
  } else if (bookingReqAny?.latitude && bookingReqAny?.longitude && !isNaN(Number(bookingReqAny.latitude)) && !isNaN(Number(bookingReqAny.longitude))) {
    destCoords = { lat: Number(bookingReqAny.latitude), lng: Number(bookingReqAny.longitude) };
  } else {
    const geoResult = await geocodingService.resolveCoordinates({
      addressLine: customerAddressLine,
      area: customerArea,
      city: customerCity,
      pincode: customerPincode,
      locationLink: addrAny?.locationLink || bookingReqAny?.locationLink
    });
    if (geoResult) {
      destCoords = { lat: geoResult.lat, lng: geoResult.lng };
      if (job.booking.addressId) {
        prisma.customerAddress.update({
          where: { id: job.booking.addressId },
          data: { latitude: destCoords.lat, longitude: destCoords.lng }
        }).catch(() => {});
      }
    }
  }

  const hasExactCustomerLocation = !!destCoords;

  // Technician coordinates
  let techLat = job.technician.currentLatitude;
  let techLng = job.technician.currentLongitude;

  if (!techLat || !techLng || (techLat === 13.0827 && techLng === 80.2707)) {
    if (destCoords) {
      techLat = Number((destCoords.lat + 0.012).toFixed(6));
      techLng = Number((destCoords.lng - 0.009).toFixed(6));
    } else {
      techLat = 11.9416;
      techLng = 79.8083;
    }
  }

  const distanceKm = destCoords ? calculateDistanceKm(techLat, techLng, destCoords.lat, destCoords.lng) : null;
  const etaMinutes = distanceKm !== null ? Math.max(3, Math.round((distanceKm / 24) * 60) + 2) : null;
  const waypoints = destCoords ? generateRouteWaypoints({ lat: techLat, lng: techLng }, destCoords, 10) : [];

  // Compute actual completed jobs for technician from database
  const completedJobsCount = await prisma.serviceJob.count({
    where: { technicianId: job.technician.id, status: 'COMPLETED' }
  });

  return res.json({
    success: true,
    data: {
      jobId: job.id,
      jobNumber: job.jobNumber,
      status: job.status,
      isOtpVerified: job.isOtpVerified,
      hasExactCustomerLocation,
      needsLocationLink: !hasExactCustomerLocation,
      technician: {
        id: job.technician.id,
        name: job.technician.user.name,
        phone: job.technician.user.phone || '+91 98400 44001',
        completedJobs: completedJobsCount,
        currentLatitude: techLat,
        currentLongitude: techLng,
        lastLocationAt: job.technician.lastLocationAt || new Date(),
        isOnline: job.technician.isOnline,
        heading: 65
      },
      customer: {
        name: job.booking.customer.name,
        phone: job.booking.customer.phone,
        addressLine: job.booking.address.addressLine,
        area: job.booking.address.area,
        city: job.booking.address.city,
        pincode: job.booking.address.pincode,
        latitude: destCoords?.lat ?? null,
        longitude: destCoords?.lng ?? null,
        locationLink: addrAny?.locationLink || bookingReqAny?.locationLink || null
      },
      route: {
        distanceKm,
        durationMinutes: etaMinutes,
        statusDescription: !hasExactCustomerLocation
          ? 'Customer exact location pending. Please enter Google Maps location link.'
          : job.status === 'ARRIVED'
          ? 'Technician has arrived at customer doorstep'
          : job.status === 'IN_PROGRESS'
          ? 'Service inspection & maintenance in progress'
          : 'Technician is en-route with service tools',
        trafficCondition: (distanceKm && distanceKm > 4) ? 'MODERATE' : 'SMOOTH',
        waypoints
      },
      service: {
        serviceName: job.booking.serviceType.nameEn,
        acDetails: job.acUnit ? `${job.acUnit.brand} ${job.acUnit.unitType} (${job.acUnit.tonnage}T)` : 'Split AC (1.5T)',
        scheduledDate: job.booking.scheduledDate,
        timeSlot: job.booking.timeSlot
      }
    }
  });
});

// Update customer exact location (via Google Maps link or coordinates from technician)
serviceJobsRouter.post('/:id/customer-location', async (req: Request, res: Response) => {
  const { id } = req.params;
  const { locationLink, latitude, longitude } = req.body;

  let lat: number | null = typeof latitude === 'number' ? latitude : null;
  let lng: number | null = typeof longitude === 'number' ? longitude : null;

  if ((lat === null || lng === null) && locationLink) {
    const resolved = await geocodingService.resolveLocationFromLink(locationLink);
    if (resolved) {
      lat = resolved.lat;
      lng = resolved.lng;
    }
  }

  if (lat === null || lng === null) {
    return res.status(400).json({
      success: false,
      error: {
        code: 'INVALID_LOCATION',
        message: 'Could not extract valid GPS coordinates. Please paste a valid Google Maps link or coordinates (lat, lng).'
      }
    });
  }

  let job = await prisma.serviceJob.findUnique({
    where: { id },
    include: { booking: { include: { address: true, bookingRequest: true } } }
  });

  if (!job) {
    job = await prisma.serviceJob.findFirst({
      where: {
        OR: [
          { bookingId: id },
          { jobNumber: id },
          { booking: { bookingRequestId: id } }
        ]
      },
      include: { booking: { include: { address: true, bookingRequest: true } } }
    });
  }

  if (job) {
    if (job.booking?.addressId) {
      await prisma.customerAddress.update({
        where: { id: job.booking.addressId },
        data: {
          latitude: lat,
          longitude: lng,
          locationLink: locationLink || null
        }
      });
    }
    if (job.booking?.bookingRequestId) {
      await prisma.bookingRequest.update({
        where: { id: job.booking.bookingRequestId },
        data: {
          latitude: lat,
          longitude: lng,
          locationLink: locationLink || null
        }
      }).catch(() => {});
    }

    return res.json({
      success: true,
      message: 'Customer exact location saved successfully from location link.',
      data: {
        latitude: lat,
        longitude: lng,
        locationLink: locationLink || null
      }
    });
  }

  const bReq = await prisma.bookingRequest.findUnique({
    where: { id },
    include: { address: true }
  });

  if (bReq) {
    await prisma.bookingRequest.update({
      where: { id: bReq.id },
      data: {
        latitude: lat,
        longitude: lng,
        locationLink: locationLink || null
      }
    });
    if (bReq.addressId) {
      await prisma.customerAddress.update({
        where: { id: bReq.addressId },
        data: {
          latitude: lat,
          longitude: lng,
          locationLink: locationLink || null
        }
      }).catch(() => {});
    }

    return res.json({
      success: true,
      message: 'Ticket customer exact location saved successfully.',
      data: {
        latitude: lat,
        longitude: lng,
        locationLink: locationLink || null
      }
    });
  }

  return res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: 'Job or ticket not found' }
  });
});

// Update technician location for specific job (live beacon from technician app)
serviceJobsRouter.post('/:id/tracking/location', async (req: Request, res: Response) => {
  const { latitude, longitude } = req.body;
  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    return res.status(400).json({ success: false, error: { code: 'INVALID_COORDINATES', message: 'Valid latitude and longitude required' } });
  }

  const job = await prisma.serviceJob.findUnique({ where: { id: req.params.id } });
  if (!job) {
    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Job not found' } });
  }

  await prisma.technician.update({
    where: { id: job.technicianId },
    data: {
      currentLatitude: latitude,
      currentLongitude: longitude,
      lastLocationAt: new Date(),
      isOnline: true
    }
  });

  await prisma.technicianLocationLog.create({
    data: {
      technicianId: job.technicianId,
      latitude,
      longitude
    }
  });

  return res.json({ success: true, message: 'Location updated' });
});

const statusSchema = z.object({
  status: z.nativeEnum(JobStatus),
  diagnosis: z.string().optional(),
  resolutionNotes: z.string().optional()
});

// Update Job Status (Start, En-route, Arrived, In-progress)
serviceJobsRouter.patch('/:id/status', validateBody(statusSchema), async (req: Request, res: Response) => {
  const user = req.user!;
  const job = await prisma.serviceJob.findUnique({ where: { id: req.params.id } });

  if (!job) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Job not found' } });

  const techId = user.role === Role.ADMIN ? job.technicianId : user.technicianId!;

  try {
    const updated = await serviceJobWorkflowService.updateStatus(
      req.params.id,
      techId,
      req.body.status,
      req.body.diagnosis,
      req.body.resolutionNotes
    );
    return res.json({ success: true, data: updated });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'STATUS_UPDATE_FAILED', message: err.message } });
  }
});

const requestOtpSchema = z.object({
  alternatePhone: z.string().min(10).max(15).optional()
});

// Request Customer Closure OTP (Triggered by Technician/Admin when work is finished)
serviceJobsRouter.post('/:id/request-closure-otp', async (req: Request, res: Response) => {
  const user = req.user!;
  const job = await prisma.serviceJob.findUnique({ where: { id: req.params.id } });

  if (!job) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Job not found' } });

  const techId = user.role === Role.ADMIN ? job.technicianId : user.technicianId!;
  const alternatePhone = req.body.alternatePhone ? String(req.body.alternatePhone).trim() : undefined;

  try {
    const result = await serviceJobWorkflowService.requestClosureOtp(req.params.id, techId, alternatePhone);
    return res.json({
      success: true,
      message: `OTP sent directly to customer mobile (${result.targetPhone}) via SMS`,
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'OTP_REQUEST_FAILED', message: err.message } });
  }
});

const verifyOtpSchema = z.object({
  otp: z.string().min(4).max(8),
  diagnosis: z.string().optional(),
  resolutionNotes: z.string().optional()
});

// Verify Customer Closure OTP to finalize and close ticket
serviceJobsRouter.post('/:id/verify-closure-otp', validateBody(verifyOtpSchema), async (req: Request, res: Response) => {
  const user = req.user!;
  const job = await prisma.serviceJob.findUnique({ where: { id: req.params.id } });

  if (!job) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Job not found' } });

  const techId = user.role === Role.ADMIN ? job.technicianId : user.technicianId!;

  try {
    const closed = await serviceJobWorkflowService.verifyClosureOtpAndClose(
      req.params.id,
      techId,
      req.body.otp,
      req.body.diagnosis,
      req.body.resolutionNotes
    );
    return res.json({
      success: true,
      message: 'Ticket successfully verified and closed with customer OTP!',
      data: closed
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'OTP_VERIFICATION_FAILED', message: err.message } });
  }
});

const reassignJobSchema = z.object({
  newTechnicianId: z.string().min(1, 'New technician is required'),
  reason: z.string().optional()
});

// Reassign job to another technician (Admin & Staff)
serviceJobsRouter.post('/:id/reassign', authorize(Role.ADMIN, Role.BOOKING_STAFF), validateBody(reassignJobSchema), async (req: Request, res: Response) => {
  const adminUserId = req.user!.userId;
  const { newTechnicianId, reason } = req.body;

  try {
    const result = await serviceJobWorkflowService.reassignJob(
      req.params.id,
      newTechnicianId,
      adminUserId,
      reason
    );
    return res.json({
      success: true,
      message: `Job successfully reassigned from ${result.previousTechnicianName} to ${result.newTechnicianName}.`,
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'REASSIGN_FAILED', message: err.message } });
  }
});

const checklistSchema = z.object({
  isChecked: z.boolean(),
  notes: z.string().optional()
});

// Check off checklist task item
serviceJobsRouter.patch('/:id/checklist/:itemId', validateBody(checklistSchema), async (req: Request, res: Response) => {
  const item = await prisma.jobChecklistItem.findUnique({ where: { id: req.params.itemId } });
  if (!item || item.jobId !== req.params.id) {
    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Checklist item not found' } });
  }

  const updated = await prisma.jobChecklistItem.update({
    where: { id: req.params.itemId },
    data: {
      isChecked: req.body.isChecked,
      notes: req.body.notes,
      completedAt: req.body.isChecked ? new Date() : null
    }
  });

  return res.json({ success: true, data: updated });
});

const attachmentSchema = z.object({
  attachmentType: z.enum(['BEFORE_PHOTO', 'AFTER_PHOTO', 'REPORT', 'DIAGNOSIS_SIGNATURE']),
  fileUrl: z.string().url().or(z.string().min(5)),
  caption: z.string().optional()
});

// Upload job photo/report attachment
serviceJobsRouter.post('/:id/attachments', validateBody(attachmentSchema), async (req: Request, res: Response) => {
  const attachment = await prisma.jobAttachment.create({
    data: {
      jobId: req.params.id,
      attachmentType: req.body.attachmentType,
      fileUrl: req.body.fileUrl,
      caption: req.body.caption
    }
  });

  return res.json({ success: true, data: attachment });
});

const consumePartSchema = z.object({
  partId: z.string().uuid(),
  quantity: z.number().int().positive()
});

// Consume spare part for job (deducts inventory, records stock movement)
serviceJobsRouter.post('/:id/consume-part', validateBody(consumePartSchema), async (req: Request, res: Response) => {
  try {
    const result = await serviceJobWorkflowService.consumePart(req.params.id, req.body.partId, req.body.quantity);
    return res.json({
      success: true,
      message: 'Spare part consumed and stock deducted successfully',
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'PART_CONSUMPTION_FAILED', message: err.message } });
  }
});
