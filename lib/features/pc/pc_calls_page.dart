// PC 의료 호출함 · 간호사 모드. 왼쪽 호출함(생활관 선생님 호출) · 가운데 의료진 채팅(펼쳐짐) · 오른쪽 비대면 진단·처방 기록 / 종합 건강기록.
// 레일·머리는 pc_shell.dart 가 그린다. 의료 글은 명단에 적힌 그대로 보여주기만 한다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/baseline.dart';
import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_calls_common.dart';
import 'pc_calls_dialogs.dart';
import 'pc_medical_rooms.dart';
import 'pc_shell.dart';

class PcCallsPage extends StatelessWidget {
  const PcCallsPage({super.key});

  @override
  Widget build(BuildContext context) => const McLayout(
        inbox: NurseInbox(),
        rooms: ChatRooms(doctor: false),
        side: _NurseSide(),
      );
}

/// 오른쪽: 종합 건강기록 · 비대면 진단·처방 탭.
class _NurseSide extends ConsumerStatefulWidget {
  const _NurseSide();

  @override
  ConsumerState<_NurseSide> createState() => _NurseSideState();
}

class _NurseSideState extends ConsumerState<_NurseSide> {
  int _tab = 0;

  void _toast(String text, {bool info = false}) => showDsToast(context, text,
      icon: info ? Icons.info_outline : Icons.check_circle, iconColor: info ? Ds.gray400 : Ds.green500);

  void _enterVideo(MedicalCall call) {
    final repo = ref.read(repoProvider);
    if (call.videoAt == null) {
      _toast('먼저 가운데 "비대면 화상 진료 예약"으로 시각을 정해 주세요', info: true);
      return;
    }
    final me = repo.staff(ref.read(currentUserProvider));
    repo.sendMessage(call.id, 'system',
        '${withSubject(me.displayName)} 촉탁의에게 화상 진료 입장을 요청했어요 (예약 ${relTime(call.videoAt!, repo.now())})',
        kind: 'system');
    _toast('촉탁의에게 입장 요청을 남겼어요. 화상 연결은 이 웹에서 하지 않아요', info: true);
  }

  void _complete(MedicalCall call) {
    final repo = ref.read(repoProvider);
    ref.read(selectedCallProvider.notifier).select(call.id);
    repo.completeCall(call.id, ref.read(currentUserProvider));
    _toast('호출을 완료했어요');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final call = shownCall(ref);
    final r = call == null ? null : repo.resident(call.residentId);

    Widget tab(int i, IconData icon, String label) {
      final on = _tab == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: McHover(
            builder: (h) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: on ? Ds.shadowSm : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 17, color: on ? Ds.blue500 : (h ? Ds.gray900 : Ds.gray600)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mcText(12.5,
                            weight: on ? FontWeight.w700 : FontWeight.w500, color: on || h ? Ds.gray900 : Ds.gray600)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    // 탭 0: 비대면 진단·처방 기록 (날짜순) · 탭 1: 고른 호출 별님의 종합 건강기록
    final List<Widget> body;
    if (_tab == 0) {
      body = rxRecordCards(repo);
    } else if (call == null || r == null) {
      body = [
        if (repo.isDev)
          const ExampleWrap(child: _ExampleRecord())
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text('호출을 고르면 별님 건강기록이 보여요', textAlign: TextAlign.center, style: mcText(12.5, color: Ds.gray500)),
          ),
      ];
    } else {
      final cls = repo.classOf(r.classId);
      final now = repo.now();
      final base = repo.baselineOf(r.id, now);
      final p = repo.prescriptionOf(call.id);
      body = [
        _RecordCard(
          r: r,
          place: '${cls.name} ${cls.room ?? ''}'.trim(),
          baseline: base,
          latest: repo.latestOf(r.id),
          onOpen: () => showFullRecord(context, repo, r.id),
        ),
        _TrendCard(measurements: repo.measurementsOf(r.id), baseline: base.value, now: now),
        _MedsCard(r: r),
        _PreviewCard(
          call: call,
          p: p,
          doctorName: _doctorName(repo, p),
          onVideo: () => _enterVideo(call),
          onPrint: () => _toast('인쇄는 아직 연결되지 않았어요. 처방 내용은 "비대면 진단·처방 기록" 탭에서 볼 수 있어요', info: true),
          onComplete: call.isOpen ? () => _complete(call) : null,
        ),
      ];
    }

    return McPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Ds.gray200))),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Ds.gray100,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: mcGray200a60),
            ),
            child: Row(children: [
              tab(0, Icons.medication_outlined, '비대면 진단·처방 기록'),
              tab(1, Icons.assignment_outlined, r == null ? '종합 건강기록' : '종합 건강기록 (${r.name})'),
            ]),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: const Color(0x80F9FAFB),
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: body.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => body[i],
            ),
          ),
        ),
      ]),
    );
  }

  /// 담당 촉탁의: 처방을 쓴 의사, 없으면 명단의 첫 촉탁의.
  static String _doctorName(InMemoryRepository repo, Prescription? p) {
    if (p != null) return repo.staff(p.doctorId).displayName;
    for (final s in repo.allStaff) {
      if (s.role == Role.doctor) return s.displayName;
    }
    return '아직 정해지지 않음';
  }
}

