# End-to-End Automated Integration Test for Parental Control Platform
$ErrorActionPreference = "Stop"

$baseUrl = "http://localhost:8080/api/v1"
Write-Host "=== 1. Testing Parent Registration ===" -ForegroundColor Cyan
$regBody = @{
    email = "parent_test_$(Get-Random)@family.local"
    password = "SuperPassword2026!"
    full_name = "Ahmad Al-Mansour"
    phone_number = "+966500000000"
    family_name = "Al-Mansour Family"
} | ConvertTo-Json

$regResp = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -Body $regBody -ContentType "application/json"
$token = $regResp.tokens.access_token
$familyId = $regResp.family.id
Write-Host "Registered successfully! Family ID: $familyId" -ForegroundColor Green

Write-Host "`n=== 2. Testing Parent Login ===" -ForegroundColor Cyan
$loginBody = @{
    email = ($regBody | ConvertFrom-Json).email
    password = "SuperPassword2026!"
} | ConvertTo-Json
$loginResp = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$authHeader = @{ Authorization = "Bearer $($loginResp.tokens.access_token)" }
Write-Host "Login verified. Token acquired." -ForegroundColor Green

Write-Host "`n=== 3. Creating Child Profile ===" -ForegroundColor Cyan
$childBody = @{
    name = "Rayan"
    avatar_url = "https://ui-avatars.com/api/?name=Rayan"
} | ConvertTo-Json
$childResp = Invoke-RestMethod -Uri "$baseUrl/devices/children" -Method Post -Headers $authHeader -Body $childBody -ContentType "application/json"
$childId = $childResp.id
Write-Host "Child profile created: Rayan (ID: $childId)" -ForegroundColor Green

Write-Host "`n=== 4. Generating 6-Digit Pairing Code ===" -ForegroundColor Cyan
$codeResp = Invoke-RestMethod -Uri "$baseUrl/devices/children/$childId/pair-code" -Method Post -Headers $authHeader -Body "{}" -ContentType "application/json"
$pairingCode = $codeResp.code
Write-Host "Generated Pairing Code: $pairingCode (Valid for 15 min)" -ForegroundColor Yellow

Write-Host "`n=== 5. Simulating Kids Agent Device Pairing ===" -ForegroundColor Cyan
$pairKidBody = @{
    code = $pairingCode
    device_uid = "android_hw_uid_$(Get-Random)"
    device_name = "Samsung Galaxy A54 (Rayan)"
    model = "SM-A546B"
    os_version = "14.0"
    app_version = "1.0.0"
} | ConvertTo-Json
$kidResp = Invoke-RestMethod -Uri "$baseUrl/devices/pair" -Method Post -Body $pairKidBody -ContentType "application/json"
$deviceId = $kidResp.device_id
$deviceSecret = $kidResp.pairing_secret
Write-Host "Kids Agent paired! Device ID: $deviceId" -ForegroundColor Green

Write-Host "`n=== 6. Fetching Devices on Parent Dashboard ===" -ForegroundColor Cyan
$devices = Invoke-RestMethod -Uri "$baseUrl/devices" -Method Get -Headers $authHeader
Write-Host "Total devices in family: $($devices.Count)" -ForegroundColor Green
Write-Host "Device: $($devices[0].device_name) | Status: $($devices[0].status)" -ForegroundColor Green

Write-Host "`n=== 7. Simulating GPS Location Telemetry from Kid ===" -ForegroundColor Cyan
$locPayload = @{
    latitude = 24.7136
    longitude = 46.6753
    accuracy = 5.0
    altitude = 612.0
    speed = 0.0
    bearing = 90.0
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
} | ConvertTo-Json
$locResp = Invoke-RestMethod -Uri "$baseUrl/devices/$deviceId/location" -Method Post -Body $locPayload -ContentType "application/json"
Write-Host "Location updated: Lat: $($locResp.location.latitude), Lon: $($locResp.location.longitude)" -ForegroundColor Green

Write-Host "`n=== 8. Creating Geofence (Safe Zone) ===" -ForegroundColor Cyan
$geoBody = @{
    child_id = $childId
    name = "Home Safe Zone"
    latitude = 24.7136
    longitude = 46.6753
    radius_meters = 250
    alert_on_entry = $true
    alert_on_exit = $true
} | ConvertTo-Json
$geoResp = Invoke-RestMethod -Uri "$baseUrl/geofences" -Method Post -Headers $authHeader -Body $geoBody -ContentType "application/json"
Write-Host "Geofence created: $($geoResp.name) (Radius: $($geoResp.radius_meters)m)" -ForegroundColor Green

Write-Host "`n=== 9. Sending Remote Command (LOCK_DEVICE) ===" -ForegroundColor Cyan
$cmdBody = @{
    action = "LOCK_DEVICE"
    params = @{ message = "Hand phone to parent" }
} | ConvertTo-Json
$cmdResp = Invoke-RestMethod -Uri "$baseUrl/devices/$deviceId/command" -Method Post -Headers $authHeader -Body $cmdBody -ContentType "application/json"
Write-Host "Command sent: $($cmdResp.command_type) | Status: $($cmdResp.status)" -ForegroundColor Green

Write-Host "`n=== 10. Fetching WebRTC ICE Configuration (Coturn) ===" -ForegroundColor Cyan
$rtcResp = Invoke-RestMethod -Uri "$baseUrl/webrtc/config" -Method Get
Write-Host "STUN URL: $($rtcResp.ice_servers[0].urls[0])" -ForegroundColor Green
Write-Host "TURN URL: $($rtcResp.ice_servers[1].urls[0]) | Username: $($rtcResp.ice_servers[1].username)" -ForegroundColor Green

Write-Host "`n=======================================================" -ForegroundColor Magenta
Write-Host "ALL 10 END-TO-END INTEGRATION TESTS PASSED SUCCESSFULLY!" -ForegroundColor Magenta
Write-Host "=======================================================" -ForegroundColor Magenta
