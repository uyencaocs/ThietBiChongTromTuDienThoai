using System.Collections.Concurrent;

namespace CaoThiThuUyen_2380616457.Services.Alerts
{
    /// <summary>
    /// Kho cảnh báo trong bộ nhớ (singleton). Đủ cho 1 máy chủ LAN; dữ liệu mất
    /// khi khởi động lại. Có thể thay bằng bảng EF Core sau này.
    /// </summary>
    public class AlertStore
    {
        private const int MaxAlerts = 200;
        private readonly ConcurrentDictionary<Guid, SecurityAlert> _alerts = new();
        private readonly object _resolveLock = new();

        public SecurityAlert Create(string reason, string? imageUrl)
        {
            var alert = new SecurityAlert { Reason = reason, ImageUrl = imageUrl };
            _alerts[alert.Id] = alert;
            Prune();
            return alert;
        }

        public SecurityAlert? Get(Guid id) => _alerts.TryGetValue(id, out var a) ? a : null;

        public SecurityAlert? Latest() =>
            _alerts.Values.OrderByDescending(a => a.CreatedAt).FirstOrDefault();

        /// <summary>
        /// Chuyển alert từ Pending sang trạng thái mới. Trả về false nếu alert không
        /// tồn tại hoặc đã được người khác xử lý (chỉ lần bấm đầu tiên có hiệu lực).
        /// </summary>
        public bool TryResolve(Guid id, AlertStatus status, string handledBy, out SecurityAlert? alert)
        {
            lock (_resolveLock)
            {
                alert = Get(id);
                if (alert == null || alert.Status != AlertStatus.Pending) return false;

                alert.Status = status;
                alert.HandledBy = handledBy;
                alert.HandledAt = DateTime.UtcNow;
                return true;
            }
        }

        private void Prune()
        {
            if (_alerts.Count <= MaxAlerts) return;
            foreach (var old in _alerts.Values.OrderBy(a => a.CreatedAt).Take(_alerts.Count - MaxAlerts))
            {
                _alerts.TryRemove(old.Id, out _);
            }
        }
    }
}
