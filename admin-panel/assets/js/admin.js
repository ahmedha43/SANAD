/**
 * Master Admin Panel - Application Controller
 * إدارة جلب وعرض بيانات لوحة التحكم الشاملة
 */

// Automatically resolve API Base URL
function getApiBase() {
    // If accessing via Nginx on standard port 80/443 (e.g. http://localhost/admin)
    if (window.location.port === '' || window.location.port === '80' || window.location.port === '443') {
        return `${window.location.origin}/api/v1`;
    }

    // If accessing via dedicated port 3080 (e.g. http://localhost:3080)
    // Connect directly to the Go Fiber backend on port 8880 (which has CORS enabled)
    return `${window.location.protocol}//${window.location.hostname}:8080/api/v1`;
}

const API_BASE = getApiBase();
console.log('[Admin Panel PHP] Resolved API Base URL:', API_BASE);


function switchTab(tabId) {
    const tabs = ['dashboard', 'users', 'devices', 'subscriptions', 'plans', 'logs', 'infrastructure'];
    tabs.forEach(t => {
        const el = document.getElementById('tab-' + t);
        if (el) el.classList.add('hidden');
    });

    const target = document.getElementById('tab-' + tabId);
    if (target) target.classList.remove('hidden');

    // Update sidebar nav button styling
    const buttons = document.querySelectorAll('aside nav button');
    buttons.forEach(btn => {
        btn.classList.remove('bg-blue-600/10', 'text-blue-400', 'border-blue-500/20');
        btn.classList.add('text-gray-400');
    });

    const activeBtn = document.getElementById('nav-' + tabId);
    if (activeBtn) {
        activeBtn.classList.remove('text-gray-400');
        activeBtn.classList.add('bg-blue-600/10', 'text-blue-400', 'border-blue-500/20');
    }

    // Update Header Title
    const titles = {
        'dashboard': 'لوحة القيادة والمراقبة الحية',
        'users': 'أولياء الأمور والعائلات المسجلة',
        'devices': 'أجهزة الأطفال المتصلة',
        'subscriptions': 'التراخيص والاشتراكات العائلية',
        'plans': 'إدارة باقات الاشتراك والأسعار',
        'logs': 'سجل البث والأمان (Live Logs)',
        'infrastructure': 'الخوادم والبنية التحتية'
    };
    document.getElementById('page-title').textContent = titles[tabId] || 'لوحة الإدارة';
}

async function loadAllData() {
    try {
        await Promise.allSettled([
            loadOverview(),
            loadUsers(),
            loadDevices(),
            loadSubscriptions(),
            loadPlans(),
            loadLogs()
        ]);
    } catch (err) {
        console.error('Error loading admin data:', err);
    }
}

async function loadOverview() {
    try {
        const res = await fetch(`${API_BASE}/admin/overview`);
        if (!res.ok) return;
        const data = await res.json();

        if (data.stats) {
            document.getElementById('stat-parents').textContent = data.stats.total_parents || 0;
            document.getElementById('stat-devices').textContent = data.stats.total_devices || 0;
            document.getElementById('stat-online').textContent = data.stats.online_devices || 0;
            document.getElementById('stat-subs').textContent = data.stats.active_subscriptions || 0;
            document.getElementById('stat-children-sub').textContent = `${data.stats.total_children || 0} أطفال مقترنين`;
        }

        // Populate recent devices table
        const tbody = document.getElementById('overview-devices-body');
        if (!tbody) return;

        if (data.recent_devices && data.recent_devices.length > 0) {
            tbody.innerHTML = data.recent_devices.map(d => {
                const childName = (d.child && d.child.name) ? d.child.name : 'غير محدد';
                const isOnline = d.status === 'online';
                const statusBadge = isOnline
                    ? '<span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Online</span>'
                    : (d.status === 'sleep'
                        ? '<span class="px-2 py-0.5 rounded text-xs bg-amber-500/10 text-amber-400 border border-amber-500/20 font-bold">Sleep</span>'
                        : '<span class="px-2 py-0.5 rounded text-xs bg-gray-800 text-gray-400 border border-gray-700">Offline</span>');

                const batteryColor = d.battery_level > 50 ? 'text-emerald-400' : (d.battery_level > 20 ? 'text-amber-400' : 'text-red-400');
                const chargingText = d.is_charging ? ' (شحن)' : '';

                return `
                    <tr>
                        <td class="py-3 px-5 font-medium text-white flex items-center gap-2">
                            <div class="w-7 h-7 rounded-full bg-blue-600/20 text-blue-400 flex items-center justify-center text-xs font-bold">
                                ${childName.charAt(0)}
                            </div>
                            <span>${childName}</span>
                        </td>
                        <td class="py-3 px-5 text-xs text-gray-400">${d.device_name || d.model || 'جهاز أندرويد'}</td>
                        <td class="py-3 px-5 text-xs text-gray-300">${d.os_version || 'Android'} (${d.network_type || 'WiFi'})</td>
                        <td class="py-3 px-5"><span class="${batteryColor} font-bold">${d.battery_level || 100}%</span>${chargingText}</td>
                        <td class="py-3 px-5">${statusBadge}</td>
                    </tr>
                `;
            }).join('');
        } else {
            tbody.innerHTML = '<tr><td colspan="5" class="py-6 text-center text-gray-500">لا توجد أجهزة أطفال مقترنة بعد.</td></tr>';
        }
    } catch (e) {
        console.warn('loadOverview failed:', e.message);
    }
}