/// 별님 요약: 이름 · 반 · 주진단 · 금기 · 기저/현재 체온 · 혈압/맥박.
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.r, required this.place, required this.baseline, required this.latest, required this.onOpen});
  final Resident r;
  final String place;
  final BaselineResult baseline;
  final Measurement? latest;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final head = cautionHead(r);
    final m = latest;
    final stage = m?.judgment.stage;
    final diff = m?.judgment.diff ?? 0;
    final color = m == null ? Ds.gray900 : vitalColor(stage, diff);
    final hot = m != null && color == Ds.red500;

    Widget tile({required Widget a, required Widget b, required Widget c, bool red = false}) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: red ? mcRed50 : Ds.gray100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: red ? mcRed200 : mcGray200a60),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [a, const SizedBox(height: 2), b, const SizedBox(height: 2), c]),
        );

    return McCard(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Ds.blue50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: mcBlueLine),
          ),
          child: Text(r.shortName, style: mcText(14, weight: FontWeight.w700, color: Ds.blue500, height: 20 / 14)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(starName(r.name),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(16, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text(sexAge(r), style: mcText(11.5, color: Ds.gray500)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(
                child: McPill(place,
                    bg: Ds.gray100,
                    fg: Ds.gray700,
                    border: Ds.gray200,
                    size: 10.5,
                    weight: FontWeight.w600,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
              if (r.code != null) ...[
                const SizedBox(width: 8),
                Text(r.code!, style: mcText(10.5, color: Ds.gray500, mono: true)),
              ],
            ]),
          ]),
        ),
        McIconButton(icon: Icons.open_in_new, tooltip: '전체 의무기록 원문 열기', size: 28, iconSize: 17, onTap: onOpen),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _InfoRow(
          icon: Icons.medical_information_outlined,
          iconColor: Ds.blue500,
          bg: Ds.gray100,
          line: mcGray200a60,
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '주진단: ', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: r.diagnosis ?? '기록 없음'),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mcText(11.5, color: Ds.gray800),
          ),
        ),
        if (head != null) ...[
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.warning_amber_rounded,
            iconColor: Ds.red500,
            bg: mcRed50,
            line: mcRed200,
            child: Text(head,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mcText(11.5, weight: FontWeight.w700, color: Ds.red500)),
          ),
        ],
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: tile(
                a: Text('평소 기저체온', style: mcText(10, color: Ds.gray500)),
                b: Text(fmtC(baseline.value), style: mcText(18, weight: FontWeight.w700, mono: true, height: 1.3)),
                c: Text(baseline.note,
                    textAlign: TextAlign.center, maxLines: 2, style: mcText(9.5, color: Ds.gray500, height: 1.3)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: tile(
                red: hot,
                a: Text('현재 체온',
                    style: mcText(10, weight: hot ? FontWeight.w700 : FontWeight.w400, color: hot ? Ds.red500 : Ds.gray500)),
                b: Text(m == null ? '기록 없음' : fmtC(m.value),
                    style: mcText(m == null ? 13 : 19, weight: FontWeight.w900, color: color, mono: true, height: 1.3)),
                c: Text(m == null ? '—' : '${formatDiff(diff)}°C ${vitalWord(stage, diff, short: true)}'.trim(),
                    textAlign: TextAlign.center,
                    style: mcText(9.5, weight: FontWeight.w700, color: m == null ? Ds.gray500 : color, height: 1.3)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: tile(
                a: Text('혈압 / 맥박', style: mcText(10, color: Ds.gray500)),
                b: Text('기록 없음', style: mcText(13, weight: FontWeight.w700, color: Ds.gray500, height: 1.3)),
                c: Text('연동된 측정값 없음', style: mcText(9.5, color: Ds.gray500, height: 1.3)),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.iconColor, required this.bg, required this.line, required this.child});
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final Color line;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
        child: Row(children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Expanded(child: child),
        ]),
      );
}

