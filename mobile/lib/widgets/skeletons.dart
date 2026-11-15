import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'core_widgets.dart';

/// Khung đặt chỗ theo đúng hình nội dung thật, để lúc tải xong bố cục không nhảy.

/// Thẻ chỉ số: icon + tiêu đề, số lớn, chú thích, đường xu hướng.
class MetricCardSkeleton extends StatelessWidget {
  const MetricCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
          children: [
            SkeletonBlock(width: 18, height: 18, circle: true),
            SizedBox(width: AppSpacing.xs),
            SkeletonBlock(width: 72, height: 13),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        SkeletonBlock(width: 96, height: 30, borderRadius: 8),
        SizedBox(height: AppSpacing.xs),
        SkeletonBlock(width: 70, height: 11),
        SizedBox(height: AppSpacing.sm),
        SkeletonBlock(height: 32, borderRadius: 8),
      ],
    ),
  );
}

/// Lưới 2 cột thẻ chỉ số (Tổng quan).
class MetricGridSkeleton extends StatelessWidget {
  const MetricGridSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Đang tải chỉ số',
    child: LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(width: w, child: const MetricCardSkeleton()),
          ],
        );
      },
    ),
  );
}

/// Danh sách một cột thẻ chỉ số (màn Chỉ số).
class MetricListSkeleton extends StatelessWidget {
  const MetricListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Đang tải chỉ số',
    child: Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          const MetricCardSkeleton(),
        ],
      ],
    ),
  );
}

/// Thẻ "Hôm nay": ba vòng bên trái, ba dòng số liệu bên phải.
class RingsCardSkeleton extends StatelessWidget {
  const RingsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Đang tải tóm tắt hôm nay',
    child: AppCard(
      child: Row(
        children: [
          const SkeletonBlock(width: 120, height: 120, circle: true),
          const SizedBox(width: AppSpacing.ml),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  const SkeletonBlock(width: 110, height: 11),
                  const SizedBox(height: AppSpacing.xs),
                  const SkeletonBlock(width: 70, height: 22, borderRadius: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Nhóm cài đặt kiểu iOS: mỗi hàng có ô icon bo góc và một dòng chữ.
class SettingsGroupSkeleton extends StatelessWidget {
  const SettingsGroupSkeleton({super.key, this.rows = 4, this.label});

  final int rows;
  final String? label;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: label ?? 'Đang tải dữ liệu',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const SkeletonBlock(width: 28, height: 28, borderRadius: 7),
                  const SizedBox(width: AppSpacing.sm),
                  SkeletonBlock(width: i.isEven ? 120 : 90, height: 14),
                  const Spacer(),
                  const SkeletonBlock(width: 64, height: 14),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Hồ sơ: thẻ nhận diện + hai nhóm cài đặt.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Đang tải hồ sơ',
    child: Column(
      children: const [
        AppCard(
          child: Row(
            children: [
              SkeletonBlock(width: 56, height: 56, circle: true),
              SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(width: 140, height: 18),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBlock(width: 190, height: 13),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        SettingsGroupSkeleton(rows: 4),
        SizedBox(height: AppSpacing.lg),
        SettingsGroupSkeleton(rows: 2),
      ],
    ),
  );
}

/// Danh sách thẻ mục tiêu: icon tròn, tên, thanh tiến độ.
class GoalListSkeleton extends StatelessWidget {
  const GoalListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Đang tải mục tiêu',
    child: Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBlock(width: 36, height: 36, circle: true),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBlock(width: 110, height: 15),
                    Spacer(),
                    SkeletonBlock(width: 56, height: 24, borderRadius: 8),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                SkeletonBlock(height: 8, borderRadius: 4),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Lưới huy hiệu 2 cột.
class BadgeGridSkeleton extends StatelessWidget {
  const BadgeGridSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Đang tải huy hiệu',
    child: LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                width: w,
                child: const AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: 48, height: 48, circle: true),
                      SizedBox(height: AppSpacing.sm),
                      SkeletonBlock(width: 90, height: 14),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBlock(height: 11),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
