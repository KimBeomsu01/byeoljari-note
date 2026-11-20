// 프로필 사진 주소: 설치형 앱은 서버 주소 + 로그인 토큰으로 받는다.
import 'package:byeoljari_note/core/photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('서버 사진(/api/photo/..)은 서버 주소로 바꾸고 로그인 헤더를 붙인다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        photoAccessProvider.overrideWithValue(
            () => (base: Uri.parse('http://server.test:8093/api/'), headers: {'Authorization': 'Bearer t1'})),
      ],
      child: const MaterialApp(home: ResidentPhotoImage('/api/photo/abc')),
    ));
    final image = tester.widget<Image>(find.byType(Image)).image as NetworkImage;
    expect(image.url, 'http://server.test:8093/api/photo/abc');
    expect(image.headers, {'Authorization': 'Bearer t1'});
  });

  testWidgets('웹(기본)은 주소 그대로 · 헤더 없음', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ResidentPhotoImage('/api/photo/abc'))));
    final image = tester.widget<Image>(find.byType(Image)).image as NetworkImage;
    expect(image.url, '/api/photo/abc');
    expect(image.headers, isNull);
  });

  test('data: 주소 나누기', () {
    final (mime, bytes) = decodeDataUrl('data:image/jpeg;base64,AQID');
    expect(mime, 'image/jpeg');
    expect(bytes, [1, 2, 3]);
  });
}
