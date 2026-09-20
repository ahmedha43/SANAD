<?php
/**
 * WebRTC Live Screen Mirroring & Continuous Snapshots Component
 * بث وعرض شاشة الطفل الحي والتحديث الدوري المباشر
 */
declare(strict_types=1);
?>
<section class="panel-card" id="liveScreenSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-desktop" style="color: #6366f1"></i>
            <div>
                <h3>عرض وبث شاشة الطفل المباشر (Live Screen)</h3>
                <span class="sub-text">مشاهدة حية ومباشرة لكل ما يفعله الطفل على جهازه لحظة بلحظة مع الصوت أو عبر لقطات دورية مستمرة</span>
            </div>
        </div>
        <div class="header-actions" style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">
            <!-- Mode Switch Tabs -->
            <div class="screen-mode-tabs" style="display: flex; gap: 6px; background: rgba(15, 23, 42, 0.6); padding: 4px; border-radius: 10px; border: 1px solid var(--border-color);">
                <button type="button" class="screen-tab-btn active" id="tabScreenWebRTC" onclick="switchScreenSubMode('webrtc')" style="padding: 6px 14px; border-radius: 7px; border: none; font-size: 0.82rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; background: #6366f1; color: #fff;">
                    <i class="fa-solid fa-bolt"></i>
                    <span>بث فائق السرعة (WebRTC 30fps)</span>
                </button>
                <button type="button" class="screen-tab-btn" id="tabScreenSilent" onclick="switchScreenSubMode('silent')" style="padding: 6px 14px; border-radius: 7px; border: none; font-size: 0.82rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; background: transparent; color: var(--text-muted);">
                    <i class="fa-solid fa-camera"></i>
                    <span>تحديث دوري باللقطات (Snapshots)</span>
                </button>
            </div>
            <span class="stream-badge-status" id="screenStreamBadge">جاهز للبث</span>
        </div>
    </div>

    <!-- Container for Both Modes -->
    <div class="webrtc-stream-container" style="padding: 20px 10px;">

        <!-- MODE 1: WebRTC Live Stream Mode -->
        <div id="screenWebRTCContainer" class="screen-mode-view">
            <div class="phone-mirror-frame" id="phoneMirrorFrame" style="position: relative; width: 100%; max-width: 380px; height: 640px; margin: 0 auto; background: #000; border-radius: 36px; border: 4px solid #334155; overflow: hidden; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7); display: flex; align-items: center; justify-content: center;">
                
                <!-- Phone Top Speaker/Camera Notch Mockup -->
                <div style="position: absolute; top: 10px; left: 50%; transform: translateX(-50%); width: 90px; height: 18px; background: #1e293b; border-radius: 10px; z-index: 10; display: flex; align-items: center; justify-content: center; gap: 6px;">
                    <div style="width: 6px; height: 6px; border-radius: 50%; background: #0ea5e9;"></div>
                    <div style="width: 36px; height: 4px; border-radius: 2px; background: #475569;"></div>
                </div>

                <!-- Video Element for Screen Stream -->
                <video id="remoteScreenVideo" autoplay playsinline style="width: 100%; height: 100%; object-fit: contain; background: #000; display: none;"></video>

                <!-- Placeholder when Screen Stream is Idle -->
                <div class="video-placeholder" id="screenVideoPlaceholder" style="padding: 24px; text-align: center; display: flex; flex-direction: column; align-items: center; gap: 14px; z-index: 5;">
                    <div style="width: 72px; height: 72px; border-radius: 50%; background: rgba(99, 102, 241, 0.15); display: flex; align-items: center; justify-content: center; color: #818cf8; font-size: 2rem; margin-bottom: 6px;">
                        <i class="fa-solid fa-mobile-screen"></i>
                    </div>
                    <div class="placeholder-title" style="font-size: 1.2rem; font-weight: 700; color: #fff;">بث الشاشة المباشر متوقف حالياً</div>
                    <div class="placeholder-desc" style="font-size: 0.85rem; color: var(--text-muted); line-height: 1.6; max-width: 300px;">
                        اضغط على الزر لبدء عرض وبث شاشة طفلك بالكامل بدقة عالية وصوت مباشر وبمعدل 30 إطاراً في الثانية.
                    </div>
                    <button class="btn btn-primary" onclick="startLiveScreenStream()" style="background: linear-gradient(135deg, #6366f1, #4f46e5); border: none; padding: 12px 24px; border-radius: 12px; font-weight: 700; display: flex; align-items: center; gap: 8px; box-shadow: 0 10px 15px -3px rgba(99, 102, 241, 0.3);">
                        <i class="fa-solid fa-play"></i>
                        <span>بدء بث الشاشة المباشر الآن</span>
                    </button>
                    <div id="screenStreamNote" style="font-size: 0.75rem; color: #94a3b8; margin-top: 8px;">
                        💡 ملاحظة: عند البث لأول مرة قد تظهر رسالة تأكيد عادية على جهاز الطفل للموافقة على مشاركة الشاشة.
                    </div>
                </div>

                <!-- WebRTC Live Controls Overlay -->
                <div class="stream-controls-overlay" id="screenControlsOverlay" style="display: none; position: absolute; bottom: 16px; left: 16px; right: 16px; z-index: 20; background: rgba(15, 23, 42, 0.85); backdrop-filter: blur(10px); border-radius: 16px; padding: 10px 16px; border: 1px solid rgba(255,255,255,0.1); justify-content: space-between; align-items: center;">
                    <div class="stream-info-pill" style="display: flex; align-items: center; gap: 8px; font-size: 0.8rem; font-weight: 700; color: #fff;">
                        <span class="pulse-red-dot"></span>
                        <span>LIVE SCREEN</span>
                    </div>

                    <div class="stream-buttons-group" style="display: flex; gap: 8px;">
                        <button class="stream-control-btn" onclick="toggleScreenAudio()" id="btnScreenAudio" title="كتم / تشغيل الصوت" style="background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2); color: #fff; padding: 6px 12px; border-radius: 8px; cursor: pointer;">
                            <i class="fa-solid fa-volume-high" id="screenAudioIcon"></i>
                        </button>
                        <button class="stream-control-btn" onclick="toggleScreenFullscreen()" title="ملء الشاشة" style="background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2); color: #fff; padding: 6px 12px; border-radius: 8px; cursor: pointer;">
                            <i class="fa-solid fa-expand"></i>
                        </button>
                        <button class="stream-control-btn btn-danger-pill" onclick="stopLiveScreenStream()" title="إنهاء البث" style="background: #ef4444; border: none; color: #fff; padding: 6px 14px; border-radius: 8px; font-weight: 700; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                            <i class="fa-solid fa-stop"></i>
                            <span>إيقاف البث</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- MODE 2: Silent Continuous Surveillance Mode -->
        <div id="screenSilentContainer" class="screen-mode-view" style="display: none;">
            <!-- Surveillance Control Bar -->
            <div style="background: var(--bg-card, #1e293b); border: 1px solid var(--border-color); border-radius: 14px; padding: 14px 18px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
                <div style="display: flex; align-items: center; gap: 14px; flex-wrap: wrap;">
                    <button id="btnToggleSilentSurveillance" class="btn btn-primary" onclick="toggleSilentSurveillance()" style="background: #10b981; border: none; padding: 8px 18px; border-radius: 8px; font-weight: 600; display: flex; align-items: center; gap: 8px;">
                        <i class="fa-solid fa-play" id="silentSurveillanceIcon"></i>
                        <span id="silentSurveillanceText">بدء التحديث الدوري المستمر</span>
                    </button>
                    
                    <button class="btn btn-secondary" onclick="captureSingleSnapshotNow()" style="padding: 8px 14px; border-radius: 8px; font-size: 0.85rem; display: flex; align-items: center; gap: 6px;">
                        <i class="fa-solid fa-camera"></i>
                        <span>التقاط لقطة واحدة الآن</span>
                    </button>

                    <div style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem;">
                        <label for="silentIntervalSelect" style="color: var(--text-muted);">معدل التحديث:</label>
                        <select id="silentIntervalSelect" onchange="changeSilentInterval(this.value)" style="background: var(--bg-surface, #0f172a); color: var(--text-primary); border: 1px solid var(--border-color); padding: 6px 10px; border-radius: 6px; font-size: 0.85rem;">
                            <option value="2000">كل 2 ثانية (فائق السرعة)</option>
                            <option value="5000" selected>كل 5 ثوانٍ (متوازن وموصى به)</option>
                            <option value="10000">كل 10 ثوانٍ (توفير البيانات)</option>
                            <option value="30000">كل 30 ثانية (تحديث هادئ)</option>
                        </select>
                    </div>
                </div>

                <div style="display: flex; align-items: center; gap: 12px;">
                    <span id="silentStatusText" style="font-size: 0.82rem; color: var(--text-muted);">التحديث الدوري متوقف</span>
                    <button class="btn btn-outline" id="btnDownloadSilentSnapshot" onclick="downloadCurrentSnapshot()" style="display: none; padding: 6px 12px; font-size: 0.8rem; border-radius: 6px;">
                        <i class="fa-solid fa-download"></i> حفظ الصورة
                    </button>
                </div>
            </div>

            <!-- Phone Frame for Snapshot Display -->
            <div class="phone-mirror-frame" id="silentPhoneFrame" style="position: relative; width: 100%; max-width: 380px; height: 640px; margin: 0 auto; background: #000; border-radius: 36px; border: 4px solid #334155; overflow: hidden; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7); display: flex; align-items: center; justify-content: center;">
                
                <!-- Phone Top Speaker/Camera Notch Mockup -->
                <div style="position: absolute; top: 10px; left: 50%; transform: translateX(-50%); width: 90px; height: 18px; background: #1e293b; border-radius: 10px; z-index: 10; display: flex; align-items: center; justify-content: center; gap: 6px;">
                    <div style="width: 6px; height: 6px; border-radius: 50%; background: #10b981;"></div>
                    <div style="width: 36px; height: 4px; border-radius: 2px; background: #475569;"></div>
                </div>

                <!-- Snapshot Image -->
                <img id="silentSurveillanceImg" src="" alt="شاشة الطفل" style="width: 100%; height: 100%; object-fit: contain; background: #000; display: none;" />

                <!-- Spinner during initial capture -->
                <div id="silentSurveillanceSpinner" style="display: none; position: absolute; z-index: 15; text-align: center; background: rgba(0,0,0,0.7); padding: 20px; border-radius: 16px;">
                    <i class="fa-solid fa-circle-notch fa-spin" style="font-size: 2rem; color: #10b981;"></i>
                    <div style="color: #fff; font-size: 0.85rem; margin-top: 10px;">جاري جلب لقطة الشاشة من الجهاز...</div>
                </div>

                <!-- Placeholder when no snapshot yet -->
                <div id="silentSurveillancePlaceholder" style="padding: 24px; text-align: center; display: flex; flex-direction: column; align-items: center; gap: 14px; z-index: 5;">
                    <div style="width: 72px; height: 72px; border-radius: 50%; background: rgba(16, 185, 129, 0.15); display: flex; align-items: center; justify-content: center; color: #34d399; font-size: 2rem;">
                        <i class="fa-solid fa-camera-retro"></i>
                    </div>
                    <div style="font-size: 1.15rem; font-weight: 700; color: #fff;">الاطمئنان الدوري باللقطات</div>
                    <div style="font-size: 0.85rem; color: var(--text-muted); line-height: 1.6; max-width: 280px;">
                        تتيح لك التقاط صور مستمرة وفورية لشاشة الجهاز دون استهلاك كبير للإنترنت وبشكل صامت تماماً.
                    </div>
                    <button class="btn btn-primary" onclick="toggleSilentSurveillance()" style="background: #10b981; border: none; padding: 10px 22px; border-radius: 10px; font-weight: 700;">
                        <i class="fa-solid fa-play"></i> تشغيل التحديث الآن
                    </button>
                </div>

                <!-- Snapshot Overlay Timestamp -->
                <div id="silentTimestampOverlay" style="display: none; position: absolute; bottom: 16px; left: 16px; right: 16px; z-index: 20; background: rgba(15, 23, 42, 0.85); backdrop-filter: blur(8px); border-radius: 12px; padding: 8px 14px; border: 1px solid rgba(255,255,255,0.1); justify-content: space-between; align-items: center; font-size: 0.78rem; color: #cbd5e1;">
                    <div style="display: flex; align-items: center; gap: 6px;">
                        <span style="width: 8px; height: 8px; border-radius: 50%; background: #10b981; display: inline-block;"></span>
                        <span id="silentLastUpdatedTime">آخر تحديث: الآن</span>
                    </div>
                    <button onclick="toggleSilentFullscreen()" style="background: none; border: none; color: #fff; cursor: pointer; font-size: 0.9rem;" title="تكبير الصورة">
                        <i class="fa-solid fa-expand"></i>
                    </button>
                </div>
            </div>
        </div>
    </div>
</section>
