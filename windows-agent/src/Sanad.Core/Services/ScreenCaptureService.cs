using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Sanad.Core.Services
{
    public static class ScreenCaptureService
    {
        [DllImport("user32.dll")]
        private static extern IntPtr GetDesktopWindow();

        [DllImport("user32.dll")]
        private static extern IntPtr GetWindowDC(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern IntPtr ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll")]
        private static extern bool BitBlt(IntPtr hObject, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hObjectSource, int nXSrc, int nYSrc, int dwRop);

        [DllImport("user32.dll")]
        private static extern int GetSystemMetrics(int nIndex);

        private const int SM_XVIRTUALSCREEN = 76;
        private const int SM_YVIRTUALSCREEN = 77;
        private const int SM_CXVIRTUALSCREEN = 78;
        private const int SM_CYVIRTUALSCREEN = 79;
        private const int SRCCOPY = 0x00CC0020;

        public static string? CaptureScreenAsBase64Jpeg(int quality = 75)
        {
            try
            {
                // Determine virtual screen bounds (covers all monitors)
                int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
                int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
                int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
                int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);

                if (width <= 0 || height <= 0)
                {
                    var bounds = Screen.PrimaryScreen?.Bounds ?? new Rectangle(0, 0, 1920, 1080);
                    left = bounds.X;
                    top = bounds.Y;
                    width = bounds.Width;
                    height = bounds.Height;
                }

                using var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb);

                bool captured = false;
                // Method 1: Graphics.CopyFromScreen
                try
                {
                    using (var g = Graphics.FromImage(bitmap))
                    {
                        g.CopyFromScreen(left, top, 0, 0, new Size(width, height), CopyPixelOperation.SourceCopy);
                        captured = true;
                    }
                }
                catch
                {
                    captured = false;
                }

                // Method 2: Win32 GDI BitBlt fallback
                if (!captured)
                {
                    IntPtr hDesk = GetDesktopWindow();
                    IntPtr hDeskDC = GetWindowDC(hDesk);
                    using (var g = Graphics.FromImage(bitmap))
                    {
                        IntPtr hMemDC = g.GetHdc();
                        BitBlt(hMemDC, 0, 0, width, height, hDeskDC, left, top, SRCCOPY);
                        g.ReleaseHdc(hMemDC);
                    }
                    ReleaseDC(hDesk, hDeskDC);
                }

                using var ms = new MemoryStream();
                var encoder = GetEncoder(ImageFormat.Jpeg);
                if (encoder != null)
                {
                    using var encoderParams = new EncoderParameters(1);
                    encoderParams.Param[0] = new EncoderParameter(Encoder.Quality, (long)quality);
                    bitmap.Save(ms, encoder, encoderParams);
                }
                else
                {
                    bitmap.Save(ms, ImageFormat.Jpeg);
                }

                return Convert.ToBase64String(ms.ToArray());
            }
            catch (Exception ex)
            {
                var logPath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
                try { File.AppendAllText(logPath, $"{DateTime.Now}: [ScreenCapture] Exception: {ex.Message}\n"); } catch { }
                Console.WriteLine($"[ScreenCapture] Error: {ex.Message}");
                return null;
            }
        }

        public static (byte[]? data, int width, int height) CaptureScreenAsBgr(int targetWidth = 1280, int targetHeight = 720)
        {
            try
            {
                int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
                int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
                int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
                int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);

                if (width <= 0 || height <= 0)
                {
                    var bounds = Screen.PrimaryScreen?.Bounds ?? new Rectangle(0, 0, 1920, 1080);
                    left = bounds.X;
                    top = bounds.Y;
                    width = bounds.Width;
                    height = bounds.Height;
                }

                using var screenBmp = new Bitmap(width, height, PixelFormat.Format24bppRgb);
                using (var g = Graphics.FromImage(screenBmp))
                {
                    g.CopyFromScreen(left, top, 0, 0, new Size(width, height), CopyPixelOperation.SourceCopy);
                }

                // Resize to target dimensions for efficient encoding
                using var resizedBmp = new Bitmap(targetWidth, targetHeight, PixelFormat.Format24bppRgb);
                using (var gResized = Graphics.FromImage(resizedBmp))
                {
                    gResized.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBilinear;
                    gResized.DrawImage(screenBmp, 0, 0, targetWidth, targetHeight);
                }

                var bmpData = resizedBmp.LockBits(new Rectangle(0, 0, targetWidth, targetHeight), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
                int stride = bmpData.Stride;
                int rowBytes = targetWidth * 3;
                byte[] rgbValues = new byte[rowBytes * targetHeight];

                if (stride == rowBytes)
                {
                    Marshal.Copy(bmpData.Scan0, rgbValues, 0, rgbValues.Length);
                }
                else
                {
                    // Copy row by row to eliminate any stride padding
                    for (int y = 0; y < targetHeight; y++)
                    {
                        IntPtr srcRow = IntPtr.Add(bmpData.Scan0, y * stride);
                        Marshal.Copy(srcRow, rgbValues, y * rowBytes, rowBytes);
                    }
                }
                resizedBmp.UnlockBits(bmpData);

                return (rgbValues, targetWidth, targetHeight);
            }
            catch (Exception ex)
            {
                var logPath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
                try { File.AppendAllText(logPath, $"{DateTime.Now}: [ScreenCapture] CaptureScreenAsBgr error: {ex.Message}\n"); } catch { }
                return (null, 0, 0);
            }
        }

        private static ImageCodecInfo? GetEncoder(ImageFormat format)
        {
            var codecs = ImageCodecInfo.GetImageEncoders();
            foreach (var codec in codecs)
            {
                if (codec.FormatID == format.Guid)
                {
                    return codec;
                }
            }
            return null;
        }
    }
}