async function loadUsers() {
    try {
        const res = await fetch(`${API_BASE}/admin/users`);
        if (!res.ok) return;
        const raw = await res.json();
        const users = Array.isArray(raw) ? raw : (raw ? [raw] : []);

        const countBadge = document.getElementById('users-count-badge');
        if (countBadge) countBadge.textContent = `${users.length} مستخدم`;

        const tbody = document.getElementById('users-table-body');
        if (!tbody) return;

        if (users.length > 0) {
            tbody.innerHTML = users.map(u => {
                const family = (u.families && u.families.length > 0) ? u.families[0] : null;
                const familyName = family ? family.name : 'بدون عائلة';
                const tier = (family && family.subscription) ? family.subscription.tier : 'free';
                const childrenCount = (family && family.children) ? family.children.length : 0;
                const devicesCount = (family && family.devices) ? family.devices.length : 0;
                const dateStr = u.created_at ? new Date(u.created_at).toLocaleDateString('ar-SA') : '-';

                const tierBadges = {
                    'family_unlimited': '<span class="px-2 py-0.5 rounded text-xs bg-purple-500/20 text-purple-300 border border-purple-500/30 font-bold">Unlimited</span>',
                    'premium': '<span class="px-2 py-0.5 rounded text-xs bg-amber-500/20 text-amber-300 border border-amber-500/30 font-bold">Premium</span>',
                    'basic': '<span class="px-2 py-0.5 rounded text-xs bg-blue-500/20 text-blue-300 border border-blue-500/30 font-bold">Basic</span>',
                    'free': '<span class="px-2 py-0.5 rounded text-xs bg-gray-700 text-gray-300">Free</span>'
                };
                const tierBadge = tierBadges[tier] || tierBadges['free'];

                return `
                    <tr>
                        <td class="py-3.5 px-5 font-medium text-white flex items-center gap-2">
                            <div class="w-8 h-8 rounded-lg bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold text-xs">
                                ${(u.full_name || 'U').charAt(0)}
                            </div>
                            <span>${u.full_name || 'مستخدم'}</span>
                        </td>
                        <td class="py-3.5 px-5 text-xs text-gray-300 font-mono">${u.email}</td>
                        <td class="py-3.5 px-5 text-xs text-gray-400 font-mono">${u.phone_number || '-'}</td>
                        <td class="py-3.5 px-5 text-xs text-blue-300 font-medium">${familyName}</td>
                        <td class="py-3.5 px-5">${tierBadge}</td>
                        <td class="py-3.5 px-5 text-xs text-gray-300">${devicesCount} جهاز / ${childrenCount} طفل</td>
                        <td class="py-3.5 px-5"><span class="px-2 py-0.5 rounded text-xs bg-gray-800 text-gray-300 font-mono">${u.role || 'parent'}</span></td>
                        <td class="py-3.5 px-5 text-xs text-gray-400">${dateStr}</td>
                    </tr>
                `;
            }).join('');
        } else {
            tbody.innerHTML = '<tr><td colspan="8" class="py-8 text-center text-gray-500">لا يوجد أولياء أمور مسجلين حالياً.</td></tr>';
        }
    } catch (e) {
        console.warn('loadUsers failed:', e.message);
    }
}

