# FrostPro AC Service Management System

A production-oriented Field Service Management & WhatsApp Automation System designed for AC service companies operating with 10–50 field technicians.

---

## 🏗️ Architecture & Technology Stack

- **Mobile Internal Staff App:** Flutter 3.47 + Dart, Material 3, Riverpod (State Management), Dio (HTTP/REST Interceptors), Google Fonts, Shared Preferences.
- **Backend API Server:** Node.js 24 + Express + TypeScript, Prisma ORM, Helmet, CORS, Rate Limiting, Winston/Morgan, PDFKit.
- **Database:** PostgreSQL (with normalized tables, foreign keys, unique indexes, enums, UTC timestamps, and migrations).
- **Messaging & Automation:** Meta WhatsApp Business Platform Cloud API with bilingual state machine (English + Tamil), webhook signature verification, deduplication, and transactional outbox.

---

## 📁 Repository Structure

```text
/
├── backend/                  # Node.js + Express + TypeScript REST API
│   ├── prisma/               # Prisma schema and migrations
│   │   ├── schema.prisma     # Normalized PostgreSQL schema
│   │   ├── migrations/       # SQL migrations
│   │   └── seed.ts           # Demo seed data (10 technicians, inventory, services)
│   ├── src/
│   │   ├── routes/           # REST endpoints (auth, bookings, jobs, billing, inventory, dashboard, webhooks)
│   │   ├── services/         # State machines, booking approval, job workflow, PDF invoice, WhatsApp client
│   │   ├── middleware/       # JWT auth, RBAC guards, Zod validation, HMAC signature check
│   │   ├── app.ts            # Express setup and outbox background worker
│   │   └── config.ts         # Centralized configuration
│   └── tests/                # Automated Jest API and Unit tests
│
├── mobile/                   # Flutter Staff Application
│   ├── lib/
│   │   ├── core/             # Theme tokens, ApiClient, storage constants
│   │   ├── data/             # Typed models & API repository
│   │   ├── presentation/     # Screens (Login, Dashboard, Requests, Technician Jobs, Inventory, Invoices)
│   │   └── main.dart         # Flutter entrypoint
│   └── test/                 # Widget tests
│
├── docs/
│   └── WHATSAPP_SETUP.md     # Official Meta WhatsApp Cloud API credentials & setup guide
└── docker-compose.yml        # Docker compose for PostgreSQL & Backend
```

---

## 🚀 Quick Start Guide

### 1. Backend Setup
1. Open PowerShell and navigate to the backend:
   ```bash
   cd backend
   ```
2. Copy environment file:
   ```bash
   cp .env.example .env
   ```
3. Generate Prisma client:
   ```bash
   npx prisma generate
   ```
4. Start a local PostgreSQL instance or run via Docker:
   ```bash
   docker-compose up -d postgres
   ```
5. Apply database migrations:
   ```bash
   npx prisma migrate dev
   ```
6. Seed sample data (10 field technicians, service catalog, spare parts, opening stock):
   ```bash
   npm run prisma:seed
   ```
7. Run tests:
   ```bash
   npm test
   ```
8. Start development server:
   ```bash
   npm run dev
   ```
   Local dev server runs on `http://localhost:4000/api/v1`.
   Production Railway backend runs on `https://coolops-production.up.railway.app/api/v1` (Health: `/health`, API Console: `/docs`).

---

## 🔑 Demo / Seeded Login Credentials

> **Note:** Quick demo login buttons and pre-filled credentials have been removed from the mobile app login screen for production security. Use the credentials below after running `npm run prisma:seed` (locally) or `npx --yes tsx prisma/seed.ts` (inside the Railway backend container), and update passwords via **User Management** or **Forgot Password**.

### Primary Staff Accounts

