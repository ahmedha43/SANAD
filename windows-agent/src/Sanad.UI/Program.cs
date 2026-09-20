using System;
using System.Drawing;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using Sanad.Core.Services;
using Sanad.UI.Forms;

namespace Sanad.UI
{
    internal static class Program
    {
        private static NotifyIcon? _trayIcon;
        private static LockOverlayForm? _lockForm;
        private static ApplicationContext? _appContext;

        [STAThread]
        static void Main()
        {
            var logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
            try
            {
                File.AppendAllText(logPath, $"{DateTime.Now}: Starting Main()...\n");

                AppDomain.CurrentDomain.UnhandledException += (s, e) =>
                {
                    try { File.AppendAllText(logPath, $"{DateTime.Now}: UNHANDLED EXCEPTION: {e.ExceptionObject}\n"); } catch { }
                };

                TaskScheduler.UnobservedTaskException += (s, e) =>
                {
                    try { File.AppendAllText(logPath, $"{DateTime.Now}: UNOBSERVED TASK EXCEPTION: {e.Exception}\n"); } catch { }
                    e.SetObserved();
                };

                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
                Application.ThreadException += (s, e) =>
                {
                    try { File.AppendAllText(logPath, $"{DateTime.Now}: THREAD EXCEPTION: {e.Exception}\n"); } catch { }
                };

                ApplicationConfiguration.Initialize();
                File.AppendAllText(logPath, $"{DateTime.Now}: Initialized app config\n");

                var configService = new ConfigService();
                File.AppendAllText(logPath, $"{DateTime.Now}: Loaded config. IsPaired={configService.Current.IsPaired}\n");

                var apiClient = new ApiClient(configService);
                var alarmService = new AudioAlarmService();
                var commandHandler = new CommandHandler(configService, alarmService);
                var processMonitor = new ProcessMonitorService(configService);
                var webRtcService = new WebRtcLiveStreamService(configService);
                var riskService = new RiskDetectionService(configService);
                var fileManagerService = new FileManagerService();
                var webFilterService = new WebFilterService(configService);
                var screenTimeService = new ScreenTimeService(configService);

                var wsClient = new WebSocketClientService(
                    configService,
                    commandHandler,
                    processMonitor,
                    webRtcService,
                    riskService,
                    fileManagerService,
                    webFilterService,
                    screenTimeService
                );

                var locationService = new LocationSyncService(configService);
                var appSyncService = new AppSyncService(configService);

                locationService.OnLocationUpdated += async (lat, lon, acc) =>
                {
                    await wsClient.SendLocationUpdateAsync(lat, lon, acc);
                };

                // 1. Check if device is paired
                if (!configService.Current.IsPaired)
                {
                    File.AppendAllText(logPath, $"{DateTime.Now}: Opening PairingForm dialog...\n");
                    using var pairForm = new PairingForm(apiClient, configService);
                    var res = pairForm.ShowDialog();
                    File.AppendAllText(logPath, $"{DateTime.Now}: PairingForm result={res}, Success={pairForm.IsPairingSuccessful}\n");
                    if (res != DialogResult.OK || !pairForm.IsPairingSuccessful)
                    {
                        File.AppendAllText(logPath, $"{DateTime.Now}: Exiting because not paired.\n");
                        return;
                    }
                }

                var syncContext = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();
                SynchronizationContext.SetSynchronizationContext(syncContext);

                // 2. Setup Lock Screen & Screen Time Events (Thread-safe UI marshaling)
                void ShowLockForm()
                {
                    syncContext.Post(_ =>
                    {
                        try
                        {
                            if (_lockForm == null || _lockForm.IsDisposed)
                            {
                                _lockForm = new LockOverlayForm();
                                _lockForm.Show();
                            }
                        }
                        catch (Exception ex)
                        {
                            File.AppendAllText(logPath, $"{DateTime.Now}: Error showing lock form: {ex.Message}\n");
                        }
                    }, null);
                }

                void HideLockForm()
                {
                    syncContext.Post(_ =>
                    {
                        try
                        {
                            if (_lockForm != null && !_lockForm.IsDisposed)
                            {
                                _lockForm.UnlockAndClose();
                                _lockForm = null;
                            }
                        }
                        catch (Exception ex)
                        {
                            File.AppendAllText(logPath, $"{DateTime.Now}: Error hiding lock form: {ex.Message}\n");
                        }
                    }, null);
                }

                commandHandler.OnLockRequested += ShowLockForm;
                commandHandler.OnUnlockRequested += HideLockForm;
                screenTimeService.OnScreenTimeLimitExceeded += (reason) => ShowLockForm();
                screenTimeService.OnScreenTimeAllowed += HideLockForm;

                // 3. Setup System Tray Icon
                SetupTrayIcon(configService, wsClient, apiClient, syncContext);

                // 4. Enable Auto-Start on Windows Boot
                AutoStartService.EnableAutoStart();

                // 5. Start Background Workers
                processMonitor.Start();
                wsClient.Start();
                locationService.Start();
                appSyncService.Start();
                riskService.Start();
                screenTimeService.Start();

                File.AppendAllText(logPath, $"{DateTime.Now}: All services (WS, WebRTC, ProcessMonitor, LocationSync, AppSync, RiskDetection, ScreenTime) started successfully.\n");

                // Run message loop with ApplicationContext (canonical pattern for tray-only apps)
                _appContext = new ApplicationContext();
                Application.Run(_appContext);
            }
            catch (Exception ex)
            {
                File.AppendAllText(logPath, $"{DateTime.Now}: FATAL EXCEPTION: {ex}\n");
            }
        }

