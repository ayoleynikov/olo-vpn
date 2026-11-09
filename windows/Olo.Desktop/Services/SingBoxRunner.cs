using System.Diagnostics;
using System.Runtime.InteropServices;
using Olo.Desktop.Models;

namespace Olo.Desktop.Services;

/// <summary>
/// Starts bundled/fetched sing-box with a generated config.
/// Default mode: mixed inbound on 127.0.0.1:7890 (no admin).
/// Optional TUN when PreferTun is set and binary supports it (Windows admin + WinTun).
/// </summary>
public sealed class SingBoxRunner : IDisposable
{
    private Process? _process;
    private readonly ServerStore _store;

    public SingBoxRunner(ServerStore store) => _store = store;

    public bool IsRunning => _process is { HasExited: false };
    public string Status { get; private set; } = "Готов";
    public event Action? Changed;

    public string ResolveBinary()
    {
        var candidates = new[]
        {
            Path.Combine(_store.DataDir, "bin", OperatingSystem.IsWindows() ? "sing-box.exe" : "sing-box"),
            Path.Combine(AppContext.BaseDirectory, "bin", OperatingSystem.IsWindows() ? "sing-box.exe" : "sing-box"),
            "sing-box"
        };
        foreach (var c in candidates)
        {
            if (c == "sing-box") continue;
            if (File.Exists(c)) return c;
        }
        return candidates[0];
    }

    public async Task StartAsync(VpnServer server, AppSettings settings, CancellationToken ct = default)
    {
        await StopAsync();
        var binary = ResolveBinary();
        if (!File.Exists(binary))
        {
            Status = $"Нет sing-box: положите бинарь в {_store.DataDir}/bin/ (scripts/fetch_singbox_windows.sh)";
            Changed?.Invoke();
            throw new FileNotFoundException(Status, binary);
        }

        var useTun = settings.PreferTun && OperatingSystem.IsWindows();
        var json = SingBoxConfigBuilder.Build(
            server, settings.RouteMode, settings.LocalPolicy, settings.LocalRegion, settings.Protection, useTun);
        var configPath = Path.Combine(_store.DataDir, "sing-box-config.json");
        await File.WriteAllTextAsync(configPath, json, ct);

        var psi = new ProcessStartInfo
        {
            FileName = binary,
            Arguments = $"run -c \"{configPath}\"",
            WorkingDirectory = _store.DataDir,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        _process = Process.Start(psi) ?? throw new InvalidOperationException("Не удалось запустить sing-box");
        Status = useTun
            ? $"TUN · {server.DisplayName}"
            : $"Proxy 127.0.0.1:7890 · {server.DisplayName}";
        Changed?.Invoke();

        _ = Task.Run(async () =>
        {
            try
            {
                var err = await _process.StandardError.ReadToEndAsync();
                await _process.WaitForExitAsync();
                if (_process.ExitCode != 0)
                {
                    Status = $"sing-box exit {_process.ExitCode}: {Trim(err)}";
                    Changed?.Invoke();
                }
            }
            catch
            {
                // ignored
            }
        }, ct);
    }

    public Task StopAsync()
    {
        if (_process is { HasExited: false })
        {
            try
            {
                _process.Kill(entireProcessTree: true);
            }
            catch
            {
                // ignored
            }
        }
        _process?.Dispose();
        _process = null;
        Status = "Отключено";
        Changed?.Invoke();
        return Task.CompletedTask;
    }

    public void Dispose() => _ = StopAsync();

    private static string Trim(string s) =>
        string.IsNullOrWhiteSpace(s) ? "" : (s.Length > 180 ? s[..180] + "…" : s.Trim());
}
