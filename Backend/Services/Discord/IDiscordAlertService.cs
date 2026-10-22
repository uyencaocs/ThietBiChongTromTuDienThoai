using CaoThiThuUyen_2380616457.Services.Alerts;

namespace CaoThiThuUyen_2380616457.Services.Discord
{
    public interface IDiscordAlertService
    {
        bool IsBotConnected { get; }
        Task<bool> SendAlertAsync(SecurityAlert alert, string? localImagePath = null);
    }
}
