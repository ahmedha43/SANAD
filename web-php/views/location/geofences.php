<?php
/**
 * Professional Interactive Geofencing & Safe Zones Manager Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="geofenceSection">
    <!-- Header -->
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-draw-polygon" style="color: var(--accent-emerald)"></i>
            <div>
                <h3>المناطق الجغرافية الآمنة ومحيط الحماية (Interactive Safe Zones)</h3>
                <span class="sub-text">حدد محيط الأمان التفاعلي على الخريطة واستلم تنبيهاً فورياً مع تتبع دقيق لأي تجاوز في المسار</span>
            </div>
        </div>
        <div style="display: flex; gap: 8px;">
            <button class="btn btn-outline-sm" onclick="App.loadGeofences(true)" title="تحديث الخريطة والمناطق">
                <i class="fa-solid fa-arrows-rotate"></i>
                <span>تحديث</span>
            </button>
            <button class="btn btn-emerald-sm" onclick="GeofenceMapController.startCreatingZone()">
                <i class="fa-solid fa-plus"></i>
                <span>إضافة منطقة جديدة</span>
            </button>
        </div>
    </div>

    <!-- Interactive Geofence Designer Split Grid -->
    <div class="geofence-designer-grid" style="display: grid; grid-template-columns: 1.8fr 1.2fr; gap: 20px; padding: 20px;">
        <!-- Left: Interactive Leaflet Map -->
        <div class="geofence-map-wrapper" style="position: relative; border-radius: var(--radius-md); overflow: hidden; border: 1px solid var(--border-color); background: var(--bg-card);">
            <!-- Map Container -->
            <div id="geofenceMap" class="leaflet-map-view" style="height: 480px; width: 100%;"></div>

            <!-- Map Top Overlay Floating Pill -->
            <div class="geofence-map-floating-pill" id="geofenceMapStatusPill" style="position: absolute; top: 12px; right: 12px; z-index: 1000; background: rgba(15, 23, 42, 0.88); backdrop-filter: blur(8px); border: 1px solid var(--border-color); border-radius: 30px; padding: 6px 14px; font-size: 0.8rem; display: flex; align-items: center; gap: 8px; box-shadow: var(--shadow-md);">
                <span class="pulse-dot emerald" id="geofenceModeDot"></span>
                <span id="geofenceModeText">انقر على الخريطة لتحديد مركز المنطقة الآمنة</span>
            </div>

            <!-- Map Floating Action Buttons -->
            <div style="position: absolute; bottom: 12px; right: 12px; z-index: 1000; display: flex; gap: 6px;">
                <button class="btn btn-outline-sm" style="background: rgba(15, 23, 42, 0.85); backdrop-filter: blur(6px);" onclick="GeofenceMapController.centerOnKidLocation()" title="توسيط على موقع الطفل الحالي">
                    <i class="fa-solid fa-crosshairs"></i>
                    <span>موقع الطفل</span>
                </button>
                <button class="btn btn-outline-sm" style="background: rgba(15, 23, 42, 0.85); backdrop-filter: blur(6px);" onclick="GeofenceMapController.fitAllZones()" title="عرض كافة المناطق الآمنة">
                    <i class="fa-solid fa-expand"></i>
                    <span>كافة المناطق</span>
                </button>
            </div>
        </div>

        <!-- Right: Interactive Zone Designer & Settings Panel -->
        <div class="geofence-controls-card" style="background: var(--bg-surface-2, rgba(255,255,255,0.02)); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 18px; display: flex; flex-direction: column; justify-content: space-between;">
            <div>
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; border-bottom: 1px solid var(--border-color); padding-bottom: 10px;">
                    <h4 style="margin: 0; font-size: 1rem; color: var(--text-primary); display: flex; align-items: center; gap: 8px;">
                        <i class="fa-solid fa-circle-dot" style="color: var(--accent-emerald);"></i>
                        <span id="zoneDesignerTitle">تحديد محيط الأمان التفاعلي</span>
                    </h4>
                    <span class="badge" style="background: rgba(16, 185, 129, 0.15); color: var(--accent-emerald); font-size: 0.75rem;" id="designerModeBadge">وضع الرسم ✏️</span>
                </div>

                <!-- Zone Name -->
                <div class="form-group" style="margin-bottom: 14px;">
                    <label style="font-size: 0.85rem; font-weight: 600; margin-bottom: 6px; display: block;">اسم المنطقة الآمنة:</label>
                    <input type="text" id="fenceName" placeholder="مثال: المدرسة، المنزل، نادي الكاراتيه..." class="form-input" style="width: 100%;">
                </div>

                <!-- Quick Presets -->
                <div class="form-group" style="margin-bottom: 16px;">
                    <label style="font-size: 0.82rem; color: var(--text-muted); margin-bottom: 6px; display: block;">نماذج سريعة جاهزة:</label>
                    <div class="preset-chips-row" style="display: flex; gap: 6px; flex-wrap: wrap;">
                        <button type="button" class="btn btn-outline-sm" style="font-size: 0.78rem; padding: 4px 10px;" onclick="GeofenceMapController.applyPreset('المنزل', 150)">
                            🏠 المنزل (150م)
                        </button>
                        <button type="button" class="btn btn-outline-sm" style="font-size: 0.78rem; padding: 4px 10px;" onclick="GeofenceMapController.applyPreset('المدرسة', 300)">
                            🏫 المدرسة (300م)
                        </button>
                        <button type="button" class="btn btn-outline-sm" style="font-size: 0.78rem; padding: 4px 10px;" onclick="GeofenceMapController.applyPreset('النادي الرياضي', 500)">
                            ⚽ النادي (500م)
                        </button>
                        <button type="button" class="btn btn-outline-sm" style="font-size: 0.78rem; padding: 4px 10px;" onclick="GeofenceMapController.applyPreset('الحي السكني', 1000)">
                            🏘️ الحي (1000م)
                        </button>
                    </div>
                </div>

                <!-- Interactive Radius Slider & Live Value -->
                <div class="form-group" style="margin-bottom: 16px; background: rgba(0,0,0,0.2); border: 1px solid var(--border-color); border-radius: var(--radius-sm); padding: 12px;">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                        <label style="font-size: 0.85rem; font-weight: 600; margin: 0;">نصف قطر الدائرة (محيط الأمان):</label>
                        <span class="badge" style="background: var(--accent-emerald); color: #fff; font-size: 0.85rem; font-weight: 700;" id="fenceRadiusBadge">300 متر</span>
                    </div>
                    <input type="range" id="fenceRadiusSlider" min="50" max="3000" step="25" value="300" class="time-slider" style="width: 100%; margin-bottom: 8px;" oninput="GeofenceMapController.onRadiusSlider(this.value)">
                    <div style="display: flex; justify-content: space-between; font-size: 0.72rem; color: var(--text-muted);">
                        <span>50 متر (مبنى محدد)</span>
                        <span>1,500 متر</span>
                        <span>3,000 متر (حي واسع)</span>
                    </div>
                    <input type="hidden" id="fenceRadius" value="300">
                </div>

                <!-- Center Coordinates & Use Kid Location Button -->
                <div class="form-group" style="margin-bottom: 14px;">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                        <label style="font-size: 0.82rem; margin: 0;">إحداثيات مركز المنطقة:</label>
                        <button type="button" class="btn btn-outline-sm" style="padding: 2px 8px; font-size: 0.75rem;" onclick="GeofenceMapController.useKidLocationAsCenter()">
                            <i class="fa-solid fa-location-crosshairs"></i> موقع الطفل الحالي
                        </button>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                        <input type="text" id="fenceLat" placeholder="خط العرض Lat" class="form-input" style="font-size: 0.8rem; direction: ltr;" readonly>
                        <input type="text" id="fenceLng" placeholder="خط الطول Lng" class="form-input" style="font-size: 0.8rem; direction: ltr;" readonly>
                    </div>
                </div>

                <!-- Trigger Alert Type -->
                <div class="form-group" style="margin-bottom: 14px;">
                    <label style="font-size: 0.85rem; font-weight: 600; margin-bottom: 6px; display: block;">نوع التنبيه المطلوب:</label>
                    <select id="fenceTriggerType" class="form-input" style="width: 100%;">
                        <option value="both" selected>عند الدخول والخروج معاً 🔄 (موصى به)</option>
                        <option value="exit">عند الخروج فقط 🚨 (تنبيه الهروب والتجاوز)</option>
                        <option value="enter">عند الدخول والوصول فقط 🟢 (تأكيد الوصول للمدرسة)</option>
                    </select>
                </div>
            </div>

            <!-- Form Actions -->
            <div style="display: flex; gap: 10px; margin-top: 14px;">
                <button class="btn btn-emerald" id="btnSaveGeofence" onclick="GeofenceMapController.saveZone()" style="flex: 1; justify-content: center;">
                    <i class="fa-solid fa-floppy-disk"></i>
                    <span>حفظ وتفعيل المنطقة الآمنة</span>
                </button>
                <button class="btn btn-secondary-sm" onclick="GeofenceMapController.resetDesigner()" title="إلغاء وإعادة تعيين">
                    <i class="fa-solid fa-xmark"></i>
                </button>
            </div>
        </div>
    </div>

    <!-- Active Safe Zones Table -->
    <div style="padding: 0 20px 20px 20px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
            <h4 style="margin: 0; font-size: 0.95rem; display: flex; align-items: center; gap: 8px;">
                <i class="fa-solid fa-list-check" style="color: var(--accent-cyan);"></i>
                <span>قائمة المناطق الآمنة النشطة</span>
                <span class="badge badge-primary" id="activeGeofencesCountBadge">0</span>
            </h4>
            <span style="font-size: 0.78rem; color: var(--text-muted);">انقر على أيقونة التكبير 🔍 لعرض وتوسيط المنطقة على الخريطة مباشرة</span>
        </div>

        <div class="table-responsive">
            <table class="modern-table">
                <thead>
                    <tr>
                        <th>اسم المنطقة</th>
                        <th>نصف القطر (المحيط)</th>
                        <th>نوع التنبيه</th>
                        <th>الإحداثيات الجغرافية</th>
                        <th>الحالة</th>
                        <th>إجراءات</th>
                    </tr>
                </thead>
                <tbody id="geofencesTableBody">
                    <tr>
                        <td colspan="6" class="text-center text-muted">جاري تحميل المناطق الآمنة...</td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Perimeter Breaches & Events History Section -->
    <div style="padding: 0 20px 20px 20px; border-top: 1px solid var(--border-color); margin-top: 10px; padding-top: 20px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
            <div style="display: flex; align-items: center; gap: 8px;">
                <i class="fa-solid fa-clock-rotate-left" style="color: var(--accent-rose);"></i>
                <h4 style="margin: 0; font-size: 0.95rem;">سجل تجاوزات وخروقات المناطق الآمنة (Perimeter Breach Log)</h4>
            </div>
            <span class="badge" style="background: rgba(239, 68, 68, 0.15); color: var(--accent-rose); font-size: 0.75rem;" id="geofenceBreachEventsCountBadge">0 تنبيه تجاوز</span>
        </div>

        <div class="table-responsive">
            <table class="modern-table">
                <thead>
                    <tr>
                        <th>الوقت والتاريخ</th>
                        <th>المنطقة الآمنة</th>
                        <th>نوع الحدث</th>
                        <th>حالة الحماية</th>
                        <th>عرض في المسار</th>
                    </tr>
                </thead>
                <tbody id="geofenceEventsTableBody">
                    <tr>
                        <td colspan="5" class="text-center text-muted" style="padding: 24px;">جاري فحص سجل التجاوزات...</td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</section>
