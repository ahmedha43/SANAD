<?php
/**
 * Admin Panel - Global Header Component
 */
declare(strict_types=1);
$config = require __DIR__ . '/../config/config.php';
?>
<!DOCTYPE html>
<html lang="<?= htmlspecialchars($config['lang']) ?>" dir="<?= htmlspecialchars($config['dir']) ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($config['app_title']) ?> | <?= htmlspecialchars($config['app_name']) ?></title>
    
    <!-- Tailwind CSS CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- Font Awesome 6.5 -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">
    
    <!-- Google Fonts: Tajawal & Inter -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    colors: {
                        brand: {
                            50: '#eff6ff',
                            500: '#3b82f6',
                            600: '#2563eb',
                            700: '#1d4ed8',
                        },
                        dark: {
                            bg: '#0b0f19',
                            card: '#111827',
                            border: '#1f2937'
                        }
                    }
                }
            }
        }
    </script>
    
    <!-- Custom Admin Stylesheet -->
    <link rel="stylesheet" href="assets/css/admin.css?v=<?= time() ?>">
    
    <!-- Dynamic Config for JavaScript -->
    <script>
        window.ADMIN_CONFIG = {
            apiBase: <?= json_encode($config['api_base_url']) ?>,
            wsBase: <?= json_encode($config['ws_base_url']) ?>,
            refreshInterval: <?= (int)$config['refresh_interval_sec'] ?> * 1000
        };
    </script>
</head>
<body class="bg-[#0b0f19] text-gray-100 min-h-screen flex">
