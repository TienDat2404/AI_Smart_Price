import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Card hiển thị kết quả AI dự đoán để User xác nhận trước khi lưu.
/// Xuất hiện phía bên trái trong giao diện chat (bubble AI).
class AiPreviewCard extends StatelessWidget {
  final String amount;
  final String category;
  final String note;
  final double confidence;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const AiPreviewCard({
    super.key,
    required this.amount,
    required this.category,
    required this.note,
    required this.confidence,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final confidencePct = (confidence * 100).toStringAsFixed(0);
    final isHighConfidence = confidence >= 0.8;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: AppColors.neonCyan.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header AI ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.neonCyan.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: AppColors.neonCyan),
                const SizedBox(width: 6),
                const Text(
                  'SmartPrice AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                // Badge độ tin cậy
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isHighConfidence
                        ? AppColors.income.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$confidencePct% chính xác',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isHighConfidence ? AppColors.income : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Nội dung bóc tách ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tôi đã nhận diện được:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                // Số tiền — nổi bật nhất
                _InfoRow(
                  icon: Icons.attach_money,
                  label: 'Số tiền',
                  value: amount,
                  valueStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.expense,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.inputBackground),
                const SizedBox(height: 8),

                _InfoRow(
                  icon: Icons.label_outline,
                  label: 'Hạng mục',
                  value: category,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.notes,
                  label: 'Ghi chú',
                  value: note.isNotEmpty ? note : '—',
                ),

                const SizedBox(height: 14),

                // ── Nút hành động ─────────────────────────────────────
                Row(
                  children: [
                    // Hủy
                    _ActionButton(
                      label: 'Hủy',
                      icon: Icons.close,
                      color: AppColors.textSecondary,
                      backgroundColor: AppColors.inputBackground,
                      onTap: onCancel,
                    ),
                    const SizedBox(width: 8),
                    // Sửa
                    _ActionButton(
                      label: 'Sửa',
                      icon: Icons.edit_outlined,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 8),
                    // Lưu — nổi bật
                    Expanded(
                      child: GestureDetector(
                        onTap: onConfirm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.neonCyan],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Lưu giao dịch',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
