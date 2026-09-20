<?php
/**
 * Instant Walkie-Talkie (Push-to-Talk) Component
 * اتصال صوتي لاسلكي فوري بمكبر صوت الهاتف مع تجاوز وضع الصامت
 */
declare(strict_types=1);
?>
<section class="panel-card" id="walkieTalkieSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-walkie-talkie" style="color: var(--accent-cyan); font-size: 1.5rem;"></i>
            <div>
                <h3>الاتصال اللاسلكي الفوري (Walkie-Talkie / Push-to-Talk)</h3>
                <span class="sub-text">تحدث فوراً مع طفلك بصوت عالي عبر مكبر الصوت (Loudspeaker) متجاوزاً وضع الصامت وعدم الإزعاج</span>
            </div>
        </div>
        <div class="header-actions">
            <span class="stream-badge-status" id="pttBadge">جاهز للإرسال</span>
        </div>
    </div>

    <!-- Emergency Loudspeaker Advisory Banner -->
    <div class="alert-banner-info" style="background: rgba(245, 158, 11, 0.12); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: var(--radius-md); padding: 0.9rem 1.25rem; margin-top: 1rem; display: flex; align-items: center; gap: 1rem;">
        <i class="fa-solid fa-triangle-exclamation" style="color: var(--accent-amber); font-size: 1.5rem; flex-shrink: 0;"></i>
        <div style="font-size: 0.9rem; line-height: 1.5;">
            <strong style="color: var(--accent-amber);">تنبيه استثنائي:</strong>
            عند الضغط للتحدث، سيتم تشغيل نغمة إنذار لاسلكية (Tactical Chirp) متبوعة بصوتك مباشرة عبر مكبر الصوت الخارجي للهاتف بأقصى مستوى، حتى لو كان هاتف الطفل في وضع الصامت التام أو "عدم الإزعاج".
        </div>
    </div>

    <div class="ptt-main-container" style="background: var(--bg-surface); border-radius: var(--radius-lg); border: 1px solid var(--border-color); padding: 3rem 1.5rem; text-align: center; margin-top: 1rem; position: relative;">
        
        <!-- Big Push-to-Talk Button Wrapper -->
        <div class="ptt-button-wrapper" style="margin-bottom: 2rem;">
            <button class="ptt-tactical-btn" id="pttButton" 
                onmousedown="startPushToTalk()" 
                onmouseup="stopPushToTalk()" 
                ontouchstart="startPushToTalk(event)" 
                ontouchend="stopPushToTalk(event)"
                style="width: 170px; height: 170px; border-radius: 50%; background: linear-gradient(145deg, #0e7490, #06b6d4); border: 5px solid rgba(6, 182, 212, 0.4); box-shadow: 0 0 35px rgba(6, 182, 212, 0.3); color: #fff; display: inline-flex; flex-direction: column; align-items: center; justify-content: center; cursor: pointer; transition: all 0.2s ease; user-select: none; -webkit-user-select: none;">
                <i class="fa-solid fa-microphone-lines" id="pttIcon" style="font-size: 3.5rem; margin-bottom: 0.4rem;"></i>
                <span id="pttText" style="font-size: 0.95rem; font-weight: 800; letter-spacing: 0.5px;">اضغط وتحدث</span>
            </button>
            <div style="margin-top: 1rem; color: var(--text-secondary); font-size: 0.9rem;">
                <span>أو اضغط نقرة واحدة للوضع المستمر: </span>
                <button class="btn btn-outline btn-sm" id="btnPttToggleMode" onclick="toggleContinuousTalk()" style="margin-right: 6px; padding: 4px 12px; font-size: 0.85rem;">
                    <i class="fa-solid fa-toggle-off" id="pttToggleIcon"></i>
                    <span id="pttToggleText">تحدث حر مستمر</span>
                </button>
            </div>
        </div>

        <!-- Parent Mic Audio Level VU-Meter -->
        <div class="ptt-vumeter-wrapper" style="max-width: 320px; margin: 0 auto 1.5rem auto; display: none;" id="pttVuMeter">
            <div style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 6px; display: flex; justify-content: space-between;">
                <span>مستوى صوت الميكروفون:</span>
                <span id="pttVolumePercent" style="color: var(--accent-cyan); font-weight: 700;">0%</span>
            </div>
            <div style="height: 8px; background: rgba(255,255,255,0.1); border-radius: 4px; overflow: hidden;">
                <div id="pttVolumeBar" style="width: 0%; height: 100%; background: linear-gradient(90deg, #10b981, #06b6d4, #ef4444); transition: width 0.08s ease;"></div>
            </div>
        </div>

        <!-- Connection State & Details -->
        <div class="ptt-specs-pill-group" style="display: flex; flex-wrap: wrap; justify-content: center; gap: 0.75rem; max-width: 600px; margin: 0 auto;">
            <div style="background: rgba(255,255,255,0.04); border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.5rem 1rem; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 0.5rem;">
                <i class="fa-solid fa-bullhorn" style="color: var(--accent-cyan);"></i>
                <span>مكبر الصوت: <strong>نشط وفوري</strong></span>
            </div>
            <div style="background: rgba(255,255,255,0.04); border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.5rem 1rem; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 0.5rem;">
                <i class="fa-solid fa-bell-slash" style="color: var(--accent-amber);"></i>
                <span>تجاوز الصامت: <strong>نعم (MODE_IN_COMMUNICATION)</strong></span>
            </div>
            <div style="background: rgba(255,255,255,0.04); border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.5rem 1rem; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 0.5rem;">
                <i class="fa-solid fa-shield-halved" style="color: var(--accent-emerald);"></i>
                <span>التشفير: <strong>WebRTC SRTP</strong></span>
            </div>
        </div>

    </div>
</section>

<style>
.ptt-tactical-btn:active, .ptt-tactical-btn.transmitting {
    background: linear-gradient(145deg, #b91c1c, #ef4444) !important;
    border-color: #f87171 !important;
    box-shadow: 0 0 50px rgba(239, 68, 68, 0.8) !important;
    transform: scale(0.96);
}
</style>
