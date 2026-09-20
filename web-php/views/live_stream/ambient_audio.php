<?php
/**
 * WebRTC Remote Ambient Audio Listener Component
 * استماع حي وفوري للصوت المحيط بهاتف الطفل (ميكروفون فقط دون كاميرا أو شاشة)
 */
declare(strict_types=1);
?>
<section class="panel-card" id="ambientAudioSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-microphone-lines" style="color: var(--accent-emerald); font-size: 1.5rem;"></i>
            <div>
                <h3>الاستماع الصوتي الحي للمحيط (Ambient Audio Listener)</h3>
                <span class="sub-text">استماع فوري لمحيط هاتف الطفل عبر الميكروفون فقط بأقل استهلاك للبطارية والبيانات (~90% توفير)</span>
            </div>
        </div>
        <div class="header-actions">
            <span class="stream-badge-status" id="ambientBadge">جاهز للاستماع</span>
        </div>
    </div>

    <!-- Hidden HTML5 Audio Element for WebRTC Stream -->
    <audio id="ambientAudioPlayer" autoplay playsinline></audio>

    <div class="ambient-audio-container" style="background: var(--bg-surface); border-radius: var(--radius-lg); border: 1px solid var(--border-color); padding: 2.5rem 1.5rem; text-align: center; margin-top: 1rem; position: relative; overflow: hidden;">
        
        <!-- Background decorative radar circle -->
        <div class="ambient-radar-circle" id="ambientRadarCircle" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 320px; height: 320px; border-radius: 50%; border: 2px dashed rgba(16, 185, 129, 0.15); pointer-events: none; transition: all 0.5s ease;"></div>

        <!-- Center Visual Icon & Equalizer -->
        <div class="ambient-visualizer-wrapper" style="position: relative; z-index: 2; margin-bottom: 2rem;">
            <div class="ambient-mic-avatar" id="ambientMicAvatar" style="width: 110px; height: 110px; border-radius: 50%; background: linear-gradient(135deg, #064e3b, #059669); display: inline-flex; align-items: center; justify-content: center; box-shadow: 0 0 30px rgba(16, 185, 129, 0.25); border: 3px solid rgba(16, 185, 129, 0.4); transition: transform 0.3s ease, box-shadow 0.3s ease;">
                <i class="fa-solid fa-microphone" id="ambientMicIcon" style="font-size: 3rem; color: #fff;"></i>
            </div>

            <!-- Animated Audio Bars (Equalizer) -->
            <div class="ambient-bars" id="ambientAudioBars" style="display: none; align-items: center; justify-content: center; gap: 5px; height: 45px; margin-top: 1.5rem;">
                <span class="abar bar1"></span>
                <span class="abar bar2"></span>
                <span class="abar bar3"></span>
                <span class="abar bar4"></span>
                <span class="abar bar5"></span>
                <span class="abar bar6"></span>
                <span class="abar bar7"></span>
                <span class="abar bar8"></span>
                <span class="abar bar7"></span>
                <span class="abar bar6"></span>
                <span class="abar bar5"></span>
                <span class="abar bar4"></span>
                <span class="abar bar3"></span>
                <span class="abar bar2"></span>
                <span class="abar bar1"></span>
            </div>

            <!-- Listening Timer -->
            <div class="ambient-timer" id="ambientTimerWrap" style="display: none; margin-top: 1rem;">
                <span class="pulse-green-dot" style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; background: #10b981; margin-left: 6px; box-shadow: 0 0 8px #10b981;"></span>
                <span style="font-size: 1.1rem; font-weight: 700; color: #10b981;" id="ambientDuration">00:00</span>
                <span style="font-size: 0.85rem; color: var(--text-muted); margin-right: 6px;">(بث صوتي مشفر فوري)</span>
            </div>
        </div>

        <!-- Action Control Buttons -->
        <div class="ambient-actions" style="position: relative; z-index: 2; display: flex; flex-wrap: wrap; justify-content: center; gap: 1rem; margin-bottom: 2rem;">
            <button class="btn btn-primary" id="btnToggleAmbientAudio" onclick="toggleAmbientAudioStream()" style="background: linear-gradient(135deg, #059669, #10b981); border: none; padding: 0.85rem 2.2rem; font-size: 1.05rem; font-weight: 700; border-radius: var(--radius-lg); box-shadow: 0 4px 15px rgba(16, 185, 129, 0.35); cursor: pointer; display: inline-flex; align-items: center; gap: 0.75rem;">
                <i class="fa-solid fa-headphones" id="ambientBtnIcon"></i>
                <span id="ambientBtnText">بدء الاستماع للمحيط الآن</span>
            </button>
        </div>

        <!-- Volume Slider & Audio Controls -->
        <div class="ambient-volume-panel" style="position: relative; z-index: 2; max-width: 420px; margin: 0 auto; background: rgba(0,0,0,0.25); border: 1px solid var(--border-light); border-radius: var(--radius-md); padding: 1rem 1.5rem; display: flex; align-items: center; gap: 1rem;">
            <button class="icon-btn" onclick="toggleAmbientMute()" id="btnAmbientMute" title="كتم / تشغيل الصوت" style="background: none; border: none; color: var(--text-primary); font-size: 1.2rem; cursor: pointer;">
                <i class="fa-solid fa-volume-high" id="ambientVolIcon"></i>
            </button>
            <input type="range" id="ambientVolumeSlider" min="0" max="100" value="100" oninput="setAmbientVolume(this.value)" style="flex: 1; accent-color: var(--accent-emerald); cursor: pointer;">
            <span id="ambientVolVal" style="font-size: 0.9rem; font-weight: 600; min-width: 40px; color: var(--text-secondary);">100%</span>
        </div>

        <!-- Technical Specs Grid -->
        <div class="ambient-tech-grid" style="position: relative; z-index: 2; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; max-width: 750px; margin: 2rem auto 0 auto; text-align: right;">
            <div class="ambient-spec-card" style="background: rgba(255,255,255,0.03); border: 1px solid var(--border-light); border-radius: var(--radius-md); padding: 0.85rem 1rem;">
                <div style="font-size: 0.8rem; color: var(--text-muted);"><i class="fa-solid fa-bolt" style="color: var(--accent-amber);"></i> استهلاك الطاقة</div>
                <div style="font-weight: 700; color: var(--text-primary); margin-top: 3px;">خفيف جداً (أقل من 3% في الساعة)</div>
            </div>
            <div class="ambient-spec-card" style="background: rgba(255,255,255,0.03); border: 1px solid var(--border-light); border-radius: var(--radius-md); padding: 0.85rem 1rem;">
                <div style="font-size: 0.8rem; color: var(--text-muted);"><i class="fa-solid fa-shield-halved" style="color: var(--accent-emerald);"></i> تشفير الاتصال</div>
                <div style="font-weight: 700; color: var(--text-primary); margin-top: 3px;">SRTP / WebRTC End-to-End</div>
            </div>
            <div class="ambient-spec-card" style="background: rgba(255,255,255,0.03); border: 1px solid var(--border-light); border-radius: var(--radius-md); padding: 0.85rem 1rem;">
                <div style="font-size: 0.8rem; color: var(--text-muted);"><i class="fa-solid fa-gauge" style="color: var(--accent-cyan);"></i> استهلاك الإنترنت</div>
                <div style="font-weight: 700; color: var(--text-primary); margin-top: 3px;">~32 kbps (توفير 90% مقارنة بالكاميرا)</div>
            </div>
        </div>

    </div>
