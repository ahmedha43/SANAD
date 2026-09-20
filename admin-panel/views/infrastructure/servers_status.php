<?php
/**
 * Admin Panel - Infrastructure & Servers Status Component
 */
declare(strict_types=1);
?>
<section id="tab-infrastructure" class="hidden">
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Card 1: Core Services -->
        <div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass p-6">
            <div class="flex items-center gap-3 mb-4">
                <div class="w-10 h-10 rounded-xl bg-blue-500/10 text-blue-400 flex items-center justify-center text-lg">
                    <i class="fa-solid fa-server"></i>
                </div>
                <div>
                    <h3 class="font-bold text-white text-base">حاويات وخوادم النظام (Docker Fleet)</h3>
                    <p class="text-xs text-gray-400">حالة الخدمات الأساسية وقواعد البيانات</p>
                </div>
            </div>

            <div class="space-y-2.5 text-xs">
                <div class="flex justify-between items-center p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="flex items-center gap-2">
                        <i class="fa-solid fa-database text-blue-400"></i>
                        <span class="text-white font-bold">pc_postgres</span>
                        <span class="text-gray-500">(PostgreSQL 16)</span>
                    </div>
                    <span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Healthy :5432</span>
                </div>

                <div class="flex justify-between items-center p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="flex items-center gap-2">
                        <i class="fa-solid fa-bolt text-red-400"></i>
                        <span class="text-white font-bold">pc_redis</span>
                        <span class="text-gray-500">(Redis 7 Cache)</span>
                    </div>
                    <span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Healthy :6379</span>
                </div>

                <div class="flex justify-between items-center p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="flex items-center gap-2">
                        <i class="fa-solid fa-cube text-cyan-400"></i>
                        <span class="text-white font-bold">pc_backend</span>
                        <span class="text-gray-500">(Go Fiber 3 API & WS)</span>
                    </div>
                    <span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Up :8080</span>
                </div>

                <div class="flex justify-between items-center p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="flex items-center gap-2">
                        <i class="fa-brands fa-php text-purple-400"></i>
                        <span class="text-white font-bold">pc_php_dashboard</span>
                        <span class="text-gray-500">(Parent Dashboard PHP 8)</span>
                    </div>
                    <span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Up :8085</span>
                </div>

                <div class="flex justify-between items-center p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="flex items-center gap-2">
                        <i class="fa-solid fa-shield-halved text-amber-400"></i>
                        <span class="text-white font-bold">pc_admin_panel</span>
                        <span class="text-gray-500">(Master Admin PHP 8)</span>
                    </div>
                    <span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Up :3080</span>
                </div>

                <div class="flex justify-between items-center p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="flex items-center gap-2">
                        <i class="fa-solid fa-network-wired text-emerald-400"></i>
                        <span class="text-white font-bold">pc_nginx</span>
                        <span class="text-gray-500">(Gateway & Reverse Proxy)</span>
                    </div>
                    <span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Up :80 / :443</span>
                </div>
            </div>
        </div>

        <!-- Card 2: WebRTC Coturn -->
        <div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass p-6">
            <div class="flex items-center gap-3 mb-4">
                <div class="w-10 h-10 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center text-lg">
                    <i class="fa-solid fa-video"></i>
                </div>
                <div>
                    <h3 class="font-bold text-white text-base">خادم Coturn WebRTC STUN/TURN</h3>
                    <p class="text-xs text-gray-400">تأمين البث المباشر الحي وتجاوز الـ NAT والـ Firewalls</p>
                </div>
            </div>

            <div class="space-y-3 text-xs">
                <div class="p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="flex justify-between items-center mb-1">
                        <span class="text-gray-400">حالة الحاوية (pc_coturn):</span>
                        <span class="text-emerald-400 font-bold flex items-center gap-1">
                            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                            Up & Running
                        </span>
                    </div>
                    <p class="text-[11px] text-gray-500 font-mono">Image: coturn/coturn:latest</p>
                </div>

                <div class="p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="text-gray-400 mb-1">المنافذ المخصصة للبث:</div>
                    <div class="grid grid-cols-2 gap-2 text-[11px] font-mono">
                        <span class="p-1.5 rounded bg-gray-900 text-blue-400">3478 TCP / UDP</span>
                        <span class="p-1.5 rounded bg-gray-900 text-purple-400">49152-49200 UDP</span>
                    </div>
                </div>

                <div class="p-3 rounded-xl bg-gray-800/40 border border-gray-800">
                    <div class="text-gray-400 mb-1">بيانات الاعتماد التلقائية (WebRTC Config):</div>
                    <p class="text-[11px] text-gray-500 font-mono">Realm: parentalcontrol.local</p>
                    <p class="text-[11px] text-gray-500 font-mono">User: parentalctl (Secured)</p>
                </div>
            </div>
        </div>
    </div>
</section>
