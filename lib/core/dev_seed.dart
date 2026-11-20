// 개발 DB의 처음 상태. 가상 시연 자료 없이, 화면이 비어 보이지 않도록 자리마다 "예시" 한 건만 둔다.
// 예시 명단(반·별님·직원)은 실제 명단이 하나라도 생기면 화면에서 숨겨진다 (repository.dart).
// 목록 자리(기록·이상 건·일정·호출 등)의 예시 카드는 데이터가 아니라 화면이 그린다 (ds.dart ExampleTag).
import 'models.dart';

const exampleStaff = <Staff>[
  Staff(id: 'ex_care', name: '예시', role: Role.care, title: '선생님', example: true),
  Staff(id: 'ex_nurse', name: '예시', role: Role.nurse, title: '간호사', team: '의료지원팀', example: true),
  Staff(id: 'ex_doctor', name: '예시', role: Role.doctor, title: '촉탁의', team: '촉탁의', example: true),
];

const exampleClasses = <Class>[
  Class(id: 'ex_class', name: '예시반', color: 0xFF8B95A1, homeroomId: 'ex_care', order: 0, sex: '남', room: '000호', example: true),
];

const exampleResidents = <Resident>[
  Resident(id: 'ex_resident', classId: 'ex_class', name: '예시 별님', order: 0, sex: '남', age: 20, example: true),
];

const exampleUsers = {'mobile': 'ex_care', 'pc': 'ex_nurse', 'doctor': 'ex_doctor'};
