// 공통 가상 명단 (통합 명세 10장). 모두 가상 인물이며 실제 혜진원 사람과 관계없다.
import 'judgment.dart';
import 'models.dart';

/// 시연 시계 시작 (10-3).
final DateTime demoStart = DateTime(2026, 10, 28, 9, 41);

const staff = <Staff>[
  Staff(id: 'park_jieun', name: '박지은', role: Role.care),
  Staff(id: 'han_jimin', name: '한지민', role: Role.care),
  Staff(id: 'jung_daun', name: '정다운', role: Role.care),
  Staff(id: 'lee_sujin', name: '이수진', role: Role.care),
  Staff(id: 'oh_sehun', name: '오세훈', role: Role.care),
  Staff(id: 'jung_haeun', name: '정하은', role: Role.care),
  Staff(id: 'kim_haneul', name: '김하늘', role: Role.care),
  Staff(id: 'choi_minho', name: '최민호', role: Role.care),
  Staff(id: 'oh_jimin', name: '오지민', role: Role.care),
  Staff(id: 'park_soyeon', name: '박소연', role: Role.nurse),
  Staff(id: 'park_seoyeon', name: '박서연', role: Role.office),
  Staff(id: 'lee_minjae', name: '이민재', role: Role.office),
  Staff(id: 'han_kyungsoo', name: '한경수', role: Role.director),
];

/// 시연 기본 사용자.
const String demoUserId = 'kim_haneul';

/// 오전 근무조 (10-2).
const amShiftStaff = ['kim_haneul', 'park_jieun', 'lee_sujin', 'choi_minho'];

/// 근무 선생님의 배치 반.
const staffPlacement = {'kim_haneul': 'milkyway', 'choi_minho': 'whale', 'oh_jimin': 'aries'};
const nightDutyStaffId = 'oh_jimin';

const classes = <Class>[
  Class(id: 'aquarius', name: '물병자리', color: 0xFFA89AC2, homeroomId: 'park_jieun', order: 0, sex: '여'),
  Class(id: 'pisces', name: '물고기자리', color: 0xFF7FA8C4, homeroomId: 'han_jimin', order: 1, sex: '여'),
  Class(id: 'bear', name: '곰자리', color: 0xFFB59A7A, homeroomId: 'jung_daun', order: 2, sex: '남'),
  Class(id: 'milkyway', name: '은하수자리', color: 0xFF87A98E, homeroomId: 'lee_sujin', order: 3, sex: '남'),
  Class(id: 'aries', name: '양자리', color: 0xFFD39B94, homeroomId: 'oh_sehun', order: 4, sex: '남'),
  Class(id: 'whale', name: '고래자리', color: 0xFF7D9BB0, homeroomId: 'jung_haeun', order: 5, sex: '남'),
];

/// 이전 담임 (10-1).
const _previousHomeroom = {
  'aquarius': 'han_jimin',
  'pisces': 'park_jieun',
  'bear': 'oh_sehun',
  'milkyway': 'park_jieun',
  'aries': 'jung_daun',
  'whale': 'choi_minho',
};

final homeroomHistory = <ClassHomeroomHistory>[
  for (final c in classes) ...[
    ClassHomeroomHistory(
        classId: c.id, staffId: _previousHomeroom[c.id]!, from: DateTime(2024, 3, 1), to: DateTime(2026, 3, 1)),
    ClassHomeroomHistory(classId: c.id, staffId: c.homeroomId, from: DateTime(2026, 3, 1)),
  ],
];

