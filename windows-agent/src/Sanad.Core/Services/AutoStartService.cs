using System;
using System.IO;
using Microsoft.Win32;

namespace Sanad.Core.Services
{
    public static class AutoStartService
    {
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AppName = "SanadAgent";

        public static void EnableAutoStart()
        {
            try
            {
                var exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName;
                if (string.IsNullOrEmpty(exePath) || !File.Exists(exePath)) return;

                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true);
                if (key != null)
                {
                    key.SetValue(AppName, $"\"{exePath}\"");
                    Log("[AutoStart] Successfully registered SanadAgent in Windows Startup (Run key).");
                }
            }
            catch (Exception ex)
            {
                Log($"[AutoStart] Error registering in Startup: {ex.Message}");
            }
        }

        public static void DisableAutoStart()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true);
                if (key != null && key.GetValue(AppName) != null)
                {
                    key.DeleteValue(AppName, false);
                    Log("[AutoStart] Removed SanadAgent from Windows Startup.");
                }
            }
            catch (Exception ex)
            {
                Log($"[AutoStart] Error removing from Startup: {ex.Message}");
            }
        }

        private static void Log(string message)
        {
            var logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
            try { File.AppendAllText(logPath, $"{DateTime.Now}: {message}\n"); } catch { }
            Console.WriteLine(message);
        }
    }
}
