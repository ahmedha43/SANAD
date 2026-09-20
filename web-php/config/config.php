<?php
/**
 * SANAD Platform - System Configuration
 * إعدادات منظومة سَنَد للرعاية والحماية الأسرية
 */

declare(strict_types=1);

return [
    'app_name' => 'سَنَد | SANAD',
    'app_title' => 'سَنَد | منظومة الأمان والرعاية الأسرية',
    'app_version' => '2.5.0-PRO',
    
    // Server API & WebSocket Configuration
    'api_base_url' => getenv('API_BASE_URL') ?: '/api/v1',
    'ws_base_url' => getenv('WS_BASE_URL') ?: '',
    
    // Default fallback E2EE salt (matches kids-agent and parent-app)
    'default_e2ee_salt' => 'ParentalControlSalt2026',
    
    // Default credentials hint
    'default_admin_email' => 'admin@parentalcontrol.local',
    
    // UI Settings
    'theme' => 'dark-glass',
    'lang' => 'ar',
    'dir' => 'rtl',
];
