using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Olo.Desktop.Models;
using Olo.Desktop.Services;

namespace Olo.Desktop.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly ServerStore _store = new();
    private readonly SingBoxRunner _runner;

    public ObservableCollection<VpnServer> Servers { get; } = new();

    [ObservableProperty] private VpnServer? selectedServer;
    [ObservableProperty] private string status = "Готов";
    [ObservableProperty] private bool isConnected;
    [ObservableProperty] private string pasteText = "";
    [ObservableProperty] private string importError = "";
    [ObservableProperty] private bool preferTun;
    [ObservableProperty] private RouteMode routeMode = RouteMode.smart;
    [ObservableProperty] private LocalPolicy localPolicy = LocalPolicy.bypass;
    [ObservableProperty] private string connectLabel = "Старт";
    [ObservableProperty] private bool smartRouting = true;
    [ObservableProperty] private bool bypassLocal = true;

    public MainViewModel()
    {
        _runner = new SingBoxRunner(_store);
        _runner.Changed += () =>
        {
            Status = _runner.Status;
            IsConnected = _runner.IsRunning;
            ConnectLabel = IsConnected ? "Стоп" : "Старт";
        };
        Reload();
    }

    public void Reload()
    {
        Servers.Clear();
        var settings = _store.LoadSettings();
        RouteMode = settings.RouteMode;
        LocalPolicy = settings.LocalPolicy;
        SmartRouting = settings.RouteMode == RouteMode.smart;
        BypassLocal = settings.LocalPolicy == LocalPolicy.bypass;
        PreferTun = settings.PreferTun;
        ConnectLabel = IsConnected ? "Стоп" : "Старт";
        foreach (var s in _store.LoadServers()) Servers.Add(s);
        SelectedServer = Servers.FirstOrDefault(s => s.Id == settings.SelectedId) ?? Servers.FirstOrDefault();
        Status = _runner.Status;
    }

    private void Persist()
    {
        _store.SaveServers(Servers);
        var settings = _store.LoadSettings();
        settings.SelectedId = SelectedServer?.Id;
        settings.RouteMode = RouteMode;
        settings.LocalPolicy = LocalPolicy;
        settings.PreferTun = PreferTun;
        _store.SaveSettings(settings);
    }

    [RelayCommand]
    private async Task ToggleConnectAsync()
    {
        ImportError = "";
        if (IsConnected)
        {
            await _runner.StopAsync();
            ConnectLabel = "Старт";
            return;
        }
        if (SelectedServer is null)
        {
            Status = "Сначала добавьте сервер";
            return;
        }
        Persist();
        try
        {
            await _runner.StartAsync(SelectedServer, _store.LoadSettings());
            ConnectLabel = IsConnected ? "Стоп" : "Старт";
        }
        catch (Exception ex)
        {
            Status = ex.Message;
            IsConnected = false;
            ConnectLabel = "Старт";
        }
    }

    [RelayCommand]
    private async Task ImportAsync()
    {
        ImportError = "";
        try
        {
            var raw = PasteText.Trim();
            if (string.IsNullOrEmpty(raw)) return;
            if (SubscriptionImporter.IsSubscriptionUrl(raw))
            {
                var name = SubscriptionImporter.Remark(raw);
                var items = await SubscriptionImporter.FetchServersAsync(raw, name);
                foreach (var item in items) Servers.Add(item);
            }
            else
            {
                var many = LinkParser.ParseMany(raw);
                if (many.Count > 0) foreach (var item in many) Servers.Add(item);
                else Servers.Add(LinkParser.Parse(raw));
            }
            SelectedServer ??= Servers.LastOrDefault();
            Persist();
            PasteText = "";
            Status = $"Импортировано · серверов: {Servers.Count}";
        }
        catch (Exception ex)
        {
            ImportError = ex.Message;
        }
    }

    [RelayCommand]
    private void RemoveSelected()
    {
        if (SelectedServer is null) return;
        Servers.Remove(SelectedServer);
        SelectedServer = Servers.FirstOrDefault();
        Persist();
    }

    partial void OnSelectedServerChanged(VpnServer? value) => Persist();
    partial void OnPreferTunChanged(bool value) => Persist();

    partial void OnSmartRoutingChanged(bool value)
    {
        RouteMode = value ? RouteMode.smart : RouteMode.global;
        Persist();
    }

    partial void OnBypassLocalChanged(bool value)
    {
        LocalPolicy = value ? LocalPolicy.bypass : LocalPolicy.throughVPN;
        Persist();
    }
}
