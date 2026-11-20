// 별님카드 위 프로필 (Claude Design ResidentProfileCard + VitalSparkline + 투약 지침 줄).
// 평소 체온은 baselineOf, 최근 체온·차이는 측정에 저장된 판정(judgment)을 그대로 쓴다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/baseline.dart';
import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/photo.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'resident_timeline.dart';

/// 그래프에 그리는 기간 (평소 체온 계산 기간과 같다).
const int sparkDays = 14;

class ResidentProfileCard extends StatelessWidget {
  const ResidentProfileCard({
    super.key,
    required this.repo,
    required this.resident,
    required this.now,
    required this.onOpenGuide,
    required this.onOpenPhotos,
  });
  final InMemoryRepository repo;
  final Resident resident;
  final DateTime now;
  final VoidCallback onOpenGuide;

  /// 프로필 사진을 누르면 사진 기록 (카카오톡 프로필처럼).
  final VoidCallback onOpenPhotos;

  @override
  Widget build(BuildContext context) {
    final r = resident;
    final cls = repo.classOf(r.classId);
    final homeroom = repo.staff(cls.homeroomId);
    final total = recordTotalOf(repo, r.id);
    final since = total.since;
    final ageSex = [if (r.age != null) '만 ${r.age}세', if (r.sex != null) r.sex!].join(' · ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Ds.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Ds.borderCard),
        boxShadow: Ds.shadowCard,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.only(bottom: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ds.gray100))),
          child: Row(children: [
            _ProfilePhoto(resident: r, photo: repo.profilePhotoOf(r.id), onTap: onOpenPhotos),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 이름 + "만 19세" (한 줄, 같은 글자 바닥선, 좁으면 끝을 …)
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: r.name),
                      if (ageSex.isNotEmpty) ...[
                        const WidgetSpan(child: SizedBox(width: 8)),
                        TextSpan(
                          text: ageSex,
                          style: const TextStyle(fontSize: T.label, fontWeight: FontWeight.w500, letterSpacing: 0, color: Ds.gray500),
                        ),
                      ],
                    ]),
                    key: const Key('rc-profile-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, height: 1.5, fontWeight: FontWeight.w700, letterSpacing: -0.55, color: Ds.gray900),
                  ),
                ),
                const SizedBox(height: 2),
                Text('${cls.name} · 담임 ${homeroom.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: T.label, height: 1.5, color: Ds.gray600)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Ds.gray100, borderRadius: BorderRadius.circular(6)),
                child: Text('총 ${total.count}건',
                    style: const TextStyle(
                        fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w600, color: Ds.gray500, fontFeatures: tabular)),
              ),
              if (since != null) ...[
                const SizedBox(height: 4),
                Text('${(since.year % 100).toString().padLeft(2, '0')}.${since.month.toString().padLeft(2, '0')} ~',
                    style: const TextStyle(fontSize: T.micro, height: 1.5, color: Ds.gray500, fontFeatures: tabular)),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        VitalSparkline(repo: repo, residentId: r.id, now: now),
        _GuideRow(repo: repo, resident: r, onTap: onOpenGuide),
      ]),
    );
  }
}

