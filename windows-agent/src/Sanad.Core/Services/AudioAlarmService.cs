using System;
using System.Media;
using System.Threading;
using System.Threading.Tasks;

namespace Sanad.Core.Services
{
    public class AudioAlarmService
    {
        private CancellationTokenSource? _alarmCts;

        public void StartAlarm()
        {
            StopAlarm();
            _alarmCts = new CancellationTokenSource();
            var token = _alarmCts.Token;

            Task.Run(() =>
            {
                while (!token.IsCancellationRequested)
                {
                    try
                    {
                        SystemSounds.Exclamation.Play();
                        Console.Beep(2000, 400);
                        Console.Beep(1200, 400);
                        Thread.Sleep(200);
                    }
                    catch
                    {
                        Thread.Sleep(1000);
                    }
                }
            }, token);
        }

        public void StopAlarm()
        {
            _alarmCts?.Cancel();
            _alarmCts = null;
        }
    }
}
