namespace CaoThiThuUyen_2380616457.Services.Discord
{
    /// <summary>Cấu hình section "Discord" trong appsettings / user-secrets.</summary>
    public class DiscordOptions
    {
        /// <summary>Bot token từ Discord Developer Portal → Bot → Reset Token.</summary>
        public string BotToken { get; set; } = string.Empty;

        /// <summary>ID kênh nhận cảnh báo (bật Developer Mode → chuột phải kênh → Copy Channel ID).</summary>
        public ulong ChannelId { get; set; }

        /// <summary>
        /// Danh sách Discord user ID được phép bấm nút. Để trống = mọi người trong kênh.
        /// </summary>
        public List<ulong> AllowedUserIds { get; set; } = new();

        /// <summary>Webhook dự phòng (chỉ gửi văn bản, không có nút) khi bot chưa cấu hình/offline.</summary>
        public string WebhookUrl { get; set; } = string.Empty;

        public bool IsBotConfigured => !string.IsNullOrWhiteSpace(BotToken) && ChannelId != 0;
    }
}
