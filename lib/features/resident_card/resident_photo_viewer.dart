// 별님 프로필 사진 기록 (카카오톡 프로필처럼): 검은 화면에 최신 사진부터 옆으로 넘겨 본다.
// 사진은 그 반 담당 선생님만 올린다. 지우는 기능은 없다 (기록은 지우지 않는다).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/photo.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// 프로필 사진 기록을 연다.
Future<void> openPhotoHistory(BuildContext context, String residentId) => Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => ResidentPhotoViewer(residentId: residentId),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
          );
        },
      ),
    );

class ResidentPhotoViewer extends ConsumerStatefulWidget {
  const ResidentPhotoViewer({super.key, required this.residentId});
  final String residentId;

  @override
  ConsumerState<ResidentPhotoViewer> createState() => _ResidentPhotoViewerState();
}

class _ResidentPhotoViewerState extends ConsumerState<ResidentPhotoViewer> {
  final _pages = PageController();
  int _index = 0;
  bool _uploading = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    // 설치형 앱은 카메라 · 사진첩을 먼저 고른다 (웹은 브라우저가 고르게 한다).
    var camera = false;
    if (!kIsWeb) {
      final choice = await showModalBottomSheet<bool>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 찍기'),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('사진첩에서 고르기'),
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ]),
        ),
      );
      if (choice == null || !mounted) return;
      camera = choice;
    }
    String? picked;
    try {
      picked = await ref.read(photoPickerProvider)(camera: camera);
    } catch (e) {
      if (mounted) showDsToast(context, '사진을 고르지 못했어요', icon: Icons.error_outline, iconColor: Ds.red500);
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(photoUploadProvider)(picked);
      repo.addPhoto(widget.residentId, url, by: me);
      if (!mounted) return;
      setState(() => _index = 0);
      if (_pages.hasClients) _pages.jumpToPage(0);
      showDsToast(context, '프로필 사진을 바꿨어요');
    } catch (e) {
      if (mounted) showDsToast(context, '사진을 올리지 못했어요. 다시 시도해 주세요.', icon: Icons.error_outline, iconColor: Ds.red500);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final r = repo.residents.where((x) => x.id == widget.residentId).firstOrNull;
    if (r == null) return const SizedBox.shrink();
    final photos = repo.photosOf(r.id);
    final canUpload = repo.canUploadPhoto(me, r.id);
    // 개발 DB에서 사진이 아직 없으면 예시 한 장 (저장하지 않음)
    final example = photos.isEmpty && repo.isDev;
    final index = photos.isEmpty ? 0 : _index.clamp(0, photos.length - 1);
    final current = photos.isEmpty ? null : photos[index];
    final safe = MediaQuery.paddingOf(context);

    Widget body;
    if (photos.isNotEmpty) {
      body = PageView.builder(
        controller: _pages,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => _ZoomablePhoto(key: ValueKey(photos[i].id), url: photos[i].url),
      );
    } else if (example) {
      body = Center(
        child: AspectRatio(aspectRatio: 1, child: ResidentPhotoImage('face:${r.id}:1', fit: BoxFit.contain)),
      );
    } else {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(40)),
            child: Text(r.shortName,
                style: const TextStyle(fontSize: 32, height: 1.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          const Text('아직 올린 프로필 사진이 없어요',
              style: TextStyle(fontSize: T.body, height: 1.5, fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: body),
        // 위: 닫기 · 이름 · 몇 번째
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _Shade(
            top: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(4, safe.top + 4, 16, 16),
              child: Row(children: [
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${r.name} 프로필',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: T.bodyLg, height: 1.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                if (photos.length > 1)
                  Text('${index + 1} / ${photos.length}',
                      style: const TextStyle(
                          fontSize: T.label, height: 1.5, fontWeight: FontWeight.w600, color: Colors.white70, fontFeatures: tabular)),
                if (example) const ExampleTag(),
              ]),
            ),
          ),
        ),
        // 아래: 언제 · 누가 올렸는지 + 사진 올리기
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _Shade(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 32, 20, safe.bottom + 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                if (current != null) ...[
                  Row(children: [
                    if (index == 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Ds.violet500, borderRadius: BorderRadius.circular(Radii.pill)),
                        child: const Text('지금 프로필',
                            style: TextStyle(fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(_date(current.uploadedAt),
                        style: const TextStyle(
                            fontSize: T.body, height: 1.5, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: tabular)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${repo.staff(current.uploadedBy).displayName}이 올렸어요',
                      style: const TextStyle(fontSize: T.label, height: 1.5, color: Colors.white70)),
                ] else if (example)
                  const Text('예시 사진이에요. 실제 사진을 올리면 이 예시는 사라져요.',
                      style: TextStyle(fontSize: T.label, height: 1.5, color: Colors.white70)),
                const SizedBox(height: 16),
                if (canUpload)
                  Semantics(
                    button: true,
                    label: '프로필 사진 올리기',
                    excludeSemantics: true,
                    child: FilledButton.icon(
                      key: const Key('photo-upload'),
                      onPressed: _uploading ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Ds.gray900,
                        disabledBackgroundColor: Colors.white24,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
                        textStyle: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.photo_camera_outlined, size: 20),
                      label: Text(_uploading ? '올리는 중…' : '사진 올리기'),
                    ),
                  )
                else
                  Row(children: [
                    const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('프로필 사진은 ${repo.classOf(r.classId).name} 담당 선생님만 올릴 수 있어요',
                          style: const TextStyle(fontSize: T.caption, height: 1.5, color: Colors.white54)),
                    ),
                  ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  static String _date(DateTime t) =>
      '${t.year}. ${t.month.toString().padLeft(2, '0')}. ${t.day.toString().padLeft(2, '0')}.';
}

/// 글자가 사진 위에서도 읽히게 위·아래를 살짝 어둡게.
class _Shade extends StatelessWidget {
  const _Shade({required this.top, required this.child});
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: const [Color(0x99000000), Color(0x00000000)],
          ),
        ),
        child: child,
      );
}

/// 두 손가락으로 키워 보기. 키우지 않았을 때는 옆으로 넘기기가 되게 끌기를 막는다.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({super.key, required this.url});
  final String url;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _ctrl = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        transformationController: _ctrl,
        panEnabled: _zoomed,
        minScale: 1,
        maxScale: 4,
        onInteractionEnd: (_) {
          final zoomed = _ctrl.value.getMaxScaleOnAxis() > 1.01;
          if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
        },
        child: Center(child: ResidentPhotoImage(widget.url, fit: BoxFit.contain)),
      );
}
