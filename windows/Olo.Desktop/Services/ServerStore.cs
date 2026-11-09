using System.Text.Json;
using Olo.Desktop.Models;

namespace Olo.Desktop.Services;

public sealed class ServerStore
{
    private readonly string _path;
    private readonly string _settingsPath;

    public ServerStore()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Olo");
        Directory.CreateDirectory(dir);
        _path = Path.Combine(dir, "olo-servers.json");
        _settingsPath = Path.Combine(dir, "settings.json");
        DataDir = dir;
    }

    public string DataDir { get; }

    public List<VpnServer> LoadServers()
    {
        if (!File.Exists(_path)) return new List<VpnServer>();
        var json = File.ReadAllText(_path);
        return JsonSerializer.Deserialize<List<VpnServer>>(json, JsonOpts()) ?? new List<VpnServer>();
    }

    public void SaveServers(IEnumerable<VpnServer> servers) =>
        File.WriteAllText(_path, JsonSerializer.Serialize(servers.ToList(), JsonOpts()));

    public AppSettings LoadSettings()
    {
        if (!File.Exists(_settingsPath)) return new AppSettings();
        return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(_settingsPath), JsonOpts())
               ?? new AppSettings();
    }

    public void SaveSettings(AppSettings settings) =>
        File.WriteAllText(_settingsPath, JsonSerializer.Serialize(settings, JsonOpts()));

    private static JsonSerializerOptions JsonOpts() => new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };
}

public sealed class AppSettings
{
    public string? SelectedId { get; set; }
    public RouteMode RouteMode { get; set; } = RouteMode.smart;
    public LocalPolicy LocalPolicy { get; set; } = LocalPolicy.bypass;
    public LocalRegion LocalRegion { get; set; } = LocalRegion.auto;
    public Protection Protection { get; set; } = new();
    public bool PreferTun { get; set; }
}
