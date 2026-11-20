import {createServer} from 'node:http';
import {createHash} from 'node:crypto';
import {
  generateRegistrationOptions, verifyRegistrationResponse,
  generateAuthenticationOptions, verifyAuthenticationResponse,
} from '@simplewebauthn/server';

const expectedOrigin = process.env.PASSKEY_ORIGIN;
if (!expectedOrigin) throw new Error('Passkey origin is required');
const rpID = new URL(expectedOrigin).hostname;

const routes = {
  '/register/options': input => generateRegistrationOptions({
    rpName: '별자리노트',
    rpID,
    userName: input.login,
    userID: createHash('sha256').update('byeoljari-new2/' + input.login).digest(),
    attestationType: 'none',
    authenticatorSelection: {
      authenticatorAttachment: 'platform',
      residentKey: 'preferred',
      userVerification: 'required',
    },
    excludeCredentials: input.credentialIDs.map(id => ({id})),
    supportedAlgorithmIDs: [-7, -257],
    timeout: 120000,
  }),
  '/register/verify': async input => {
    const result = await verifyRegistrationResponse({
      response: input.response,
      expectedChallenge: input.challenge,
      expectedOrigin,
      expectedRPID: rpID,
      requireUserVerification: true,
    });
    if (!result.verified || !result.registrationInfo) throw new Error('Registration failed');
    const cred = result.registrationInfo.credential;
    return {id: cred.id, publicKey: Buffer.from(cred.publicKey).toString('base64url'), counter: cred.counter};
  },
  '/login/options': input => generateAuthenticationOptions({
    rpID,
    allowCredentials: input.credentialIDs.map(id => ({id})),
    userVerification: 'required',
    timeout: 120000,
  }),
  '/login/verify': async input => {
    const result = await verifyAuthenticationResponse({
      response: input.response,
      expectedChallenge: input.challenge,
      expectedOrigin,
      expectedRPID: rpID,
      requireUserVerification: true,
      credential: {
        id: input.credential.id,
        publicKey: new Uint8Array(Buffer.from(input.credential.public_key, 'base64url')),
        counter: input.credential.counter,
      },
    });
    if (!result.verified) throw new Error('Authentication failed');
    return {counter: result.authenticationInfo.newCounter};
  },
};

createServer(async (request, response) => {
  response.setHeader('Content-Type', 'application/json');
  if (request.method !== 'POST' || !Object.hasOwn(routes, request.url)) {
    response.writeHead(404).end('{}');
    return;
  }
  try {
    const chunks = [];
    let size = 0;
    for await (const chunk of request) {
      size += chunk.length;
      if (size > 512 * 1024) throw new Error('Input too large');
      chunks.push(chunk);
    }
    const data = await routes[request.url](JSON.parse(Buffer.concat(chunks)));
    response.writeHead(200).end(JSON.stringify(data));
  } catch {
    response.writeHead(400).end('{}');
  }
}).listen(8081, '0.0.0.0');
