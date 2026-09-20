using System;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;
using Sanad.Core.Services;

namespace Sanad.UI.Forms
{
    public class PairingForm : Form
    {
        private readonly ApiClient _apiClient;
        private readonly ConfigService _configService;
        private TextBox _txtCode = null!;
        private TextBox _txtServer = null!;
        private Button _btnPair = null!;
        private Label _lblStatus = null!;

        public bool IsPairingSuccessful { get; private set; } = false;

        public PairingForm(ApiClient apiClient, ConfigService configService)
        {
            _apiClient = apiClient;
            _configService = configService;
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            this.Text = "منظومة سَنَد - إقران جهاز الكمبيوتر";
            this.Size = new Size(500, 480);
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(15, 23, 42); // #0F172A
            this.ForeColor = Color.White;
            this.RightToLeft = RightToLeft.Yes;
            this.RightToLeftLayout = true;

            var panel = new Panel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(30)
            };

            var iconLabel = new Label
            {
                Text = "🛡️",
                Font = new Font("Segoe UI Emoji", 36),
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Top,
                Height = 60
            };

            var titleLabel = new Label
            {
                Text = "سَنَد | SANAD",
                Font = new Font("Segoe UI", 18, FontStyle.Bold),
                ForeColor = Color.FromArgb(96, 165, 250), // #60A5FA
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Top,
                Height = 35
            };

            var descLabel = new Label
            {
                Text = "أدخل كود الاقتران المكون من 6 أرقام الظاهر في تطبيق ولي الأمر لربط هذا الكمبيوتر بالمنظومة:",
                Font = new Font("Segoe UI", 10),
                ForeColor = Color.FromArgb(203, 213, 225),
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Top,
                Height = 45
            };

            var codePanel = new Panel { Dock = DockStyle.Top, Height = 65, Padding = new Padding(40, 10, 40, 10) };
            _txtCode = new TextBox
            {
                Font = new Font("Consolas", 22, FontStyle.Bold),
                TextAlign = HorizontalAlignment.Center,
                MaxLength = 6,
                Dock = DockStyle.Fill,
                BackColor = Color.FromArgb(30, 41, 59),
                ForeColor = Color.FromArgb(52, 211, 153), // Emerald
                BorderStyle = BorderStyle.FixedSingle,
                RightToLeft = RightToLeft.No
            };
            _txtCode.TextChanged += (s, e) =>
            {
                var norm = ApiClient.NormalizeDigits(_txtCode.Text);
                if (norm != _txtCode.Text)
                {
                    var pos = _txtCode.SelectionStart;
                    _txtCode.Text = norm;
                    _txtCode.SelectionStart = Math.Min(norm.Length, pos);
                }
            };
            codePanel.Controls.Add(_txtCode);

            var serverPanel = new Panel { Dock = DockStyle.Top, Height = 60, Padding = new Padding(40, 5, 40, 5) };
            var lblServer = new Label { Text = "عنوان الخادم (Server Host):", Font = new Font("Segoe UI", 8), ForeColor = Color.Gray, Dock = DockStyle.Top, Height = 18 };
            _txtServer = new TextBox
            {
                Text = ApiClient.CleanUrl(_configService.Current.ServerUrl),
                Font = new Font("Segoe UI", 10),
                Dock = DockStyle.Bottom,
                Height = 26,
                BackColor = Color.FromArgb(30, 41, 59),
                ForeColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle,
                RightToLeft = RightToLeft.No
            };
            serverPanel.Controls.Add(_txtServer);
            serverPanel.Controls.Add(lblServer);

            var btnPanel = new Panel { Dock = DockStyle.Top, Height = 55, Padding = new Padding(40, 8, 40, 0) };
            _btnPair = new Button
            {
                Text = "إقران هذا الكمبيوتر الآن",
                Font = new Font("Segoe UI", 11, FontStyle.Bold),
                BackColor = Color.FromArgb(37, 99, 235), // Blue #2563EB
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Dock = DockStyle.Fill,
                Cursor = Cursors.Hand
            };
            _btnPair.FlatAppearance.BorderSize = 0;
            _btnPair.Click += async (s, e) => await OnPairClickedAsync();
            btnPanel.Controls.Add(_btnPair);

            _lblStatus = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 9, FontStyle.Bold),
                ForeColor = Color.FromArgb(248, 113, 113),
                TextAlign = ContentAlignment.MiddleCenter,
                Dock = DockStyle.Fill
            };

            panel.Controls.Add(_lblStatus);
            panel.Controls.Add(btnPanel);
            panel.Controls.Add(serverPanel);
            panel.Controls.Add(codePanel);
            panel.Controls.Add(descLabel);
            panel.Controls.Add(titleLabel);
            panel.Controls.Add(iconLabel);

            this.Controls.Add(panel);
        }

        private async Task OnPairClickedAsync()
        {
            var code = _txtCode.Text.Trim();
            if (code.Length < 4)
            {
                _lblStatus.Text = "يرجى إدخال كود اقتران صالح!";
                _lblStatus.ForeColor = Color.FromArgb(248, 113, 113);
                return;
            }

            _btnPair.Enabled = false;
            _lblStatus.Text = "جاري الاتصال بالخادم والاقتران...";
            _lblStatus.ForeColor = Color.FromArgb(96, 165, 250);

            var (success, msg) = await _apiClient.PairDeviceAsync(code, _txtServer.Text.Trim());
            _btnPair.Enabled = true;

            if (success)
            {
                IsPairingSuccessful = true;
                _lblStatus.Text = msg;
                _lblStatus.ForeColor = Color.FromArgb(52, 211, 153);
                await Task.Delay(1200);
                this.DialogResult = DialogResult.OK;
                this.Close();
            }
            else
            {
                _lblStatus.Text = msg;
                _lblStatus.ForeColor = Color.FromArgb(248, 113, 113);
            }
        }
    }
}
