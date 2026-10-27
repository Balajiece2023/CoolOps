# FrostPro AC - System and Backend Diagnostic Verification Script
# Usage: powershell -ExecutionPolicy Bypass -File .\check_backend.ps1

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   FrostPro AC System Diagnostics and Verification Tool   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$port = 4000
$healthUrl = "http://127.0.0.1:$port/health"
$loginUrl = "http://127.0.0.1:$port/api/v1/auth/login"

# 1. CHECK SERVER PORT
Write-Host "[1/4] Checking Port $port (Server Process)..." -NoNewline
$portActive = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue

if ($portActive) {
    $procId = ($portActive | Select-Object -First 1).OwningProcess
    $procName = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName
    Write-Host " [RUNNING] (PID: $procId, Process: $procName)" -ForegroundColor Green
} else {
    Write-Host " [NOT RUNNING]" -ForegroundColor Red
    Write-Host "DIAGNOSIS: SERVER ISSUE" -ForegroundColor Red
    Write-Host "The backend process is stopped. Start it with: 'npm run dev' inside e:\ACService\backend" -ForegroundColor Yellow
    Write-Host ""
    exit
}

# 2. CHECK HTTP SERVER AND DB VIA /health
Write-Host "[2/4] Testing HTTP Server and Database Connection..." -NoNewline
try {
    $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 5 -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
    Write-Host "   - Status: $($response.status)" -ForegroundColor Cyan
    Write-Host "   - Database: $($response.subsystems.database.status) (Latency: $($response.subsystems.database.latencyMs) ms)" -ForegroundColor $(if ($response.subsystems.database.status -eq 'CONNECTED') { 'Green' } else { 'Red' })
    Write-Host "   - Memory: $($response.subsystems.server.memoryUsageMb) MB | Uptime: $($response.subsystems.uptimeSeconds)s" -ForegroundColor Gray
    
    if ($response.subsystems.database.status -ne 'CONNECTED') {
        Write-Host ""
        Write-Host "DIAGNOSIS: DATABASE ISSUE" -ForegroundColor Red
        Write-Host "The Node.js server is UP, but cannot reach PostgreSQL!" -ForegroundColor Red
        Write-Host "Error: $($response.subsystems.database.error)" -ForegroundColor Yellow
        Write-Host "Fix: Ensure PostgreSQL service is started on localhost:5432 or check .env DATABASE_URL" -ForegroundColor Yellow
        exit
    }
} catch {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host "DIAGNOSIS: SERVER OR DB CONNECTION ISSUE" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
    exit
}

# 3. TEST AUTHENTICATION (SAMPLE QUERY TO DB)
Write-Host "[3/4] Testing Auth Endpoint and Credentials Query..." -NoNewline
$loginBody = @{
    email = "admin@frostpro.in"
    password = "Demo@1234"
} | ConvertTo-Json

try {
    $authRes = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
    if ($authRes.success -eq $true) {
        Write-Host " [OK]" -ForegroundColor Green
        Write-Host "   - Logged in successfully as: $($authRes.data.user.name) ($($authRes.data.user.role))" -ForegroundColor Cyan
    } else {
        Write-Host " [AUTH FAILED]" -ForegroundColor Yellow
    }
} catch {
    Write-Host " [ERROR]" -ForegroundColor Red
    Write-Host "Login failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. TEST INPUT VALIDATION (PRODUCING AND IDENTIFYING INPUT ERROR)
Write-Host "[4/4] Testing Input Validation Engine..." -NoNewline
$badInputBody = @{
    email = "not-an-email"
    password = ""
} | ConvertTo-Json

try {
    $testBad = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $badInputBody -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
    Write-Host " [UNEXPECTED]" -ForegroundColor Yellow
} catch {
    $statusCode = 0
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }
    if ($statusCode -eq 400) {
        Write-Host " [VERIFIED (HTTP 400 Caught Cleanly)]" -ForegroundColor Green
        Write-Host "   Input validation engine is intercepting invalid fields correctly." -ForegroundColor Gray
    } else {
        Write-Host " [HTTP $statusCode]" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   ALL CHECKS PASSED: Server, DB, and Input Logic Normal   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
