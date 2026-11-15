import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';
let cached: {token: string; expires: number} | undefined;
export async function sendFcm(token: string, id: string): Promise<void> {
  const account = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}');
  if (!account.project_id || !account.private_key || !account.client_email) throw new Error('FCM not configured');
  if (!cached || cached.expires < Date.now()) {
    const key = await importPKCS8(account.private_key, 'RS256');
    const assertion = await new SignJWT({scope: 'https://www.googleapis.com/auth/firebase.messaging'})
      .setProtectedHeader({alg: 'RS256'}).setIssuer(account.client_email)
      .setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h').sign(key);
    const response = await fetch('https://oauth2.googleapis.com/token', {method: 'POST',
      body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion}), signal: AbortSignal.timeout(10000)});
    const data = await response.json();
    if (!response.ok || !data.access_token) throw new Error('FCM authorization failed');
    cached = {token: data.access_token, expires: Date.now() + 3000000};
  }
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${cached.token}`},
    body: JSON.stringify({message: {token, notification: {title: 'alphajournal',
      body: 'You have new activity. Open alphajournal to view it.'}, data: {notification_id: id}}}),
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) {
    const data = await response.json();
    const expired = data.error?.details?.some((d: {errorCode?: string}) => d.errorCode === 'UNREGISTERED');
    throw Object.assign(new Error('FCM delivery failed'), {statusCode: expired ? 410 : response.status});
  }
}
