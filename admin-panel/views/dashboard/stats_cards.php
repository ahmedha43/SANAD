<?php
/**
 * Admin Panel - Dashboard Stats Cards Component
 */
declare(strict_types=1);
?>
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
    <!-- Stat 1: Parents -->
    <div class="p-5 rounded-2xl bg-gray-900/50 border border-gray-800 glass relative overflow-hidden group hover:border-blue-500/50 transition">
        <div class="flex items-center justify-between mb-3">
            <span class="text-xs font-semibold text-gray-400">أولياء الأمور المسجلين</span>
            <div class="w-9 h-9 rounded-xl bg-blue-500/10 text-blue-400 flex items-center justify-center">
                <i class="fa-solid fa-users text-sm"></i>
            </div>
        </div>
        <div class="text-2xl font-black text-white mb-1" id="stat-parents">0</div>
        <div class="text-[11px] text-gray-500 flex items-center gap-1">
            <i class="fa-solid fa-check text-emerald-400"></i>
            <span>حسابات عائلية معتمدة</span>
        </div>
    </div>

    <!-- Stat 2: Total Devices -->
    <div class="p-5 rounded-2xl bg-gray-900/50 border border-gray-800 glass relative overflow-hidden group hover:border-purple-500/50 transition">
        <div class="flex items-center justify-between mb-3">
            <span class="text-xs font-semibold text-gray-400">إجمالي أجهزة الأطفال</span>
            <div class="w-9 h-9 rounded-xl bg-purple-500/10 text-purple-400 flex items-center justify-center">
                <i class="fa-solid fa-mobile-screen text-sm"></i>
            </div>
        </div>
        <div class="text-2xl font-black text-white mb-1" id="stat-devices">0</div>
        <div class="text-[11px] text-gray-500 flex items-center gap-1">
            <i class="fa-solid fa-child text-purple-400"></i>
            <span id="stat-children-sub">0 أطفال مقترنين</span>
        </div>
    </div>

    <!-- Stat 3: Online Devices -->
    <div class="p-5 rounded-2xl bg-gray-900/50 border border-gray-800 glass relative overflow-hidden group hover:border-emerald-500/50 transition">
        <div class="flex items-center justify-between mb-3">
            <span class="text-xs font-semibold text-gray-400">متصل الآن (Online)</span>
            <div class="w-9 h-9 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center">
                <i class="fa-solid fa-signal text-sm"></i>
            </div>
        </div>
        <div class="text-2xl font-black text-emerald-400 mb-1" id="stat-online">0</div>
        <div class="text-[11px] text-gray-500 flex items-center gap-1">
            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span>بث وإشارات حية متزامنة</span>
        </div>
    </div>

    <!-- Stat 4: Subscriptions -->
    <div class="p-5 rounded-2xl bg-gray-900/50 border border-gray-800 glass relative overflow-hidden group hover:border-amber-500/50 transition">
        <div class="flex items-center justify-between mb-3">
            <span class="text-xs font-semibold text-gray-400">الاشتراكات والتراخيص</span>
            <div class="w-9 h-9 rounded-xl bg-amber-500/10 text-amber-400 flex items-center justify-center">
                <i class="fa-solid fa-crown text-sm"></i>
            </div>
        </div>
        <div class="text-2xl font-black text-white mb-1" id="stat-subs">0</div>
        <div class="text-[11px] text-gray-500 flex items-center gap-1">
            <i class="fa-solid fa-shield-halved text-amber-400"></i>
            <span>تراخيص نشطة ومفعلة</span>
        </div>
    </div>
</div>
