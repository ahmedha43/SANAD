<?php
/**
 * Global Header Component
 */
declare(strict_types=1);
$config = require __DIR__ . '/../config/config.php';
?>
<!DOCTYPE html>
<html lang="<?= e($config['lang']) ?>" dir="<?= e($config['dir']) ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= e($config['app_name']) ?> | لوحة التحكم السحابية المتقدمة</title>
    
    <!-- Google Fonts: Cairo & Inter -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800;900&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    
    <!-- Font Awesome 6.5 -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    
    <!-- Leaflet CSS -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    
    <!-- Custom Style -->
    <link rel="stylesheet" href="assets/css/style.css?v=<?= time() ?>">
    <!-- Fullscreen Auth Screen Style -->
    <link rel="stylesheet" href="assets/css/auth.css?v=<?= time() ?>">
    
    <!-- Dynamic Config Object for Client-Side JS -->
    <script>
        window.APP_CONFIG = {
            appName: <?= json_encode($config['app_name']) ?>,
            version: <?= json_encode($config['app_version']) ?>,
            apiBase: <?= json_encode($config['api_base_url']) ?>,
            wsBase: <?= json_encode($config['ws_base_url']) ?>,
            defaultSalt: <?= json_encode($config['default_e2ee_salt']) ?>,
            defaultEmail: <?= json_encode($config['default_admin_email']) ?>
        };
    </script>
</head>
<body>

<!-- Standalone Full-Screen Authentication Screen -->
<?php require_once __DIR__ . '/../views/auth/auth_view.php'; ?>

<!-- Master Dashboard Application Layout (Shown only after successful authentication) -->
<div class="app-layout" id="dashboardAppLayout" style="display: none;">
