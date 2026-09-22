<?php
/**
 * Global Footer Component
 */
declare(strict_types=1);
?>
</div> <!-- End of #dashboardAppLayout -->

<!-- Modals Inclusion -->
<?php
require_once __DIR__ . '/../views/devices/add_child_modal.php';
require_once __DIR__ . '/../views/gallery/media_modal.php';
require_once __DIR__ . '/../views/live_stream/screenshot_modal.php';
require_once __DIR__ . '/../views/settings/e2ee_modal.php';
require_once __DIR__ . '/../views/settings/device_owner_modal.php';
require_once __DIR__ . '/../views/devices/delete_device_modal.php';
?>

<!-- Toast Notifications Container -->
<div id="toastContainer" class="toast-container"></div>

<!-- Libraries -->
<!-- Leaflet JS -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<!-- QRCode Generator -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<!-- Chart.js for screen time analytics -->
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>

<!-- WebUSB / WebADB Provisioner for One-Click Android Setup -->
<script src="assets/js/webadb.js?v=<?= time() ?>"></script>
<script src="assets/js/webusb_provisioner.js?v=<?= time() ?>"></script>

<!-- Modular Application Scripts -->
<script src="assets/js/crypto.js?v=<?= time() ?>"></script>
<script src="assets/js/api.js?v=<?= time() ?>"></script>
<script src="assets/js/ws.js?v=<?= time() ?>"></script>
<script src="assets/js/map.js?v=<?= time() ?>"></script>
<script src="assets/js/geofence_map.js?v=<?= time() ?>"></script>
<script src="assets/js/webrtc.js?v=<?= time() ?>"></script>
<script src="assets/js/ui.js?v=<?= time() ?>"></script>
<script src="assets/js/app.js?v=<?= time() ?>"></script>

</body>
</html>
