import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/core/format.dart';

void main() {
  test('formatNumber dùng dấu phẩy thập phân và dấu chấm hàng nghìn', () {
    expect(formatNumber(0.8), '0,8');
    expect(formatNumber(68.4), '68,4');
    expect(formatNumber(2), '2');
    expect(formatNumber(1234.5), '1.234,5');
    expect(formatNumber(2000, digits: 0), '2.000');
    expect(formatNumber(1234567, digits: 0), '1.234.567');
  });

  test('formatDuration', () {
    expect(formatDuration(440), '7 giờ 20 phút');
    expect(formatDuration(480), '8 giờ');
    expect(formatDuration(45), '45 phút');
  });

  test('bmiLabel theo ngưỡng WHO', () {
    expect(bmiLabel(17.0), 'Thiếu cân');
    expect(bmiLabel(18.5), 'Bình thường');
    expect(bmiLabel(24.9), 'Bình thường');
    expect(bmiLabel(25.0), 'Thừa cân');
    expect(bmiLabel(30.0), 'Béo phì');
  });

  test('formatHeaderDate', () {
    expect(formatHeaderDate(DateTime(2026, 11, 9)), 'Thứ hai, 9 tháng 11');
    expect(formatHeaderDate(DateTime(2026, 11, 15)), 'Chủ nhật, 15 tháng 11');
  });
}
