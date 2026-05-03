namespace SmartPrice.Api.Models
{
    // ── Admin Overview ────────────────────────────────────────────────────────

    /// <summary>Số liệu tổng quan cho Admin Dashboard.</summary>
    public record AdminOverviewDto(
        int    TotalUsers,
        int    ActiveUsers,
        int    LockedUsers,
        int    TotalTransactions,
        double TotalRevenue,
        double TotalExpense,
        double OcrSuccessRate,
        int    ActiveErrors,
        double UserGrowthPercent,
        double RevenueGrowthPercent
    );

    /// <summary>Dữ liệu một điểm trên biểu đồ theo tháng.</summary>
    public record MonthlyChartPointDto(
        string Month,       // "Th7", "Th8", ...
        double Income,
        double Expense,
        int    Transactions
    );

    // ── Transaction Admin ─────────────────────────────────────────────────────

    /// <summary>Giao dịch trả về cho Admin — có thêm tên user.</summary>
    public record AdminTransactionDto(
        string   Id,
        string   UserId,
        string   UserName,
        string   ItemName,
        double   Amount,
        string   Category,
        bool     IsExpense,
        string   Note,
        DateTime Date,
        string   Type      // "Chi tiêu" | "Thu nhập" | "Điều chỉnh"
    );

    /// <summary>Thống kê giao dịch tổng hợp.</summary>
    public record TransactionStatsDto(
        int    TotalCount,
        double TotalIncome,
        double TotalExpense,
        int    AdjustmentCount,
        double Balance
    );

    // ── User Admin ────────────────────────────────────────────────────────────

    /// <summary>User trả về cho Admin — có thêm điểm sức khỏe tài chính.</summary>
    public record AdminUserDto(
        string   Id,
        string   FullName,
        string   Email,
        string   Role,
        bool     IsActive,
        DateTime CreatedAt,
        string   Tier,          // "Hạng vàng" | "Hạng bạc" | "Hạng đồng"
        int      HealthScore,   // 0–1000
        int      TransactionCount
    );

    // ── OCR Log ───────────────────────────────────────────────────────────────

    /// <summary>Một bản ghi log OCR cho Admin.</summary>
    public record OcrLogDto(
        string   Id,
        string   UserId,
        string   UserName,
        string   StoreName,
        double   Amount,
        int      Confidence,    // 0–100
        bool     IsSuccess,
        DateTime ScannedAt
    );

    // ── Notification ──────────────────────────────────────────────────────────

    public record SendNotificationRequest(
        string Title,
        string Body,
        string Target   // "all" | "gold" | "silver" | "bronze"
    );

    public record NotificationHistoryDto(
        string   Id,
        string   Title,
        string   Body,
        string   Target,
        int      ReachCount,
        DateTime SentAt
    );
}
