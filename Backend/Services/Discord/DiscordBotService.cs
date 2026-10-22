using System.Text;
using System.Text.Json;
using CaoThiThuUyen_2380616457.Services.Alerts;
using Discord;
using Discord.WebSocket;
using Microsoft.Extensions.Options;

namespace CaoThiThuUyen_2380616457.Services.Discord
{
    public class DiscordBotService : IHostedService, IDiscordAlertService
    {
        private readonly DiscordOptions _options;
        private readonly AlertStore _alertStore;
        private readonly ILogger<DiscordBotService> _logger;
        private DiscordSocketClient? _client;
        private bool _isBotReady = false;

        public bool IsBotConnected => _isBotReady && _client?.ConnectionState == ConnectionState.Connected;

        public DiscordBotService(
            IOptions<DiscordOptions> options,
            AlertStore alertStore,
            ILogger<DiscordBotService> logger)
        {
            _options = options.Value;
            _alertStore = alertStore;
            _logger = logger;
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            if (!_options.IsBotConfigured)
            {
                _logger.LogWarning("Discord Bot chưa được cấu hình đầy đủ (BotToken hoặc ChannelId còn trống). Bot sẽ chạy ở chế độ Webhook fallback nếu có WebhookUrl.");
                return;
            }

            try
            {
                var socketConfig = new DiscordSocketConfig
                {
                    GatewayIntents = GatewayIntents.Guilds | GatewayIntents.GuildMessages,
                    AlwaysDownloadUsers = false,
                    LogLevel = LogSeverity.Info
                };

                _client = new DiscordSocketClient(socketConfig);
                _client.Log += OnLogAsync;
                _client.Ready += OnReadyAsync;
                _client.ButtonExecuted += OnButtonExecutedAsync;

                await _client.LoginAsync(TokenType.Bot, _options.BotToken);
                await _client.StartAsync();
                _logger.LogInformation("Khởi động Discord Socket Client thành công.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi khởi động Discord Bot. Hệ thống sẽ fallback sang Webhook.");
            }
        }

        public async Task StopAsync(CancellationToken cancellationToken)
        {
            if (_client != null)
            {
                try
                {
                    await _client.StopAsync();
                    await _client.LogoutAsync();
                    _client.Dispose();
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Lỗi khi tắt Discord Bot.");
                }
            }
        }

        private Task OnLogAsync(LogMessage log)
        {
            var level = log.Severity switch
            {
                LogSeverity.Critical => LogLevel.Critical,
                LogSeverity.Error => LogLevel.Error,
                LogSeverity.Warning => LogLevel.Warning,
                LogSeverity.Info => LogLevel.Information,
                LogSeverity.Verbose => LogLevel.Debug,
                LogSeverity.Debug => LogLevel.Trace,
                _ => LogLevel.Information
            };
            _logger.Log(level, log.Exception, "[Discord.Net] {Message}", log.Message);
            return Task.CompletedTask;
        }

        private Task OnReadyAsync()
        {
            _isBotReady = true;
            _logger.LogInformation("Discord Bot đã kết nối và sẵn sàng hoạt động!");
            return Task.CompletedTask;
        }

