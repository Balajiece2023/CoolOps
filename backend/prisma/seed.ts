import { PrismaClient, Role, StockMovementType, RequestStatus } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seed with realistic fake sample data...');

  // 1. Service Types Catalogue
  const services = [
    { code: 'WASH', nameEn: 'Jet Pump Foam Wash & Cleaning', nameTa: 'ஜெட் பம்ப் வாஷ் & சுத்தம் செய்தல்', basePrice: 699, estimatedMinutes: 60 },
    { code: 'DEEP_CLEAN', nameEn: 'Comprehensive Deep Service & Disinfection', nameTa: 'முழுமையான டீப் சர்வீஸ் & கிருமி நீக்கம்', basePrice: 1199, estimatedMinutes: 90 },
    { code: 'GAS_CHARGE', nameEn: 'Refrigerant / Gas Leak Fix & Top-up', nameTa: 'கேஸ் கசிவு சரிசெய்தல் & கேஸ் ஏற்றுதல்', basePrice: 2499, estimatedMinutes: 120 },
    { code: 'INSTALLATION', nameEn: 'New AC Split Installation & Mounting', nameTa: 'புதிய ஸ்பிளிட் ஏசி பொருத்துதல்', basePrice: 1499, estimatedMinutes: 120 },
    { code: 'UNINSTALLATION', nameEn: 'Safe AC Dismantling & Uninstallation', nameTa: 'ஏசி பிரித்தெடுத்தல்', basePrice: 799, estimatedMinutes: 60 },
    { code: 'REPAIR_DIAGNOSIS', nameEn: 'Electrical & PCB Diagnostic Inspection', nameTa: 'மின் மற்றும் பிசிபி ஆய்வு', basePrice: 399, estimatedMinutes: 45 }
  ];

  for (const s of services) {
    await prisma.serviceType.upsert({
      where: { code: s.code },
      update: {},
      create: s
    });
  }

  // 2. Demo Users & Technicians
  const defaultPassword = await bcrypt.hash('Demo@1234', 10);

  // Admin
  const adminUser = await prisma.user.upsert({
    where: { email: 'admin@frostpro.in' },
    update: {},
    create: {
      email: 'admin@frostpro.in',
      passwordHash: defaultPassword,
      name: 'Ramesh Sundaram (Admin)',
      role: Role.ADMIN,
      phone: '+919840011111'
    }
  });

  // Booking Staff
  await prisma.user.upsert({
    where: { email: 'staff@frostpro.in' },
    update: {},
    create: {
      email: 'staff@frostpro.in',
      passwordHash: defaultPassword,
      name: 'Kavitha Murugan (Booking Staff)',
      role: Role.BOOKING_STAFF,
      phone: '+919840022222'
    }
  });

  // Accountant
  await prisma.user.upsert({
    where: { email: 'accounts@frostpro.in' },
    update: {},
    create: {
      email: 'accounts@frostpro.in',
      passwordHash: defaultPassword,
      name: 'Venkatesh Rao (Accountant)',
      role: Role.ACCOUNTANT,
      phone: '+919840033333'
    }
  });

  // Technicians (10 Field Technicians across Chennai Zones)
  const techProfiles = [
    { name: 'Karthik Raja', email: 'tech.karthik@frostpro.in', phone: '+919840044001', areas: ['Adyar', 'Besant Nagar', 'Thiruvanmiyur', 'OMR'], skills: ['SPLIT', 'CASSETTE', 'INVERTER', 'GAS_LEAKAGE'] },
    { name: 'Suresh Kumar', email: 'tech.suresh@frostpro.in', phone: '+919840044002', areas: ['Anna Nagar', 'Kilpauk', 'Shenoy Nagar', 'Mogappair'], skills: ['SPLIT', 'WINDOW', 'ELECTRICAL'] },
    { name: 'Saravanan P', email: 'tech.saravanan@frostpro.in', phone: '+919840044003', areas: ['T. Nagar', 'Nungambakkam', 'Kodambakkam', 'Alwarpet'], skills: ['SPLIT', 'DUCTED', 'VRV_SYSTEMS'] },
    { name: 'Vijay Anand', email: 'tech.vijay@frostpro.in', phone: '+919840044004', areas: ['Velachery', 'Madipakkam', 'Tambaram', 'Chromepet'], skills: ['SPLIT', 'GAS_LEAKAGE', 'INVERTER'] },
    { name: 'Manoj Kumar', email: 'tech.manoj@frostpro.in', phone: '+919840044005', areas: ['Porur', 'Valasaravakkam', 'Ramapuram', 'Guindy'], skills: ['SPLIT', 'WINDOW', 'PCB_REPAIR'] },
    { name: 'Anbu Selvan', email: 'tech.anbu@frostpro.in', phone: '+919840044006', areas: ['Perambur', 'Kolathur', 'Villivakkam'], skills: ['SPLIT', 'JET_WASH'] },
    { name: 'Dinesh Babu', email: 'tech.dinesh@frostpro.in', phone: '+919840044007', areas: ['Sholinganallur', 'Navalur', 'Kelambakkam', 'Siruseri'], skills: ['SPLIT', 'INVERTER', 'GAS_LEAKAGE'] },
    { name: 'Pradeep Raj', email: 'tech.pradeep@frostpro.in', phone: '+919840044008', areas: ['Mylapore', 'Mandaveli', 'RA Puram', 'Royapettah'], skills: ['SPLIT', 'CASSETTE'] },
    { name: 'Gopalakrishnan', email: 'tech.gopal@frostpro.in', phone: '+919840044009', areas: ['Pallavaram', 'Keelkattalai', 'Medavakkam'], skills: ['SPLIT', 'WINDOW'] },
    { name: 'Rajesh V', email: 'tech.rajesh@frostpro.in', phone: '+919840044010', areas: ['Egmore', 'Purasawalkam', 'George Town'], skills: ['SPLIT', 'ELECTRICAL', 'GAS_LEAKAGE'] }
  ];

  const createdTechnicians: any[] = [];
  for (const t of techProfiles) {
    const user = await prisma.user.upsert({
      where: { email: t.email },
      update: {},
      create: {
        email: t.email,
        passwordHash: defaultPassword,
        name: t.name,
        role: Role.TECHNICIAN,
        phone: t.phone
      }
    });

    const tech = await prisma.technician.upsert({
      where: { userId: user.id },
      update: {},
      create: {
        userId: user.id,
        skills: t.skills,
        serviceAreas: t.areas,
        maxDailyJobs: 4,
        isAvailable: true
      }
    });
    createdTechnicians.push({ ...tech, user });
  }

  // 3. Inventory Spare Parts & Stock Movements
  const parts = [
    { sku: 'CAP-45UF', name: '45 µF Running Capacitor (Heavy Duty)', category: 'CAPACITOR', unitPrice: 180, sellingPrice: 450, stock: 35, minAlert: 10, supplier: 'Havells India' },
    { sku: 'CAP-35UF', name: '35 µF Dual Capacitor (Outdoor Fan/Comp)', category: 'CAPACITOR', unitPrice: 150, sellingPrice: 380, stock: 24, minAlert: 8, supplier: 'Havells India' },
    { sku: 'GAS-R32-CYL', name: 'R32 Eco-Friendly Refrigerant Can (1 Kg)', category: 'REFRIGERANT', unitPrice: 850, sellingPrice: 1800, stock: 15, minAlert: 5, supplier: 'Flora Chemicals' },
    { sku: 'GAS-R410A-CYL', name: 'R410A Refrigerant Can (1 Kg)', category: 'REFRIGERANT', unitPrice: 950, sellingPrice: 1950, stock: 12, minAlert: 5, supplier: 'Flora Chemicals' },
    { sku: 'COP-PIPE-0.5', name: 'Half-Inch Pure Copper Pipe (10 Feet Roll)', category: 'COPPER_PIPE', unitPrice: 1200, sellingPrice: 2100, stock: 8, minAlert: 3, supplier: 'Mandovi Metals' },
    { sku: 'UNIV-REMOTE', name: 'Universal Inverter AC Remote Control', category: 'ACCESSORY', unitPrice: 180, sellingPrice: 450, stock: 45, minAlert: 10, supplier: 'Chunghop Electronics' },
    { sku: 'DRAIN-PIPE-5M', name: 'Flexible AC Water Drain Hose (5 Meters)', category: 'ACCESSORY', unitPrice: 90, sellingPrice: 220, stock: 3, minAlert: 5, supplier: 'Plasto Chennai' } // Low stock demonstration!
  ];

  for (const p of parts) {
    const existing = await prisma.inventoryPart.findUnique({ where: { sku: p.sku } });
    if (!existing) {
      const part = await prisma.inventoryPart.create({
        data: {
          sku: p.sku,
          name: p.name,
          category: p.category,
          unitPrice: p.unitPrice,
          sellingPrice: p.sellingPrice,
          currentStock: p.stock,
          minStockAlertLevel: p.minAlert,
          supplierName: p.supplier
        }
      });

      await prisma.stockMovement.create({
        data: {
          partId: part.id,
          type: StockMovementType.INWARD,
          quantity: p.stock,
          balanceAfter: p.stock,
          reference: 'INITIAL_PO_OPENING_STOCK',
          notes: 'Initial warehouse inventory inward batch'
        }
      });
    }
  }

  // 4. Sample Customers & Address
  const customerA = await prisma.customer.upsert({
    where: { phone: '+919884012345' },
    update: {},
    create: {
      phone: '+919884012345',
      name: 'Anand Narayanan',
      email: 'anand.n@example.com',
      language: 'en'
    }
  });

  const addressA = await prisma.customerAddress.create({
    data: {
      customerId: customerA.id,
      addressLine: 'Plot 42, 3rd Seaward Road, Valmiki Nagar',
      area: 'Thiruvanmiyur',
      pincode: '600041',
      city: 'Chennai',
      isDefault: true
    }
  });

  const acUnitA = await prisma.acUnit.create({
    data: {
      customerId: customerA.id,
      addressId: addressA.id,
      brand: 'Daikin',
      unitType: 'SPLIT',
      tonnage: 1.5,
      locationInHouse: 'Master Bedroom',
      installationYear: 2023
    }
  });

  // 5. Booking Request in PENDING_APPROVAL
  const washService = await prisma.serviceType.findUnique({ where: { code: 'WASH' } });
  await prisma.bookingRequest.upsert({
    where: { referenceNumber: 'REQ-20261016-0001' },
    update: {},
    create: {
      referenceNumber: 'REQ-20261016-0001',
      customerId: customerA.id,
      addressId: addressA.id,
      serviceTypeId: washService!.id,
      acUnitId: acUnitA.id,
      complaint: 'Water leakage from indoor unit and needs foam jet wash',
      acBrand: 'Daikin',
      acType: 'SPLIT',
      acTonnage: 1.5,
      preferredDate: new Date('2026-10-17T00:00:00Z'),
      preferredTimeSlot: '09:00-11:00',
      status: RequestStatus.PENDING_APPROVAL
    }
  });

  console.log('✅ Demo seed data inserted successfully!');
  console.log(`Demo Credentials:
    Admin: admin@frostpro.in / Demo@1234
    Booking Staff: staff@frostpro.in / Demo@1234
    Technician: tech.karthik@frostpro.in / Demo@1234
    Accountant: accounts@frostpro.in / Demo@1234
  `);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