async function loadDevices() {
    try {
        const res = await fetch(`${API_BASE}/admin/devices`);
        if (!res.ok) return;
        const raw = await res.json();
        const devices = Array.isArray(raw) ? raw : (raw ? [raw] : []);

        const countBadge = document.getElementById('devices-count-badge');
        if (countBadge) countBadge.textContent = `${devices.length} جهاز`;

        const tbody = document.getElementById('devices-table-body');
        if (!tbody) return;

        if (devices.length > 0) {
            tbody.innerHTML = devices.map(d => {
                const childName = (d.child && d.child.name) ? d.child.name : 'غير محدد';
                const isOnline = d.status === 'online';
                const statusBadge = isOnline
                    ? '<span class="px-2.5 py-0.5 rounded-full text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">Online</span>'
                    : (d.status === 'sleep'
                        ? '<span class="px-2.5 py-0.5 rounded-full text-xs bg-amber-500/10 text-amber-400 border border-amber-500/20 font-bold">Sleep</span>'
                        : '<span class="px-2.5 py-0.5 rounded-full text-xs bg-gray-800 text-gray-400 border border-gray-700">Offline</span>');

                const batteryColor = d.battery_level > 50 ? 'text-emerald-400' : (d.battery_level > 20 ? 'text-amber-400' : 'text-red-400');
                const lastSeen = d.last_seen_at ? new Date(d.last_seen_at).toLocaleTimeString('ar-SA') : '-';

                return `
                    <tr>
                        <td class="py-3.5 px-5 font-medium text-white flex items-center gap-2">
                            <div class="w-8 h-8 rounded-lg bg-purple-500/20 text-purple-400 flex items-center justify-center font-bold text-xs">
                                ${childName.charAt(0)}
                            </div>
                            <span>${childName}</span>
                        </td>
                        <td class="py-3.5 px-5 text-xs text-gray-300">
                            <div class="font-bold text-white">${d.device_name || 'جهاز طفل'}</div>
                            <div class="text-[11px] text-gray-500 font-mono">${d.model || d.device_uid || ''}</div>
                        </td>
                        <td class="py-3.5 px-5 text-xs text-gray-400">${d.os_version || 'Android'}</td>
                        <td class="py-3.5 px-5">
                            <span class="${batteryColor} font-bold">${d.battery_level || 100}%</span>
                            ${d.is_charging ? '<i class="fa-solid fa-bolt text-yellow-400 text-xs ml-1"></i>' : ''}
                        </td>
                        <td class="py-3.5 px-5 text-xs text-gray-300">${d.network_type || 'WiFi'}</td>
                        <td class="py-3.5 px-5">${statusBadge}</td>
                        <td class="py-3.5 px-5 text-xs text-gray-400">${lastSeen}</td>
                        <td class="py-3.5 px-5 text-center">
                            <div class="inline-flex items-center gap-2">
                                <button onclick="sendRemoteCommand('${d.id}', 'LOCK_DEVICE', '${d.device_name || childName}')" class="px-2.5 py-1 text-xs bg-red-600/20 text-red-400 border border-red-500/30 rounded-lg hover:bg-red-600/30 transition">
                                    <i class="fa-solid fa-lock ml-1"></i> قفل
                                </button>
                                <button onclick="sendRemoteCommand('${d.id}', 'SIREN', '${d.device_name || childName}')" class="px-2.5 py-1 text-xs bg-amber-600/20 text-amber-400 border border-amber-500/30 rounded-lg hover:bg-amber-600/30 transition">
                                    <i class="fa-solid fa-bullhorn ml-1"></i> إنذار
                                </button>
                            </div>
                        </td>
                    </tr>
                `;
            }).join('');
        } else {
            tbody.innerHTML = '<tr><td colspan="8" class="py-10 text-center text-gray-500 font-medium"><i class="fa-solid fa-mobile-screen-button text-3xl mb-2 text-gray-600 block"></i>لا توجد أجهزة أطفال مقترنة بالنظام حالياً.<br><span class="text-xs text-gray-600">بانتظار اقتران أول جهاز طفل عبر كود الاقتران.</span></td></tr>';
        }
    } catch (e) {
        console.warn('loadDevices failed:', e.message);
    }
}

