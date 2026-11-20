// 시연 DB에 넣는 가상 자료. Claude Design 화면(모바일 3 · PC 4)에 나온 내용을 그대로 옮겼다.
// 모두 가상 인물이며 실제 혜진원 사람과 관계없다.
// 개발 DB는 이 파일을 쓰지 않는다 (dev_seed.dart의 예시 한 건씩만).
//
// 시각은 [anchor] 날짜의 시:분으로 만든다. 시연 자료를 다시 채우면 그날 기준으로 새로 만들어진다.
import 'judgment.dart';
import 'models.dart';

const staff = <Staff>[
  Staff(id: 'park_jieun', name: '박지은', role: Role.care),
  Staff(id: 'han_jimin', name: '한지민', role: Role.care),
  Staff(id: 'jung_daun', name: '정다운', role: Role.care),
  Staff(id: 'lee_sujin', name: '이수진', role: Role.care, title: '담임복지사'),
  Staff(id: 'oh_sehun', name: '오세훈', role: Role.care),
  Staff(id: 'jung_haeun', name: '정하은', role: Role.care),
  Staff(id: 'kim_haneul', name: '김하늘', role: Role.care),
  Staff(id: 'choi_minho', name: '최민호', role: Role.care),
  Staff(id: 'oh_jimin', name: '오지민', role: Role.care),
  Staff(id: 'park_soyeon', name: '박소연', role: Role.nurse, title: '수석간호사', team: '혜진원 의료지원팀'),
  Staff(id: 'park_seoyeon', name: '박서연', role: Role.office, team: '관리팀'),
  Staff(id: 'lee_minjae', name: '이민재', role: Role.office),
  Staff(id: 'han_kyungsoo', name: '한경수', role: Role.director),
  Staff(id: 'kang_dahye', name: '강다혜', role: Role.doctor, title: '촉탁의 (원장)', team: '내과·외과 · 촉탁의 · 외래전담'),
  // 협진 의료진 (가상 병원 · 가상 인물)
  Staff(id: 'yoon_seojin', name: '윤서진', role: Role.doctor, title: '원장', team: '별빛소아청소년과의원 · 소아청소년과'),
  Staff(id: 'moon_jaeho', name: '문재호', role: Role.doctor, title: '전문의', team: '온마음정신건강의학과의원 · 정신건강의학과'),
];

/// 화면별 기본 사용자: 모바일 = 생활관 선생님, PC = 수석간호사, 의사 포털 = 촉탁의.
const demoUsers = {'mobile': 'kim_haneul', 'pc': 'park_soyeon', 'doctor': 'kang_dahye'};

/// 근무조 구성 (매일 같은 틀).
const demoShiftTemplate = {
  'am': ['kim_haneul', 'park_jieun', 'lee_sujin', 'choi_minho'],
  'pm': ['oh_sehun', 'jung_daun', 'han_jimin', 'jung_haeun'],
  'night': ['oh_jimin'],
};

/// 이전 담임 (2024.03~2026.03).
const demoPreviousHomeroom = {
  'aquarius': 'han_jimin',
  'pisces': 'park_jieun',
  'bear': 'oh_sehun',
  'milkyway': 'park_jieun',
  'aries': 'jung_daun',
  'whale': 'choi_minho',
};

/// 근무 선생님의 배치 반 (담임이 아닌 사람).
const demoPlacement = {'kim_haneul': 'milkyway', 'choi_minho': 'whale', 'oh_jimin': 'aries'};

const classes = <Class>[
  Class(id: 'aquarius', name: '물병자리', color: 0xFFA89AC2, homeroomId: 'park_jieun', order: 0, sex: '여', room: '101호'),
  Class(id: 'pisces', name: '물고기자리', color: 0xFF7FA8C4, homeroomId: 'han_jimin', order: 1, sex: '여', room: '102호'),
  Class(id: 'bear', name: '곰자리', color: 0xFFB59A7A, homeroomId: 'jung_daun', order: 2, sex: '남', room: '105호'),
  Class(id: 'milkyway', name: '은하수자리', color: 0xFF87A98E, homeroomId: 'lee_sujin', order: 3, sex: '남', room: '203호'),
  Class(id: 'aries', name: '양자리', color: 0xFFD39B94, homeroomId: 'oh_sehun', order: 4, sex: '남', room: '202호'),
  Class(id: 'whale', name: '고래자리', color: 0xFF7D9BB0, homeroomId: 'jung_haeun', order: 5, sex: '남', room: '204호'),
];

