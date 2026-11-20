// 별님·직원 얼굴 그림. 팀 시제품(byeoljari-handover_v2.html)의 face()를 그대로 옮겼다.
// 실제 사진 대신 쓰는 가상 일러스트다.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

/// 별님 id로 색·머리를 정한다 (명단은 DB에 있으므로 id만 보고 고른다).
_Look _residentLook(String residentId) {
  final h = residentId.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
  final p = _pal[h % 7];
  return _Look(p[0], p[1], p[2], h % 4);
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

/// 시연용 프로필 사진 그림 (가상 일러스트, 실제 사진 아님). 0 생일 · 1 봄 소풍 · 2 겨울 · 3 바다.
const residentSceneTitles = ['생일 파티', '봄 소풍', '첫눈 오는 날', '바다 나들이'];

String residentSceneSvg(String residentId, int scene) {
  final p = _residentLook(residentId);
  final s = scene % 4;
  const bgs = ['#fce9ee', '#e7f3e1', '#e4ecf8', '#ddf0f4'];
  final b = StringBuffer('<svg viewBox="0 0 320 320" xmlns="http://www.w3.org/2000/svg"><rect width="320" height="320" fill="${bgs[s]}"/>');
  // 뒤 배경
  switch (s) {
    case 0:
      for (final (x, y, c) in [(40, 60, '#f6b0c3'), (276, 48, '#ffd66b'), (60, 170, '#9fd3c7'), (262, 160, '#b8a6e0'), (30, 260, '#ffd66b'), (290, 250, '#f6b0c3')]) {
        b.write('<circle cx="$x" cy="$y" r="9" fill="$c"/>');
      }
    case 1:
      b.write('<circle cx="262" cy="58" r="28" fill="#ffe3a3"/>');
      for (final (x, y) in [(42, 236), (74, 262), (276, 222), (250, 268)]) {
        b.write('<circle cx="$x" cy="$y" r="14" fill="#f7c6d0"/><circle cx="$x" cy="$y" r="5" fill="#ffd66b"/>');
      }
    case 2:
      for (final (x, y) in [(36, 40), (90, 26), (250, 34), (292, 90), (24, 130), (280, 170), (52, 200), (300, 260), (20, 290)]) {
        b.write('<circle cx="$x" cy="$y" r="5" fill="#ffffff"/>');
      }
    case 3:
      b.write('<circle cx="58" cy="62" r="26" fill="#ffe3a3"/>'
          '<path d="M0 230q40-20 80 0t80 0 80 0 80 0V320H0z" fill="#9ccfe0"/>'
          '<path d="M0 262q40-18 80 0t80 0 80 0 80 0V320H0z" fill="#7dbbd3"/>');
  }
  // 얼굴 (64 그림을 4배로)
  b.write('<g transform="translate(32 64) scale(4)">'
      '<path d="${_back[p.style]}" fill="${p.hair}"/>'
      '<path d="M9 64c0-20 12-24 23-24s23 4 23 24" fill="${p.shirt}"/>'
      '<path d="M26 39v7c4 4 8 4 12 0v-7" fill="#e6bba3"/>'
      '<ellipse cx="32" cy="28" rx="14" ry="17" fill="#f0ccb3"/><path d="${_front[p.style]}" fill="${p.hair}"/>'
      '<circle cx="26" cy="30" r="1.4" fill="#68554e"/><circle cx="38" cy="30" r="1.4" fill="#68554e"/>'
      '<path d="M28 35q4 4 8 0" fill="none" stroke="#bd8c7b" stroke-width="1.2" stroke-linecap="round"/>'
      '<circle cx="22" cy="34" r="2.2" fill="#f2b5a8" opacity="0.6"/><circle cx="42" cy="34" r="2.2" fill="#f2b5a8" opacity="0.6"/>'
      '</g>');
  // 앞 소품
  switch (s) {
    case 0:
      b.write('<polygon points="160,14 128,100 192,100" fill="#f6b0c3"/>'
          '<path d="M141 66h38M134 84h52" stroke="#ffffff" stroke-width="5"/><circle cx="160" cy="14" r="10" fill="#ffd66b"/>');
    case 2:
      b.write('<rect x="114" y="236" width="92" height="24" rx="12" fill="#e58c8c"/><rect x="176" y="250" width="22" height="56" rx="8" fill="#d97a7a"/>');
  }
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
