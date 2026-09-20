<?php
/**
 * WebRTC Live Camera & Audio Streamer Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="liveStreamSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-video" style="color: var(--accent-rose)"></i>
            <div>
                <h3>البث المباشر الحي للكاميرا والصوت (WebRTC Live Stream)</h3>
                <span class="sub-text">مشاهدة حية ومباشرة بكاميرا هاتف الطفل مع إمكانية التبديل بين الكاميرا الأمامية والخلفية</span>
            </div>
        </div>
        <div class="header-actions">
            <span class="stream-badge-status" id="streamBadge">جاهز للبث</span>
        </div>
    </div>

    <div class="webrtc-stream-container">
        <!-- Video Screen Player -->
        <div class="video-player-wrapper">
            <video id="remoteVideo" autoplay playsinline class="webrtc-video"></video>
            
            <!-- Placeholder when stream is not active -->
            <div class="video-placeholder" id="videoPlaceholder">
                <i class="fa-solid fa-video-slash placeholder-icon"></i>
                <div class="placeholder-title">البث المباشر متوقف حالياً</div>
                <div class="placeholder-desc">اضغط على زر "بدء البث المباشر" للاتصال الفوري بكاميرا هاتف الطفل عبر تقنية WebRTC المشفرة.</div>
                <button class="btn btn-primary" onclick="startLiveCameraStream()">
                    <i class="fa-solid fa-play"></i>
                    <span>بدء البث المباشر الآن</span>
                </button>
            </div>

            <!-- Live Streaming Controls Overlay -->
            <div class="stream-controls-overlay" id="streamControlsOverlay" style="display: none;">
                <div class="stream-info-pill">
                    <span class="pulse-red-dot"></span>
                    <span>LIVE WebRTC</span>
                </div>

                <div class="stream-buttons-group">
                    <button class="stream-control-btn" onclick="switchCameraFacing()" title="تبديل الكاميرا (أمامية / خلفية)">
                        <i class="fa-solid fa-camera-rotate"></i>
                        <span>تبديل الكاميرا</span>
                    </button>

                    <button class="stream-control-btn btn-danger-pill" onclick="stopLiveCameraStream()" title="إيقاف البث">
                        <i class="fa-solid fa-stop"></i>
                        <span>إنهاء البث</span>
                    </button>
                </div>
            </div>
        </div>
    </div>
</section>