/// 반별 별님 (이름, 기저치 ×10, 나이). 순서 = 다이얼 순서.
const _roster = <String, List<(String, int, int)>>{
  'aquarius': [('임유나', 364, 23), ('송지은', 365, 18), ('한나리', 363, 21), ('김윤서', 366, 26), ('서소율', 364, 17), ('홍다은', 365, 29), ('오하린', 362, 31)],
  'pisces': [('정서아', 362, 22), ('신지유', 365, 27), ('박채원', 366, 24), ('배수아', 364, 30), ('이하은', 363, 25), ('안예린', 365, 28)],
  'bear': [('문하준', 362, 26), ('조은우', 366, 23), ('장도현', 368, 22), ('권건우', 365, 29), ('백태윤', 364, 31)],
  'milkyway': [('김민준', 365, 19), ('이서준', 371, 19), ('한지호', 366, 20), ('류은호', 363, 18), ('최도윤', 369, 17), ('강시우', 366, 21)],
  'aries': [('고준우', 364, 18), ('윤예준', 368, 25), ('정현우', 365, 27), ('김민재', 366, 23), ('남정우', 363, 30), ('유로운', 365, 24)],
  'whale': [('서연우', 364, 17), ('노재희', 366, 26), ('황태양', 365, 28), ('박승민', 368, 24), ('차우진', 362, 32), ('엄성민', 367, 27)],
};

/// 학교에 다니는 별님 (통학 차량 반 공지와 맞춤).
const _commuters = {'송지은', '서소율', '최도윤', '고준우', '서연우'};

/// 의료진이 쓴 자료 (글자 그대로 보여주기만 한다).
const _medical = <String, ({String code, String? diagnosis, String? cautions, String? meds, String? prn, bool severe})>{
  '이서준': (
    code: 'HJ-2021-088',
    diagnosis: '뇌병변 2급, 경련성 질환 (발작 주의)',
    cautions: '페니실린계 · 세파계 항생제 절대 금기\n2022년 아나필락시스 유사 과민반응력 기록',
    meds: '데파코트정 250mg (조석 식후 복약)',
    prn: '38.2°C 초과 시 아세트아미노펜 500mg 1정 투여 (촉탁의 지시)',
    severe: false,
  ),
  '박승민': (
    code: 'HJ-2019-041',
    diagnosis: '지적장애 1급, 자폐성 장애',
    cautions: null,
    meds: null,
    prn: null,
    severe: true,
  ),
  '최도윤': (code: 'HJ-2023-102', diagnosis: '지적장애 2급', cautions: null, meds: null, prn: null, severe: false),
};

final residents = <Resident>[
  for (final e in _roster.entries)
    for (var i = 0; i < e.value.length; i++)
      Resident(
        id: '${e.key}-${i + 1}',
        classId: e.key,
        name: e.value[i].$1,
        order: i,
        age: e.value[i].$3,
        sex: classes.firstWhere((c) => c.id == e.key).sex,
        commutesToSchool: _commuters.contains(e.value[i].$1),
        code: _medical[e.value[i].$1]?.code ?? 'HJ-20${18 + (i + e.key.length) % 7}-${(100 + i * 7 + e.key.length * 3).toString().padLeft(3, '0')}',
        diagnosis: _medical[e.value[i].$1]?.diagnosis,
        cautions: _medical[e.value[i].$1]?.cautions,
        regularMeds: _medical[e.value[i].$1]?.meds,
        prnNote: _medical[e.value[i].$1]?.prn,
        severe: _medical[e.value[i].$1]?.severe ?? false,
      ),
];

Resident residentByName(String name) => residents.firstWhere((r) => r.name == name);

/// 시드에서 기저치가 나오도록 쓰는 목표값. 실제 기저치는 측정 기록에서 계산된다.
final Map<String, int> seedBaselines = {
  for (final e in _roster.entries)
    for (var i = 0; i < e.value.length; i++) '${e.key}-${i + 1}': e.value[i].$2,
};

