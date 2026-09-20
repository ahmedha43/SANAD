using Microsoft.Extensions.Hosting.WindowsServices;
using Sanad.Service;

var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "SanadAgentService";
});
builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
