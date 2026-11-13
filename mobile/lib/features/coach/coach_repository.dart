import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'coach_models.dart';

/// Lỗi có thông báo sẵn cho người dùng (ví dụ Coach chưa được bật, hỏi quá nhanh).
class CoachException implements Exception {
  const CoachException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CoachRepository {
  CoachRepository(this._dio);

  final Dio _dio;

  int get _tzOffset => DateTime.now().timeZoneOffset.inMinutes;

  Future<CoachProviders> providers() async {
    final res = await _dio.get<Map<String, dynamic>>('/coach/providers');
    return CoachProviders.fromJson(res.data!);
  }

  Future<WeeklyInsight> weekly() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/coach/weekly',
      queryParameters: {'tz_offset': _tzOffset},
      // AI local có thể mất vài chục giây cho lần sinh đầu tiên trong tuần
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );
    return WeeklyInsight.fromJson(res.data!);
  }

  /// Gửi cuộc trò chuyện và đọc luồng SSE: mỗi sự kiện là một dòng `data: {json}` cách nhau
  /// bằng một dòng trống.
  Stream<CoachEvent> chat(
    List<ChatMessage> history, {
    String provider = 'auto',
  }) async* {
    final res = await _dio.post<ResponseBody>(
      '/coach/chat',
      data: {
        'messages': [
          for (final m in history)
            {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
        ],
        'provider': provider,
        'tz_offset': _tzOffset,
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 2),
        // Tự đọc lỗi: với luồng, Dio không tự giải mã phần thân của phản hồi lỗi
        validateStatus: (_) => true,
      ),
    );
    final status = res.statusCode ?? 0;
    if (status >= 400) {
      final body = await utf8.decoder
          .bind(res.data!.stream.cast<List<int>>())
          .join();
      var detail = switch (status) {
        429 => 'Bạn hỏi hơi nhanh, thử lại sau ít phút.',
        >= 500 => 'Máy chủ gặp sự cố, thử lại sau.',
        _ => 'Có lỗi xảy ra, vui lòng thử lại.',
      };
      try {
        final d = (jsonDecode(body) as Map<String, dynamic>)['detail'];
        if (d is String) detail = d;
      } on Object {
        // giữ thông báo mặc định
      }
      throw CoachException(detail);
    }
    var buffer = '';
    await for (final chunk in res.data!.stream.cast<List<int>>().transform(
      utf8.decoder,
    )) {
      buffer += chunk;
      int end;
      while ((end = buffer.indexOf('\n\n')) >= 0) {
        final block = buffer.substring(0, end);
        buffer = buffer.substring(end + 2);
        for (final line in block.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final event = CoachEvent.parse(
            jsonDecode(line.substring(5).trim()) as Map<String, dynamic>,
          );
          if (event != null) yield event;
        }
      }
    }
  }
}

final coachRepositoryProvider = Provider<CoachRepository>(
  (ref) => CoachRepository(ref.watch(dioProvider)),
);
