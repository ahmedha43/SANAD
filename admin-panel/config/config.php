<?php
/**
 * Master Admin Panel - System Configuration
 * إعدادات لوحة الإدارة الرئيسية
 */

declare(strict_types=1);

return [
    'app_name' => 'KidsControl Master Admin',
    'app_title' => 'لوحة إدارة منصة الرقابة الأبوية',
    'version' => '2.5.0-ENTERPRISE',
    
    // REST API Endpoint for Go Fiber Backend
    // When accessed via browser: defaults to /api/v1 (via Nginx) or localhost:8080/api/v1
    'api_base_url' => getenv('API_BASE_URL') ?: '/api/v1',
    'ws_base_url' => getenv('WS_BASE_URL') ?: '/ws',
    
    // Super Admin Identity
    'admin_name' => 'Super Admin',
    'admin_email' => 'admin@parentalcontrol.local',
    
    // Auto-refresh interval in seconds
    'refresh_interval_sec' => 10,
    
    // UI Settings
    'lang' => 'ar',
    'dir' => 'rtl',
];
