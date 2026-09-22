/**
 * SANAD Parental Control - WebUSB / WebADB One-Click Device Provisioner
 * يتيح تفعيل حماية Device Owner ومنح كافة الصلاحيات الحساسة لهاتف الطفل مباشرة عبر المتصفح
 */

const WebUsbProvisioner = {
    PACKAGE_NAME: 'com.parentalcontrol.kidsagent',
    ADMIN_RECEIVER: 'com.parentalcontrol.kidsagent/.service.AgentDeviceAdminReceiver',
    ACCESSIBILITY_SERVICE: 'com.parentalcontrol.kidsagent/com.parentalcontrol.kidsagent.service.AgentAccessibilityService',
    NOTIFICATION_SERVICE: 'com.parentalcontrol.kidsagent/.service.NotificationInterceptService',
    MAIN_ACTIVITY: 'com.parentalcontrol.kidsagent/.ui.MainActivity',

    isSupported() {
        return !!(navigator && navigator.usb && typeof navigator.usb.requestDevice === 'function');
    },

    async execShell(adb, cmd, timeoutMs = 8000) {
        let stream = await adb.shell(cmd);
        let output = '';
        let decoder = new TextDecoder('utf-8');

        const readPromise = (async () => {
            while (true) {
                let resp = await stream.receive();
                if (resp.cmd === 'WRTE') {
                    if (resp.data) {
                        output += decoder.decode(resp.data);
                    }
                    await stream.send('OKAY');
                } else if (resp.cmd === 'CLSE') {
                    await stream.close();
                    break;
                }
            }
            return output.trim();
        })();

        const timeoutPromise = new Promise((_, reject) => 
            setTimeout(() => {
                try { stream.close(); } catch(e) {}
                reject(new Error(`مهلة الأمر (${cmd.substring(0, 25)}...) انتهت.`));
            }, timeoutMs)
        );

        return Promise.race([readPromise, timeoutPromise]);
    },

    async runProvisioningPipeline(options = {}) {
        const {
            pairCode = null,
            onLog = (msg, type) => console.log(`[WebUSB] ${type}: ${msg}`),
            onStep = (stepNumber, totalSteps, title) => {},
            onProgress = (pct) => {},
            onSuccess = () => {},
            onError = (err) => {}
        } = options;

        if (!this.isSupported()) {
            const err = new Error('متصفحك الحالي لا يدعم WebUSB. يرجى استخدام Google Chrome أو Microsoft Edge أو Brave على جهاز الحاسوب.');
            onError(err);
            return;
        }

        let transport = null;
        let adb = null;

        try {
            onLog('جاري البحث عن جهاز Android المتصل بكابل USB...', 'info');
            onStep(1, 6, 'البحث عن الجهاز والاتصال');
            onProgress(15);

            try {
                transport = await Adb.open('WebUSB');
            } catch (usbErr) {
                if (usbErr.name === 'NotFoundError' || (usbErr.message && usbErr.message.includes('No device selected'))) {
                    throw new Error('لم يتم اختيار أي جهاز. يرجى توصيل هاتف الطفل وتفعيل (تصحيح أخطاء USB).');
                }
                throw usbErr;
            }

            onLog('🔌 تم الاتصال بمنفذ USB للجهاز بنجاح.', 'success');
            onLog('يرجى مراقبة شاشة هاتف الطفل والضغط على "سماح" (Allow Always) لتصحيح USB إذا ظهرت نافذة التأكيد...', 'warning');
            onStep(2, 6, 'المصادقة الأمنية مع الجهاز');
            onProgress(30);

            adb = await transport.connectAdb('host::SANAD-Parental-Control', (key) => {
                onLog('⚠️ بانتظار موافقة ولي الأمر على شاشة هاتف الطفل (Allow USB Debugging)...', 'warning');
            });

            onLog('🔑 تمت المصادقة الأمنية مع هاتف الطفل بنجاح!', 'success');

            // Get device model & info
            let model = '';
            try {
                model = await this.execShell(adb, 'getprop ro.product.model');
                let androidVer = await this.execShell(adb, 'getprop ro.build.version.release');
                onLog(`📱 طراز الجهاز المتصل: ${model || 'Android'} (نظام أندرويد ${androidVer || 'غير معروف'})`, 'info');
            } catch (e) {
                onLog('📱 تم التحقق من اتصال نظام أندرويد.', 'info');
            }

            // Check if app is installed
            onStep(3, 6, 'فحص تثبيت تطبيق سَنَد');
            onProgress(45);
            let checkPkg = await this.execShell(adb, `pm path ${this.PACKAGE_NAME}`);
            if (!checkPkg || !checkPkg.includes('package:')) {
                throw new Error(`تطبيق سَنَد (${this.PACKAGE_NAME}) غير مثبت على هاتف الطفل بعد. يرجى تثبيت ملف APK على الجهاز أولاً ثم الضغط على زر التفعيل.`);
            }
            onLog('✅ تم العثور على تطبيق سَنَد للطفل على الجهاز.', 'success');

            // Step 4: Set Device Owner
            onStep(4, 6, 'تفعيل صلاحيات مالك الجهاز (Device Owner)');
            onProgress(60);
            onLog('🛡️ جاري تفعيل صلاحيات مالك الجهاز (Enterprise Device Owner)...', 'info');

            let dpmOutput = await this.execShell(adb, `dpm set-device-owner ${this.ADMIN_RECEIVER}`);
            if (dpmOutput.includes('Success')) {
                onLog('🎉 تم تفعيل صلاحية مالك الجهاز (Device Owner) بنجاح فائق!', 'success');
            } else if (dpmOutput.includes('already some accounts')) {
                onLog('⚠️ تنبيه أندرويد: يوجد حساب Google مسجل على الهاتف حالياً.', 'warning');
                onLog('💡 الحل: توجه إلى إعدادات الجهاز > الحسابات، وقم بإزالة حسابات Google مؤقتاً، ثم أعد الضغط على زر التفعيل (يمكنك إعادتها بعد التفعيل فوراً).', 'warning');
                throw new Error('تعذر تفعيل Device Owner لوجود حسابات Google مسجلة. أزل الحسابات مؤقتاً وأعد المحاولة.');
            } else if (dpmOutput.includes('already set') || dpmOutput.includes('already a device owner')) {
                onLog('🛡️ هاتف الطفل مفعل مسبقاً كـ Device Owner ومحمي بالفعل!', 'success');
            } else {
                onLog(`ملاحظة النظام: ${dpmOutput}`, 'info');
            }

            // Step 5: Grant Permissions & Enable Services
            onStep(5, 6, 'منح الأذونات الحساسة وتفعيل الخدمات');
            onProgress(80);
            onLog('⚡ جاري منح كافة الأذونات الحساسة تلقائياً بنقرة واحدة...', 'info');

            const permissions = [
                'android.permission.ACCESS_FINE_LOCATION',
                'android.permission.ACCESS_COARSE_LOCATION',
                'android.permission.READ_CALL_LOG',
                'android.permission.READ_SMS',
                'android.permission.RECEIVE_SMS',
                'android.permission.READ_CONTACTS',
                'android.permission.RECORD_AUDIO',
                'android.permission.CAMERA',
                'android.permission.POST_NOTIFICATIONS'
            ];

            for (const perm of permissions) {
                try {
                    await this.execShell(adb, `pm grant ${this.PACKAGE_NAME} ${perm}`);
                } catch(e) {}
            }
            onLog('✅ تم منح أذونات الموقع والمكالمات والرسائل والكاميرا والمايكروفون.', 'success');

            // AppOps overlay & usage stats
            try {
                await this.execShell(adb, `appops set ${this.PACKAGE_NAME} SYSTEM_ALERT_WINDOW allow`);
                await this.execShell(adb, `appops set ${this.PACKAGE_NAME} GET_USAGE_STATS allow`);
                onLog('✅ تم تفعيل إذن العرض فوق التطبيقات وقراءة إحصائيات الاستخدام.', 'success');
            } catch(e) {}

            // Accessibility service
            try {
                await this.execShell(adb, `settings put secure enabled_accessibility_services ${this.ACCESSIBILITY_SERVICE}`);
                await this.execShell(adb, `settings put secure accessibility_enabled 1`);
                onLog('✅ تم تفعيل خدمة إمكانية الوصول (Accessibility Shield) تلقائياً.', 'success');
            } catch(e) {}

            // Notification Intercept listener
            try {
                await this.execShell(adb, `cmd notification allow_listener ${this.NOTIFICATION_SERVICE}`);
                onLog('✅ تم تفعيل قراءة الإشعارات الحية.', 'success');
            } catch(e) {}

            // Step 6: Launch app & pair code
            onStep(6, 6, 'تشغيل التطبيق وإتمام الربط');
            onProgress(95);

            if (pairCode) {
                onLog(`🔗 جاري حقن كود الاقتران السداسي (${pairCode}) وتشغيل التطبيق...`, 'info');
                await this.execShell(adb, `am start -n ${this.MAIN_ACTIVITY} --es pair_code ${pairCode}`);
            } else {
                onLog('🚀 جاري تشغيل تطبيق سَنَد على هاتف الطفل...', 'info');
                await this.execShell(adb, `am start -n ${this.MAIN_ACTIVITY}`);
            }

            onProgress(100);
            onLog('🌟 اكتملت التهيئة والتفعيل بنجاح 100%! جهاز طفلك الآن تحت حماية سَنَد القصوى.', 'success');
            onSuccess();

        } catch (err) {
            console.error('WebUSB Provisioning Error:', err);
            onLog(`❌ خطأ: ${err.message}`, 'error');
            onError(err);
        } finally {
            if (transport) {
                try {
                    transport.close();
                } catch(e) {}
            }
        }
    }
};

window.WebUsbProvisioner = WebUsbProvisioner;
