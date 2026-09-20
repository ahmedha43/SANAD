<?php
/**
 * Admin Panel - Sidebar Navigation Component
 */
declare(strict_types=1);
$config = require __DIR__ . '/../config/config.php';
?>
<aside class="w-64 bg-gray-900 border-l border-gray-800 flex flex-col justify-between p-4 shrink-0 h-screen sticky top-0">
    <div>
        <!-- Brand / Logo -->
        <div class="flex items-center gap-3 px-2 py-4 mb-6 border-b border-gray-800">
            <div class="w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center text-white text-xl font-bold shadow-lg shadow-blue-500/30">
                <i class="fa-solid fa-shield-halved"></i>
            </div>
            <div>
                <h1 class="font-bold text-lg leading-none">KidsControl</h1>
                <span class="text-xs text-blue-400 font-semibold">Master Admin PHP</span>
            </div>
        </div>

        <!-- Navigation Menu -->
        <nav class="space-y-1.5">
            <button onclick="switchTab('dashboard')" id="nav-dashboard" class="w-full flex items-center gap-3 px-4 py-3 text-sm font-medium rounded-xl bg-blue-600/10 text-blue-400 border border-blue-500/20 transition">
                <i class="fa-solid fa-chart-pie w-5 text-center"></i>
                <span>لوحة القيادة المباشرة</span>
            </button>

            <button onclick="switchTab('users')" id="nav-users" class="w-full flex items-center gap-3 px-4 py-3 text-sm font-medium rounded-xl text-gray-400 hover:bg-gray-800 hover:text-gray-200 transition">
                <i class="fa-solid fa-users w-5 text-center"></i>
                <span>أولياء الأمور والعائلات</span>
            </button>

            <button onclick="switchTab('devices')" id="nav-devices" class="w-full flex items-center gap-3 px-4 py-3 text-sm font-medium rounded-xl text-gray-400 hover:bg-gray-800 hover:text-gray-200 transition">
                <i class="fa-solid fa-mobile-screen w-5 text-center"></i>
                <span>أجهزة الأطفال المتصلة</span>
            </button>

            <button onclick="switchTab('subscriptions')" id="nav-subscriptions" class="w-full flex items-center gap-3 px-4 py-3 text-sm font-medium rounded-xl text-gray-400 hover:bg-gray-800 hover:text-gray-200 transition">
                <i class="fa-solid fa-crown w-5 text-center"></i>
                <span>التراخيص والاشتراكات</span>
            </button>

            <button onclick="switchTab('plans')" id="nav-plans" class="w-full flex items-center gap-3 px-4 py-3 text-sm font-medium rounded-xl text-gray-400 hover:bg-gray-800 hover:text-gray-200 transition">
                <i class="fa-solid fa-tags w-5 text-center"></i>
                <span>الباقات والأسعار</span>
            </button>

            <button onclick="switchTab('logs')" id="nav-logs" class="w-full flex items-center gap-3 px-4 py-3 text-sm font-medium rounded-xl text-gray-400 hover:bg-gray-800 hover:text-gray-200 transition">
                <i class="fa-solid fa-terminal w-5 text-center"></i>
                <span>سجل البث والأمان (Live Logs)</span>
            </button>

            <button onclick="switchTab('infrastructure')" id="nav-infrastructure" class="w-full flex items-center gap-3 px-4 py-3 text-sm font-medium rounded-xl text-gray-400 hover:bg-gray-800 hover:text-gray-200 transition">
                <i class="fa-solid fa-server w-5 text-center"></i>
                <span>الخوادم و Coturn WebRTC</span>
            </button>
        </nav>
    </div>

    <!-- Super Admin Profile Badge -->
    <div class="p-3 bg-gray-800/60 rounded-xl border border-gray-700/50 flex items-center gap-3">
        <div class="w-9 h-9 rounded-lg bg-emerald-500/20 text-emerald-400 flex items-center justify-center font-bold text-sm">
            SA
        </div>
        <div class="flex-1 overflow-hidden">
            <p class="text-xs font-bold truncate text-white"><?= htmlspecialchars($config['admin_name']) ?></p>
            <p class="text-[11px] text-gray-400 truncate"><?= htmlspecialchars($config['admin_email']) ?></p>
        </div>
    </div>
</aside>
