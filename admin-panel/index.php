<?php
/**
 * Master Admin Panel - Entrypoint & Router
 * لوحة الإدارة الرئيسية لمنظومة الرقابة الأبوية الذكية
 */

declare(strict_types=1);

require_once __DIR__ . '/config/config.php';

// Include Header (HTML head, fonts, styles)
require_once __DIR__ . '/includes/header.php';

// Include Sidebar Navigation
require_once __DIR__ . '/includes/sidebar.php';
?>

<!-- Main Content Area -->
<main class="flex-1 flex flex-col min-w-0 overflow-auto">
    <!-- Top Header Bar -->
    <?php require_once __DIR__ . '/includes/navbar.php'; ?>

    <!-- Dynamic Tab Content Views -->
    <div class="p-8 space-y-8 flex-1">
        
        <!-- 1. Dashboard Overview Tab (Default Active) -->
        <section id="tab-dashboard" class="space-y-8">
            <!-- Stats Overview Cards -->
            <?php require_once __DIR__ . '/views/dashboard/stats_cards.php'; ?>

            <!-- Recent Active Devices Table -->
            <?php require_once __DIR__ . '/views/dashboard/recent_devices.php'; ?>
        </section>

        <!-- 2. Parents & Families Tab -->
        <?php require_once __DIR__ . '/views/users/users_list.php'; ?>

        <!-- 3. Connected Kids Devices Tab -->
        <?php require_once __DIR__ . '/views/devices/devices_list.php'; ?>

        <!-- 4. Subscriptions & Licenses Tab -->
        <?php require_once __DIR__ . '/views/subscriptions/subscriptions_list.php'; ?>

        <!-- 5. Subscription Plans & Pricing Tab -->
        <?php require_once __DIR__ . '/views/plans/plans_list.php'; ?>

        <!-- 6. Live Streaming & Security Logs Tab -->
        <?php require_once __DIR__ . '/views/logs/live_logs.php'; ?>

        <!-- 7. Infrastructure & Docker Fleet Tab -->
        <?php require_once __DIR__ . '/views/infrastructure/servers_status.php'; ?>

    </div>
</main>

<!-- Modals -->
<?php require_once __DIR__ . '/views/plans/plan_modal.php'; ?>
<?php require_once __DIR__ . '/views/subscriptions/edit_sub_modal.php'; ?>

<!-- Include Footer & JavaScript -->
<?php require_once __DIR__ . '/includes/footer.php'; ?>
