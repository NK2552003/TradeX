import { sendFcm } from './fcm.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.8';
import webpush from 'npm:web-push@3.6.7';
import { allowedEndpoint, shouldSend } from './policy.ts';

Deno.serve(async (request) => {
  const secret = Deno.env.get('PUSH_DISPATCH_SECRET');
  if (request.method !== 'POST' || !secret || request.headers.get('x-push-secret') !== secret) {
    return new Response('Unauthorized', {status: 401});
  }
  const publicKey = Deno.env.get('WEB_PUSH_PUBLIC_KEY');
  const privateKey = Deno.env.get('WEB_PUSH_PRIVATE_KEY');
  const subject = Deno.env.get('WEB_PUSH_SUBJECT');
  const webConfigured = !!publicKey && !!privateKey && !!subject;
  if (!webConfigured && !Deno.env.get('FIREBASE_SERVICE_ACCOUNT')) return new Response('Push is not configured', {status: 503});
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  if (webConfigured) webpush.setVapidDetails(subject!, publicKey!, privateKey!);
  const {data: jobs, error} = await db.rpc('claim_push_deliveries');
  if (error) return new Response('Queue unavailable', {status: 503});
  let delivered = 0;
  for (const job of jobs ?? []) {
    const {data: sub, error: subError} = await db.from('push_subscriptions').select().eq('id', job.subscription_id).maybeSingle();
    const {data: notification, error: notificationError} = await db.from('notifications').select('user_id,type,category,read_at').eq('id', job.notification_id).maybeSingle();
    if (subError || notificationError) continue;
    if (!sub || !notification || sub.user_id !== notification.user_id || !(sub.endpoint.startsWith('fcm:') || allowedEndpoint(sub.endpoint))) {
      await db.from('push_deliveries').update({completed_at: new Date().toISOString()}).eq('id', job.id);
      continue;
    }
    const {data: pref, error: prefError} = await db.from('trader_preferences').select('notification_settings').eq('user_id', sub.user_id).maybeSingle();
    if (prefError) continue;
    if (notification.read_at || !shouldSend(pref?.notification_settings ?? {}, notification.type, notification.category, sub.utc_offset_minutes)) {
      await db.from('push_deliveries').update({completed_at: new Date().toISOString()}).eq('id', job.id);
      continue;
    }
    try {
      if (sub.endpoint.startsWith('fcm:')) {
        await sendFcm(sub.endpoint.slice(4), job.notification_id);
      } else {
      if (!webConfigured) continue;
      await webpush.sendNotification({endpoint: sub.endpoint, keys: {p256dh: sub.p256dh, auth: sub.auth}},
        JSON.stringify({id: job.notification_id}), {TTL: 3600, timeout: 10000});
      }
      await db.from('push_deliveries').update({completed_at: new Date().toISOString()}).eq('id', job.id);
      delivered++;
    } catch (error) {
      const status = (error as {statusCode?: number}).statusCode;
      if (status === 404 || status === 410) await db.from('push_subscriptions').delete().eq('id', sub.id);
      // Transient failures retain their lease and retry, up to six attempts.
    }
  }
  return Response.json({delivered});
});
