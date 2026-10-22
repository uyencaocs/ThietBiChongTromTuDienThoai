using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CaoThiThuUyen_2380616457.Models
{
    // Đã xóa bỏ class SecurityCamApi bao bọc bên ngoài

    public class User
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [MaxLength(100)]
        public string Email { get; set; } = string.Empty;

        [Required]
        public string PasswordHash { get; set; } = string.Empty;

        [Required]
        public string Role { get; set; } = "User";

        public ICollection<Device>? Devices { get; set; }
    }

    public class Device
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public Guid UserId { get; set; }

        [Required]
        [MaxLength(100)]
        public string DeviceName { get; set; } = string.Empty;

        public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;

        [ForeignKey("UserId")]
        public User? User { get; set; }

        public MonitoringSetting? MonitoringSetting { get; set; }
        public ICollection<AccessLog>? AccessLogs { get; set; }
    }

    public class MonitoringSetting
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public Guid DeviceId { get; set; }

        public double NoiseThreshold { get; set; } = 70.0;

        [MaxLength(5)]
        public string ActiveFrom { get; set; } = "22:00";

        [MaxLength(5)]
        public string ActiveTo { get; set; } = "06:00";

        [ForeignKey("DeviceId")]
        public Device? Device { get; set; }
    }

    public class AccessLog
    {
        [Key]
        public long Id { get; set; }

        [Required]
        public Guid DeviceId { get; set; }

        [Required]
        [MaxLength(50)]
        public string EventType { get; set; } = string.Empty;

        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        public string? ImageUrl { get; set; }

        [ForeignKey("DeviceId")]
        public Device? Device { get; set; }
    }
}