async function loadSubscriptions() {
    try {
        const res = await fetch(`${API_BASE}/admin/subscriptions`);
        if (!res.ok) return;
        const raw = await res.json();
        const subs = Array.isArray(raw) ? raw : (raw ? [raw] : []);

        const countBadge = document.getElementById('subs-count-badge');
        if (countBadge) countBadge.textContent = `${subs.length} اشتراك`;

        const tbody = document.getElementById('subs-table-body');
        if (!tbody) return;

        if (subs.length > 0) {
            tbody.innerHTML = subs.map(s => {
                const familyName = s.family ? s.family.name : (s.family_id || '').substring(0, 8);
                const ownerEmail = s.family && s.family.owner ? s.family.owner.email : '-';
                const usedDevices = s.family && s.family.devices ? s.family.devices.length : 0;

                const tierBadges = {
                    'family_unlimited': '<span class="px-2.5 py-0.5 rounded-full text-xs bg-purple-500/20 text-purple-300 border border-purple-500/30 font-bold">Family Unlimited</span>',
                    'premium': '<span class="px-2.5 py-0.5 rounded-full text-xs bg-amber-500/20 text-amber-300 border border-amber-500/30 font-bold">Premium</span>',
                    'basic': '<span class="px-2.5 py-0.5 rounded-full text-xs bg-blue-500/20 text-blue-300 border border-blue-500/30 font-bold">Basic</span>',
                    'free': '<span class="px-2.5 py-0.5 rounded-full text-xs bg-gray-700 text-gray-300">Free</span>'
                };
                const tierBadge = tierBadges[s.tier] || tierBadges['free'];
                const startDate = s.starts_at ? new Date(s.starts_at).toLocaleDateString('ar-SA') : '-';
                const expiresDate = s.expires_at ? new Date(s.expires_at).toLocaleDateString('ar-SA') : 'اشتراك دائم';
                const statusBadge = s.is_active
                    ? '<span class="px-2 py-0.5 rounded text-xs bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-bold">نشط ومفعل</span>'
                    : '<span class="px-2 py-0.5 rounded text-xs bg-red-500/10 text-red-400 border border-red-500/20">معلق / متوقف</span>';

                const subJson = JSON.stringify({
                    id: s.id,
                    familyName: familyName,
                    ownerEmail: ownerEmail,
                    tier: s.tier,
                    maxDevices: s.max_devices,
                    expiresAt: s.expires_at ? s.expires_at.substring(0, 10) : '',
                    isActive: s.is_active
                }).replace(/"/g, '&quot;');

                return `
                    <tr>
                        <td class="py-3.5 px-5">
                            <div class="font-bold text-white">${familyName}</div>
                            <div class="text-xs text-gray-400 font-mono">${ownerEmail}</div>
                        </td>
                        <td class="py-3.5 px-5">${tierBadge}</td>
                        <td class="py-3.5 px-5 text-xs text-gray-300">
                            <span class="font-bold text-white">${usedDevices}</span> / ${s.max_devices || 1} أجهزة
                        </td>
                        <td class="py-3.5 px-5 text-xs text-gray-400">${startDate}</td>
                        <td class="py-3.5 px-5 text-xs text-emerald-400 font-medium">${expiresDate}</td>
                        <td class="py-3.5 px-5">${statusBadge}</td>
                        <td class="py-3.5 px-5 text-center">
                            <div class="inline-flex items-center gap-1.5">
                                <button onclick="openEditSubModal(${subJson})" class="p-1.5 text-xs bg-amber-600/20 hover:bg-amber-600/30 text-amber-400 border border-amber-500/30 rounded-lg transition" title="تعديل الترخيص">
                                    <i class="fa-solid fa-pen-to-square"></i>
                                </button>
                                <button onclick="quickRenewSub('${s.id}')" class="p-1.5 text-xs bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-400 border border-emerald-500/30 rounded-lg transition" title="تجديد سريع (+30 يوم)">
                                    <i class="fa-solid fa-rotate-right"></i>
                                </button>
                                <button onclick="toggleSub('${s.id}')" class="p-1.5 text-xs ${s.is_active ? 'bg-red-600/20 hover:bg-red-600/30 text-red-400 border-red-500/30' : 'bg-blue-600/20 hover:bg-blue-600/30 text-blue-400 border-blue-500/30'} border rounded-lg transition" title="${s.is_active ? 'تجميد الترخيص' : 'تفعيل الترخيص'}">
                                    <i class="fa-solid ${s.is_active ? 'fa-pause' : 'fa-play'}"></i>
                                </button>
                            </div>
                        </td>
                    </tr>
                `;
            }).join('');
        } else {
            tbody.innerHTML = '<tr><td colspan="7" class="py-8 text-center text-gray-500">لا توجد اشتراكات مسجلة.</td></tr>';
        }
    } catch (e) {
        console.warn('loadSubscriptions failed:', e.message);
    }
}

let _currentPlans = [];

async function loadPlans() {
    try {
        const res = await fetch(`${API_BASE}/admin/plans`);
        if (!res.ok) return;
        const raw = await res.json();
        _currentPlans = Array.isArray(raw) ? raw : (raw ? [raw] : []);

        const container = document.getElementById('plans-grid-container');
        if (!container) return;

        if (_currentPlans.length === 0) {
            container.innerHTML = `
                <div class="col-span-full py-12 text-center text-gray-500">
                    <i class="fa-solid fa-tags text-3xl mb-2 block opacity-40"></i>
                    <span>لا توجد باقات محددة حالياً. اضغط على "إضافة باقة جديدة" للبدء.</span>
                </div>
            `;
            return;
        }

        const featureLabels = {
            'live_gps': 'تتبع GPS المباشر',
            'route_replay': 'إعادة مسار 24h',
            'geofencing': 'سياج جغرافي',
            'app_blocking': 'حظر التطبيقات',
            'screen_time': 'وقت الشاشة',
            'silent_screenshot': 'لقطات صامتة',
            'live_camera': 'بث حي WebRTC',
            'ai_risk_detection': 'رصد المخاطر بالذكاء الاصطناعي',
            'zero_knowledge_e2ee': 'تشفير تام E2EE',
            'priority_support': 'دعم فني مخصص',
            'calls_log': 'سجل المكالمات',
            'sms_log': 'سجل الرسائل',
            'contacts': 'جهات الاتصال',
            'media_gallery': 'معرض الوسائط',
            'notifications': 'تدفق الإشعارات'
        };

        const tierColors = {
            'family_unlimited': 'border-purple-500/50 bg-gradient-to-b from-purple-950/30 to-gray-900/50',
            'premium': 'border-amber-500/50 bg-gradient-to-b from-amber-950/20 to-gray-900/50',
            'basic': 'border-blue-500/40 bg-gradient-to-b from-blue-950/20 to-gray-900/50',
            'free': 'border-gray-800 bg-gray-900/50'
        };

        container.innerHTML = _currentPlans.map(p => {
            let features = [];
            try {
                features = typeof p.features === 'string' ? JSON.parse(p.features) : (p.features || []);
            } catch (e) { features = []; }

            const colorClass = tierColors[p.tier] || tierColors['basic'];
            const planJson = JSON.stringify(p).replace(/"/g, '&quot;');

            return `
                <div class="rounded-2xl border ${colorClass} glass p-5 flex flex-col justify-between relative overflow-hidden group">
                    <div>
                        <div class="flex items-center justify-between mb-3">
                            <span class="px-2.5 py-0.5 rounded-full text-xs font-bold uppercase tracking-wider ${p.tier === 'family_unlimited' ? 'bg-purple-500/20 text-purple-300' : p.tier === 'premium' ? 'bg-amber-500/20 text-amber-300' : 'bg-blue-500/20 text-blue-300'}">
                                ${p.tier}
                            </span>
                            <span class="text-xs ${p.is_active ? 'text-emerald-400' : 'text-gray-500'} font-semibold">
                                ${p.is_active ? '● نشطة' : '○ معطلة'}
                            </span>
                        </div>

                        <h4 class="font-black text-white text-lg mb-1">${p.name}</h4>
                        <div class="flex items-baseline gap-1 mb-4">
                            <span class="text-3xl font-black text-white">${p.price > 0 ? p.price : 'مجاناً'}</span>
                            <span class="text-xs text-gray-400 font-bold">${p.price > 0 ? `${p.currency} / ${p.billing_cycle === 'yearly' ? 'سنة' : p.billing_cycle === 'lifetime' ? 'دائم' : 'شهر'}` : ''}</span>
                        </div>

                        <div class="space-y-2 mb-5 text-xs text-gray-300 border-t border-b border-gray-800/80 py-3">
                            <div class="flex items-center gap-2">
                                <i class="fa-solid fa-mobile-screen text-blue-400 w-4 text-center"></i>
                                <span>حتى <b>${p.max_devices}</b> أجهزة أطفال</span>
                            </div>
                            <div class="flex items-center gap-2">
                                <i class="fa-solid fa-calendar-days text-emerald-400 w-4 text-center"></i>
                                <span>المدة: <b>${p.duration_days > 0 ? `${p.duration_days} يوماً` : 'دائم بدون انتهاء'}</b></span>
                            </div>
                        </div>

                        <div class="space-y-1.5 mb-5">
                            <span class="text-[11px] font-bold text-gray-400 block mb-1">الميزات المشمولة:</span>
                            ${features.map(f => `
                                <div class="flex items-center gap-2 text-[11px] text-gray-300">
                                    <i class="fa-solid fa-check text-emerald-400 text-[10px]"></i>
                                    <span>${featureLabels[f] || f}</span>
                                </div>
                            `).join('')}
                        </div>
                    </div>

                    <div class="flex items-center gap-2 pt-3 border-t border-gray-800/60">
                        <button onclick="openEditPlanModal(${planJson})" class="flex-1 py-2 text-xs font-bold bg-gray-800 hover:bg-gray-700 text-white rounded-xl transition flex items-center justify-center gap-1.5">
                            <i class="fa-solid fa-pen-to-square"></i>
                            <span>تعديل الباقة</span>
                        </button>
                        <button onclick="deletePlan('${p.id}')" class="p-2 text-xs bg-red-600/10 hover:bg-red-600/20 text-red-400 border border-red-500/20 rounded-xl transition" title="حذف الباقة">
                            <i class="fa-solid fa-trash"></i>
                        </button>
                    </div>
                </div>
            `;
        }).join('');
    } catch (e) {
        console.warn('loadPlans failed:', e.message);
    }
}

async function loadLogs() {
    try {
        const res = await fetch(`${API_BASE}/admin/logs`);
        if (!res.ok) return;
        const raw = await res.json();
        const logs = Array.isArray(raw) ? raw : (raw ? [raw] : []);

        const logConsole = document.getElementById('log-console');
        if (!logConsole) return;

        if (logs.length > 0) {
            logConsole.innerHTML = logs.map(l => {
                const time = l.created_at ? new Date(l.created_at).toLocaleTimeString('ar-SA') : new Date().toLocaleTimeString();
                let color = 'text-gray-300';
                let icon = 'fa-circle-info';
                let label = l.action;

                if (l.action === 'RISK_ALERT') {
                    color = 'text-rose-400 font-bold';
                    icon = 'fa-triangle-exclamation';
                    label = 'تنبيه خطر ذكي (AI Risk)';
                } else if (l.action === 'SOS_ALERT') {
                    color = 'text-red-500 font-black';
                    icon = 'fa-bell';
                    label = 'استغاثة طارئة (SOS)';
                } else if (l.action === 'GEOFENCE_EXIT') {
                    color = 'text-cyan-400';
                    icon = 'fa-arrow-right-from-bracket';
                    label = 'خروج من منطقة آمنة';
                } else if (l.action === 'GEOFENCE_ENTER') {
                    color = 'text-blue-400';
                    icon = 'fa-arrow-right-to-bracket';
                    label = 'دخول إلى منطقة آمنة';
                } else if (l.action === 'COMMAND_SENT') {
                    color = 'text-amber-400';
                    icon = 'fa-bolt';
                    label = 'أمر تحكم عن بُعد';
                } else if (l.action === 'DEVICE_PAIRED') {
                    color = 'text-emerald-400 font-bold';
                    icon = 'fa-mobile-screen-button';
                    label = 'اقتران جهاز طفل';
                } else if (l.action === 'APP_BLOCKED') {
                    color = 'text-red-400';
                    icon = 'fa-ban';
                    label = 'حظر تطبيق';
                }

                // Format details
                let detailsText = '';
                if (l.details) {
                    try {
                        const parsed = typeof l.details === 'string' ? JSON.parse(l.details) : l.details;
                        if (typeof parsed === 'object') {
                            detailsText = Object.entries(parsed).map(([k, v]) => `${k}: ${v}`).join(' | ');
                        } else {
                            detailsText = String(parsed);
                        }
                    } catch (e) {
                        detailsText = String(l.details);
                    }
                }

                return `
                    <div class="${color} flex items-start gap-2 py-1 border-b border-gray-900/50">
                        <span class="text-gray-500 font-mono text-[11px] shrink-0">[${time}]</span>
                        <span class="px-1.5 py-0.2 rounded text-[10px] bg-gray-800 shrink-0 font-bold"><i class="fa-solid ${icon} ml-1"></i>${label}</span>
                        <span class="text-white font-medium shrink-0">${l.resource || 'DEVICE'}:</span>
                        <span class="text-gray-300 font-mono text-[11px]">${detailsText}</span>
                    </div>
                `;
            }).join('');
        } else {
            logConsole.innerHTML = '<div class="text-gray-500 font-mono py-8 text-center"><i class="fa-solid fa-terminal text-2xl mb-2 block opacity-40"></i>لا توجد سجلات أمنية حتى الآن. ستظهر السجلات تلقائياً عند إجراء أي نشاط أو بث أو اقتران جهاز.</div>';
        }
    } catch (e) {
        console.warn('loadLogs failed:', e.message);
    }
}

async function sendRemoteCommand(deviceId, action, deviceName) {
    const logConsole = document.getElementById('log-console');
    if (logConsole) {
        const time = new Date().toLocaleTimeString();
        const div = document.createElement('div');
        div.className = 'text-amber-300';
        div.textContent = `[${time}] [ADMIN_ACTION] Triggered ${action} for ${deviceName || deviceId}`;
        logConsole.appendChild(div);
        logConsole.scrollTop = logConsole.scrollHeight;
    }

    try {
        const mappedAction = action === 'SIREN' ? 'PLAY_ALARM' : action;
        await fetch(`${API_BASE}/devices/${deviceId}/command`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: mappedAction, params: {} })
        });
        alert(`تم إرسال أمر ${action} بنجاح للجهاز: ${deviceName || deviceId}`);
    } catch (err) {
        alert(`تم إرسال الأمر عبر كونسول الإدارة: ${action}`);
    }
}

