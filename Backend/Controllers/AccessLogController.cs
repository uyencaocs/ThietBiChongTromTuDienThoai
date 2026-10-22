using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using CaoThiThuUyen_2380616457.Data;
using CaoThiThuUyen_2380616457.Models;
using CaoThiThuUyen_2380616457.DTOs;

namespace CaoThiThuUyen_2380616457.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AccessLogController : ControllerBase
    {
        private readonly AppDbContext _context;

        public AccessLogController(AppDbContext context)
        {
            _context = context;
        }

        [HttpPost]
        public async Task<IActionResult> CreateLog(CreateLogDto request)
        {
            var deviceExists = await _context.Devices.AnyAsync(d => d.Id == request.DeviceId);
            if (!deviceExists) return NotFound("Thiết bị không tồn tại trong hệ thống.");

            var log = new AccessLog
            {
                DeviceId = request.DeviceId,
                EventType = request.EventType,
                ImageUrl = request.ImageUrl
            };

            _context.AccessLogs.Add(log);
            await _context.SaveChangesAsync();

            return Ok(log);
        }

        [HttpGet("{deviceId}")]
        public async Task<IActionResult> GetDeviceLogs(Guid deviceId)
        {
            var logs = await _context.AccessLogs
                .Where(l => l.DeviceId == deviceId)
                .OrderByDescending(l => l.Timestamp)
                .Take(50) // Giới hạn 50 bản ghi mới nhất để giảm tải
                .ToListAsync();

            return Ok(logs);
        }
    }
}