/// 반별 별님 (이름, 기저치 ×10). 순서 = 화면 그리드 순서.
const _roster = <String, List<(String, int)>>{
  'aquarius': [('임유나', 364), ('송지은', 365), ('한나리', 363), ('김윤서', 366), ('서소율', 364), ('홍다은', 365), ('오하린', 362)],
  'pisces': [('정서아', 362), ('신지유', 365), ('박채원', 366), ('배수아', 364), ('이하은', 363), ('안예린', 365)],
  'bear': [('문하준', 362), ('조은우', 366), ('장도현', 368), ('권건우', 365), ('백태윤', 364)],
  'milkyway': [('김민준', 365), ('이서준', 371), ('한지호', 366), ('류은호', 363), ('최도윤', 369), ('강시우', 366)],
  'aries': [('고준우', 364), ('윤예준', 368), ('정현우', 365), ('김민재', 366), ('남정우', 363), ('유로운', 365)],
  'whale': [('서연우', 364), ('노재희', 366), ('황태양', 365), ('박승민', 368), ('차우진', 362), ('엄성민', 367)],
};

/// 시드에서 기저치가 나오도록 쓰는 목표값. 실제 기저치는 측정 기록에서 계산된다.
final Map<String, int> seedBaselines = {
  for (final e in _roster.entries)
    for (var i = 0; i < e.value.length; i++) '${e.key}-${i + 1}': e.value[i].$2,
};

/// 학교에 다니는 별님 (통학 차량 반 공지와 맞춤).
const _commuters = {'송지은', '서소율', '김민준', '고준우', '서연우'};

final residents = <Resident>[
  for (final e in _roster.entries)
    for (var i = 0; i < e.value.length; i++)
      Resident(
        id: '${e.key}-${i + 1}',
        classId: e.key,
        name: e.value[i].$1,
        order: i,
        commutesToSchool: _commuters.contains(e.value[i].$1),
      ),
];

Resident residentByName(String name) => residents.firstWhere((r) => r.name == name);

/// 지난 14일 측정 (하루 2번). 오프셋이 대칭이라 중앙값 = 목표 기저치.
List<Measurement> seedHistory() {
  const offsets = [0, 1, -1, 2, -2, 0, -1, 1, 0, 2, -2, 1, -1, 0];
  final out = <Measurement>[];
  for (final r in residents) {
    final base = seedBaselines[r.id]!;
    final cls = classes.firstWhere((c) => c.id == r.classId);
    for (var day = 1; day <= 14; day++) {
      final date = demoStart.subtract(Duration(days: day));
      for (final (h, m, k) in [(9, 50, 0), (15, 30, 7)]) {
        final value = base + offsets[(day + k + r.order) % offsets.length];
        out.add(Measurement(
          id: 'seed-${r.id}-$day-$h',
          residentId: r.id,
          classId: r.classId,
          value: value,
          measuredAt: DateTime(date.year, date.month, date.day, h, m),
          recordedBy: cls.homeroomId,
          judgment: judge(value: value, baseline: base),
        ));
      }
    }
  }
  return out;
}

final medicationGuidelines = <MedicationGuideline>[
  MedicationGuideline(
    residentId: residentByName('이서준').id,
    body: '38.0℃ 이상이 30분 넘게 이어지면 간호사에게 먼저 연락합니다.\n'
        '해열제는 간호사 또는 원장님 지시가 있을 때만 줍니다.\n'
        '평소 체온이 37.1℃로 높은 편입니다.',
    writtenBy: 'park_soyeon',
    updatedAt: DateTime(2026, 9, 2),
  ),
  MedicationGuideline(
    residentId: residentByName('박승민').id,
    body: '열이 나면 물을 자주 마시게 하고 겉옷을 벗깁니다.\n'
        '해열제는 간호사 또는 원장님 지시가 있을 때만 줍니다.',
    writtenBy: 'park_soyeon',
    updatedAt: DateTime(2026, 8, 20),
  ),
  MedicationGuideline(
    residentId: residentByName('최도윤').id,
    body: '열이 나면 간호사에게 연락합니다.',
    writtenBy: 'park_soyeon',
    updatedAt: DateTime(2026, 3, 10), // 180일 넘게 안 고침 → 오래된 지침 경고
  ),
  // 김윤서: 지침 없음 (지침 없음 화면 시연)
];