function clearLogs() {
    const el = document.getElementById('log-console');
    if (el) el.innerHTML = '<div class="text-gray-500 font-mono py-8 text-center">تم مسح السجلات.</div>';
}

function toggleLang() {
    const html = document.documentElement;
    if (html.dir === 'rtl') {
        html.dir = 'ltr';
        html.lang = 'en';
    } else {
        html.dir = 'rtl';
        html.lang = 'ar';
    }
}

async function refreshData() {
    const icon = document.getElementById('refresh-icon');
    if (icon) icon.classList.add('animate-spin');
    await loadAllData();
    if (icon) setTimeout(() => icon.classList.remove('animate-spin'), 600);
}

// Auto initialize on DOMContentLoaded
window.addEventListener('DOMContentLoaded', () => {
    loadAllData();
    const interval = window.ADMIN_CONFIG?.refreshInterval || 10000;
    setInterval(loadAllData, interval);
});

// === Modal Helpers ===
function openModal(id) {
    const m = document.getElementById(id);
    if (m) m.classList.remove('hidden');
}

function closeModal(id) {
    const m = document.getElementById(id);
    if (m) m.classList.add('hidden');
}

// === Plans Actions ===
function openCreatePlanModal() {
    document.getElementById('planModalTitle').innerHTML = '<i class="fa-solid fa-plus text-blue-400"></i><span>إضافة باقة اشتراك جديدة</span>';
    document.getElementById('planModalIsEdit').value = '0';
    document.getElementById('planIdInput').disabled = false;
    document.getElementById('planIdInput').value = '';
    document.getElementById('planNameInput').value = '';
    document.getElementById('planTierSelect').value = 'basic';
    document.getElementById('planPriceInput').value = '9.99';
    document.getElementById('planCurrencySelect').value = 'USD';
    document.getElementById('planBillingCycleSelect').value = 'monthly';
    document.getElementById('planDurationDaysInput').value = '30';
    document.getElementById('planMaxDevicesInput').value = '3';
    document.getElementById('planIsActiveInput').checked = true;

    // Check default features
    document.querySelectorAll('input[name="plan_features"]').forEach(cb => {
        cb.checked = ['live_gps', 'geofencing', 'app_blocking', 'screen_time'].includes(cb.value);
    });

    openModal('planModal');
}

