using System.Text.Json.Serialization;

namespace CaoThiThuUyen_2380616457.Services.Alerts
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum AlertStatus
    {
        /// <summary>Chờ người dùng xử lý trên Discord.</summary>
        Pending,
        /// <summary>Đã xác nhận là người nhà – điện thoại tắt cảnh báo.</summary>
        ConfirmedHome,
        /// <summary>Người dùng yêu cầu báo động – điện thoại phát còi.</summary>
        AlarmTriggered
    }

    public class SecurityAlert
    {
        public Guid Id { get; init; } = Guid.NewGuid();
        /// <summary>Lý do do client gửi lên, ví dụ NGUOI_LA, RUNG_LAC.</summary>
        public string Reason { get; init; } = "NGUOI_LA";
        /// <summary>Đường dẫn tương đối của ảnh, ví dụ /images/xxx.jpg (có thể null).</summary>
        public string? ImageUrl { get; init; }
        public DateTime CreatedAt { get; init; } = DateTime.UtcNow;

        public AlertStatus Status { get; set; } = AlertStatus.Pending;
        public string? HandledBy { get; set; }
        public DateTime? HandledAt { get; set; }
        public ulong? DiscordMessageId { get; set; }
    }
}
