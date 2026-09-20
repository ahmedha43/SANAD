<?php
/**
 * Admin Panel - Subscription Plans & Pricing Component
 * شاشة إدارة باقات الاشتراك وتحديد الأسعار والمدد والميزات
 */
declare(strict_types=1);
?>
<section id="tab-plans" class="hidden">
    <div class="space-y-6">
        <!-- Header & Action Bar -->
        <div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass p-5 flex flex-wrap items-center justify-between gap-4">
            <div>
                <h3 class="font-bold text-white text-base flex items-center gap-2">
                    <i class="fa-solid fa-tags text-amber-400"></i>
                    <span>إدارة باقات الاشتراك والأسعار (Subscription Plans & Pricing)</span>
                </h3>
                <p class="text-xs text-gray-500 mt-1">تحديد مدة وأسعار الباقات، السعة القصوى للأجهزة، والميزات المتاحة لكل فئة</p>
            </div>
            <button onclick="openCreatePlanModal()" class="px-4 py-2 text-xs font-bold bg-gradient-to-r from-blue-600 to-blue-500 text-white rounded-xl hover:from-blue-500 hover:to-blue-400 transition shadow-lg shadow-blue-500/20 flex items-center gap-2">
                <i class="fa-solid fa-plus"></i>
                <span>إضافة باقة جديدة</span>
            </button>
        </div>

        <!-- Plans Grid -->
        <div id="plans-grid-container" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
            <div class="col-span-full py-12 text-center text-gray-500">
                <i class="fa-solid fa-spinner fa-spin text-2xl mb-2 block"></i>
                <span>جاري تحميل الباقات والأسعار...</span>
            </div>
        </div>
    </div>
</section>