function openEditPlanModal(plan) {
    document.getElementById('planModalTitle').innerHTML = '<i class="fa-solid fa-pen-to-square text-amber-400"></i><span>تعديل باقة الاشتراك</span>';
    document.getElementById('planModalIsEdit').value = '1';
    document.getElementById('planIdInput').disabled = true;
    document.getElementById('planIdInput').value = plan.id;
    document.getElementById('planNameInput').value = plan.name;
    document.getElementById('planTierSelect').value = plan.tier;
    document.getElementById('planPriceInput').value = plan.price;
    document.getElementById('planCurrencySelect').value = plan.currency || 'USD';
    document.getElementById('planBillingCycleSelect').value = plan.billing_cycle || 'monthly';
    document.getElementById('planDurationDaysInput').value = plan.duration_days;
    document.getElementById('planMaxDevicesInput').value = plan.max_devices;
    document.getElementById('planIsActiveInput').checked = plan.is_active;

    let features = [];
    try {
        features = typeof plan.features === 'string' ? JSON.parse(plan.features) : (plan.features || []);
    } catch (e) { features = []; }

    document.querySelectorAll('input[name="plan_features"]').forEach(cb => {
        cb.checked = features.includes(cb.value);
    });

    openModal('planModal');
}

function onBillingCycleChange(val) {
    const daysInput = document.getElementById('planDurationDaysInput');
    if (val === 'monthly') daysInput.value = '30';
    else if (val === 'yearly') daysInput.value = '365';
    else if (val === 'lifetime') daysInput.value = '0';
}

