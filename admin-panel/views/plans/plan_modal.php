<?php
/**
 * Admin Panel - Create / Edit Plan Modal
 */
declare(strict_types=1);
?>
<div id="planModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4 hidden">
    <div class="bg-gray-900 border border-gray-800 rounded-2xl w-full max-w-xl overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
        <!-- Header -->
        <div class="p-5 border-b border-gray-800 flex items-center justify-between">
            <h3 id="planModalTitle" class="font-bold text-white text-base flex items-center gap-2">
                <i class="fa-solid fa-tag text-blue-400"></i>
                <span>إضافة باقة اشتراك جديدة</span>
            </h3>
            <button onclick="closeModal('planModal')" class="text-gray-400 hover:text-white transition">
                <i class="fa-solid fa-xmark text-lg"></i>
            </button>
        </div>

        <!-- Body Form -->
        <form id="planForm" onsubmit="handlePlanFormSubmit(event)" class="p-5 space-y-4 max-h-[80vh] overflow-y-auto">
            <input type="hidden" id="planModalIsEdit" value="0">

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">معرف الباقة البرمجي (Plan ID)</label>
                    <input type="text" id="planIdInput" required class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white font-mono focus:border-blue-500 focus:outline-none" placeholder="e.g. plan_gold_monthly">
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">اسم الباقة المعروض</label>
                    <input type="text" id="planNameInput" required class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white focus:border-blue-500 focus:outline-none" placeholder="e.g. باقة الأمان الذهبية">
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">فئة الباقة (Tier)</label>
                    <select id="planTierSelect" class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white focus:border-blue-500 focus:outline-none">
                        <option value="free">Free (مجانية)</option>
                        <option value="basic">Basic (أساسية)</option>
                        <option value="premium">Premium (متقدمة)</option>
                        <option value="family_unlimited">Family Unlimited (غير محدودة)</option>
                    </select>
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">السعر</label>
                    <input type="number" step="0.01" id="planPriceInput" required class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white font-bold focus:border-blue-500 focus:outline-none" placeholder="0.00">
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">العملة</label>
                    <select id="planCurrencySelect" class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white focus:border-blue-500 focus:outline-none">
                        <option value="USD">USD ($)</option>
                        <option value="SAR">SAR (ر.س)</option>
                        <option value="AED">AED (د.إ)</option>
                        <option value="IQD">IQD (د.ع)</option>
                    </select>
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">دورة الفوترة</label>
                    <select id="planBillingCycleSelect" onchange="onBillingCycleChange(this.value)" class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white focus:border-blue-500 focus:outline-none">
                        <option value="monthly">شهري (Monthly)</option>
                        <option value="yearly">سنوي (Yearly)</option>
                        <option value="lifetime">دائم (Lifetime)</option>
                    </select>
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">مدة الباقة (بالأيام)</label>
                    <input type="number" id="planDurationDaysInput" value="30" class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white font-mono focus:border-blue-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-300 mb-1.5">الحد الأقصى للأجهزة</label>
                    <input type="number" id="planMaxDevicesInput" value="3" required class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white font-bold focus:border-blue-500 focus:outline-none">
                </div>
            </div>

            <!-- Features Checkboxes -->
            <div>
                <label class="block text-xs font-semibold text-gray-300 mb-2">الميزات المتاحة في هذه الباقة:</label>
                <div class="grid grid-cols-2 gap-2 text-xs text-gray-300 bg-gray-800/40 p-3 rounded-xl border border-gray-800">
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="live_gps" checked class="rounded border-gray-700 text-blue-600">
                        <span>تتبع GPS المباشر</span>
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="route_replay" class="rounded border-gray-700 text-blue-600">
                        <span>إعادة مسار الرحلات 24h</span>
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="geofencing" checked class="rounded border-gray-700 text-blue-600">
                        <span>المناطق الجغرافية الآمنة</span>
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="app_blocking" checked class="rounded border-gray-700 text-blue-600">
                        <span>حظر التطبيقات والألعاب</span>
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="screen_time" checked class="rounded border-gray-700 text-blue-600">
                        <span>وقت الشاشة وموعد النوم</span>
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="silent_screenshot" class="rounded border-gray-700 text-blue-600">
                        <span>لقطات الشاشة الصامتة</span>
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="live_camera" class="rounded border-gray-700 text-blue-600">
                        <span>البث المباشر WebRTC</span>
                    </label>
                    <label class="flex items-center gap-2 cursor-pointer hover:text-white">
                        <input type="checkbox" name="plan_features" value="ai_risk_detection" class="rounded border-gray-700 text-blue-600">
                        <span>رصد مخاطر الذكاء الاصطناعي</span>
                    </label>
                </div>
            </div>

            <div class="flex items-center gap-2 pt-1">
                <input type="checkbox" id="planIsActiveInput" checked class="rounded border-gray-700 text-emerald-500">
                <label for="planIsActiveInput" class="text-xs font-semibold text-emerald-400 cursor-pointer">الباقة نشطة ومتاحة للاشتراك الفوري</label>
            </div>

            <!-- Footer Buttons -->
            <div class="flex items-center justify-end gap-3 pt-3 border-t border-gray-800">
                <button type="button" onclick="closeModal('planModal')" class="px-4 py-2 text-xs font-semibold bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-xl transition">إلغاء</button>
                <button type="submit" id="planSubmitBtn" class="px-5 py-2 text-xs font-bold bg-blue-600 hover:bg-blue-500 text-white rounded-xl transition shadow-lg shadow-blue-500/20">حفظ الباقة</button>
            </div>
        </form>
    </div>
</div>