/// 최근 14일 체온 추이 (CustomPainter).
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.measurements, required this.baseline, required this.now});

  /// 이 별님의 측정 전체 (최신순).
  final List<Measurement> measurements;
  final int baseline;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final start = now.subtract(const Duration(days: 14));
    final pts = [
      for (final m in measurements.reversed)
        if (!m.isVoided && m.measuredAt.isAfter(start) && !m.measuredAt.isAfter(now)) (m.measuredAt, m.value, m),
    ];
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final yLast = pts.where((p) => !p.$1.isBefore(yesterday) && p.$1.isBefore(today)).lastOrNull?.$2;
    final tLast = pts.where((p) => !p.$1.isBefore(today)).lastOrNull;
    final last = pts.lastOrNull;
    final lastColor = last == null ? Ds.red500 : vitalColor(last.$3.judgment.stage, last.$3.judgment.diff);
    final label = last == null
        ? ''
        : '${!last.$1.isBefore(today) ? '금일 ${hhmm(last.$1)}' : relTime(last.$1, now)} (${fmtC(last.$2)})';
    final font = DefaultTextStyle.of(context).style;

    return McCard(gap: 8, children: [
      McCardTitle('최근 14일 체온 추이 및 급상승',
          icon: Icons.show_chart, gap: 4, trailing: Text('단위: °C', style: mcText(10.5, color: Ds.gray500, mono: true))),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Ds.gray50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: mcGray200a70),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 96,
            child: pts.length < 2
                ? Center(child: Text('체온 기록이 아직 적어요', style: mcText(11.5, color: Ds.gray500)))
                : Semantics(
                    label: '최근 14일 체온 ${pts.length}회 그래프',
                    child: CustomPaint(
                      painter: _TrendPainter(
                        points: [for (final p in pts) (p.$1, p.$2)],
                        start: start,
                        end: now,
                        baseline: baseline,
                        label: label,
                        lastColor: lastColor,
                        font: font,
                      ),
                    ),
                  ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ds.gray200))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('D-14', style: mcText(10, color: Ds.gray500, mono: true)),
              Text('D-7', style: mcText(10, color: Ds.gray500, mono: true)),
              Text(yLast == null ? '어제' : '어제 (${fmtC(yLast)})', style: mcText(10, color: Ds.gray500, mono: true)),
              Text(tLast == null ? '금일' : '금일 (${fmtC(tLast.$2)})',
                  style: mcText(10,
                      mono: true,
                      weight: FontWeight.w700,
                      color: tLast == null ? Ds.gray500 : vitalColor(tLast.$3.judgment.stage, tLast.$3.judgment.diff))),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.start,
    required this.end,
    required this.baseline,
    required this.label,
    required this.lastColor,
    required this.font,
  });
  final List<(DateTime, int)> points;
  final DateTime start;
  final DateTime end;
  final int baseline;
  final String label;
  final Color lastColor;
  final TextStyle font;

  void _dash(Canvas canvas, double y, double width, Paint paint, double on, double off) {
    var x = 0.0;
    while (x < width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + on, width), y), paint);
      x += on + off;
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: font.copyWith(fontSize: 9, height: 1.2, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final values = [for (final p in points) p.$2, baseline, hotTemp];
    final lo = values.reduce(math.min) - 3;
    final hi = values.reduce(math.max) + 3;
    double y(int v) => 4 + (hi - v) / (hi - lo) * (h - 8);
    final span = math.max(1, end.difference(start).inMinutes).toDouble();
    double x(DateTime t) => 10 + (t.difference(start).inMinutes / span).clamp(0.0, 1.0) * (w - 20);

    // 기준선
    final hotY = y(hotTemp);
    _dash(canvas, hotY, w, Paint()..color = Ds.red500.withValues(alpha: 0.7)..strokeWidth = 1.2, 3, 3);
    _text(canvas, '38.0°C 고열 기준선', Offset(5, hotY - 13), Ds.red500, bold: true);
    final baseY = y(baseline);
    _dash(canvas, baseY, w, Paint()..color = Ds.gray500.withValues(alpha: 0.4)..strokeWidth = 1, 2, 2);
    if ((baseY - hotY).abs() > 12) _text(canvas, '${formatTemp(baseline)}°C 평소 기저', Offset(5, baseY - 13), Ds.gray600);

    // 면 + 선
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].$1), y(points[i].$2));
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    final area = Path.from(line)
      ..lineTo(x(points.last.$1), h)
      ..lineTo(x(points.first.$1), h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Ds.red500.withValues(alpha: 0.2), Ds.blue500.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = Ds.red500.withValues(alpha: 0.55),
    );

    // 마지막 점 + 꼬리표
    final c = Offset(x(points.last.$1), y(points.last.$2));
    canvas.drawCircle(c, 4.5, Paint()..color = lastColor.withValues(alpha: 0.75));
    canvas.drawCircle(c, 4, Paint()..color = lastColor);
    canvas.drawCircle(c, 1.8, Paint()..color = Colors.white);
    if (label.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(text: label, style: font.copyWith(fontSize: 9, height: 1.2, color: Colors.white, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    final bw = tp.width + 10;
    const bh = 16.0;
    var bx = c.dx - 5 - bw;
    if (bx < 0) bx = math.min(c.dx + 8, w - bw);
    final by = (c.dy - bh / 2 - 2).clamp(0.0, h - bh);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(4)), Paint()..color = lastColor);
    tp.paint(canvas, Offset(bx + 5, by + (bh - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.baseline != baseline || old.label != label || old.lastColor != lastColor;
}

/// 상시 복약 및 주의사항 (명단의 글 그대로).
class _MedsCard extends StatelessWidget {
  const _MedsCard({required this.r});
  final Resident r;

  @override
  Widget build(BuildContext context) {
    final head = cautionHead(r);
    final rest = cautionRest(r);
    final meds = r.regularMeds?.trim();
    final prn = r.prnNote?.trim();

    Widget row({required IconData icon, required Color iconColor, required Color bg, required Color line, required Widget child}) =>
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: iconColor)),
            const SizedBox(width: 8),
            Expanded(child: child),
          ]),
        );

    // '데파코트정 250mg (조석 식후 복약)' → 이름만 굵게.
    InlineSpan medSpan(String text) {
      final i = text.indexOf(' (');
      if (i <= 0) return TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w700));
      return TextSpan(children: [
        TextSpan(text: text.substring(0, i), style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: text.substring(i)),
      ]);
    }

    final rows = <Widget>[
      if (head != null)
        row(
          icon: Icons.block,
          iconColor: Ds.red500,
          bg: mcRed50,
          line: const Color(0xCCFECACA),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(head, style: mcText(11.5, weight: FontWeight.w700, color: Ds.red500)),
            if (rest != null) ...[
              const SizedBox(height: 2),
              Text(rest, style: mcText(10.5, color: Ds.gray600)),
            ],
          ]),
        ),
      if (meds != null && meds.isNotEmpty)
        row(
          icon: Icons.check_circle,
          iconColor: Ds.green500,
          bg: Ds.gray100,
          line: mcGray200a70,
          child: Text.rich(medSpan(meds), style: mcText(11.5)),
        ),
      if (prn != null && prn.isNotEmpty)
        row(
          icon: Icons.info,
          iconColor: Ds.blue500,
          bg: const Color(0x80E8F3FF),
          line: mcBlueLine,
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '발열 PRN: ', style: TextStyle(color: Ds.blue500, fontWeight: FontWeight.w700)),
              TextSpan(text: prn),
            ]),
            style: mcText(11.5),
          ),
        ),
    ];

    return McCard(gap: 8, children: [
      const McCardTitle('상시 복약 및 주의사항', icon: Icons.medication_outlined),
      if (rows.isEmpty) Text('등록된 복약·주의 정보가 없어요', style: mcText(11.5, color: Ds.gray500)),
      for (var i = 0; i < rows.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 6), child: rows[i]),
    ]);
  }
}