/// 프로필 사진 (없으면 이름 글자) + 카메라 표시. 누르면 사진 기록.
class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.resident, required this.photo, required this.onTap});
  final Resident resident;
  final ResidentPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = photo;
    return Semantics(
      button: true,
      label: '${resident.name} 프로필 사진 보기',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('rc-profile-photo'),
        onTap: onTap,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              top: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  color: Ds.gray100,
                  child: p != null
                      ? SizedBox.expand(child: ResidentPhotoImage(p.url))
                      : Text(resident.shortName,
                          maxLines: 1,
                          style: const TextStyle(fontSize: T.bodyLg, height: 1.5, fontWeight: FontWeight.w600, color: Ds.gray700)),
                ),
              ),
            ),
            // 카메라 표시: 누구에게나 보인다 (올리기는 사진 기록 화면에서 담당 선생님만).
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Ds.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: Ds.gray200),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 13, color: Ds.gray700),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// 평소 체온 · 최근 체온 · 14일 추이 (VitalSparkline).
class VitalSparkline extends StatelessWidget {
  const VitalSparkline({super.key, required this.repo, required this.residentId, required this.now});
  final InMemoryRepository repo;
  final String residentId;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final base = repo.baselineOf(residentId, now);
    final latest = repo.latestOf(residentId);
    final from = now.subtract(const Duration(days: sparkDays));
    final points = repo
        .measurementsOf(residentId)
        .where((m) => !m.isVoided && m.measuredAt.isAfter(from) && !m.measuredAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    // 그래프 점: 지난 날은 그날 가장 높은 값 하나, 오늘은 잰 값 그대로 (끝 점 = 지금 체온).
    final today = DateTime(now.year, now.month, now.day);
    final dayMax = <DateTime, Measurement>{};
    final todays = <Measurement>[];
    for (final m in points) {
      final d = DateTime(m.measuredAt.year, m.measuredAt.month, m.measuredAt.day);
      if (!d.isBefore(today)) {
        todays.add(m);
      } else if ((dayMax[d]?.value ?? -1) < m.value) {
        dayMax[d] = m;
      }
    }
    final plotted = [
      for (final m in [...dayMax.values, ...todays]) (m.measuredAt, m.value),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final diff = latest?.judgment.diff ?? 0;
    final tone = _tone(diff);
    final sourceLabel = switch (base.source) {
      BaselineSource.median => '$sparkDays일 중앙값',
      BaselineSource.manual => '간호사 지정',
      BaselineSource.provisional => '계산 중 ${base.count}/$baselineMinRecords',
    };

    String whenLabel(DateTime t) {
      final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
      return days == 0 ? '오늘' : (days == 1 ? '어제' : '${t.month}/${t.day}');
    }

    final example = points.isEmpty && repo.isDev;
    final Widget chart;
    if (points.isNotEmpty) {
      chart = Semantics(
        label: '최근 $sparkDays일 체온 추이: 기저치 ${formatTemp(base.value)}도에서 현재 ${formatTemp(points.last.value)}도',
        child: ExcludeSemantics(
          child: CustomPaint(
            painter: SparkPainter(
              points: plotted,
              baseline: base.value,
              from: from,
              color: tone.line,
            ),
          ),
        ),
      );
    } else if (example) {
      chart = Stack(children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.6,
            child: CustomPaint(
              painter: SparkPainter(
                points: [
                  for (var i = 0; i <= 12; i++) (from.add(Duration(days: i + 1)), base.value + const [0, 1, -1, 0, 1, 0, -1, 0, 1, 2, 1, 3, 5][i]),
                ],
                baseline: base.value,
                from: from,
                color: Ds.red500,
              ),
            ),
          ),
        ),
        const Positioned(top: 0, left: 0, child: ExampleTag()),
      ]);
    } else {
      chart = Center(
        child: Text('최근 $sparkDays일 동안 잰 체온이 없어요',
            style: const TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500)),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              const Text('평소 체온', style: TextStyle(fontSize: T.label, height: 1.5, fontWeight: FontWeight.w500, color: Ds.gray600)),
              const SizedBox(width: 6),
              Text('${formatTemp(base.value)}°',
                  style: const TextStyle(
                      fontSize: T.number,
                      height: 1.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.65,
                      color: Ds.gray900,
                      fontFeatures: tabular)),
              if (latest != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: tone.pillBg, borderRadius: BorderRadius.circular(Radii.pill)),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${whenLabel(latest.measuredAt)} ${formatTemp(latest.value)}°'),
                      TextSpan(
                          text: ' (${fmtDiffDeg(diff)})',
                          style: const TextStyle(fontSize: T.micro, fontWeight: FontWeight.w600)),
                    ]),
                    style: TextStyle(
                        fontSize: T.label, height: 1.5, fontWeight: FontWeight.w700, color: tone.pillFg, fontFeatures: tabular),
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text(sourceLabel, style: const TextStyle(fontSize: T.micro, height: 1.5, color: Ds.gray500)),
      ]),
      const SizedBox(height: 14),
      SizedBox(height: 48, child: chart),
      const SizedBox(height: 8),
      if (example)
        Text('체온을 재면 이 자리에 $sparkDays일 추이가 그려져요',
            style: const TextStyle(fontSize: T.micro, height: 1.5, color: Ds.gray500))
      else if (points.isNotEmpty)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$sparkDays일 전', style: const TextStyle(fontSize: T.micro, height: 1.5, color: Ds.gray500)),
          Flexible(
            child: Text('기저치 ${formatTemp(base.value)}°',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w500, color: Ds.gray600, fontFeatures: tabular)),
          ),
          if (latest != null)
            Text('현재 ${formatTemp(latest.value)}°',
                style: TextStyle(
                    fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w700, color: diffColor(diff), fontFeatures: tabular)),
        ]),
    ]);
  }
}

