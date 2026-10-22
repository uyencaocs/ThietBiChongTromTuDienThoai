using System.ComponentModel.DataAnnotations;

namespace CaoThiThuUyen_2380616457.DTOs
{
    public class CreateLogDto
    {
        [Required]
        public Guid DeviceId { get; set; }

        [Required]
        [MaxLength(50)]
        public string EventType { get; set; } = string.Empty;

        public string? ImageUrl { get; set; }
    }
}