/// 지난 14일 측정 (하루 2번). 오프셋이 대칭이라 중앙값 = 목표 기저치.
List<Measurement> seedHistory(DateTime anchor) {
  const offsets = [0, 1, -1, 2, -2, 0, -1, 1, 0, 2, -2, 1, -1, 0];
  final out = <Measurement>[];
  for (final r in residents) {
    final base = seedBaselines[r.id]!;
    final cls = classes.firstWhere((c) => c.id == r.classId);
    for (var day = 1; day <= 14; day++) {
      final date = DateTime(anchor.year, anchor.month, anchor.day - day);
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

List<MedicationGuideline> medicationGuidelines(DateTime anchor) => [
      MedicationGuideline(
        residentId: residentByName('이서준').id,
        body: '38.0℃ 이상이 30분 넘게 이어지면 간호 선생님에게 먼저 연락합니다.\n'
            '해열제는 간호 선생님 또는 촉탁의 지시가 있을 때만 줍니다.\n'
            '평소 체온이 37.1℃로 높은 편입니다.',
        writtenBy: 'park_soyeon',
        updatedAt: DateTime(anchor.year, anchor.month - 2, 2),
      ),
      MedicationGuideline(
        residentId: residentByName('박승민').id,
        body: '열이 나면 물을 자주 마시게 하고 겉옷을 벗깁니다.\n'
            '해열제는 간호 선생님 또는 촉탁의 지시가 있을 때만 줍니다.',
        writtenBy: 'park_soyeon',
        updatedAt: DateTime(anchor.year, anchor.month - 2, 20),
      ),
      MedicationGuideline(
        residentId: residentByName('최도윤').id,
        body: '열이 나면 간호 선생님에게 연락합니다.',
        writtenBy: 'park_soyeon',
        updatedAt: DateTime(anchor.year, anchor.month - 7, 10), // 180일 넘게 안 고침 → 오래된 지침 경고
      ),
    ];

// ── 별님 하루 일정 (체온 측정 시점 · 현재 위치 계산용). 날짜만 같으면 늘 같은 결과.
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

/// 한 별님의 하루 일정. [cls]·[homeroom]은 저장소에서 넘겨준다 (개발 DB의 반에도 쓴다).
List<ScheduleItem> scheduleFor(Resident r, Class cls, String homeroom, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
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
      it(8, 40, 14, 30, '울산행복학교 등교', '특수학교', ScheduleKind.school),
      it(15, 0, 15, 30, '귀가 · 휴식', '${cls.name} 생활실', ScheduleKind.living, slot: TempSlot.pmReturn),
      it(16, 0, 17, 0, _art[r.classId] ?? '여가 활동', '강당', ScheduleKind.art),
      it(17, 30, 18, 20, '저녁 식사', '식당', ScheduleKind.meal),
    ];
  }
  final (therapyTitle, therapyPlace) = _therapy[r.classId] ?? ('개별화 교육', '1층 교육실');
  // 목욕 시간은 반마다 다르다 (13:00 / 13:40 / 14:20 …).
  final bathStart = 13 * 60 + (cls.order % 3) * 40;
  return [
    it(7, 30, 8, 10, '아침 식사', '식당', ScheduleKind.meal),
    it(9, 0, 9, 30, '건강 확인', '${cls.name} 생활실', ScheduleKind.living, who: homeroom, slot: TempSlot.am),
    it(10, 0, 11, 0, therapyTitle, therapyPlace, ScheduleKind.therapy),
    it(11, 50, 12, 40, '점심 식사', '식당', ScheduleKind.meal),
    it(bathStart ~/ 60, bathStart % 60, (bathStart + 40) ~/ 60, (bathStart + 40) % 60, '목욕', '2층 목욕실', ScheduleKind.bath,
        slot: TempSlot.pmBath),
    it(15, 30, 16, 30, _art[r.classId] ?? '여가 활동', '강당', ScheduleKind.art),
    it(17, 30, 18, 20, '저녁 식사', '식당', ScheduleKind.meal),
  ];
}

// ── 별님카드용 지난 기록. 모두 가상 예시.
List<Entry> seedPastEntries(DateTime anchor) {
  DateTime ago(int days, int h, int m) => DateTime(anchor.year, anchor.month, anchor.day - days, h, m);
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
    e('1', 'park_jieun', ago(420, 16, 20), '이서준', '낯선 소리(드라이기)에 놀라 귀를 막고 한참 울었어요. 조용한 방으로 옮기니 10분 뒤 진정했어요.', kind: '감각 메모'),
    e('2', 'park_jieun', ago(350, 10, 5), '이서준', '목욕 전에 소리 나는 장난감을 주면 덜 불안해해요.', kind: '감각 메모'),
    e('3', 'park_jieun', ago(270, 19, 30), '이서준', '저녁에 미열이 있었지만 다음 날 아침 평소대로 돌아왔어요.'),
    e('4', 'lee_sujin', ago(200, 11, 0), '이서준', '새 담임으로 첫 주. 큰 소리가 나면 손을 잡아 주면 금방 편안해져요.'),
    e('5', 'lee_sujin', ago(8, 15, 40), '이서준', '작업 치료 시간에 블록 쌓기를 끝까지 했어요.', photos: 1),
    e('6', 'jung_haeun', ago(3, 18, 10), '박승민', '저녁을 평소의 절반만 먹었어요.'),
    e('7', 'park_jieun', ago(2, 9, 30), '한나리', '왼쪽 무릎 상처 소독 3일째. 잘 아물고 있어요.'),
    e('8', 'lee_sujin', ago(4, 14, 0), '최도윤', '요즘 오전에 졸려해요. 밤잠을 확인해 주세요.'),
    e('9', 'han_jimin', ago(5, 16, 30), '정서아', '산책 중 신발이 불편해 보였어요. 새 신발 신청했어요.'),
  ];
}

