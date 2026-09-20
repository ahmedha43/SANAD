using System;
using System.Drawing;
using System.Windows.Forms;

namespace Sanad.UI.Forms
{
    public class LockOverlayForm : Form
    {
        private bool _allowClose = false;

        public LockOverlayForm()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.TopMost = true;
            this.ShowInTaskbar = false;
            this.BackColor = Color.FromArgb(15, 23, 42); // Dark slate #0F172A
            this.StartPosition = FormStartPosition.CenterScreen;

            var panel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 5,
                BackColor = Color.Transparent
            };
            panel.RowStyles.Add(new RowStyle(SizeType.Percent, 25f));
            panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 100f));
            panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 60f));
            panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 80f));
            panel.RowStyles.Add(new RowStyle(SizeType.Percent, 35f));

            var iconLabel = new Label
            {
                Text = "🔒",
                Font = new Font("Segoe UI Emoji", 48, FontStyle.Bold),
                ForeColor = Color.FromArgb(239, 68, 68), // Red #EF4444
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Fill
            };

            var titleLabel = new Label
            {
                Text = "تم قفل هذا الكمبيوتر بواسطة منظومة سَنَد",
                Font = new Font("Segoe UI", 24, FontStyle.Bold),
                ForeColor = Color.White,
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Fill
            };

            var subtitleLabel = new Label
            {
                Text = "Device Locked by SANAD Family Safety",
                Font = new Font("Segoe UI", 14, FontStyle.Regular),
                ForeColor = Color.FromArgb(148, 163, 184), // Slate-400
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Fill
            };

            var descLabel = new Label
            {
                Text = "تم قفل الكمبيوتر عن بُعد بواسطة ولي الأمر لحمايتك أو لانتهاء وقت الشاشة المسموح به.\nيرجى التواصل مع والديك لفتحه.",
                Font = new Font("Segoe UI", 12, FontStyle.Regular),
                ForeColor = Color.FromArgb(203, 213, 225),
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Fill
            };

            panel.Controls.Add(iconLabel, 0, 1);
            panel.Controls.Add(titleLabel, 0, 2);
            panel.Controls.Add(subtitleLabel, 0, 3);
            panel.Controls.Add(descLabel, 0, 4);

            this.Controls.Add(panel);
        }

        public void UnlockAndClose()
        {
            _allowClose = true;
            this.Close();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!_allowClose && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true; // Prevent Alt+F4
            }
            base.OnFormClosing(e);
        }

        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ExStyle |= 0x80; // WS_EX_TOOLWINDOW (hide from Alt+Tab)
                return cp;
            }
        }
    }
}
