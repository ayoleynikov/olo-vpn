using Avalonia.Controls;
using Olo.Desktop.ViewModels;

namespace Olo.Desktop.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainViewModel();
    }
}