</section>

<style>
.ambient-bars .abar {
    display: inline-block;
    width: 5px;
    height: 10px;
    background: #10b981;
    border-radius: 4px;
    animation: barPulse 1.2s ease-in-out infinite;
}
.ambient-bars .bar1 { animation-delay: 0.1s; }
.ambient-bars .bar2 { animation-delay: 0.25s; }
.ambient-bars .bar3 { animation-delay: 0.4s; }
.ambient-bars .bar4 { animation-delay: 0.15s; }
.ambient-bars .bar5 { animation-delay: 0.3s; }
.ambient-bars .bar6 { animation-delay: 0.5s; }
.ambient-bars .bar7 { animation-delay: 0.2s; }
.ambient-bars .bar8 { animation-delay: 0.35s; }

@keyframes barPulse {
    0%, 100% { height: 8px; opacity: 0.4; }
    50% { height: 38px; opacity: 1; background: #34d399; }
}

.ambient-mic-avatar.active-pulsing {
    animation: micPulseGlow 1.8s ease-in-out infinite;
    border-color: #10b981 !important;
}

@keyframes micPulseGlow {
    0% { transform: scale(1); box-shadow: 0 0 25px rgba(16, 185, 129, 0.3); }
    50% { transform: scale(1.06); box-shadow: 0 0 50px rgba(16, 185, 129, 0.7); }
    100% { transform: scale(1); box-shadow: 0 0 25px rgba(16, 185, 129, 0.3); }
}
</style>