async function handlePlanFormSubmit(e) {
    e.preventDefault();
    const isEdit = document.getElementById('planModalIsEdit').value === '1';
    const planId = document.getElementById('planIdInput').value.trim();

    const selectedFeatures = Array.from(document.querySelectorAll('input[name="plan_features"]:checked')).map(cb => cb.value);

    const payload = {
        id: planId,
        name: document.getElementById('planNameInput').value.trim(),
        tier: document.getElementById('planTierSelect').value,
        price: parseFloat(document.getElementById('planPriceInput').value) || 0,
        currency: document.getElementById('planCurrencySelect').value,
        billing_cycle: document.getElementById('planBillingCycleSelect').value,
        duration_days: parseInt(document.getElementById('planDurationDaysInput').value) || 0,
        max_devices: parseInt(document.getElementById('planMaxDevicesInput').value) || 1,
        features: JSON.stringify(selectedFeatures),
        is_active: document.getElementById('planIsActiveInput').checked
    };

    try {
        const url = isEdit ? `${API_BASE}/admin/plans/${planId}` : `${API_BASE}/admin/plans`;
        const method = isEdit ? 'PUT' : 'POST';

        const res = await fetch(url, {
            method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!res.ok) {
            const err = await res.json();
            throw new Error(err.error || 'Failed to save plan');
        }

        closeModal('planModal');
        alert(isEdit ? 'تم تحديث بيانات الباقة بنجاح' : 'تم إنشاء باقة الاشتراك الجديدة بنجاح');
        loadPlans();
    } catch (err) {
        alert('خطأ في حفظ الباقة: ' + err.message);
    }
}

async function deletePlan(id) {
    if (!confirm(`هل أنت متأكد من حذف الباقة (${id})؟`)) return;

    try {
        const res = await fetch(`${API_BASE}/admin/plans/${id}`, { method: 'DELETE' });
        if (!res.ok) throw new Error('Failed to delete plan');
        alert('تم حذف الباقة بنجاح');
        loadPlans();
    } catch (err) {
        alert('خطأ في حذف الباقة: ' + err.message);
    }
}

// === Subscriptions Actions ===
function openEditSubModal(sub) {
    document.getElementById('editSubId').value = sub.id;
    document.getElementById('editSubFamilyName').textContent = sub.familyName || '-';
    document.getElementById('editSubOwnerEmail').textContent = sub.ownerEmail || '-';
    document.getElementById('editSubTierSelect').value = sub.tier || 'free';
    document.getElementById('editSubMaxDevicesInput').value = sub.maxDevices || 2;
    document.getElementById('editSubExpiresAtInput').value = sub.expiresAt || '';
    document.getElementById('editSubIsActiveInput').checked = sub.isActive;

    openModal('editSubModal');
}

function setQuickExpiry(days) {
    const input = document.getElementById('editSubExpiresAtInput');
    if (days === 0) {
        input.value = '';
        return;
    }
    const d = new Date();
    d.setDate(d.getDate() + days);
    input.value = d.toISOString().substring(0, 10);
}

async function handleEditSubSubmit(e) {
    e.preventDefault();
    const id = document.getElementById('editSubId').value;
    const expiresVal = document.getElementById('editSubExpiresAtInput').value;

    const payload = {
        tier: document.getElementById('editSubTierSelect').value,
        max_devices: parseInt(document.getElementById('editSubMaxDevicesInput').value) || 2,
        is_active: document.getElementById('editSubIsActiveInput').checked
    };

    if (expiresVal) {
        payload.expires_at = new Date(expiresVal).toISOString();
    }

    try {
        const res = await fetch(`${API_BASE}/admin/subscriptions/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!res.ok) {
            const err = await res.json();
            throw new Error(err.error || 'Failed to update subscription');
        }

        closeModal('editSubModal');
        alert('تم تحديث ترخيص واشتراك العائلة بنجاح');
        loadSubscriptions();
    } catch (err) {
        alert('خطأ في تعديل الترخيص: ' + err.message);
    }
}

async function quickRenewSub(id) {
    if (!confirm('هل ترغب بتجديد اشتراك هذه العائلة فورياً بإضافة 30 يوماً؟')) return;

    try {
        const res = await fetch(`${API_BASE}/admin/subscriptions/${id}/renew`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ days: 30 })
        });

        if (!res.ok) throw new Error('Failed to renew subscription');
        alert('تم تجديد ترخيص العائلة بنجاح (+30 يوم)');
        loadSubscriptions();
    } catch (err) {
        alert('خطأ في تجديد الاشتراك: ' + err.message);
    }
}

async function toggleSub(id) {
    try {
        const res = await fetch(`${API_BASE}/admin/subscriptions/${id}/toggle`, {
            method: 'POST'
        });

        if (!res.ok) throw new Error('Failed to toggle subscription');
        loadSubscriptions();
    } catch (err) {
        alert('خطأ في تغيير حالة الترخيص: ' + err.message);
    }
}