// ── PC 02 통합 일정 (월간 캘린더 + 선택 일과표). 날짜는 [anchor] 달의 같은 날짜.
List<CalendarEvent> seedCalendar(DateTime anchor) {
  final out = <CalendarEvent>[];
  var n = 0;
  final lastDay = DateTime(anchor.year, anchor.month + 1, 0).day;
  void add(int day, String? time, String title, CalendarCategory cat,
      {String? classId, String? owner, String? detail, bool holiday = false, int monthOffset = 0}) {
    final d = monthOffset == 0 ? day.clamp(1, lastDay) : day;
    out.add(CalendarEvent(
      id: 'cal-${++n}',
      date: DateTime(anchor.year, anchor.month + monthOffset, d),
      time: time,
      title: title,
      category: cat,
      classId: classId,
      owner: owner,
      detail: detail,
      holiday: holiday,
      createdBy: 'park_seoyeon',
      createdAt: DateTime(anchor.year, anchor.month, 1, 9),
    ));
  }

  const f = CalendarCategory.facility, ed = CalendarCategory.education, th = CalendarCategory.therapy;
  const c = CalendarCategory.care, md = CalendarCategory.medical;
  // 지난달 마지막 주 (달력 첫 줄)
  add(27, null, '최종 정산', f, monthOffset: -1);
  add(28, null, '주간 위생 회의', f, monthOffset: -1);
  add(29, null, '식자재 수급 검수', f, monthOffset: -1);
  add(30, null, '월간 당직표 확정', f, monthOffset: -1);
  // 이번 달
  add(1, '09:00', '특별지원 프로그램', f);
  add(1, '12:00', '절기 특별급식', c);
  add(2, '10:00', '가을 나들이 산책', f);
  add(2, '14:00', '외부자원봉사팀', f);
  add(3, null, '공휴일 당직 비상대기', f, holiday: true);
  add(4, '11:00', '일요 종교활동', f);
  add(5, '09:30', '특수교육 개학', ed);
  add(5, '13:30', '수질 검사', f);
  add(6, '10:00', '물리/작업치료', th);
  add(6, '14:00', '치과검진 방문', md);
  add(7, '10:00', '소방합동훈련', f);
  add(7, '14:00', '위생소독 (전관)', f);
  add(8, '09:30', '특수학급 통학', ed);
  add(8, '13:00', '물병자리 목욕', c, classId: 'aquarius');
  add(9, null, '공휴일 간호 당직', md, holiday: true);
  add(9, '14:00', '영화 상영회', f);
  add(10, null, '주말 프로그램 운영', f);
  add(11, null, '시설 내부 정리', f);
  add(12, '09:30', '개별화 교육', ed);
  add(12, '10:30', '촉탁의 비대면', md);
  add(13, '09:30', '물리치료 1차', th);
  add(13, '14:00', '독감 예방접종', md);
  add(14, '10:00', '식자재 정기점검', f);
  add(14, '13:00', '곰자리 온수목욕', c, classId: 'bear');
  add(15, '14:00', '미술 감각치료', th);
  add(15, '15:30', '정밀 혈압추적', md);
  add(16, '09:30', '특수학급 통학', ed);
  add(16, '16:00', '주간 인수인계', f);
  add(17, null, '가족 비대면 영상면회', f);
  add(18, null, '휴일 시설 안전순찰', f);
  add(19, '09:30', '1층 개별화 교육', ed);
  add(19, '14:30', '작업치료 세션', th);
  add(20, '10:00', '정밀 건강검진', md);
  add(20, '13:00', '고래자리 목욕', c, classId: 'whale');
  add(21, '10:00', '공조기 필터 청소', f);
  add(21, '14:00', '음악치료', th);
  add(22, '09:30', '물리치료 2차', th);
  add(22, '15:00', '실내 레크레이션', f);
  add(23, '09:30', '특수학급 통학', ed);
  add(23, '15:30', '약제 처방 점검', md);
  add(24, '10:00', '주말 음악 산책', f);
  add(25, null, '온수 공급 상태 검수', f);
  add(26, '09:30', '특수학급 통학', ed);
  add(26, '14:00', '전기안전 정기점검', f);
  add(27, '10:00', '재활운동 세션', th);
  add(27, '13:30', '생활관 환기 정비', f);
  add(29, '09:30', '1층 개별화 교육', ed);
  add(29, '13:00', '양자리 온수목욕', c, classId: 'aries');
  add(30, '10:00', '월말 위생소독', f);
  add(30, '14:00', '촉탁의사 종합회의', md);
  add(31, '14:00', '생일 축하회', f);

  // 오늘 일과표 (선택 일과표 12건 중 화면에 보이는 것)
  final today = anchor.day;
  add(today, '08:30', '전체 온수 보일러 점검 및 난방 시운전', f, owner: '관리팀 박서연', detail: '1~3층 전 생활관 동파 대비 정기 순회 점검');
  add(today, '09:30', '1층 개별화 교육실 인지 촉진 활동', ed,
      classId: 'milkyway', owner: '특수교사 김민호', detail: '은하수자리 3명 (김민준, 류은호, 최도윤 별님)');
  add(today, '09:30', '2층 물리치료실 관절 가동성 훈련', th, owner: '물리치료사 이원호', detail: '하체 보행 보조 기구 훈련 및 상지 스트레칭');
  add(today, '10:25', '촉탁의 비대면 화상 진료 세션', md, owner: '강다혜 촉탁의', detail: '강다혜 촉탁의 ↔ 박소연 수석간호사 화상 입회');
  add(today, '11:30', '점심 식사 배식 및 연하장애 별님 맞춤 케어', c, owner: '영양조리팀 & 생활교사', detail: '연식/다진식 분류 확인, 식후 복약 지도 (6개 반)');
  add(today, '13:00', '온수 목욕 진행 (은하수자리 1순위)', c,
      classId: 'milkyway', owner: '은하수자리 이수진', detail: '특수 목욕실 1호기 가동 · 수온 38.5°C 안정 유지 상태 확인');
  add(today, '14:00', '실내 감각 자유놀이 & 진정 음악 치료', th, owner: '생활재활교사 배정', detail: '물소리 음향 자극 및 촉각 블록 놀이 (대강당)');
  add(today, '15:00', '울산행복학교 통학 버스 도착 및 귀가 맞이', ed, owner: '인솔교사 배정', detail: '최도윤 별님 외 4명 하차 인수인계 및 체온 확인');
  add(today, '15:30', '2차 경과 확인 진료 및 처방전 발행', md, owner: '강다혜 촉탁의', detail: '약제 조제 요청 및 복약 시간표 반영');
  add(today, '16:30', '오후 간식 제공 및 생활관 30분 공기 순환', c, owner: '영양실 & 생활반', detail: '단호박죽(저당) 제공, 섭취량 기록');
  return out;
}