// ── 근무조 (10-2). 교대 시간은 [확인 필요]: 오전 07~15, 오후 14~22, 야간 22~07로 가정.
List<Shift> seedShifts() {
  DateTime d(int day, int h) => DateTime(2026, 10, day, h);
  return [
    Shift(id: 'sh-1027-am', type: ShiftType.am, startAt: d(27, 7), endAt: d(27, 15), staffIds: const ['park_jieun', 'lee_sujin', 'han_jimin', 'kim_haneul']),
    Shift(id: 'sh-1027-pm', type: ShiftType.pm, startAt: d(27, 14), endAt: d(27, 22), staffIds: const ['oh_sehun', 'jung_daun', 'jung_haeun', 'oh_jimin']),
    Shift(id: 'sh-1027-night', type: ShiftType.night, startAt: d(27, 22), endAt: d(28, 7), staffIds: const ['oh_jimin', 'choi_minho']),
    Shift(id: 'sh-1028-am', type: ShiftType.am, startAt: d(28, 7), endAt: d(28, 15), staffIds: amShiftStaff),
    Shift(id: 'sh-1028-pm', type: ShiftType.pm, startAt: d(28, 14), endAt: d(28, 22), staffIds: const ['oh_sehun', 'jung_daun', 'han_jimin', 'jung_haeun']),
    Shift(id: 'sh-1028-night', type: ShiftType.night, startAt: d(28, 22), endAt: d(29, 7), staffIds: const ['oh_jimin']),
  ];
}

// ── 일정 (일정 명세). 가상 예시이며 반별로 조금씩 다르게 만든다.
const _therapy = {
  'aquarius': ('감각 통합 활동', '1층 교육실'),
  'pisces': ('개별화 교육', '1층 교육실'),
  'bear': ('물리 치료', '1층 치료실'),
  'milkyway': ('작업 치료', '1층 치료실'),
  'aries': ('언어 치료', '2층 상담실'),
  'whale': ('개별화 교육', '2층 교육실'),
};
const _art = {
  'aquarius': '음악 활동',
  'pisces': '미술 활동',
  'bear': '산책',
  'milkyway': '체육 활동',
  'aries': '원예 활동',
  'whale': '음악 활동',
};

/// 한 별님의 하루 일정. 날짜만 같으면 늘 같은 결과 (저장할 필요 없음).
List<ScheduleItem> scheduleFor(Resident r, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final cls = classes.firstWhere((c) => c.id == r.classId);
  final homeroom = staff.firstWhere((s) => s.id == cls.homeroomId).displayName;
  final weekend = day.weekday >= DateTime.saturday;
  var n = 0;
  ScheduleItem it(int sh, int sm, int eh, int em, String title, String place, ScheduleKind kind,
          {String? who, TempSlot? slot}) =>
      ScheduleItem(
        id: 'sch-${r.id}-${day.month}${day.day}-${n++}',
        residentId: r.id,
        classId: r.classId,
        date: day,
        startAt: day.add(Duration(hours: sh, minutes: sm)),
        endAt: day.add(Duration(hours: eh, minutes: em)),
        title: title,
        place: place,
        kind: kind,
        staffName: who,
        tempSlot: slot,
      );

  if (weekend) {
    return [
      it(8, 0, 8, 50, '아침 식사', '식당', ScheduleKind.meal),
      it(9, 30, 10, 0, '건강 확인', '${cls.name} 생활실', ScheduleKind.living, who: homeroom, slot: TempSlot.am),
      it(10, 0, 11, 30, '여가 활동', '강당', ScheduleKind.living),
      it(12, 0, 12, 50, '점심 식사', '식당', ScheduleKind.meal),
      it(15, 0, 16, 0, '목욕', '2층 목욕실', ScheduleKind.bath, slot: TempSlot.pmBath),
      it(17, 30, 18, 20, '저녁 식사', '식당', ScheduleKind.meal),
    ];
  }
  if (r.commutesToSchool) {
    return [
      it(7, 30, 8, 10, '아침 식사', '식당', ScheduleKind.meal),
      it(8, 10, 8, 30, '건강 확인 · 등교 준비', '${cls.name} 생활실', ScheduleKind.living, who: homeroom, slot: TempSlot.am),
      it(8, 40, 14, 30, '학교', '특수학교', ScheduleKind.school),
      it(15, 0, 15, 30, '귀가 · 휴식', '${cls.name} 생활실', ScheduleKind.living, slot: TempSlot.pmReturn),
      it(16, 0, 17, 0, _art[r.classId]!, '강당', ScheduleKind.art),
      it(17, 30, 18, 20, '저녁 식사', '식당', ScheduleKind.meal),
    ];
  }
  final (therapyTitle, therapyPlace) = _therapy[r.classId]!;
  // 목욕 시간은 반마다 다르다 (13:00 / 13:40 / 14:20 …).
  final bathStart = 13 * 60 + (cls.order % 3) * 40;
  return [
    it(7, 30, 8, 10, '아침 식사', '식당', ScheduleKind.meal),
    it(9, 0, 9, 30, '건강 확인', '${cls.name} 생활실', ScheduleKind.living, who: homeroom, slot: TempSlot.am),
    it(10, 0, 11, 0, therapyTitle, therapyPlace, ScheduleKind.therapy),
    it(11, 50, 12, 40, '점심 식사', '식당', ScheduleKind.meal),
    it(bathStart ~/ 60, bathStart % 60, (bathStart + 40) ~/ 60, (bathStart + 40) % 60, '목욕', '2층 목욕실', ScheduleKind.bath,
        slot: TempSlot.pmBath),
    it(15, 30, 16, 30, _art[r.classId]!, '강당', ScheduleKind.art),
    it(17, 30, 18, 20, '저녁 식사', '식당', ScheduleKind.meal),
  ];
}

