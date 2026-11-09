import { Router, Request, Response } from 'express';

export const apiDocsRouter = Router();

apiDocsRouter.get('/', (_req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader("Content-Security-Policy", "default-src 'self' 'unsafe-inline' 'unsafe-eval' https: data:;");

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Caring CoolTech • API Testing Console</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0B0F19;
      --card-bg: #111827;
      --card-border: #1F2937;
      --primary: #1E75BB;
      --primary-hover: #16609C;
      --text-main: #F3F4F6;
      --text-muted: #9CA3AF;
      --emerald: #10B981;
      --rose: #F43F5E;
      --amber: #F59E0B;
      --purple: #8B5CF6;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
    body { background: var(--bg); color: var(--text-main); min-height: 100vh; display: flex; flex-direction: column; }
    header { background: #0F172A; border-bottom: 1px solid var(--card-border); padding: 16px 24px; display: flex; align-items: center; justify-content: space-between; position: sticky; top: 0; z-index: 100; }
    .logo-badge { display: flex; align-items: center; gap: 12px; }
    .logo-badge h1 { font-size: 18px; font-weight: 800; color: #FFF; }
    .logo-badge span { font-size: 11px; background: rgba(30, 117, 187, 0.2); color: #38BDF8; padding: 4px 8px; border-radius: 6px; font-weight: 600; }
    .status-pill { display: flex; align-items: center; gap: 8px; font-size: 12px; color: var(--emerald); font-weight: 600; background: rgba(16, 185, 129, 0.1); padding: 6px 12px; border-radius: 20px; border: 1px solid rgba(16, 185, 129, 0.3); }
    .status-dot { width: 8px; height: 8px; background: var(--emerald); border-radius: 50%; box-shadow: 0 0 10px var(--emerald); }
    
    .main-layout { display: flex; flex: 1; height: calc(100vh - 65px); }
    
    /* Sidebar */
    .sidebar { width: 340px; border-right: 1px solid var(--card-border); background: #0D1322; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 20px; }
    .section-title { font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.8px; margin-bottom: 8px; }
    .quick-login-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
    .quick-btn { background: var(--card-bg); border: 1px solid var(--card-border); color: #FFF; font-size: 12px; font-weight: 600; padding: 8px 10px; border-radius: 8px; cursor: pointer; text-align: left; display: flex; align-items: center; gap: 6px; transition: all 0.2s; }
    .quick-btn:hover { border-color: var(--primary); background: rgba(30, 117, 187, 0.15); }
    
    .auth-status-card { background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 10px; padding: 12px; }
    .auth-status-card.active { border-color: rgba(16, 185, 129, 0.5); background: rgba(16, 185, 129, 0.05); }
    .token-text { font-family: 'JetBrains Mono', monospace; font-size: 10px; color: #6EE7B7; word-break: break-all; max-height: 40px; overflow-y: auto; margin-top: 6px; }

    .nav-group { display: flex; flex-direction: column; gap: 4px; }
    .endpoint-item { display: flex; align-items: center; justify-content: space-between; padding: 8px 10px; border-radius: 8px; font-size: 12px; color: var(--text-muted); cursor: pointer; border: 1px solid transparent; transition: all 0.15s; }
    .endpoint-item:hover, .endpoint-item.active { background: var(--card-bg); color: #FFF; border-color: var(--card-border); }
    .endpoint-item.active { border-color: var(--primary); background: rgba(30, 117, 187, 0.15); }
    .ep-left { display: flex; align-items: center; gap: 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    
    .badge { font-family: 'JetBrains Mono', monospace; font-size: 9px; font-weight: 800; padding: 2px 6px; border-radius: 4px; text-transform: uppercase; }
    .badge-get { background: rgba(16, 185, 129, 0.2); color: var(--emerald); }
    .badge-post { background: rgba(30, 117, 187, 0.2); color: #38BDF8; }
    .badge-put { background: rgba(245, 158, 11, 0.2); color: var(--amber); }
    .badge-delete { background: rgba(244, 63, 94, 0.2); color: var(--rose); }

    /* Workbench Area */
    .workbench { flex: 1; display: flex; flex-direction: column; background: var(--bg); overflow-y: auto; padding: 24px; gap: 20px; }
    .runner-bar { display: flex; gap: 10px; align-items: center; background: var(--card-bg); padding: 12px 16px; border-radius: 12px; border: 1px solid var(--card-border); }
    .method-select { background: #1E293B; color: #FFF; border: 1px solid var(--card-border); padding: 8px 12px; border-radius: 8px; font-weight: 700; font-size: 13px; outline: none; }
    .url-input { flex: 1; background: #0B0F19; border: 1px solid var(--card-border); color: #FFF; padding: 10px 14px; border-radius: 8px; font-family: 'JetBrains Mono', monospace; font-size: 13px; outline: none; }
    .url-input:focus { border-color: var(--primary); }
    .send-btn { background: var(--primary); color: #FFF; font-weight: 700; padding: 10px 20px; border-radius: 8px; border: none; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 8px; }
    .send-btn:hover { background: var(--primary-hover); transform: translateY(-1px); }
    .send-btn:disabled { opacity: 0.5; cursor: not-allowed; }

    .editor-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; flex: 1; min-height: 480px; }
    .pane { background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 12px; display: flex; flex-direction: column; overflow: hidden; }
    .pane-header { background: #1F2937; padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; font-size: 12px; font-weight: 700; }
    .pane-content { flex: 1; position: relative; }
    textarea.code-editor { width: 100%; height: 100%; background: transparent; border: none; padding: 14px; color: #E5E7EB; font-family: 'JetBrains Mono', monospace; font-size: 12.5px; resize: none; outline: none; line-height: 1.5; }
    pre.response-view { width: 100%; height: 100%; overflow: auto; padding: 14px; color: #34D399; font-family: 'JetBrains Mono', monospace; font-size: 12.5px; line-height: 1.5; white-space: pre-wrap; word-break: break-all; }
    
    .status-tag { padding: 3px 8px; border-radius: 4px; font-size: 11px; font-family: 'JetBrains Mono', monospace; font-weight: 700; }
    .status-200 { background: rgba(16, 185, 129, 0.2); color: var(--emerald); }
    .status-400 { background: rgba(244, 63, 94, 0.2); color: var(--rose); }

    .links-footer { display: flex; gap: 12px; margin-top: auto; padding-top: 16px; border-top: 1px solid var(--card-border); }
    .link-btn { font-size: 11px; color: var(--text-muted); text-decoration: none; display: flex; align-items: center; gap: 4px; }
    .link-btn:hover { color: #38BDF8; }
  </style>
</head>
<body>

  <header>
    <div class="logo-badge">
      <h1>Caring CoolTech</h1>
      <span>Interactive API Console</span>
    </div>
    <div style="display: flex; gap: 14px; align-items: center;">
      <div class="status-pill">
        <div class="status-dot"></div>
        <span>Backend API Online: 0.0.0.0:4000</span>
      </div>
      <a href="/health" target="_blank" style="color: #9CA3AF; text-decoration: none; font-size: 12px; font-weight: 600;">System Health ↗</a>
    </div>
  </header>

  <div class="main-layout">
    <!-- Sidebar -->
    <div class="sidebar">
      <div>
        <div class="section-title">⚡ 1-Click Quick Login</div>
        <div class="quick-login-grid">
          <button class="quick-btn" onclick="quickLogin('admin@frostpro.in', 'Demo@1234')">🛡️ Admin</button>
          <button class="quick-btn" onclick="quickLogin('accounts@frostpro.in', 'Demo@1234')">📊 Accounts</button>
          <button class="quick-btn" onclick="quickLogin('staff@frostpro.in', 'Demo@1234')">📞 Staff</button>
          <button class="quick-btn" onclick="quickLogin('tech.karthik@frostpro.in', 'Demo@1234')">🔧 Tech</button>
        </div>
      </div>

      <div class="auth-status-card" id="authCard">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span style="font-size: 11px; font-weight: 700; color: var(--text-muted);">ACTIVE JWT TOKEN</span>
          <button onclick="clearToken()" style="background: transparent; border: none; color: var(--rose); font-size: 10px; cursor: pointer;">Clear</button>
        </div>
        <div class="token-text" id="tokenDisplay">No token active (Click a role above to sign in)</div>
      </div>

      <div>
        <div class="section-title">API Endpoints Catalogue</div>
        <div class="nav-group" id="endpointList">
          <!-- Populated by JS -->
        </div>
      </div>

      <div class="links-footer">
        <a class="link-btn" href="/api/v1/billing/consol-summary" target="_blank">📊 Raw Consol Summary</a>
        <a class="link-btn" href="/health" target="_blank">🩺 Diagnostics</a>
      </div>
    </div>

    <!-- Workbench -->
    <div class="workbench">
      <div class="runner-bar">
        <select class="method-select" id="reqMethod">
          <option value="GET">GET</option>
          <option value="POST">POST</option>
          <option value="PUT">PUT</option>
          <option value="DELETE">DELETE</option>
        </select>
        <input class="url-input" id="reqUrl" value="/api/v1/billing/consol-summary">
        <button class="send-btn" id="sendBtn" onclick="executeRequest()">
          <span id="btnText">Send Request</span>
        </button>
      </div>

      <div class="editor-grid">
        <!-- Request Body -->
        <div class="pane">
          <div class="pane-header">
            <span>JSON Request Payload (Body)</span>
            <span style="color: var(--text-muted); font-size: 11px;">application/json</span>
          </div>
          <div class="pane-content">
            <textarea class="code-editor" id="reqBody" placeholder="// Enter JSON body for POST/PUT requests..."></textarea>
          </div>
        </div>

        <!-- Response Body -->
        <div class="pane">
          <div class="pane-header">
            <span>Response Viewer</span>
            <div style="display: flex; gap: 8px; align-items: center;">
              <span id="resTime" style="color: var(--text-muted); font-size: 11px;"></span>
              <span id="resStatus" class="status-tag" style="display: none;"></span>
            </div>
          </div>
          <div class="pane-content">
            <pre class="response-view" id="resBody">// Click "Send Request" to view live API response...</pre>
          </div>
        </div>
      </div>
    </div>
  </div>

  <script>
    let authToken = localStorage.getItem('cct_jwt_token') || '';

    const ENDPOINTS = [
      // 1. Auth
      { method: 'POST', url: '/api/v1/auth/login', desc: 'Login (Returns JWT)', body: { email: 'admin@frostpro.in', password: 'Demo@1234' } },
      { method: 'GET', url: '/api/v1/auth/me', desc: 'Current Profile / Role' },
      { method: 'POST', url: '/api/v1/auth/forgot-password', desc: 'Forgot Password OTP', body: { email: 'admin@frostpro.in' } },

      // 2. Billing & Custom Invoices
      { method: 'GET', url: '/api/v1/billing/consol-summary', desc: 'Consol Financial Dashboard' },
      { method: 'GET', url: '/api/v1/billing/invoices', desc: 'List Invoices / Bills' },
      { method: 'POST', url: '/api/v1/billing/invoices/custom', desc: 'Create Custom Bill', body: {
          customerName: 'Karthik Raja',
          customerPhone: '9840112233',
          customerAddress: 'No. 22 MG Road, Puducherry',
          items: [
            { description: 'Split AC Chemical Wash & Jet Pump Cleaning', quantity: 1, unitPrice: 1499 },
            { description: 'Capacitor Replacement 45uF', quantity: 1, unitPrice: 350 }
          ],
          discount: 100,
          taxRate: 18.0,
          upfrontSettlementAmount: 500,
          paymentMethod: 'UPI',
          referenceNumber: 'UPI-9840-001',
          notes: 'Customer paid 500 advance via GPay'
        }
      },
      { method: 'POST', url: '/api/v1/billing/invoices/{INVOICE_ID}/settlement', desc: 'Record Bill Settlement', body: {
          amount: 1500,
          paymentMethod: 'CASH',
          referenceNumber: 'CASH-REC-101',
          notes: 'Customer cleared remaining on-hold balance in cash'
        }
      },

      // 3. Expenses
      { method: 'GET', url: '/api/v1/billing/expenses', desc: 'List Business Expenses' },
      { method: 'POST', url: '/api/v1/billing/expenses', desc: 'Log Expense (Fuel/Spares)', body: {
          category: 'FUEL',
          amount: 300,
          description: 'Bike petrol for AC inspection in Lawspet'
        }
      },

      // 4. Inventory
      { method: 'GET', url: '/api/v1/inventory', desc: 'List Warehouse Stock' },
      { method: 'POST', url: '/api/v1/inventory', desc: 'Add Inventory Part', body: {
          sku: 'FAN-MTR-01',
          name: 'Split AC Outdoor Fan Motor 40W',
          category: 'ELECTRICAL',
          unitPrice: 1200,
          sellingPrice: 1850,
          currentStock: 15,
          minStockAlertLevel: 4,
          supplierName: 'Voltas Spares Hub'
        }
      },

      // 5. Booking Requests & Jobs
      { method: 'GET', url: '/api/v1/booking-requests', desc: 'List Booking Requests' },
      { method: 'GET', url: '/api/v1/service-jobs', desc: 'List Service Jobs' },

      // 6. Technicians & Attendance
      { method: 'GET', url: '/api/v1/technicians', desc: 'List All Technicians' },
      { method: 'GET', url: '/api/v1/technicians/live-locations', desc: 'Live Technician GPS Map' },
      { method: 'POST', url: '/api/v1/attendance/clock-in', desc: 'Clock-In (Multiple per day)', body: { latitude: 11.935, longitude: 79.829, notes: 'Clocking in for morning shift' } },
      { method: 'POST', url: '/api/v1/attendance/clock-out', desc: 'Clock-Out', body: { latitude: 11.935, longitude: 79.829, notes: 'Day work completed' } },
      { method: 'GET', url: '/api/v1/attendance/report', desc: 'Consolidated Timesheets' }
    ];

    function updateTokenUI() {
      const display = document.getElementById('tokenDisplay');
      const card = document.getElementById('authCard');
      if (authToken) {
        display.innerText = 'Bearer ' + authToken.substring(0, 36) + '...';
        card.classList.add('active');
      } else {
        display.innerText = 'No token active (Click a role above to sign in)';
        card.classList.remove('active');
      }
    }

    function clearToken() {
      authToken = '';
      localStorage.removeItem('cct_jwt_token');
      updateTokenUI();
    }

    async function quickLogin(email, password) {
      try {
        const res = await fetch('/api/v1/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password })
        });
        const data = await res.json();
        if (data.success && data.data.accessToken) {
          authToken = data.data.accessToken;
          localStorage.setItem('cct_jwt_token', authToken);
          updateTokenUI();
          alert('Logged in as ' + data.data.user.name + ' (' + data.data.user.role + ')! JWT token auto-injected into all requests.');
        } else {
          alert('Login failed: ' + (data.error?.message || 'Check credentials'));
        }
      } catch (e) {
        alert('Login error: ' + e.message);
      }
    }

    function renderEndpoints() {
      const container = document.getElementById('endpointList');
      container.innerHTML = '';
      ENDPOINTS.forEach((ep, idx) => {
        const div = document.createElement('div');
        div.className = 'endpoint-item' + (idx === 0 ? ' active' : '');
        div.innerHTML = \`
          <div class="ep-left">
            <span class="badge badge-\${ep.method.toLowerCase()}">\${ep.method}</span>
            <span title="\${ep.url}">\${ep.desc}</span>
          </div>
        \`;
        div.onclick = () => selectEndpoint(ep, div);
        container.appendChild(div);
      });
    }

    function selectEndpoint(ep, element) {
      document.querySelectorAll('.endpoint-item').forEach(e => e.classList.remove('active'));
      element.classList.add('active');
      document.getElementById('reqMethod').value = ep.method;
      document.getElementById('reqUrl').value = ep.url;
      document.getElementById('reqBody').value = ep.body ? JSON.stringify(ep.body, null, 2) : '';
    }

    async function executeRequest() {
      const method = document.getElementById('reqMethod').value;
      let url = document.getElementById('reqUrl').value.trim();
      const rawBody = document.getElementById('reqBody').value.trim();
      const sendBtn = document.getElementById('sendBtn');
      const btnText = document.getElementById('btnText');
      const resStatus = document.getElementById('resStatus');
      const resTime = document.getElementById('resTime');
      const resBody = document.getElementById('resBody');

      sendBtn.disabled = true;
      btnText.innerText = 'Requesting...';
      resStatus.style.display = 'none';

      const headers = { 'Accept': 'application/json' };
      if (authToken) {
        headers['Authorization'] = 'Bearer ' + authToken;
      }

      let options = { method, headers };
      if (method !== 'GET' && rawBody) {
        headers['Content-Type'] = 'application/json';
        options.body = rawBody;
      }

      const startTime = performance.now();
      try {
        const response = await fetch(url, options);
        const elapsed = Math.round(performance.now() - startTime);

        resTime.innerText = elapsed + ' ms';
        resStatus.style.display = 'inline-block';
        resStatus.innerText = response.status + ' ' + response.statusText;
        resStatus.className = 'status-tag ' + (response.ok ? 'status-200' : 'status-400');

        const contentType = response.headers.get('content-type') || '';
        if (contentType.includes('application/pdf')) {
          resBody.style.color = '#38BDF8';
          resBody.innerText = '🎉 Received Binary PDF Stream (' + (response.headers.get('content-length') || 'N/A') + ' bytes).\\n\\nTo download directly, click: ' + window.location.origin + url + (authToken ? '?token=' + authToken : '');
        } else {
          const json = await response.json();
          resBody.style.color = response.ok ? '#34D399' : '#F87171';
          resBody.innerText = JSON.stringify(json, null, 2);
        }
      } catch (err) {
        const elapsed = Math.round(performance.now() - startTime);
        resTime.innerText = elapsed + ' ms';
        resStatus.style.display = 'inline-block';
        resStatus.innerText = 'NETWORK ERROR';
        resStatus.className = 'status-tag status-400';
        resBody.style.color = '#F87171';
        resBody.innerText = 'Error: ' + err.message + '\\n\\nMake sure backend is running on 0.0.0.0:4000.';
      } finally {
        sendBtn.disabled = false;
        btnText.innerText = 'Send Request';
      }
    }

    // Init
    updateTokenUI();
    renderEndpoints();
    selectEndpoint(ENDPOINTS[0], document.querySelector('.endpoint-item') || {});
  </script>
</body>
</html>`;

  return res.send(html);
});

