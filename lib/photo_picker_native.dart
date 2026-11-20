// 설치형 앱(아이폰 · 안드로이드)의 사진 고르기: 카메라 또는 사진첩 → 긴 쪽 1280px JPEG → data: 주소.
import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// 사진 한 장을 골라 줄인 JPEG data: 주소로. 고르지 않으면 null.
Future<String?> pickPhotoDataUrl({bool camera = false}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 85,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final mime = file.mimeType ?? (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
