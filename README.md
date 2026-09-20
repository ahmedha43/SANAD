# منصة الرقابة الأبوية وإدارة أجهزة الأطفال المتكاملة (Parental Control Platform)

منصة احترافية، آمنة ومستقلة لإدارة ومراقبة أجهزة الأطفال عن بُعد في الوقت الفعلي (مشابهة لـ AirDroid Parental Control)، مصممة بمعمارية نظيفة (Clean Architecture) وتقنيات حديثة وقابلة للتوسع (Scalable & Production-Ready).

---

## 🏗️ هيكلية المشروع (Project Architecture)

```
clever-raman/
├── backend/            # خادم الواجهة الخلفية (Go 1.22+ & Fiber v2 + WebSockets + GORM)
├── kids-agent/         # تطبيق الطفل (Android Native Kotlin - Foreground Services & WebRTC)
├── parent-app/         # تطبيق ولي الأمر (Flutter iOS & Android - Realtime Maps & Controls)
├── admin-panel/        # لوحة الإدارة والعمليات (Web SPA Dashboard + Realtime Telemetry)
├── deploy/             # ملفات النشر والتشغيل (Docker Compose, Coturn STUN/TURN, Nginx, PostgreSQL)
└── .env.example        # متغيرات البيئة والإعدادات
```

---

## 📱 1. تطبيق ولي الأمر (Parent App - Flutter)
- **الموقع المباشر وتتبع المسار (Live GPS & Breadcrumbs)**: عرض موقع الطفل في الوقت الفعلي على الخريطة التفاعلية مع سجل التحركات الكامل (Trip Replay).
- **البث المباشر (WebRTC Streaming)**:
  - **Screen Mirroring**: مشاركة شاشة هاتف الطفل حياً بجودة متكيفة وبأقل زمن تأخير (<200ms).
  - **Remote Camera**: فتح الكاميرا الأمامية أو الخلفية عن بُعد.
  - **One-Way Audio**: الاستماع للأصوات المحيطة بجهاز الطفل عبر الميكروفون.
- **إدارة التطبيقات والحدود (App Limits & Blocking)**: إمكانية حظر أي تطبيق بضغطة زر واحدة (Toggle Block) ومزامنة الحظر فوراً مع هاتف الطفل.
- **التحكم الفوري (Remote Control)**:
  - قفل فوري للشاشة (Lock Device).
  - إطلاق جرس إنذار بصوت مرتفع للبحث عن الهاتف (Play Siren Alarm).
- **تقارير النشاط (Activity Reports)**: رسوم بيانية تفاعلية (Bar Charts) توضح ساعات الاستخدام اليومية وترتيب التطبيقات الأكثر استهلاكاً.

---

## 🤖 2. تطبيق الطفل (Kids Agent - Android Native Kotlin)
- **خدمة خلفية دائمة (Persistent Foreground Service)**: متوافقة مع متطلبات Android 14+ مع إشعار نظامي دائم وحماية من القتل التلقائي عبر `WorkManager KeepAliveWorker`.
- **مقاومة التعطيل والعبث (Anti-Tamper Protection)**:
  - `AgentAccessibilityService`: يكتشف فتح التطبيقات المحظورة ويعيد الطفل للشاشة الرئيسية فوراً، ويحمي إعدادات النظام من محاولة إزالة التثبيت.
  - `AgentDeviceAdminReceiver`: تنفيذ قفل الشاشة العتادي.
- **تتبع فائق الدقة وترشيد الطاقة**: دمج `FusedLocationProviderClient` لإرسال إحداثيات الموقع عند الحركة.
- **ترحيل الإشعارات (Notification Listener)**: ترحيل إشعارات تطبيقات التواصل الاجتماعي (WhatsApp, Telegram, etc.) إلى ولي الأمر فور ورودها.
- **محرك WebRTC**: مبني بـ `PeerConnectionFactory` و `MediaProjection` لبث الشاشة والكاميرا والصوت مع دعم STUN/TURN.

---

## ⚡ 3. خادم الباك إند (Go + Fiber + WebSockets)
- **أداء عالي وسرعة استجابة فائقة**: مبني على `gofiber/fiber/v2` المبني على FastHTTP.
- **قاعدة بيانات علائقية متينة (PostgreSQL 16)**:
  - جداول العائلات (Multi-tenancy)، الأجهزة، المستخدمين، الأوامر، النطاقات الجغرافية، والتراخيص.
- **تخزين مؤقت وتزامن فوري (Redis 7)**:
  - إدارة حالة اتصال الأجهزة (Presence TTL Heartbeats كل 30-60 ثانية).
- **WebSocket Hub & Signaling**: خادم إشارات خفيف يربط أجهزة الأطفال بأولياء أمورهم لتبادل SDP Offer/Answer و ICE Candidates.
- **أمان ومصادقة متقدمة**:
  - JWT Tokens مع تدوير Refresh Tokens.
  - توثيق الأجهزة عبر `device_uid` و `pairing_secret` المشفرين.

---

## 🎛️ 4. لوحة الإدارة (Admin Panel)
- واجهة إدارة ويب حديثة تدعم اللغتين العربية والإنجليزية (RTL / LTR).
- لوحة مراقبة حية لعدد الأجهزة المتصلة وجلسات WebRTC النشطة.
- فحص استهلاك خادم Coturn STUN/TURN وحركة البيانات.
- سجل حي ومباشر لكافة رسائل الـ WebSocket والأوامر المنفذة.

---

## 🚀 البدء والتشغيل السريع (Quick Start with Docker)

### 1. تشغيل البنية التحتية بالكامل عبر Docker Compose:
```bash
cd deploy
docker compose up -d
```
يقوم هذا الأمر بتشغيل:
- PostgreSQL 16 على المنفذ `5432`
- Redis 7 على المنفذ `6379`
- Coturn STUN/TURN على المنفذ `3478`
- خادم الباك إند Go Fiber على المنفذ `8080`
- لوحة الإدارة Admin Panel على المنفذ `3000`
- Nginx Reverse Proxy على المنفذ `80` و `443`

### 2. تشغيل الـ Backend يدوياً للتطوير المحلي (Go):
```bash
cd backend
go run cmd/server/main.go
```

### 3. تشغيل تطبيق ولي الأمر (Flutter Parent App):
```bash
cd parent-app
flutter pub get
flutter run
```

### 4. بناء تطبيق الطفل (Android Kotlin Agent):
افتح مجلد `kids-agent` في **Android Studio**، وقم بعمل Build / Run على جهاز Android تجريبي أو حقيقي.
ثم افتح التطبيق وأدخل كود الاقتران المكون من 6 أرقام المولّد من تطبيق ولي الأمر.
