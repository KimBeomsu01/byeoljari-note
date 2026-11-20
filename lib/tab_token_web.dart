import 'dart:js_interop';

const _key = 'byeoljari_tab_token';

@JS('byeoljariTab.get')
external JSString _get(JSString key);
@JS('byeoljariTab.set')
external void _set(JSString key, JSString value);
@JS('byeoljariTab.remove')
external void _remove(JSString key);

/// 이 탭에서 로그인한 토큰 (탭을 닫으면 사라진다).
String? readTabToken() {
  final v = _get(_key.toJS).toDart;
  return v.isEmpty ? null : v;
}

void writeTabToken(String? token) => token == null ? _remove(_key.toJS) : _set(_key.toJS, token.toJS);