        private static void SetupTrayIcon(ConfigService configService, WebSocketClientService wsClient, ApiClient apiClient, SynchronizationContext syncContext)
        {
            var menu = new ContextMenuStrip();
            var titleItem = new ToolStripMenuItem("سَنَد | حماية ورعاية الكمبيوتر نشطة 🟢") { Enabled = false, Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            var statusItem = new ToolStripMenuItem("حالة الاتصال: متصل بالخادم");
            var pairItem = new ToolStripMenuItem("إعادة تعيين الاقتران (Pairing)");
            var exitItem = new ToolStripMenuItem("خروج (Exit)");

            pairItem.Click += (s, e) =>
            {
                using var pairForm = new PairingForm(apiClient, configService);
                pairForm.ShowDialog();
            };

            exitItem.Click += (s, e) =>
            {
                var res = MessageBox.Show(
                    "هل أنت متأكد من رغبتك في إغلاق حماية سَنَد على هذا الكمبيوتر؟\nقد يتطلب ذلك إذن ولي الأمر.",
                    "تأكيد الخروج",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning
                );
                if (res == DialogResult.Yes)
                {
                    _trayIcon?.Dispose();
                    _appContext?.ExitThread();
                    Application.Exit();
                }
            };

            menu.Items.Add(titleItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(statusItem);
            menu.Items.Add(pairItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(exitItem);

            _trayIcon = new NotifyIcon
            {
                Text = "سَنَد - منظومة الرعاية الأسرية",
                Icon = SystemIcons.Shield,
                ContextMenuStrip = menu,
                Visible = true
            };

            wsClient.OnConnectionStateChanged += isConnected =>
            {
                syncContext.Post(_ =>
                {
                    try
                    {
                        if (_trayIcon != null)
                        {
                            statusItem.Text = isConnected ? "حالة الاتصال: متصل بالخادم 🟢" : "حالة الاتصال: جاري إعادة الاتصال... 🟡";
                        }
                    }
                    catch { }
                }, null);
            };

            _trayIcon.ShowBalloonTip(3000, "سَنَد للرعاية الأسرية", "حماية الكمبيوتر نشطة وتعمل بكفاءة في الخلفية.", ToolTipIcon.Info);
        }
    }
}
