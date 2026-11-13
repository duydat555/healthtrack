import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'coach_controller.dart';
import 'coach_models.dart';

const _suggestions = [
  'Tuần này mình uống nước đủ chưa?',
  'Giấc ngủ của mình dạo này thế nào?',
  'Vừa uống 500ml nước',
  'Gợi ý mục tiêu cho mình',
];

const _metricNames = {
  'water': 'nước uống',
  'weight': 'cân nặng',
  'steps': 'bước chân',
  'sleep': 'giấc ngủ',
  'meal': 'bữa ăn',
};

/// Chat với AI Coach. Câu trả lời hiện dần từng chữ; Coach có thể ghi chỉ số hộ.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    var value = text ?? _input.text;
    // Giới hạn độ dài khi gửi, không dùng maxLength vì nó làm hỏng gõ Telex trên iOS
    if (value.length > 1000) value = value.substring(0, 1000);
    if (value.trim().isEmpty) return;
    _input.clear();
    ref.read(coachControllerProvider.notifier).send(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(coachControllerProvider);
    ref.listen(coachControllerProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: AppMotion.of(context, AppMotion.medium),
            curve: AppMotion.curve,
          );
        }
      });
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Semantics(
          header: true,
          child: Text(
            'Coach',
            style: AppTextStyles.sectionTitle.copyWith(color: c.ink),
          ),
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Cuộc trò chuyện mới',
              icon: const Icon(Icons.restart_alt),
              onPressed: state.busy
                  ? null
                  : ref.read(coachControllerProvider.notifier).clear,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? _Intro(onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: state.messages.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: state.messages[i],
                        typing:
                            state.busy &&
                            i == state.messages.length - 1 &&
                            state.messages[i].text.isEmpty,
                        status: i == state.messages.length - 1
                            ? state.status
                            : null,
                      ),
                    ),
            ),
            _InputBar(controller: _input, busy: state.busy, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hỏi mình về thói quen sức khỏe của bạn',
          style: AppTextStyles.pageTitle.copyWith(fontSize: 28, color: c.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'Mình đọc số liệu của bạn và có thể ghi giúp khi bạn nói đã uống nước, ngủ hay ăn. '
          'Mình không thay thế bác sĩ.',
          style: TextStyle(fontSize: 15, color: c.inkSoft),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s),
                backgroundColor: c.card,
                side: BorderSide.none,
                labelStyle: TextStyle(color: c.ink),
                onPressed: () => onPick(s),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.typing, this.status});

  final ChatMessage message;
  final bool typing;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mine = message.fromUser;
    final width = MediaQuery.sizeOf(context).width * 0.8;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? c.brand : c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Semantics(
          label: '${mine ? 'Bạn' : 'Coach'}: ${message.text}',
          excludeSemantics: true,
          liveRegion: !mine,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (typing && status == null)
                Text('...', style: TextStyle(color: c.inkSoft, fontSize: 18)),
              if (status != null)
                Text(status!, style: TextStyle(color: c.inkSoft, fontSize: 13)),
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    color: mine ? c.onBrand : c.ink,
                  ),
                ),
              if (!mine && message.source != null && message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        message.source == 'local'
                            ? Icons.lock_outline
                            : Icons.cloud_outlined,
                        size: 13,
                        color: c.inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.source == 'local'
                            ? 'Chạy trên Mac của bạn'
                            : 'Claude',
                        style: TextStyle(color: c.inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              for (final m in message.logged)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: c.water),
                      const SizedBox(width: 4),
                      Text(
                        'Đã ghi ${_metricNames[m] ?? m}',
                        style: TextStyle(color: c.water, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final void Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: TextStyle(color: c.ink),
              decoration: InputDecoration(
                hintText: 'Nhắn cho Coach',
                filled: true,
                fillColor: c.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Gửi',
            style: IconButton.styleFrom(backgroundColor: c.brand),
            onPressed: busy ? null : () => onSend(),
            icon: Icon(Icons.arrow_upward, color: c.onBrand),
          ),
        ],
      ),
    );
  }
}