| Role | Name | Email | Password | Permissions & Access Scope |
| :--- | :--- | :--- | :--- | :--- |
| **Admin** | Ramesh Sundaram | `admin@frostpro.in` | `Demo@1234` | Full access: All modules, approval, scheduling, technician assignments, billing, inventory, user management |
| **Booking Staff** | Kavitha Murugan | `staff@frostpro.in` | `Demo@1234` | Manage customers, view booking calendar, inspect pending requests, dispatch & approve requests |
| **Accountant** | Venkatesh Rao | `accounts@frostpro.in` | `Demo@1234` | Consolidated billing, invoices, settlements, expenses, inventory valuation, PDF invoice downloads |

### Seeded Field Technician Accounts (Password: `Demo@1234`)

| Name | Email | Phone | Assigned Areas |
| :--- | :--- | :--- | :--- |
| Karthik Raja | `tech.karthik@frostpro.in` | `+919840044001` | Adyar, Besant Nagar, Thiruvanmiyur, OMR |
| Suresh Kumar | `tech.suresh@frostpro.in` | `+919840044002` | Anna Nagar, Kilpauk, Shenoy Nagar, Mogappair |
| Saravanan P | `tech.saravanan@frostpro.in` | `+919840044003` | T. Nagar, Nungambakkam, Kodambakkam, Alwarpet |
| Vijay Anand | `tech.vijay@frostpro.in` | `+919840044004` | Velachery, Madipakkam, Tambaram, Chromepet |
| Manoj Kumar | `tech.manoj@frostpro.in` | `+919840044005` | Porur, Valasaravakkam, Ramapuram, Guindy |
| Anbu Selvan | `tech.anbu@frostpro.in` | `+919840044006` | Perambur, Kolathur, Villivakkam |
| Dinesh Babu | `tech.dinesh@frostpro.in` | `+919840044007` | Sholinganallur, Navalur, Kelambakkam, Siruseri |
| Pradeep Raj | `tech.pradeep@frostpro.in` | `+919840044008` | Mylapore, Mandaveli, RA Puram, Royapettah |
| Gopalakrishnan | `tech.gopal@frostpro.in` | `+919840044009` | Pallavaram, Keelkattalai, Medavakkam |
| Rajesh V | `tech.rajesh@frostpro.in` | `+919840044010` | Egmore, Purasawalkam, George Town |

---

## 📱 Mobile App (Flutter)

The mobile app is pre-configured to connect to the live Railway backend at `https://coolops-production.up.railway.app/api/v1`.

1. Open PowerShell and navigate to the mobile folder:
   ```bash
   cd mobile
   ```
2. Run automated tests:
   ```bash
   flutter test
   ```
3. Build release Android APK:
   ```bash
   flutter build apk --release
   ```
4. Or run on Chrome (Web) / connected Android device:
   ```bash
   flutter run -d chrome
   ```
   or
   ```bash
   flutter run
   ```

---

## 🤖 Bilingual WhatsApp Chatbot Flow

Customers message the WhatsApp number. The guided chatbot supports **English** and **தமிழ் (Tamil)**:
1. **Language Choice:** 1 for English, 2 for தமிழ்
2. **Service Catalogue:** Lists available services with prices
3. **Complaint Input:** Captures customer's description of problem
4. **Name & Service Address:** Captures address, area, and pincode
5. **AC Details:** Captures brand, split/window type, and tonnage
6. **Date & Time Slot Selection:** Selects preferred upcoming slot
7. **Summary & Explicit Confirmation:** Shows full review. Requires explicit YES / 1 before submission.
8. **Pending Approval Notice:** Created with status `PENDING_APPROVAL` with unique reference (e.g. `REQ-20261016-0001`). Customers are informed that appointments are **NOT** confirmed until operations staff approve.

### Testing WhatsApp Without Meta Credentials:
Use the built-in simulator endpoint:
```http
POST http://localhost:4000/webhooks/whatsapp/simulate
Content-Type: application/json

{
  "phone": "+919840012345",
  "message": "1"
}
```

Refer to [docs/WHATSAPP_SETUP.md](file:///e:/ACService/docs/WHATSAPP_SETUP.md) for full Meta Cloud API production setup.
