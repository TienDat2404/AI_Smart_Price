import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/balance_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mobile_layout.dart';
import 'widgets/ai_preview_card.dart';

// ── Kiểu tin nhắn trong chat ──────────────────────────────────────────────────
enum _MessageType { user, aiResult, aiLoading, aiError, system }

class _ChatMessage {
  final _MessageType type;
  final String? text;
  final AiParseResponse? response; // thay vì AiParseResult đơn lẻ

  const _ChatMessage({required this.type, this.text, this.response});
}

// ── Screen ────────────────────────────────────────────────────────────────────
class SmartInputScreen extends StatefulWidget {
  const SmartInputScreen({super.key});

  @override
  State<SmartInputScreen> createState() => _SmartInputScreenState();
}

class _SmartInputScreenState extends State<SmartInputScreen> {
  final _controller      = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode       = FocusNode();
  bool _isSending        = false;

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      type: _MessageType.system,
      text: 'Xin chào! Hãy nhập chi tiêu của bạn.\n'
            'Ví dụ: "Ăn phở 45k" hoặc "Đi chơi 40k và ăn 50k"',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Gửi tin nhắn ─────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _isSending = true;
      _messages.add(_ChatMessage(type: _MessageType.user, text: text));
      _messages.add(const _ChatMessage(type: _MessageType.aiLoading));
    });
    _scrollToBottom();

    try {
      final response = await AiService.instance.parseText(text);

      if (!mounted) return;
      setState(() {
        _messages.removeLast(); // xóa loading
        _messages.add(_ChatMessage(type: _MessageType.aiResult, response: response));
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(const _ChatMessage(
          type: _MessageType.aiError,
          text: 'Không thể phân tích. Vui lòng thử lại.',
        ));
        _isSending = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Xác nhận lưu — hỗ trợ nhiều giao dịch ───────────────────────────────

  Future<void> _onConfirm(AiParseResponse response) async {
    // Xóa preview card ngay lập tức
    setState(() {
      _messages.removeWhere((m) => m.type == _MessageType.aiResult);
      _messages.add(const _ChatMessage(
        type: _MessageType.aiLoading,
        text: 'Đang lưu...',
      ));
    });
    _scrollToBottom();

    int savedCount = 0;
    final errors = <String>[];

    for (final item in response.items) {
      try {
        final tx = Transaction(
          id:        '',
          userId:    'user_01',
          itemName:  item.note.isNotEmpty ? item.note : item.category,
          amount:    item.amount,
          category:  item.category,
          note:      item.note,
          date:      DateTime.now(),
          isExpense: item.category != 'Thu nhập',
        );
        await ApiService.instance.saveTransaction(tx);
        // ✅ Cập nhật số dư real-time
        BalanceNotifier.instance.applyTransaction(
          amount:    item.amount,
          isExpense: item.category != 'Thu nhập',
        );
        savedCount++;
      } catch (e) {
        errors.add('${item.note}: ${e.toString()}');
      }
    }

    if (!mounted) return;

    // Xóa loading
    setState(() => _messages.removeWhere((m) => m.type == _MessageType.aiLoading));

    if (errors.isEmpty) {
      final msg = response.isMultiple
          ? '✅ Đã lưu $savedCount giao dịch thành công!'
          : '✅ Đã lưu giao dịch thành công!';
      setState(() => _messages.add(_ChatMessage(type: _MessageType.system, text: msg)));

      // Thông báo cho Dashboard reload (trả về true khi pop)
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() => _messages.add(_ChatMessage(
        type: _MessageType.aiError,
        text: 'Lưu thất bại:\n${errors.join('\n')}',
      )));
    }
    _scrollToBottom();
  }

  void _onEdit(AiParseResponse response) {
    // Điền lại text đầu tiên để user chỉnh sửa
    _controller.text = response.first.note;
    _focusNode.requestFocus();
    setState(() => _messages.removeWhere((m) => m.type == _MessageType.aiResult));
  }

  void _onCancel() {
    setState(() {
      _messages.removeWhere((m) => m.type == _MessageType.aiResult);
      _messages.add(const _ChatMessage(
        type: _MessageType.system,
        text: 'Đã hủy. Bạn có thể nhập lại.',
      ));
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: MobileLayout(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
            ),
          ),
          _buildInputBar(),
        ]),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        }),
      ),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.neonCyan]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SmartPrice AI',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text('Nhập liệu thông minh',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  // ── Bubble factory ────────────────────────────────────────────────────────

  Widget _buildMessageItem(_ChatMessage msg) {
    switch (msg.type) {
      case _MessageType.user:
        return _UserBubble(text: msg.text!);
      case _MessageType.aiLoading:
        return const _AiLoadingBubble();
      case _MessageType.aiResult:
        return _AiResultBubble(
          response: msg.response!,
          onConfirm: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            _onConfirm(msg.response!);
          }),
          onEdit: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            _onEdit(msg.response!);
          }),
          onCancel: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            _onCancel();
          }),
        );
      case _MessageType.aiError:
        return _AiErrorBubble(text: msg.text!);
      case _MessageType.system:
        return _SystemMessage(text: msg.text!);
    }
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12, offset: const Offset(0, -4),
        )],
      ),
      child: Row(children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            icon: const Icon(Icons.mic_none, color: AppColors.primary),
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_isSending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Ăn phở 50k, Đi chơi 40k và ăn 50k...',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: _isSending ? null
                : const LinearGradient(colors: [AppColors.primary, AppColors.neonCyan]),
            color: _isSending ? AppColors.inputBackground : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            icon: _isSending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.send_rounded, color: Colors.white),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ),
      ]),
    );
  }
}

// ── Bubble Widgets ────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.neonCyan]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20), bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(text,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.inputBackground,
            child: Icon(Icons.person, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _AiLoadingBubble extends StatelessWidget {
  const _AiLoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 60),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _AiAvatar(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonCyan)),
            const SizedBox(width: 10),
            Text('Đang phân tích...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }
}

/// Bubble kết quả — hiển thị 1 hoặc nhiều AiPreviewCard
class _AiResultBubble extends StatelessWidget {
  final AiParseResponse response;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _AiResultBubble({
    required this.response,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
  });

  String _fmtAmount(double v) {
    final parts = v.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
      buf.write(parts[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AiAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nếu nhiều giao dịch — hiển thị badge
            if (response.isMultiple)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tìm thấy ${response.items.length} giao dịch',
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
                  ),
                ),
              ),

            // Một card cho mỗi giao dịch
            ...response.items.asMap().entries.map((e) {
              final i    = e.key;
              final item = e.value;
              return Padding(
                padding: EdgeInsets.only(bottom: i < response.items.length - 1 ? 8 : 0),
                child: AiPreviewCard(
                  amount:     '${_fmtAmount(item.amount)} đ',
                  category:   item.category,
                  note:       item.note,
                  confidence: item.confidence,
                  // Chỉ card cuối cùng mới có nút Lưu tất cả
                  onConfirm:  i == response.items.length - 1 ? onConfirm : null,
                  onEdit:     onEdit,
                  onCancel:   onCancel,
                  label:      response.isMultiple ? 'Giao dịch ${i + 1}' : null,
                  showActions: i == response.items.length - 1,
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

class _AiErrorBubble extends StatelessWidget {
  final String text;
  const _AiErrorBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 60),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _AiAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alert.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: AppColors.alert.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.alert),
              const SizedBox(width: 8),
              Flexible(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.alert))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.neonCyan]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
    );
  }
}
