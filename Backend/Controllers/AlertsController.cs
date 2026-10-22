using CaoThiThuUyen_2380616457.Services.Alerts;
using CaoThiThuUyen_2380616457.Services.Discord;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CaoThiThuUyen_2380616457.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AlertsController : ControllerBase
    {
        private readonly AlertStore _alertStore;
        private readonly IDiscordAlertService _discordAlertService;

        public AlertsController(AlertStore alertStore, IDiscordAlertService discordAlertService)
        {
            _alertStore = alertStore;
            _discordAlertService = discordAlertService;
        }

        /// <summary>
        /// Lấy trạng thái cảnh báo mới nhất (dùng cho điện thoại lắng nghe phản hồi từ Discord).
        /// </summary>
        [HttpGet("latest")]
        public IActionResult GetLatestAlert()
        {
            var latest = _alertStore.Latest();
            if (latest == null) return NotFound("Chưa có cảnh báo nào.");
            return Ok(latest);
        }

        /// <summary>
        /// Lấy chi tiết trạng thái theo ID cảnh báo.
        /// </summary>
        [HttpGet("{id}")]
        public IActionResult GetAlertById(Guid id)
        {
            var alert = _alertStore.Get(id);
            if (alert == null) return NotFound("Không tìm thấy cảnh báo.");
            return Ok(alert);
        }

        /// <summary>
        /// Kích hoạt cảnh báo test để kiểm tra bot Discord.
        /// </summary>
        [HttpPost("test")]
        public async Task<IActionResult> TestAlert([FromQuery] string reason = "NGUOI_LA")
        {
            var alert = _alertStore.Create(reason, null);
            var success = await _discordAlertService.SendAlertAsync(alert);
            return Ok(new
            {
                Success = success,
                Alert = alert,
                IsBotConnected = _discordAlertService.IsBotConnected
            });
        }
    }
}
