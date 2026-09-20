# 🛡️ سَنَد | SANAD
### منظومة الرعاية والحماية الأبوية السحابية المتكاملة
**Next-Generation Family Safety, Real-Time Monitoring & Device Management Ecosystem**

[![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go)](https://go.dev/)
[![Fiber](https://img.shields.io/badge/Backend-Fiber_v3-000000?style=flat)](https://gofiber.io/)
[![PHP](https://img.shields.io/badge/Web_Platforms-PHP_8.2+-777BB4?style=flat&logo=php)](https://php.net/)
[![Flutter](https://img.shields.io/badge/Parent_App-Flutter_3.x-02569B?style=flat&logo=flutter)](https://flutter.dev/)
[![Android Kotlin](https://img.shields.io/badge/Kids_Agent-Android_Native_Kotlin-3DDC84?style=flat&logo=android)](https://developer.android.com/)
[![.NET](https://img.shields.io/badge/Windows_Agent-.NET_8_C%23-512BD4?style=flat&logo=dotnet)](https://dotnet.microsoft.com/)
[![WebRTC](https://img.shields.io/badge/Live_Stream-WebRTC_<200ms-333333?style=flat&logo=webrtc)](https://webrtc.org/)
[![Docker](https://img.shields.io/badge/Deployment-Docker_Compose-2496ED?style=flat&logo=docker)](https://docker.com/)

---

## 📖 جدول المحتويات (Table of Contents)
- [🌟 نبذة عن النظام (Overview)](#-نبذة-عن-النظام-overview)
- [🏗️ الهيكلية البرمجية الشاملة (System Architecture)](#️-الهيكلية-البرمجية-الشاملة-system-architecture)
- [💻 1. وكيل نظام ويندوز (Windows Agent - C# .NET 8)](#-1-وكيل-نظام-ويندوز-windows-agent---c-net-8)
- [📱 2. تطبيق الطفل للهواتف (Kids Agent - Android Native Kotlin)](#-2-تطبيق-الطفل-للهواتف-kids-agent---android-native-kotlin)
- [🌐 3. منصة أولياء الأمور السحابية (Parent Web Dashboard - PHP 8)](#-3-منصة-أولياء-الأمور-السحابية-parent-web-dashboard---php-8)
- [📱 4. تطبيق ولي الأمر للأجهزة الذكية (Parent Mobile App - Flutter)](#-4-تطبيق-ولي-الأمر-للأجهزة-الذكية-parent-mobile-app---flutter)
- [🎛️ 5. لوحة المشرف العام (Master Admin Panel - PHP 8)](#-5-لوحة-المشرف-العام-master-admin-panel---php-8)
- [⚡ 6. الخادم الخلفي والإشارات (Backend & Signaling Engine - Go Fiber)](#-6-الخادم-الخلفي-والإشارات-backend--signaling-engine---go-fiber)
- [🛰️ 7. بنية الوسائط المباشرة (Coturn WebRTC Relay)](#️-7-بنية-الوسائط-المباشرة-coturn-webrtc-relay)
- [🔄 8. نظام الإعداد المركزي الموحد (Single Source of Truth IP Config)](#-8-نظام-الإعداد-المركزي-الموحد-single-source-of-truth-ip-config)
- [🚀 9. دليل التشغيل السريع (Quick Start Guide)](#-9-دليل-التشغيل-السريع-quick-start-guide)
- [🛡️ 10. دروع الحماية والأمان (Security & Anti-Tamper)](#️-10-دروع-الحماية-والأمان-security--anti-tamper)

---

## 🌟 نبذة عن النظام (Overview)

منظومة **سَنَد (SANAD)** هي منصة سيادية متكاملة ومستقلة 100% لإدارة ومتابعة أجهزة الأطفال (هواتف أندرويد + حواسيب ويندوز) عن بُعد في الوقت الفعلي. تمنح المنظومة أولياء الأمور تحكماً شاملاً بالبث المباشر (الشاشة، الكاميرا، الصوت المحيط، واللاسلكي PTT)، وتتبع الموقع الجغرافي الحي GPS، وإدارة وقت الشاشة والتطبيقات، وتصفية الويب، مع لوحات تحكم عصرية بنظام Glassmorphism الداكن الفاخر، وبنية تحتية مشفرة بتقنية **E2EE (End-to-End Encryption)**.

---

## 🏗️ الهيكلية البرمجية الشاملة (System Architecture)

```
SANAD/
├── backend/            # خادم الواجهة الخلفية ونظام الإشارات (Go Fiber v3 + GORM + WebSockets)
├── web-php/            # لوحة تحكم أولياء الأمور السحابية (PHP 8 + Dark Glassmorphism UI)
├── admin-panel/        # لوحة المشرف العام ومراقبة السيرفرات والتراخيص (PHP 8)
├── kids-agent/         # تطبيق الطفل لنظام أندرويد (Android Native Kotlin + Device Owner)
├── windows-agent/      # عميل مراقبة وإدارة حواسيب ويندوز (C# .NET 8 + SIPSorcery WebRTC)
├── parent-app/         # تطبيق ولي الأمر للهواتف الذكية (Flutter iOS & Android)
├── deploy/             # ملفات النشر بالحاويات (Docker Compose + Coturn + Nginx + Postgres)
├── server_config.json  # ملف الإعدادات المركزي الموحد لجميع عناوين الـ IP والمنافذ
├── update_server_ip.py # محرك التحديث التلقائي لكافة مكونات المشروع الـ 13
└── update_server_ip.ps1# غلاف PowerShell السريع لتغيير IP السيرفر بضغطة واحدة
```

---

## 💻 1. وكيل نظام ويندوز (Windows Agent - C# .NET 8)

وكيل ويندوز متطور ومحمي برمجياً ليعمل كـ Background Service و UI Tray:
- **🖥️ بث الشاشة الحية (Live Screen Mirroring)**: بث شاشة الكمبيوتر بدقة عالية وزمن تأخير فائق الصغر عبر WebRTC ومكتبة `SIPSorcery`.
- **📸 لقطات شاشة صامتة فورية (Silent Instant Screenshots)**: التقاط الشاشة وحفظها أو إرسالها دون أي وميض أو صوت.
- **🔒 قفل الشاشة التام (Hardware Lock Overlay)**: واجهة قفل ملء الشاشة بنمط `TopMost` تمنع فتح مدير المهام أو تبديل النوافذ حتى يرفع ولي الأمر القفل.
- **📊 مراقبة العمليات والتطبيقات (Active Window & Process Monitor)**: حصر البرامج النشطة وحظر الألعاب والتطبيقات غير المصرح بها فور تشغيلها.
- **🌐 تصفية الويب (Web Filtering)**: مراقبة النطاقات وحظر المواقع الخطرة.
- **🔊 صفارة الإنذار العتادية (Hardware Siren Alarm)**: تشغيل صوت استغاثة مرتفع عبر مكتبة `NAudio`.
- **🚀 بدء تشغيل تلقائي ومقاومة الإيقاف (Auto-Start & Self-Recovery)**: تسجيل في بيئة النظام وحماية من الإغلاق العشوائي.

---

## 📱 2. تطبيق الطفل للهواتف (Kids Agent - Android Native Kotlin)

عميل أصلي لنظام أندرويد متوافق مع Android 9 وحتى Android 14+:
- **🛡️ وضع مالك الجهاز المتقدم (Enterprise Device Owner)**: منع إلغاء التثبيت كلياً، وحظر إعدادات الجهاز، ومنع تنزيل التطبيقات الجديدة أو التعديل على أذونات النظام.
- **📡 محرك البث المتعدد (Multi-Stream WebRTC Engine)**:
  - بث شاشة الجهاز حياً عبر `MediaProjection API`.
  - فتح الكاميرا الأمامية والخلفية عن بُعد.
  - الاستماع للصوت المحيط عبر الميكروفون الحساس.
  - جهاز الاتصال اللاسلكي الفوري **Walkie-Talkie (PTT)** وتجاوز وضع الصامت لمخاطبة الطفل عبر مكبر الصوت.
- **📍 تتبع جغرافي فائق الدقة (Fused GPS Tracking & Breadcrumbs)**: تسجيل مسار الطفل بدقة متناهية وإعادة عرض الرحلات.
- **🔕 حظر التطبيقات بضغطة زر**: عبر خدمة `AccessibilityService` لمنع فتح أي تطبيق محظور وإعادة الطفل للشاشة الرئيسية فوراً.
- **💬 التقاط الإشعارات والمكالمات والرسائل**: ترحيل إشعارات التواصل (واتساب، تيليجرام...) وسجلات المكالمات والرسائل النصية SMS والوسائط.
- **📲 مراقب بطاقة الاتصال (SIM Card Watcher)**: تنبيه فوري للأب عند تغيير أو نزع شريحة SIM.

---

## 🌐 3. منصة أولياء الأمور السحابية (Parent Web Dashboard - PHP 8)

واجهة مستخدم احترافية بالكامل بنظام **Dark Glassmorphism Luxury UI** تعمل على المنفذ `8085`:
- **🔄 مبدّل الأجهزة الذكي (Device Dock Switcher)**: شريط تفاعلي علوي يعرض كافة أجهزة العائلة (حواسيب وهواتف) مع نسبة البطارية، ونوع الجهاز، وحالة الاتصال الحية، والتبديل السلس بينها بضغطة زر.
- **⚡ أوامر التحكم الفوري عن بُعد (12 Remote Controls)**:
  - التقاط شاشة صامت فورياً.
  - فتح البث المباشر للكاميرا أو الشاشة أو الصوت المحيط.
  - إطلاق وإيقاف صفارة الإنذار.
  - قفل وإلغاء قفل الجهاز.
  - وضع التخفي (إخفاء الأيقونة كلياً وتفعيل كود الاتصال السري `*#2026#*`).
  - حظر إزالة التطبيق وحظر الدخول لإعدادات أندرويد.
  - مزامنة كافة سجلات الجهاز فورياً.
- **🗺️ خريطة حية وتسييج جغرافي (Interactive Live Map & Geofencing)**: رسم المناطق الآمنة (المنزل، المدرسة، النادي) وتلقي إشعارات فورية عند الدخول أو الخروج.
- **🔐 تشفير شامل من طرف لطرف (Zero-Knowledge E2EE)**: تشفير الصور، والمكالمات، والمواقع بمفتاح خاص لا يمكن حتى لسيرفر الاستضافة فك تشفيره.
- **⏰ حدود وقت الشاشة وموعد النوم (Bedtime Schedules)**: إيقاف تشغيل الجهاز تلقائياً في أوقات الدراسة والنوم.

---

## 📱 4. تطبيق ولي الأمر للأجهزة الذكية (Parent Mobile App - Flutter)

تطبيق Cross-Platform متطور مبني بأحدث إصدارات Flutter:
- تحكم كامل أثناء التنقل مع لوحة مراقبة حية وإشعارات Push فورية.
- عرض مسارات GPS التفاعلية مع مشغل إعادة حركة المسار (Trip Replay).
- واجهات متطابقة مع أحدث معايير Material 3 و iOS Human Interface.

---

## 🎛️ 5. لوحة المشرف العام (Master Admin Panel - PHP 8)

لوحة الإدارة المركزية المستقلة لمزود الخدمة والمدير العام على المنفذ `3080`:
- **👥 إدارة حسابات أولياء الأمور والعائلات**: متابعة الحسابات المفعلة وأجهزة الأطفال المرتبطة.
- **👑 إدارة الباقات والاشتراكات**: التحكم في مدد التراخيص وحدود عدد الأجهزة المسموحة لكل باقة.
- **🖥️ مراقبة البنية التحتية وخوادم Coturn**: قياس استهلاك الـ Bandwidth، وحالة حاويات Docker، وأداء خوادم WebRTC.
- **📜 سجلات الأمان والبث المباشر (Live Security Logs)**: مراقبة جلسات البث والاتصالات عبر WebSockets.

---

## ⚡ 6. الخادم الخلفي والإشارات (Backend & Signaling Engine - Go Fiber)

نواة النظام المكتوبة بلغة **Go** لضمان أعلى كفاءة وأقل استهلاك للموارد:
- **محرك خفيف وفائق السرعة**: مبني على `Fiber v3` لمعالجة آلاف الاتصالات المتزامنة.
- **WebSocket Signaling Hub**: ترحيل الإشارات (SDP / ICE Candidates) لإنشاء اتصالات الـ Peer-to-Peer بين الأجهزة واللوحات السحابية.
- **قواعد بيانات مزدوجة**:
  - **PostgreSQL 16**: لحفظ بيانات الحسابات، الأجهزة، المناطق الجغرافية، والاشتراكات.
  - **Redis 7**: لإدارة الجلسات الحية وعدادات الـ Heartbeats في الوقت الحقيقي.

---

## 🛰️ 7. بنية الوسائط المباشرة (Coturn WebRTC Relay)

- خادم **Coturn** احترافي لخدمات STUN و TURN و TURNS لتجاوز قيود الجدران النارية والـ NAT المتماثل (Symmetric NAT).
- يدعم التبديل التلقائي لـ Relay في حالة حجب اتصالات P2P المباشرة.
- نطاق منافذ وسائط محكم ومخصص لتفادي قيود شركات الاستضافة والـ VPS.

---

## 🔄 8. نظام الإعداد المركزي الموحد (Single Source of Truth IP Config)

لن تحتاج أبداً إلى تعديل عناوين الـ IP أو المنافذ يدوياً في ملفات الأكواد المتفرقة! يشتمل المشروع على نظام إدارة مركزي يحدث **13 ملفاً حيوياً دفعة واحدة**:

1. افتح الملف المركزي: `server_config.json`
```json
{
  "server": {
    "ip": "YOUR_SERVER_IP",
    "domain": ""
  },
  "ports": {
    "backend_http": 8080,
    "backend_ws": 8080,
    "admin_panel": 3080,
    "php_dashboard": 8085,
    "coturn_listening": 3478,
    "coturn_tls": 5349
  }
}
```
2. شغّل أمر التحديث عبر PowerShell:
```powershell
.\update_server_ip.ps1 -ServerIp "10.20.30.40"
```
أو عبر Python:
```bash
py update_server_ip.py --ip 10.20.30.40
```
يقوم المحرك تلقائياً بتحديث:
- عميل ويندوز (`AgentConfig.cs`, `WebRtcLiveStreamService.cs`, و `config.json`).
- تطبيق Flutter (`api_constants.dart`, `live_stream_screen.dart`, و `app_unit_test.dart`).
- تطبيق أندرويد (`MainActivity.kt`, و `AgentWebSocketClient.kt`).
- البنية التحتية (`docker-compose.yml`, و `turnserver.conf`).
- منصات الويب (`admin.js`, `api.js`, و `ws.js`).

---

## 🚀 9. دليل التشغيل السريع (Quick Start Guide)

### 🐳 1. تشغيل الخوادم الخلفية عبر Docker:
```bash
cd deploy
docker compose up -d
```
المنافذ النشطة:
- **Backend API & WebSockets**: `http://localhost:8080`
- **Parent Web Dashboard**: `http://localhost:8085`
- **Master Admin Panel**: `http://localhost:3080`
- **Coturn STUN/TURN**: `localhost:3478`

### 💻 2. تشغيل وكيل ويندوز (Windows Agent):
شغّل السكربت الجاهز في جذر المشروع:
```cmd
run-windows-agent.bat
```
أو قم بالبناء المباشر عبر .NET CLI:
```bash
dotnet run --project windows-agent/src/Sanad.UI/Sanad.UI.csproj
```

### 📱 3. بناء تطبيق أندرويد (Kids Agent):
افتح مجلد `kids-agent` في **Android Studio** وقم بعمل Build APK أو تشغيله مباشرة على الجهاز.

### 📱 4. تشغيل تطبيق ولي الأمر (Flutter):
```bash
cd parent-app
flutter pub get
flutter run
```

---

## 🛡️ 10. دروع الحماية والأمان (Security & Anti-Tamper)

- **حماية الأجهزة العتادية (Device Owner Protection)** لمنع مسح التطبيق دون كلمة مرور ولي الأمر.
- **تشفير تام 256-bit AES-GCM** مع تبادل مفاتيح آمن.
- **حماية كود الاتصال السري**: إمكانية إخفاء أيقونة التطبيق تماماً وتشغيله فقط بإدخال الكود المخصص من لوحة الاتصال (`*#2026#*`).
- **سجلات تشغيلية ومراقبة فورية للأنشطة المشبوهة بالذكاء الاصطناعي (AI Risk Detection)**.

---

## 📄 الترخيص (License)
هذا المشروع مخصص للأغراض الأسرية والرقابة الأبوية القانونية والمصرح بها لحماية الأطفال والقصّر.
