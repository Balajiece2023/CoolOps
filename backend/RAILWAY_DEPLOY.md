# AC Service Management System - Railway Deployment Guide

## 1. Quick Deploy Steps on Railway

1. **Create a New Project on Railway**:
   - Go to [Railway Dashboard](https://railway.com) -> **New Project**.
   - Select **Provision PostgreSQL** (this adds a managed PostgreSQL instance).
   - Once created, Railway automatically generates a `DATABASE_URL` variable.

2. **Add the Backend Service**:
   - In the same Railway project, click **+ New** -> **GitHub Repo** (or deploy via Railway CLI).
   - Point the root directory to `/backend` (if repo root is not `backend`).
   - Railway will auto-detect [`railway.toml`](file:///e:/ACService/backend/railway.toml) and build using `npm run build`.

3. **Configure Environment Variables**:
   In your Railway backend service settings (**Variables** tab), configure:

   | Variable Name | Description / Recommended Value |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (Reference your Railway Postgres service) |
   | `NODE_ENV` | `production` |
   | `PORT` | `4000` (or leave default, Railway assigns dynamically and passes via `$PORT`) |
   | `API_PREFIX` | `/api/v1` |
   | `CORS_ORIGIN` | `*` (or your frontend app domain) |
   | `JWT_ACCESS_SECRET` | Generate a strong 64-char random string |
   | `JWT_REFRESH_SECRET` | Generate a strong 64-char random string |
   | `JWT_ACCESS_EXPIRY` | `15m` |
   | `JWT_REFRESH_EXPIRY` | `7d` |
   | `BUSINESS_NAME` | `Caring Cool Tech` |
   | `BUSINESS_TIMEZONE` | `Asia/Kolkata` |
   | `BUSINESS_WORK_START_HOUR` | `8` |
   | `BUSINESS_WORK_END_HOUR` | `20` |
   | `SMTP_HOST` | `smtp.gmail.com` |
   | `SMTP_PORT` | `587` |
   | `SMTP_SECURE` | `false` |
   | `SMTP_USER` | `perfecttracker01@gmail.com` |
   | `SMTP_PASS` | `wujpdiaphonxlsch` |
   | `SMTP_FROM` | `Caring Cool Tech <support@caringcooltech.com>` |
   | `OPENSMS_API_URL` | `https://opensms.wansaw.com/v1/sms/send` |
   | `OPENSMS_API_KEY` | `osk_FEwEv_6iV8Q56CxtmtbJ-5DI-Nf7zYpoc9P_FkaWnGk` |
   | `SMS_GATEWAY_URL` | `https://opensms.wansaw.com/v1/sms/send` |
   | `SMS_GATEWAY_API_KEY` | `osk_FEwEv_6iV8Q56CxtmtbJ-5DI-Nf7zYpoc9P_FkaWnGk` |
   | `SMS_SENDER_ID` | `COOLTC` |

4. **Database Migration & Seeding**:
   - `railway.toml` is configured to run `npx prisma migrate deploy` automatically before starting the server.
   - To seed initial data (services, admin accounts):
     Open the Railway CLI or Service Console and execute:
     ```bash
     npm run prisma:seed
     ```

5. **Generate Public Domain**:
   - Go to Backend Service -> **Settings** -> **Networking** -> **Generate Domain**.
   - You'll get your public live URL, e.g. `https://acservice-backend-production.up.railway.app`.
   - Update your Flutter mobile app `apiBaseUrl` with this Railway URL!

