namespace Sanad.Service;

using Sanad.Core.Services;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly ConfigService _configService;
    private readonly ApiClient _apiClient;
    private readonly AudioAlarmService _alarmService;
    private readonly CommandHandler _commandHandler;
    private readonly ProcessMonitorService _processMonitor;
    private readonly WebSocketClientService _wsClient;

    public Worker(ILogger<Worker> logger)
    {
        _logger = logger;
        _configService = new ConfigService();
        _apiClient = new ApiClient(_configService);
        _alarmService = new AudioAlarmService();
        _commandHandler = new CommandHandler(_configService, _alarmService);
        _processMonitor = new ProcessMonitorService(_configService);
        _wsClient = new WebSocketClientService(_configService, _commandHandler, _processMonitor);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("SANAD Windows Service started. Machine: {machine}", Environment.MachineName);

        _processMonitor.Start();
        _wsClient.Start();

        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(5000, stoppingToken);
        }

        _processMonitor.Stop();
        _wsClient.Stop();
        _logger.LogInformation("SANAD Windows Service stopped.");
    }
}
