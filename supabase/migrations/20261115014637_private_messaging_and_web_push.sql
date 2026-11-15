-- Additive infrastructure. Deploy before the client. Historical plaintext is not rewritten.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.message_public_keys (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  signing_key text not null check (length(signing_key) = 44),
  public_key text not null check (length(public_key) = 44)
);
create table public.message_identities (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  signing_key text not null check (length(signing_key) = 44),
  public_key text not null check (length(public_key) = 44),
  salt text not null,
  backup jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.message_public_keys enable row level security;
alter table public.message_identities enable row level security;
revoke all on public.message_public_keys, public.message_identities from anon, authenticated;
grant select on public.message_public_keys to authenticated;
grant select, insert on public.message_identities to authenticated;
create policy public_key_read on public.message_public_keys for select to authenticated using (true);
create policy identity_read on public.message_identities for select to authenticated using (user_id = (select auth.uid()));
create policy identity_create on public.message_identities for insert to authenticated with check (user_id = (select auth.uid()));
-- Keys are immutable: another device must restore the original identity.
create function private.publish_message_key() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.message_public_keys(user_id, public_key, signing_key) values (new.user_id, new.public_key, new.signing_key);
  return new;
end $$;
revoke all on function private.publish_message_key() from public;
create trigger publish_message_key after insert on public.message_identities
for each row execute function private.publish_message_key();

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique check (length(endpoint) < 4096 and (endpoint like 'https://%' or endpoint like 'fcm:%')),
  p256dh text not null,
  auth text not null,
  utc_offset_minutes integer not null default 0 check (utc_offset_minutes between -840 and 840),
  updated_at timestamptz not null default now()
);
create index push_subscriptions_owner on public.push_subscriptions(user_id);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon;
grant select, insert, update, delete on public.push_subscriptions to authenticated;
create policy push_owner on public.push_subscriptions for all to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table public.push_deliveries (
  id bigint generated always as identity primary key,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  subscription_id uuid not null references public.push_subscriptions(id) on delete cascade,
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(notification_id, subscription_id)
);
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from anon, authenticated;
grant all on public.push_deliveries, public.push_subscriptions to service_role;
grant usage, select on sequence public.push_deliveries_id_seq to service_role;
create index pending_push_deliveries on public.push_deliveries(available_at) where completed_at is null;
create function private.queue_push() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.push_deliveries(notification_id, subscription_id)
  select new.id, s.id from public.push_subscriptions s where s.user_id = new.user_id;
  return new;
end $$;
revoke all on function private.queue_push() from public;
create trigger queue_push after insert on public.notifications for each row execute function private.queue_push();

-- Lease batches, so overlapping cron invocations do not send the same job concurrently.
create function public.claim_push_deliveries() returns setof public.push_deliveries
language sql security invoker set search_path = '' as $$
  update public.push_deliveries set attempts = attempts + 1, available_at = now() + interval '5 minutes'
  where id in (select id from public.push_deliveries
    where completed_at is null and available_at <= now() and attempts < 6
    order by available_at limit 10 for update skip locked)
  returning *;
$$;
revoke all on function public.claim_push_deliveries() from public, anon, authenticated;
grant execute on function public.claim_push_deliveries() to service_role;

create or replace function public.update_chat_thread_last_message() returns trigger
language plpgsql set search_path = '' as $$
begin
  update public.chat_threads set last_message_preview =
    case when new.body like 'e2ee:v1:%' then 'Encrypted message'
         when new.body <> '' then substring(new.body from 1 for 120) else 'Attachment' end,
    last_message_at = new.created_at, updated_at = new.created_at where id = new.thread_id;
  return new;
end $$;

create function private.notify_private_message() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications(user_id, actor_id, type, category, title, body, data)
  select p.user_id, new.sender_id, 'message', 'message', 'New message', 'Open alphajournal to read your message.',
    jsonb_build_object('thread_id', new.thread_id)
  from public.chat_participants p where p.thread_id = new.thread_id and p.user_id <> new.sender_id;
  return new;
end $$;
revoke all on function private.notify_private_message() from public;
create trigger notify_private_message after insert on public.chat_messages
for each row execute function private.notify_private_message();

-- Reject old clients that would otherwise create plaintext after this rollout.
-- Status/read updates to historical rows remain allowed.
create function private.require_encrypted_message() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_table_name = 'messages' then
    if new.content not like 'e2ee:v1:%' then raise exception 'Upgrade your app to send encrypted messages'; end if;
  else
    if new.body not like 'e2ee:v1:%' then raise exception 'Upgrade your app to send encrypted messages'; end if;
  end if;
  return new;
end $$;
revoke all on function private.require_encrypted_message() from public;
create trigger encrypted_chat_write before insert or update of body on public.chat_messages
for each row execute function private.require_encrypted_message();
create trigger encrypted_legacy_write before insert or update of content on public.messages
for each row execute function private.require_encrypted_message();

create function private.require_encrypted_workspace() returns trigger
language plpgsql set search_path = '' as $$
begin
  if jsonb_typeof(new.state->'encrypted') is distinct from 'string'
     or (new.state->>'encrypted') not like 'e2ee:v1:%'
     or new.state - 'encrypted' <> '{}'::jsonb then
    raise exception 'Upgrade your app to save encrypted AI history';
  end if;
  return new;
end $$;
revoke all on function private.require_encrypted_workspace() from public;
create trigger encrypted_workspace_write before insert or update of state on public.copilot_workspaces
for each row execute function private.require_encrypted_workspace();

-- New rich metadata belongs inside the encrypted message envelope.
revoke insert, update on public.chat_attachments, public.chat_shared_refs from authenticated;
-- The legacy AI endpoint must no longer store plaintext turns.
create trigger encrypted_ai_write before insert or update of body on public.ai_messages
for each row execute function private.require_encrypted_message();

-- Allow opaque ciphertext attachments while retaining existing media types.
update storage.buckets set allowed_mime_types =
  case when allowed_mime_types is null then null
       else array_append(allowed_mime_types, 'application/octet-stream') end
where id = 'chat-attachments' and not coalesce('application/octet-stream' = any(allowed_mime_types), false);
