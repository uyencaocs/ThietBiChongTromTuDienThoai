using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using CaoThiThuUyen_2380616457.Data;
using CaoThiThuUyen_2380616457.Models;
using CaoThiThuUyen_2380616457.DTOs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using MimeKit;
using MailKit.Net.Smtp;
using MailKit.Security;
using BCryptNet = BCrypt.Net.BCrypt;

namespace CaoThiThuUyen_2380616457.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly IMemoryCache _cache;

        public AuthController(AppDbContext context, IConfiguration configuration, IMemoryCache cache)
        {
            _context = context;
            _configuration = configuration;
            _cache = cache;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register(RegisterDto request)
        {
            if (string.IsNullOrEmpty(request.Email) || string.IsNullOrEmpty(request.Password))
            {
                return BadRequest("Thiếu thông tin đăng ký.");
            }

            var userExists = await _context.Users.AnyAsync(u => u.Email == request.Email);
            if (userExists)
            {
                return BadRequest("Email đã được sử dụng.");
            }

            string assignedRole = (!string.IsNullOrWhiteSpace(request.Role) && request.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase))
                ? "Admin"
                : (request.Email.Contains("admin") ? "Admin" : "User");
            string passwordHash = BCryptNet.HashPassword(request.Password);

            var user = new User
            {
                Email = request.Email,
                PasswordHash = passwordHash,
                Role = assignedRole
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return Ok(new { Message = "Đăng ký thành công!", Role = assignedRole });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login(LoginDto request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);

            if (user == null || !BCryptNet.Verify(request.Password, user.PasswordHash))
            {
                return Unauthorized("Sai email hoặc mật khẩu.");
            }

            string otp = new Random().Next(100000, 999999).ToString();
            _cache.Set(request.Email, otp, TimeSpan.FromMinutes(3));

            await SendEmailAsync(request.Email, otp);

            return Ok("Vui lòng kiểm tra email để lấy mã OTP.");
        }

        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp(VerifyOtpDto request)
        {
            if (_cache.TryGetValue(request.Email, out string? savedOtp))
            {
                if (savedOtp == request.Otp)
                {
                    var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
                    if (user == null) return Unauthorized("Không tìm thấy dữ liệu người dùng.");

                    string token = GenerateJwtToken(user);
                    _cache.Remove(request.Email);

                    return Ok(new { Token = token });
                }
            }

            return Unauthorized("Mã OTP không hợp lệ hoặc đã hết hạn.");
        }

        private async Task SendEmailAsync(string toEmail, string otp)
        {
            var smtpEmail = _configuration["Smtp:Email"] ?? "";
            var smtpPassword = _configuration["Smtp:Password"] ?? "";
            var smtpHost = _configuration["Smtp:Host"] ?? "smtp.gmail.com";
            var smtpPort = int.TryParse(_configuration["Smtp:Port"], out var p) ? p : 587;

            var emailMessage = new MimeMessage();
            emailMessage.From.Add(new MailboxAddress("Hệ thống cảnh báo", smtpEmail));
            emailMessage.To.Add(new MailboxAddress("", toEmail));
            emailMessage.Subject = "Mã xác thực đăng nhập";
            emailMessage.Body = new TextPart(MimeKit.Text.TextFormat.Html)
            {
                Text = $"Mã OTP của bạn là: <b>{otp}</b>. Mã có hiệu lực trong 3 phút."
            };

            using var client = new SmtpClient();
            await client.ConnectAsync(smtpHost, smtpPort, SecureSocketOptions.StartTls);
            await client.AuthenticateAsync(smtpEmail, smtpPassword);
            await client.SendAsync(emailMessage);
            await client.DisconnectAsync(true);
        }

        private string GenerateJwtToken(User user)
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["Jwt:Key"] ?? ""));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Email, user.Email),
                new Claim(ClaimTypes.Role, user.Role),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var token = new JwtSecurityToken(
                issuer: _configuration["Jwt:Issuer"],
                audience: _configuration["Jwt:Audience"],
                claims: claims,
                expires: DateTime.UtcNow.AddHours(2),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }
}