// ── 아카이브용 지난 기록 (10-3). 모두 가상 예시.
List<Entry> seedPastEntries() {
  Entry e(String id, String who, DateTime at, String name, String body, {String kind = '관찰 기록', int photos = 0}) {
    final r = residentByName(name);
    return Entry(
      id: 'past-$id',
      scope: EntryScope.resident,
      authorId: who,
      kindLabel: kind,
      createdAt: at,
      classId: r.classId,
      residentId: r.id,
      body: body,
      photoCount: photos,
    );
  }

  return [
    e('1', 'park_jieun', DateTime(2025, 9, 1, 16, 20), '이서준', '낯선 소리(드라이기)에 놀라 귀를 막고 한참 울었어요. 조용한 방으로 옮기니 10분 뒤 진정했어요.'),
    e('2', 'park_jieun', DateTime(2025, 11, 14, 10, 5), '이서준', '목욕 전에 소리 나는 장난감을 주면 덜 불안해해요.'),
    e('3', 'park_jieun', DateTime(2026, 2, 3, 19, 30), '이서준', '저녁에 미열이 있었지만 다음 날 아침 평소대로 돌아왔어요.'),
    e('4', 'lee_sujin', DateTime(2026, 4, 10, 11, 0), '이서준', '새 담임으로 첫 주. 큰 소리가 나면 손을 잡아 주면 금방 편안해져요.'),
    e('5', 'lee_sujin', DateTime(2026, 10, 20, 15, 40), '이서준', '작업 치료 시간에 블록 쌓기를 끝까지 했어요.', photos: 1),
    e('6', 'jung_haeun', DateTime(2026, 10, 25, 18, 10), '박승민', '저녁을 평소의 절반만 먹었어요.'),
    e('7', 'park_jieun', DateTime(2026, 10, 26, 9, 30), '한나리', '왼쪽 무릎 상처 소독 3일째. 잘 아물고 있어요.'),
    e('8', 'lee_sujin', DateTime(2026, 10, 24, 14, 0), '최도윤', '요즘 오전에 졸려해요. 밤잠을 확인해 주세요.'),
    e('9', 'han_jimin', DateTime(2026, 10, 23, 16, 30), '정서아', '산책 중 신발이 불편해 보였어요. 새 신발 신청했어요.'),
  ];
}
