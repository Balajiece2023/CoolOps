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
   Server will run on `http://localhost:4000/api/v1`

---

## 🔑 Demo Login Credentials

| Role | Email | Password | Permissions & Access Scope |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin@frostpro.in` | `Demo@1234` | Full access: All modules, approval, scheduling, technician assignments, billing, inventory |
| **Technician** | `tech.karthik@frostpro.in` | `Demo@1234` | Assigned jobs only, service checklists, status updates (En-Route, Arrived, In-Progress, Completed), spare parts consumed |
| **Booking Staff** | `staff@frostpro.in` | `Demo@1234` | Manage customers, view booking calendar, inspect pending requests |
| **Accountant** | `accounts@frostpro.in` | `Demo@1234` | Invoices, payment records, inventory valuation, PDF invoice downloads |

---

## 📱 Mobile App (Flutter)

1. Open PowerShell and navigate to the mobile folder:
   ```bash
   cd mobile
   ```
2. Run automated tests:
   ```bash
   flutter test
   ```
3. Run on Chrome (Web) or connected Android device:
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
