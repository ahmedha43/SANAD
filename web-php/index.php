<?php
/**
 * SANAD Platform - Master Entrypoint
 * منظومة سَنَد السحابية المتقدمة للرعاية والحماية الأسرية
 */

declare(strict_types=1);

require_once __DIR__ . '/config/config.php';
require_once __DIR__ . '/config/session.php';
require_once __DIR__ . '/includes/helpers.php';

// Include Global HTML Head & Top
require_once __DIR__ . '/includes/header.php';

// Include Top Navbar
require_once __DIR__ . '/includes/navbar.php';

// Include Navigation Sidebar
require_once __DIR__ . '/includes/sidebar.php';
?>

<!-- Main Interactive Content Area -->
<main class="main-content" id="mainContent">

    <!-- Global Subscription Status & Quota Banner -->
    <?php require_once __DIR__ . '/views/dashboard/subscription_banner.php'; ?>

    <!-- Global Emergency Alert Banner (AI Risk / SOS) -->
    <?php require_once __DIR__ . '/views/dashboard/emergency_banner.php'; ?>

    <!-- Multi-Child & Device Switcher Bar -->
    <?php require_once __DIR__ . '/views/dashboard/device_switcher.php'; ?>

    <!-- SECTION 1: Overview Dashboard (Default) -->
    <div class="content-section active" id="section-overview">
        <!-- Permanent Auto-Renewing Pairing Hero for Unpaired Children -->
        <?php require_once __DIR__ . '/views/dashboard/unpaired_hero.php'; ?>

        <!-- Quick Stats Cards (Battery, Status, Screen Time, Risks) -->
        <?php require_once __DIR__ . '/views/dashboard/stats_cards.php'; ?>

        <!-- Quick Instant Remote Actions (Screenshot, Lock, Alarm, Sync) -->
        <?php require_once __DIR__ . '/views/dashboard/quick_actions.php'; ?>

        <!-- Split Grid: Live Map Preview & Latest Risk Alerts -->
        <div class="dashboard-split-grid">
            <div class="split-col-main" id="overviewMapCol">
                <?php require_once __DIR__ . '/views/location/live_map.php'; ?>
                <?php require_once __DIR__ . '/views/location/route_history.php'; ?>
            </div>
            <div class="split-col-side" id="overviewAlertsCol">
                <?php require_once __DIR__ . '/views/dashboard/overview_risk_widget.php'; ?>
            </div>
        </div>
    </div>

    <!-- SECTION 2: WebRTC Live Camera & Audio Streaming -->
    <div class="content-section" id="section-live-stream" style="display: none;">
        <?php require_once __DIR__ . '/views/live_stream/camera.php'; ?>
    </div>

    <!-- SECTION 2.5: WebRTC Live Screen Mirroring & Surveillance -->
    <div class="content-section" id="section-live-screen" style="display: none;">
        <?php require_once __DIR__ . '/views/live_stream/screen.php'; ?>
    </div>

    <!-- SECTION 2.6: WebRTC Remote Ambient Audio Listener -->
    <div class="content-section" id="section-ambient-audio" style="display: none;">
        <?php require_once __DIR__ . '/views/live_stream/ambient_audio.php'; ?>
    </div>

    <!-- SECTION 2.7: Instant Walkie-Talkie Push-to-Talk (Loudspeaker Bypass) -->
    <div class="content-section" id="section-walkie-talkie" style="display: none;">
        <?php require_once __DIR__ . '/views/live_stream/walkie_talkie.php'; ?>
    </div>

    <!-- SECTION 3: Live GPS Tracking & Route History Replay -->
    <div class="content-section" id="section-location" style="display: none;">
        <div id="locationSectionHolder"></div>
    </div>

    <!-- SECTION 4: Geofencing Safe Zones Management -->
    <div class="content-section" id="section-geofences" style="display: none;">
        <?php require_once __DIR__ . '/views/location/geofences.php'; ?>
    </div>

    <!-- SECTION 5: Installed Apps & Remote Blocker -->
    <div class="content-section" id="section-apps" style="display: none;">
        <?php require_once __DIR__ . '/views/apps/app_management.php'; ?>
    </div>

    <!-- SECTION 6: Screen Time Limits & Bedtime Schedule -->
    <div class="content-section" id="section-screen-time" style="display: none;">
        <?php require_once __DIR__ . '/views/screen_time/screen_time.php'; ?>
    </div>

    <!-- SECTION 6.5: Web Filter & Safe Browsing -->
    <div class="content-section" id="section-web-filter" style="display: none;">
        <?php require_once __DIR__ . '/views/filter/web_filter.php'; ?>
    </div>

    <!-- SECTION 6.6: Cloud Browser History & Safe Search Explorer -->
    <div class="content-section" id="section-browser-history" style="display: none;">
        <?php require_once __DIR__ . '/views/filter/browser_history.php'; ?>
    </div>

    <!-- SECTION 7: Calls Log -->
    <div class="content-section" id="section-calls" style="display: none;">
        <?php require_once __DIR__ . '/views/data/calls.php'; ?>
    </div>

    <!-- SECTION 8: SMS Messages Explorer -->
    <div class="content-section" id="section-sms" style="display: none;">
        <?php require_once __DIR__ . '/views/data/sms.php'; ?>
    </div>

    <!-- SECTION 9: Contacts Address Book -->
    <div class="content-section" id="section-contacts" style="display: none;">
        <?php require_once __DIR__ . '/views/data/contacts.php'; ?>
    </div>

    <!-- SECTION 10: Intercepted App Notifications -->
    <div class="content-section" id="section-notifications" style="display: none;">
        <?php require_once __DIR__ . '/views/data/notifications.php'; ?>
    </div>

    <!-- SECTION 11: Media Gallery & Photos -->
    <div class="content-section" id="section-gallery" style="display: none;">
        <?php require_once __DIR__ . '/views/gallery/files.php'; ?>
    </div>

    <!-- SECTION 12: Smart AI Risk Alerts & SOS -->
    <div class="content-section" id="section-alerts" style="display: none;">
        <?php require_once __DIR__ . '/views/alerts/risk_alerts.php'; ?>
    </div>

    <!-- SECTION 13: Enterprise Anti-Tamper & Device Owner Hub -->
    <div class="content-section" id="section-device-security" style="display: none;">
        <?php require_once __DIR__ . '/views/settings/device_security.php'; ?>
    </div>

</main>

<!-- Include Global Modals & Scripts -->
<?php require_once __DIR__ . '/includes/footer.php'; ?>
