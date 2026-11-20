// 별님 프로필 사진: 그리기 · 고르기 · 올리기.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../photo_picker_native.dart' if (dart.library.js_interop) '../photo_picker_web.dart';
import 'avatar.dart';
import 'theme.dart';

/// 사진 고르기 → 줄인 JPEG data: 주소. 웹은 브라우저가 사진첩·카메라를 고르게 하고,
/// 설치형 앱은 [camera]로 카메라 · 사진첩을 나눈다. 테스트에서 덮어쓴다.
final photoPickerProvider = Provider<Future<String?> Function({bool camera})>((ref) => pickPhotoDataUrl);

/// 서버에 올린 사진(`/api/photo/<id>`) 받기: 서버 주소 + 로그인 헤더.
/// 웹은 같은 주소 · 쿠키라 비어 있어도 되고, 설치형 앱은 ServerApp이 서버 주소와 토큰을 넣는다.
final photoAccessProvider =
    Provider<({Uri? base, Map<String, String> headers}) Function()>((ref) => () => (base: null, headers: const {}));

/// 고른 사진을 올리고 저장할 주소를 돌려준다.
/// 서버 없이 쓸 때는 data: 주소를 그대로 저장한다. 서버에서는 ServerApp이 `/api/photo`로 올리게 덮어쓴다.
final photoUploadProvider = Provider<Future<String> Function(String dataUrl)>((ref) => (dataUrl) async => dataUrl);

/// data: 주소 → (mime, 바이트)
(String, List<int>) decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  final head = dataUrl.substring(5, comma); // image/jpeg;base64
  return (head.split(';').first, base64Decode(dataUrl.substring(comma + 1)));
}

/// 저장된 사진 주소를 그린다: `face:` 시연 그림 · `data:` · 서버 주소.
class ResidentPhotoImage extends ConsumerWidget {
  const ResidentPhotoImage(this.url, {super.key, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url.startsWith('face:')) {
      final parts = url.split(':');
      return SvgPicture.string(residentSceneSvg(parts[1], int.tryParse(parts.elementAtOrNull(2) ?? '') ?? 0), fit: fit);
    }
    if (url.startsWith('data:')) {
      return Image.memory(base64Decode(url.substring(url.indexOf(',') + 1)),
          fit: fit, gaplessPlayback: true, errorBuilder: (_, _, _) => const _Broken());
    }
    final access = ref.watch(photoAccessProvider)();
    final full = access.base != null && url.startsWith('/') ? access.base!.resolve(url).toString() : url;
    return Image.network(full,
        headers: access.headers.isEmpty ? null : access.headers,
        fit: fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Ds.gray300)),
        errorBuilder: (_, _, _) => const _Broken());
  }
}

/// 동그란 별님 얼굴: 프로필 사진이 있으면 사진, 없으면 이름 두 글자.
class ResidentCircle extends StatelessWidget {
  const ResidentCircle({super.key, required this.label, this.url, this.size = 28});
  final String label;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: url != null
                ? ResidentPhotoImage(url!)
                : ColoredBox(
                    color: Ds.gray100,
                    child: Center(
                      child: Text(label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                              fontSize: size * 0.36, height: 1.2, fontWeight: FontWeight.w600, color: Ds.gray700, letterSpacing: -0.3)),
                    ),
                  ),
          ),
        ),
      );
}

class _Broken extends StatelessWidget {
  const _Broken();
  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Ds.gray100, child: Center(child: Icon(Icons.broken_image_outlined, color: Ds.gray400)));
}
