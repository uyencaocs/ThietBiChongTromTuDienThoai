using CaoThiThuUyen_2380616457.Services.Alerts;
using CaoThiThuUyen_2380616457.Services.Discord;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CaoThiThuUyen_2380616457.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class CameraController : ControllerBase
    {
        private readonly AlertStore _alertStore;
        private readonly IDiscordAlertService _discordAlertService;
        private readonly ILogger<CameraController> _logger;

        public CameraController(
            AlertStore alertStore,
            IDiscordAlertService discordAlertService,
            ILogger<CameraController> logger)
        {
            _alertStore = alertStore;
            _discordAlertService = discordAlertService;
            _logger = logger;
        }

        [HttpPost("upload")]
        public async Task<IActionResult> UploadImage(
            IFormFile file,
            [FromForm] string isEmergency = "false",
            [FromForm] string reason = "NGUOI_LA")
        {
            if (file == null || file.Length == 0) return BadRequest("Không tìm thấy tệp.");

            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images");
            if (!Directory.Exists(uploadsFolder)) Directory.CreateDirectory(uploadsFolder);

            var fileName = $"{Guid.NewGuid()}_{Path.GetFileName(file.FileName)}";
            var filePath = Path.Combine(uploadsFolder, fileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            Guid? alertId = null;
            if (isEmergency.Equals("true", StringComparison.OrdinalIgnoreCase))
            {
                var alert = _alertStore.Create(reason, $"/images/{fileName}");
                alertId = alert.Id;

                // Gửi cảnh báo Discord (kèm ảnh và nút tương tác) bất đồng bộ
                _ = Task.Run(async () =>
                {
                    try
                    {
                        await _discordAlertService.SendAlertAsync(alert, filePath);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Lỗi khi kích hoạt cảnh báo Discord từ upload ảnh.");
                    }
                });
            }

            return Ok(new
            {
                Message = "Lưu hình ảnh thành công",
                FilePath = $"/images/{fileName}",
                AlertId = alertId
            });
        }

        // Test Discord alert - kiểm tra trực tiếp qua API
        [HttpGet("test-discord")]
        [AllowAnonymous]
        public async Task<IActionResult> TestDiscord([FromQuery] string reason = "NGUOI_LA")
        {
            var alert = _alertStore.Create(reason, null);
            var success = await _discordAlertService.SendAlertAsync(alert);
            return Ok(new
            {
                Message = success ? "Cảnh báo Discord đã được gửi." : "Gửi cảnh báo Discord thất bại.",
                AlertId = alert.Id,
                IsBotConnected = _discordAlertService.IsBotConnected
            });
        }

        [HttpGet("images")]
        public IActionResult GetImages()
        {
            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images");
            if (!Directory.Exists(uploadsFolder)) return Ok(new List<object>());

            var files = Directory.GetFiles(uploadsFolder)
                                 .Select(f => new
                                 {
                                     FileName = Path.GetFileName(f),
                                     Url = $"/images/{Path.GetFileName(f)}"
                                 })
                                 .ToList();
            return Ok(files);
        }

        [HttpDelete("images/{fileName}")]
        [Authorize(Roles = "Admin")]
        public IActionResult DeleteImage(string fileName)
        {
            var filePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", fileName);
            if (System.IO.File.Exists(filePath))
            {
                System.IO.File.Delete(filePath);
                return Ok(new { Message = "Xóa thành công." });
            }
            return NotFound("Không tìm thấy tệp.");
        }
    }
}