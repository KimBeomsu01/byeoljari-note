(() => {
  const translate = (input) => {
    const padded = input.replace(/-/g, '+').replace(/_/g, '/');
    return Uint8Array.from(atob(padded + '='.repeat((4 - padded.length % 4) % 4)), c => c.charCodeAt(0));
  };
  const encode = (buffer) => {
    let text = '';
    for (const byte of new Uint8Array(buffer)) text += String.fromCharCode(byte);
    return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  };
  const descriptors = list => (list ?? []).map(item => ({...item, id:translate(item.id)}));

  window.byeoljariPasskeys = {
    available: () => Boolean(window.isSecureContext && window.PublicKeyCredential && navigator.credentials),
    ceremony: async (registering, optionsJson) => {
      const opts = JSON.parse(optionsJson);
      const publicKey = {...opts, challenge:translate(opts.challenge)};
      if (registering) {
        publicKey.user = {...opts.user, id:translate(opts.user.id)};
        publicKey.excludeCredentials = descriptors(opts.excludeCredentials);
      } else {
        publicKey.allowCredentials = descriptors(opts.allowCredentials);
      }
      const credential = registering
        ? await navigator.credentials.create({publicKey})
        : await navigator.credentials.get({publicKey});
      if (!credential) throw Error('No credential returned');
      const response = credential.response;
      const data = {clientDataJSON:encode(response.clientDataJSON)};
      if (registering) {
        data.attestationObject = encode(response.attestationObject);
        data.transports = response.getTransports?.() ?? [];
      } else {
        data.authenticatorData = encode(response.authenticatorData);
        data.signature = encode(response.signature);
        if (response.userHandle !== null) data.userHandle = encode(response.userHandle);
      }
      return JSON.stringify({
        id:credential.id,
        rawId:encode(credential.rawId),
        type:credential.type,
        authenticatorAttachment:credential.authenticatorAttachment ?? undefined,
        response:data,
        clientExtensionResults:credential.getClientExtensionResults(),
      });
    },
  };
})();
