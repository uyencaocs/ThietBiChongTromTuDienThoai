using CaoThiThuUyen_2380616457.Models; 
using Microsoft.EntityFrameworkCore;


namespace CaoThiThuUyen_2380616457.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Device> Devices { get; set; }
        public DbSet<MonitoringSetting> MonitoringSettings { get; set; }
        public DbSet<AccessLog> AccessLogs { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<User>().HasIndex(u => u.Email).IsUnique();

            modelBuilder.Entity<Device>()
                .HasOne(d => d.MonitoringSetting)
                .WithOne(m => m.Device)
                .HasForeignKey<MonitoringSetting>(m => m.DeviceId);

            modelBuilder.Entity<Device>()
                .HasOne(d => d.User)
                .WithMany(u => u.Devices)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}