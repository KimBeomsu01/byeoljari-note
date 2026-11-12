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

final residents = <Resident>[
  for (final e in _roster.entries)
    for (var i = 0; i < e.value.length; i++)
      Resident(id: '${e.key}-${i + 1}', classId: e.key, name: e.value[i].$1, order: i),
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