        private async Task OnButtonExecutedAsync(SocketMessageComponent component)
        {
            try
            {
                var customId = component.Data.CustomId;
                if (!customId.StartsWith("confirm_home:") && !customId.StartsWith("trigger_alarm:"))
                {
                    return;
                }

                // Kiểm tra quyền bấm nút nếu có cấu hình AllowedUserIds
                if (_options.AllowedUserIds != null && _options.AllowedUserIds.Count > 0)
                {
                    if (!_options.AllowedUserIds.Contains(component.User.Id))
                    {
                        await component.RespondAsync("❌ Bạn không có quyền thực hiện thao tác trên hệ thống an ninh này.", ephemeral: true);
                        return;
                    }
                }

                var parts = customId.Split(':', 2);
                var action = parts[0];
                if (!Guid.TryParse(parts[1], out var alertId))
                {
                    await component.RespondAsync("ID cảnh báo không hợp lệ.", ephemeral: true);
                    return;
                }

                var userDisplayName = component.User.Username;
                var now = DateTime.Now.ToString("HH:mm:ss dd/MM/yyyy");

                if (action == "confirm_home")
                {
                    bool success = _alertStore.TryResolve(alertId, AlertStatus.ConfirmedHome, userDisplayName, out var alert);
                    if (success)
                    {
                        await component.UpdateAsync(msg =>
                        {
                            msg.Content = $"✅ **ĐÃ XÁC NHẬN NGƯỜI NHÀ**\n" +
                                          $"👤 Xử lý bởi: **{userDisplayName}** lúc {now}\n" +
                                          $"🔒 Trạng thái: An toàn - Camera di động đã tắt chế độ cảnh báo.";
                            msg.Components = new ComponentBuilder().Build(); // Xóa các nút sau khi đã xử lý
                        });
                        _logger.LogInformation("Alert {AlertId} được xác nhận NGƯỜI NHÀ bởi {User}", alertId, userDisplayName);
                    }
                    else
                    {
                        await component.RespondAsync("⚠️ Cảnh báo này đã được xử lý trước đó hoặc đã hết hạn.", ephemeral: true);
                    }
                }
                else if (action == "trigger_alarm")
                {
                    bool success = _alertStore.TryResolve(alertId, AlertStatus.AlarmTriggered, userDisplayName, out var alert);
                    if (success)
                    {
                        await component.UpdateAsync(msg =>
                        {
                            msg.Content = $"🚨 **BÁO ĐỘNG ĐÃ ĐƯỢC KÍCH HOẠT!**\n" +
                                          $"👤 Kích hoạt bởi: **{userDisplayName}** lúc {now}\n" +
                                          $"🔊 Trạng thái: BÁO ĐỘNG - Camera di động đang phát còi hú và cảnh báo xâm nhập!";
                            msg.Components = new ComponentBuilder().Build(); // Xóa các nút sau khi đã xử lý
                        });
                        _logger.LogWarning("Alert {AlertId} được kích hoạt BÁO ĐỘNG bởi {User}", alertId, userDisplayName);
                    }
                    else
                    {
                        await component.RespondAsync("⚠️ Cảnh báo này đã được xử lý trước đó hoặc đã hết hạn.", ephemeral: true);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi xử lý tương tác nút Discord.");
                try
                {
                    await component.RespondAsync("Đã xảy ra lỗi khi xử lý thao tác.", ephemeral: true);
                }
                catch { }
            }
        }

        public async Task<bool> SendAlertAsync(SecurityAlert alert, string? localImagePath = null)
        {
            var reasonTitle = alert.Reason switch
            {
                "NGUOI_LA" => "CẢNH BÁO: PHÁT HIỆN NGƯỜI LẠ!",
                "RUNG_LAC" => "CẢNH BÁO: PHÁT HIỆN RUNG LẮC THIẾT BỊ CAMERA!",
                _ => $"CẢNH BÁO AN NINH: {alert.Reason}"
            };

            var timeStr = alert.CreatedAt.ToLocalTime().ToString("HH:mm:ss dd/MM/yyyy");
            var messageText = $"⚠️ **{reasonTitle}**\n" +
                              $"🕒 Thời gian: {timeStr}\n" +
                              $"🆔 Mã cảnh báo: `{alert.Id}`\n" +
                              $"⚡ Vui lòng chọn hành động phản hồi bên dưới:";

            // 1. Ưu tiên gửi qua Bot tương tác (có Buttons hoạt động 100%)
            if (IsBotConnected && _client != null)
            {
                try
                {
                    var channel = _client.GetChannel(_options.ChannelId) as IMessageChannel;
                    if (channel != null)
                    {
                        var buttons = new ComponentBuilder()
                            .WithButton("Xác nhận người nhà", $"confirm_home:{alert.Id}", ButtonStyle.Success, new Emoji("✅"))
                            .WithButton("Báo động", $"trigger_alarm:{alert.Id}", ButtonStyle.Danger, new Emoji("🚨"))
                            .Build();

                        IUserMessage sentMsg;
                        if (!string.IsNullOrEmpty(localImagePath) && File.Exists(localImagePath))
                        {
                            sentMsg = await channel.SendFileAsync(
                                filePath: localImagePath,
                                text: messageText,
                                components: buttons
                            );
                        }
                        else
                        {
                            sentMsg = await channel.SendMessageAsync(
                                text: messageText,
                                components: buttons
                            );
                        }

                        alert.DiscordMessageId = sentMsg.Id;
                        _logger.LogInformation("Gửi cảnh báo Discord thành công qua Bot (MessageId: {MsgId})", sentMsg.Id);
                        return true;
                    }
                    else
                    {
                        _logger.LogWarning("Không tìm thấy channel Discord với ID {ChannelId}. Thử fallback sang Webhook.", _options.ChannelId);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Lỗi khi gửi cảnh báo qua Discord Bot. Đang thử fallback qua Webhook.");
                }
            }

            // 2. Fallback sang Webhook nếu bot chưa kết nối hoặc thất bại
            return await SendWebhookFallbackAsync(messageText, localImagePath);
        }

        private async Task<bool> SendWebhookFallbackAsync(string messageText, string? localImagePath)
        {
            if (string.IsNullOrWhiteSpace(_options.WebhookUrl) || _options.WebhookUrl.Contains("YOUR_WEBHOOK"))
            {
                _logger.LogWarning("Không thể gửi Discord vì WebhookUrl chưa được cấu hình.");
                return false;
            }

            try
            {
                using var httpClient = new HttpClient();

                if (!string.IsNullOrEmpty(localImagePath) && File.Exists(localImagePath))
                {
                    using var form = new MultipartFormDataContent();
                    form.Add(new StringContent(messageText), "content");

                    var fileBytes = await File.ReadAllBytesAsync(localImagePath);
                    var fileContent = new ByteArrayContent(fileBytes);
                    fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg");
                    form.Add(fileContent, "file", Path.GetFileName(localImagePath));

                    var response = await httpClient.PostAsync(_options.WebhookUrl, form);
                    return response.IsSuccessStatusCode;
                }
                else
                {
                    var payload = new { content = messageText };
                    var json = JsonSerializer.Serialize(payload);
                    var content = new StringContent(json, Encoding.UTF8, "application/json");

                    var response = await httpClient.PostAsync(_options.WebhookUrl, content);
                    return response.IsSuccessStatusCode;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gửi Webhook Discord fallback thất bại.");
                return false;
            }
        }
    }
}