/// 차이 색: +0.5° 이상 빨강, −0.5° 이하 파랑, 그 사이 기본색.
({Color line, Color pillBg, Color pillFg}) _tone(int diff) {
  if (diff >= 5) return (line: Ds.red500, pillBg: Ds.red50, pillFg: Ds.red500);
  if (diff <= -5) return (line: Ds.blue500, pillBg: Ds.blue50, pillFg: Ds.blue500);
  return (line: Ds.gray700, pillBg: Ds.gray100, pillFg: Ds.gray900);
}

/// 작은 체온 그래프: 기저치 점선 + 아래 옅은 채움 + 부드러운 선 + 마지막 점.
/// 마지막 값이 평소에서 벗어났으면 그 직전 평소 값에 회색 점을 찍는다.
class SparkPainter extends CustomPainter {
  SparkPainter({required this.points, required this.baseline, required this.from, required this.color});

  /// (시각, 체온 ×10), 오래된 순.
  final List<(DateTime, int)> points;
  final int baseline;
  final DateTime from;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = [for (final p in points) p.$2, baseline];
    var lo = values.reduce(math.min).toDouble();
    var hi = values.reduce(math.max).toDouble();
    if (hi - lo < 6) {
      final mid = (hi + lo) / 2;
      lo = mid - 3;
      hi = mid + 3;
    }
    final top = size.height * 0.12;
    final bottom = size.height * 0.66;
    double y(num v) => bottom - (v - lo) / (hi - lo) * (bottom - top);

    final t0 = from.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    final span = math.max(1.0, t1 - t0);
    double x(DateTime t) => ((t.millisecondsSinceEpoch - t0) / span).clamp(0.0, 1.0) * size.width;

    final pts = [for (final p in points) Offset(x(p.$1), y(p.$2))];

    // 기저치 점선
    final by = y(baseline);
    final dash = Paint()
      ..color = Ds.gray200
      ..strokeWidth = 1;
    for (double dx = 0; dx < size.width; dx += 6) {
      canvas.drawLine(Offset(dx, by), Offset(math.min(dx + 3, size.width), by), dash);
    }

    if (pts.length >= 2) {
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1];
        final b = pts[i];
        final mx = (a.dx + b.dx) / 2;
        line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
      }
      final area = Path.from(line)
        ..lineTo(pts.last.dx, size.height)
        ..lineTo(pts.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 벗어나기 직전의 평소 값 (회색 점)
    final lastDiff = points.last.$2 - baseline;
    if (lastDiff.abs() >= 5) {
      for (var i = points.length - 2; i >= 0; i--) {
        if ((points[i].$2 - baseline).abs() < 5) {
          canvas.drawCircle(pts[i], 3.5, Paint()..color = Colors.white);
          canvas.drawCircle(
              pts[i],
              3.5,
              Paint()
                ..color = Ds.gray500
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
          break;
        }
      }
    }

    // 마지막 점
    canvas.drawCircle(pts.last, 4, Paint()..color = color);
    canvas.drawCircle(
        pts.last,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(SparkPainter old) =>
      old.baseline != baseline || old.color != color || old.from != from || old.points.length != points.length ||
      (points.isNotEmpty && old.points.last != points.last);
}

/// 투약 지침 줄 → 시트 (의료진이 쓴 글 그대로).
class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.repo, required this.resident, required this.onTap});
  final InMemoryRepository repo;
  final Resident resident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = repo.guidelineOf(resident.id);
    final writer = g == null ? '등록된 지침 없음' : repo.staff(g.writtenBy).displayName;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        button: true,
        label: '투약 지침 보기',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ds.gray100))),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Ds.blue50, shape: BoxShape.circle),
                child: const Icon(Icons.medication_rounded, size: 16, color: Ds.blue500),
              ),
              const SizedBox(width: 8),
              const Text('투약 지침', style: TextStyle(fontSize: T.label, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(writer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500)),
              ),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Ds.gray700),
            ]),
          ),
        ),
      ),
    );
  }
}
