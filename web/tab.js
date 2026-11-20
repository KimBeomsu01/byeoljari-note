// 탭마다 따로 로그인을 기억한다 (sessionStorage). 같은 브라우저에서 /pc 와 /doctor 를 다른 계정으로 같이 열 수 있게.
window.byeoljariTab = {
  get: (key) => { try { return sessionStorage.getItem(key) ?? ''; } catch (_) { return ''; } },
  set: (key, value) => { try { sessionStorage.setItem(key, value); } catch (_) {} },
  remove: (key) => { try { sessionStorage.removeItem(key); } catch (_) {} },
};