/// 비대면 진단 및 처방 프리뷰 + 화상진료 입장 · 인쇄 · 호출 완료.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.call,
    required this.p,
    required this.doctorName,
    required this.onVideo,
    required this.onPrint,
    required this.onComplete,
  });
  final MedicalCall? call;
  final Prescription? p;
  final String doctorName;
  final VoidCallback? onVideo;
  final VoidCallback? onPrint;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final rx = p;
    final names = rx == null || rx.items.isEmpty ? '아직 없음' : rx.items.map((i) => i.name).where((n) => n.isNotEmpty).join(' · ');
    final (k3, v3, c3) = rx == null
        ? ('진단서', '아직 작성 전', Ds.gray500)
        : rx.issued
            ? ('처방전 번호', rx.number ?? '', Ds.green500)
            : ('마지막 저장', hhmm(rx.updatedAt), Ds.gray900);

    Widget kv(String k, String v, Color c, {bool last = false}) => Container(
          padding: EdgeInsets.only(bottom: last ? 0 : 4),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Ds.gray200))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: mcText(11.5, color: Ds.gray500)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.right, style: mcText(11.5, weight: FontWeight.w700, color: c))),
          ]),
        );

    return McCard(children: [
      McCardTitle('비대면 진단 및 처방 프리뷰', icon: Icons.receipt_long, trailing: RxStatusPill(rx)),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Ds.gray100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: mcGray200a70),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          kv('담당 촉탁의', doctorName, Ds.gray900),
          const SizedBox(height: 6),
          kv(rx?.issued ?? false ? '처방의약품' : '예상 처방의약품', names, Ds.blue500),
          const SizedBox(height: 6),
          kv(k3, v3, c3, last: true),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Expanded(
            child: McBlueButton(
              label: '촉탁의 화상진료 입장',
              icon: Icons.video_call_outlined,
              onTap: onVideo,
              padH: 10,
            ),
          ),
          const SizedBox(width: 8),
          McGrayButton(label: '인쇄', icon: Icons.print_outlined, tooltip: '처방전 인쇄', onTap: onPrint),
          const SizedBox(width: 8),
          McGrayButton(
            label: call?.isOpen ?? true ? '호출 완료' : '완료됨',
            icon: Icons.check,
            onTap: onComplete,
          ),
        ]),
      ),
    ]);
  }
}


/// 개발 DB 예시: 건강기록 카드 모양.
class _ExampleRecord extends StatelessWidget {
  const _ExampleRecord();

  static const _r = Resident(
    id: 'example',
    classId: 'example',
    name: '예시 별님',
    order: 0,
    sex: '남',
    age: 20,
    code: 'HJ-0000-000',
    diagnosis: '의료진이 쓴 주진단이 그대로 보여요',
    cautions: '금기 약물이 있으면 빨간 줄로 보여요',
    regularMeds: '상시 복약 (의료진이 쓴 그대로)',
    prnNote: '의료진이 쓴 필요시 투약 지시가 그대로 보여요',
  );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _RecordCard(
          r: _r,
          place: '예시반 000호',
          baseline: BaselineResult(365, BaselineSource.median, 14),
          latest: null,
          onOpen: null,
        ),
        const SizedBox(height: 12),
        const _MedsCard(r: _r),
        const SizedBox(height: 12),
        _PreviewCard(call: null, p: null, doctorName: '예시 촉탁의', onVideo: null, onPrint: null, onComplete: null),
      ]);
}
