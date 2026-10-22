using System.ComponentModel.DataAnnotations;

namespace CaoThiThuUyen_2380616457.DTOs
{
    public class CreateDeviceDto
    {
        [Required]
        [MaxLength(100)]
        public string DeviceName { get; set; } = string.Empty;
    }

    public class UpdateSettingDto
    {
        public double NoiseThreshold { get; set; }
        [MaxLength(5)]
        public string ActiveFrom { get; set; } = string.Empty;
        [MaxLength(5)]
        public string ActiveTo { get; set; } = string.Empty;
    }
}