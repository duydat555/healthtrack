/// Định dạng số, thời lượng và ngày theo kiểu Việt Nam.
library;

/// 1234.5 -> "1.234,5"; số nguyên bỏ phần thập phân.
String formatNumber(num value, {int digits = 1}) {
  final fixed = value.toStringAsFixed(digits);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  if (parts.length == 1) return intPart;
  final frac = parts[1].replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? intPart : '$intPart,$frac';
}

/// 440 -> "7 giờ 20 phút"; 480 -> "8 giờ"; 45 -> "45 phút".
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m phút';
  if (m == 0) return '$h giờ';
  return '$h giờ $m phút';
}

const _weekdays = [
  'Thứ hai',
  'Thứ ba',
  'Thứ tư',
  'Thứ năm',
  'Thứ sáu',
  'Thứ bảy',
  'Chủ nhật',
];

/// "Thứ hai, 9 tháng 11"
String formatHeaderDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} tháng ${d.month}';

const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Phân loại BMI theo ngưỡng của WHO.
String bmiLabel(double bmi) {
  if (bmi < 18.5) return 'Thiếu cân';
  if (bmi < 25) return 'Bình thường';
  if (bmi < 30) return 'Thừa cân';
  return 'Béo phì';
}

String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
