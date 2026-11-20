import 'dart:js_interop';

@JS('byeoljariPhotos.pick')
external JSPromise<JSString> _pick();

/// 사진 한 장을 골라 줄인 JPEG data: 주소로. 고르지 않으면 null.
/// [camera]는 웹에서 쓰지 않는다 (휴대폰 브라우저가 카메라 · 사진첩을 함께 보여준다).
Future<String?> pickPhotoDataUrl({bool camera = false}) async {
  final url = (await _pick().toDart).toDart;
  return url.isEmpty ? null : url;
}
