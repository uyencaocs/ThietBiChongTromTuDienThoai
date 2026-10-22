using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using CaoThiThuUyen_2380616457.Data;
using CaoThiThuUyen_2380616457.Models;
using CaoThiThuUyen_2380616457.DTOs;
using System.IdentityModel.Tokens.Jwt;

namespace CaoThiThuUyen_2380616457.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class DeviceController : ControllerBase
    {
        private readonly AppDbContext _context;

        public DeviceController(AppDbContext context)
        {
            _context = context;
        }

        [HttpPost]
        public async Task<IActionResult> RegisterDevice(CreateDeviceDto request)
        {
            var userIdString = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                               ?? User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;

            if (!Guid.TryParse(userIdString, out Guid userId))
                return Unauthorized("Không xác định được người dùng.");

            var device = new Device
            {
                UserId = userId,
                DeviceName = request.DeviceName,
                MonitoringSetting = new MonitoringSetting() // Tạo cấu hình mặc định
            };

            _context.Devices.Add(device);
            await _context.SaveChangesAsync();

            return Ok(device);
        }

        [HttpGet]
        public async Task<IActionResult> GetMyDevices()
        {
            var userIdString = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                               ?? User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;

            if (!Guid.TryParse(userIdString, out Guid userId))
                return Unauthorized();

            var devices = await _context.Devices
                .Include(d => d.MonitoringSetting)
                .Where(d => d.UserId == userId)
                .ToListAsync();

            return Ok(devices);
        }

        [HttpPut("{id}/settings")]
        public async Task<IActionResult> UpdateSettings(Guid id, UpdateSettingDto request)
        {
            var setting = await _context.MonitoringSettings.FirstOrDefaultAsync(m => m.DeviceId == id);
            if (setting == null) return NotFound("Không tìm thấy cấu hình thiết bị.");

            setting.NoiseThreshold = request.NoiseThreshold;
            setting.ActiveFrom = request.ActiveFrom;
            setting.ActiveTo = request.ActiveTo;

            await _context.SaveChangesAsync();
            return Ok(setting);
        }
    }
}