// 별님 프로필 사진 고르기: 사진첩·카메라에서 한 장 고르면 긴 쪽 1280px JPEG로 줄여 data: 주소로 돌려준다.
// 고르지 않고 닫으면 빈 문자열.
(() => {
  const MAX = 1280;
  const shrink = (file) => new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(1, MAX / Math.max(img.naturalWidth, img.naturalHeight));
      const canvas = document.createElement('canvas');
      canvas.width = Math.round(img.naturalWidth * scale);
      canvas.height = Math.round(img.naturalHeight * scale);
      canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(url);
      resolve(canvas.toDataURL('image/jpeg', 0.85));
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(Error('이미지를 읽지 못했어요.')); };
    img.src = url;
  });

  window.byeoljariPhotos = {
    pick: () => new Promise((resolve, reject) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.style.display = 'none';
      document.body.appendChild(input);
      const done = () => input.remove();
      input.addEventListener('change', () => {
        const file = input.files && input.files[0];
        done();
        if (!file) { resolve(''); return; }
        shrink(file).then(resolve, reject);
      });
      input.addEventListener('cancel', () => { done(); resolve(''); });
      input.click();
    }),
  };
})();
