import 'package:flutter/material.dart';
import 'package:podcast_history/core/theme/app_colors.dart';
import 'package:podcast_history/core/theme/app_spacing.dart';

/// Màn hình Quy chuẩn kiểm duyệt tư liệu lịch sử & Tiêu chuẩn xác thực nội dung
class HistoricalGuidelinesScreen extends StatelessWidget {
  const HistoricalGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quy chuẩn kiểm duyệt tư liệu'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: AppSpacing.md,
        ),
        children: [
          // Banner tôn chỉ nền tảng
          _buildMissionBanner(isDark),
          const SizedBox(height: AppSpacing.lg),

          // Phần I: Phân cấp nguồn tư liệu
          _buildSectionTitle('I. Phân cấp nguồn tư liệu hợp lệ', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildSourceLevelCard(
            title: 'Cấp 1: Tư liệu sơ cấp & Chính sử',
            badge: 'Ưu tiên duyệt tuyệt đối',
            badgeColor: AppColors.success,
            content: '• Châu bản, mộc bản, văn bia, thần phả, địa bạ, sắc phong, chiếu chỉ triều đại.\n'
                '• Các bộ chính sử tiêu biểu: Đại Việt Sử Ký Toàn Thư, Khâm Định Việt Sử Thông Giám Cương Mục, Đại Nam Thực Lục...\n'
                '• Hồ sơ lưu trữ tại các Trung tâm Lưu trữ Quốc gia (I, II, III, IV), Viện Nghiên cứu Hán Nôm, Viện Sử học.',
            isDark: isDark,
          ),
          _buildSourceLevelCard(
            title: 'Cấp 2: Công trình nghiên cứu & Xuất bản chuyên môn',
            badge: 'Hợp lệ',
            badgeColor: AppColors.info,
            content: '• Các công trình học thuật của học giả, nhà sử học uy tín (Trần Trọng Kim, Đào Duy Anh, Lê Thành Khôi, Phan Huy Lê, Hà Văn Tấn...).\n'
                '• Sách khảo cứu và tạp chí chuyên ngành có chỉ số ISBN/ISSN do các NXB uy tín phát hành (NXB Tri thức, NXB Khoa học Xã hội, NXB Chính trị Quốc gia Sự thật...).',
            isDark: isDark,
          ),
          _buildSourceLevelCard(
            title: 'Cấp 3: Hồi ký & Khảo sát thực địa',
            badge: 'Cần thẩm định chéo',
            badgeColor: AppColors.warning,
            content: '• Hồi ký của nhân chứng lịch sử (cần đối chiếu bối cảnh khách quan đương thời).\n'
                '• Băng ghi âm, phỏng vấn nhân chứng sống, tư liệu điền dã dân gian (cần cung cấp rõ địa điểm, thời gian và thông tin người cung cấp tư liệu).',
            isDark: isDark,
          ),
          _buildSourceLevelCard(
            title: 'Nguồn KHÔNG được chấp thuận',
            badge: 'Nghiêm cấm xuất bản',
            badgeColor: AppColors.error,
            content: '• Diễn đàn mạng xã hội, hội nhóm không kiểm duyệt, bài viết nặc danh không rõ căn cứ.\n'
                '• Tác phẩm dã sử, tiểu thuyết diễn nghĩa, truyền thuyết dân gian bị quy chụp là sự thật lịch sử mà không có chú thích minh bạch.\n'
                '• Các suy đoán ngụy tạo, xuyên tạc chủ quyền quốc gia hoặc sự kiện lịch sử đã được công nhận.',
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Phần II: Quy chuẩn trích dẫn
          _buildSectionTitle('II. Quy chuẩn khai báo trích dẫn (References)', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildGuidelineCard(
            icon: Icons.checklist_rounded,
            title: 'Các trường thông tin chuẩn theo hệ thống VietCast',
            description: 'Mỗi tập podcast khi nộp duyệt bắt buộc phải đính kèm ít nhất 01 tư liệu với các trường:\n\n'
                '1. Loại nguồn (referenceType): Sách (BOOK), Bài báo (ARTICLE), Website (WEBSITE), Tài liệu PDF (PDF), Khác (OTHER).\n'
                '2. Tiêu đề tài liệu (title): Tối đa 300 ký tự (bắt buộc).\n'
                '3. Tác giả (author): Tối đa 200 ký tự.\n'
                '4. Nhà xuất bản / Cơ quan lưu trữ (publisher): Tối đa 200 ký tự.\n'
                '5. Năm phát hành (publishedYear): Từ năm 1 đến 9999.\n'
                '6. Đường dẫn liên kết (url): Bắt đầu bằng http:// hoặc https:// (tối đa 2000 ký tự).\n'
                '7. Tệp PDF đính kèm: File PDF hợp lệ (chữ ký binary %PDF-) scan từ tư liệu gốc.\n'
                '8. Đoạn trích dẫn chi tiết (citationText): Ghi rõ chương, tập, số trang đối chiếu (tối đa 10.000 ký tự).',
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Phần III: Tiêu chuẩn biên tập & Đạo đức
          _buildSectionTitle('III. Tiêu chuẩn biên tập & Đạo đức nội dung', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildRuleRow(
            Icons.flag_rounded,
            'Chủ quyền & Toàn vẹn lãnh thổ',
            'Tuân thủ tuyệt đối bản đồ lãnh thổ Việt Nam, khẳng định chủ quyền đối với hai quần đảo Hoàng Sa và Trường Sa.',
            isDark,
          ),
          _buildRuleRow(
            Icons.verified_rounded,
            'Tôn trọng sự thật & Khách quan',
            'Không phỉ báng, xuyên tạc danh dự các anh hùng dân tộc, danh nhân văn hóa và các mốc son lịch sử dân tộc.',
            isDark,
          ),
          _buildRuleRow(
            Icons.balance_rounded,
            'Minh bạch quan điểm học thuật',
            'Nếu có nhiều quan điểm lịch sử khác nhau, Creator cần dẫn giải: "Theo học thuyết của tác giả X..." thay vì áp đặt làm chân lý duy nhất.',
            isDark,
          ),
          _buildRuleRow(
            Icons.audiotrack_rounded,
            'Bản quyền âm thanh & Nhạc nền',
            'Audio giọng đọc phải là sản phẩm sáng tạo gốc; âm thanh hiệu ứng (SFX) và nhạc nền (BGM) phải là nhạc miễn phí bản quyền (Royalty-free) hoặc có giấy phép thương mại.',
            isDark,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Phần IV: Quy trình kiểm duyệt & Kháng nghị
          _buildSectionTitle('IV. Quy trình kiểm duyệt & Kháng nghị (Appeal)', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildGuidelineCard(
            icon: Icons.security_update_good_rounded,
            title: 'Hệ thống kiểm duyệt 2 cấp độ',
            description: '• Cấp 1 (Tự động): Hệ thống Whisper bóc tách phụ đề và AI Gemini phân tích mức độ an toàn (SAFE/UNSAFE/UNCERTAIN). Nếu độ tin cậy đạt từ 90% trở lên và hoàn toàn an toàn, podcast có thể được Auto-Approve.\n'
                '• Cấp 2 (Thủ công): Hội đồng biên tập kiểm tra trực tiếp danh mục tham chiếu, tính chính xác của trích dẫn và các đoạn âm thanh nghi vấn.\n'
                '• Kháng nghị (Appeal): Nếu tập podcast bị Từ chối (REJECTED) hoặc Ẩn (HIDDEN), Creator có thể gửi khiếu nại trực tiếp trong mục "Lịch sử duyệt" hoặc gửi email hỗ trợ giải trình kèm hình ảnh/tài liệu đối chứng.',
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildMissionBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: 30,
            color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tôn chỉ kiểm duyệt VietCast',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bảo đảm tính xác thực, tôn trọng sự thật lịch sử, dựa trên tư liệu học thuật đáng tin cậy nhằm xây dựng kho tàng podcast di sản chất lượng cao.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
      ),
    );
  }

  Widget _buildSourceLevelCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required String content,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(IconData icon, String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? AppColors.onSurfaceMutedDark : AppColors.onSurfaceMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
