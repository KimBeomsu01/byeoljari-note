// 별님·직원 얼굴 그림. 팀 시제품(byeoljari-handover_v2.html)의 face()를 그대로 옮겼다.
// 실제 사진 대신 쓰는 가상 일러스트다.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'seed.dart';

/// 바탕 · 옷 · 머리 색 (시제품 PAL 7가지).
const _pal = [
  ['#e8eddf', '#9aaf88', '#55463f'],
  ['#f4e6e2', '#cda3a0', '#4b3e39'],
  ['#e5ecf4', '#8ea8c3', '#343b44'],
  ['#eee7f2', '#b2a0c1', '#54443f'],
  ['#f2ebdf', '#c6b28b', '#48433c'],
  ['#e5eeeb', '#92b6a9', '#453d39'],
  ['#f1e5e1', '#c4a198', '#534039'],
];

/// 머리 모양: 0·2 짧은 머리, 1·3 긴 머리.
const _front = {
  0: 'M17 29c-6-26 32-28 31-5-9 0-14-3-18-9-2 8-8 10-13 10z',
  1: 'M17 29c-6-26 32-28 31-5-9 0-14-3-18-9-2 8-8 10-13 10z',
  2: 'M17 28c-4-22 29-29 31-5-5 0-8-5-9-9-5 7-12 8-22 8z',
  3: 'M17 29c-5-25 31-29 31-2-10-1-14-9-15-14-2 9-7 14-16 16z',
};
const _back = {
  0: 'M0 0',
  1: 'M17 29c-2-26 34-27 31 0l5 24H12z',
  2: 'M0 0',
  3: 'M17 29c-2-26 34-27 31 0l5 24H12z',
};

/// 직원 얼굴 (시제품 T 표). 없는 사람은 이름으로 고른다.
const _staffLook = {
  'kim_haneul': (['#eae7df', '#b8a58a', '#3f342e'], 1),
  'park_jieun': (['#e9ecde', '#9cae86', '#4a3a33'], 3),
  'lee_sujin': (['#e6ebf1', '#93a9c4', '#2f2b2a'], 1),
  'choi_minho': (['#ece6ee', '#a99bbd', '#34302d'], 0),
  'park_seoyeon': (['#efe9dc', '#c9b48a', '#3b322c'], 3),
  'oh_sehun': (['#e5eeeb', '#92b6a9', '#453d39'], 0),
};

class _Look {
  const _Look(this.bg, this.shirt, this.hair, this.style);
  final String bg, shirt, hair;
  final int style;
}

/// 시제품 roster(): 반 순서(off)와 별님 순서(i)로 색·머리를 정한다. 여자 반은 긴 머리.
_Look _residentLook(String residentId) {
  final r = residents.firstWhere((x) => x.id == residentId);
  final cls = classes.firstWhere((c) => c.id == r.classId);
  final off = cls.order;
  final female = cls.sex == '여';
  final st = female ? [1, 3][(r.order + off) % 2] : [0, 2][(r.order + off) % 2];
  final p = _pal[(r.order + off) % 7];
  return _Look(p[0], p[1], p[2], st);
}

_Look _staffLookOf(String staffId) {
  final s = _staffLook[staffId];
  if (s != null) return _Look(s.$1[0], s.$1[1], s.$1[2], s.$2);
  final h = staffId.codeUnits.fold<int>(0, (a, b) => a + b);
  final p = _pal[h % 7];
  return _Look(p[0], p[1], p[2], h % 4);
}

String _svg(_Look p, {required bool detail, required bool eyes}) {
  final b = StringBuffer(
      '<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg"><rect width="64" height="64" fill="${p.bg}"/>'
      '<path d="${_back[p.style]}" fill="${p.hair}"/>'
      '<path d="M9 64c0-20 12-24 23-24s23 4 23 24" fill="${p.shirt}"/>');
  if (detail) b.write('<path d="M26 39v7c4 4 8 4 12 0v-7" fill="#e6bba3"/>');
  b.write('<ellipse cx="32" cy="28" rx="14" ry="17" fill="#f0ccb3"/><path d="${_front[p.style]}" fill="${p.hair}"/>');
  if (eyes) b.write('<circle cx="26" cy="30" r="1.4" fill="#68554e"/><circle cx="38" cy="30" r="1.4" fill="#68554e"/>');
  if (detail) b.write('<path d="M29 36q3 3 6 0" fill="none" stroke="#bd8c7b" stroke-width="1.2" stroke-linecap="round"/>');
  b.write('</svg>');
  return b.toString();
}

/// 동그란 얼굴 그림. [ring]이 있으면 바깥에 테두리 (선택됨 등).
class FaceAvatar extends StatelessWidget {
  const FaceAvatar.resident(String residentId, {super.key, this.size = 44, this.ring})
      : _id = residentId,
        _staff = false;
  const FaceAvatar.staff(String staffId, {super.key, this.size = 32, this.ring})
      : _id = staffId,
        _staff = true;

  final String _id;
  final bool _staff;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final look = _staff ? _staffLookOf(_id) : _residentLook(_id);
    final svg = SvgPicture.string(_svg(look, detail: size >= 56, eyes: size >= 24), width: size, height: size);
    final face = ClipOval(child: SizedBox(width: size, height: size, child: svg));
    if (ring == null) return ExcludeSemantics(child: face);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring!, width: 2.5)),
        child: face,
      ),
    );
  }
}
