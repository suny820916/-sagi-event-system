-- SAGI EVENT SYSTEM V2.0 / Supabase setup
-- Run this once in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.sagi_events (
  slug text primary key check (slug ~ '^[a-z0-9][a-z0-9-]{2,63}$'),
  payload jsonb not null default '{}'::jsonb,
  write_token_hash text not null,
  revision bigint not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.sagi_events enable row level security;
revoke all on public.sagi_events from anon, authenticated;

create or replace function public.sagi_get_event(p_slug text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare r public.sagi_events;
begin
  select * into r from public.sagi_events where slug=p_slug;
  if not found then return null; end if;
  return jsonb_build_object(
    'slug',r.slug,
    'payload',r.payload,
    'revision',r.revision,
    'updated_at',r.updated_at
  );
end;
$$;

create or replace function public.sagi_claim_event(
  p_slug text,
  p_token text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare r public.sagi_events;
begin
  if p_slug is null or p_slug !~ '^[a-z0-9][a-z0-9-]{2,63}$' then
    raise exception 'INVALID_SLUG';
  end if;
  if p_token is null or length(p_token) < 8 then
    raise exception 'TOKEN_TOO_SHORT';
  end if;

  select * into r from public.sagi_events where slug=p_slug for update;
  if not found then
    insert into public.sagi_events(slug,payload,write_token_hash,revision,updated_at)
    values(p_slug,coalesce(p_payload,'{}'::jsonb),crypt(p_token,gen_salt('bf')),1,now())
    returning * into r;
  else
    if crypt(p_token,r.write_token_hash) <> r.write_token_hash then
      raise exception 'INVALID_WRITE_TOKEN';
    end if;
    update public.sagi_events
      set payload=coalesce(p_payload,'{}'::jsonb), revision=revision+1, updated_at=now()
      where slug=p_slug
      returning * into r;
  end if;

  return jsonb_build_object('slug',r.slug,'payload',r.payload,'revision',r.revision,'updated_at',r.updated_at);
end;
$$;

create or replace function public.sagi_save_event(
  p_slug text,
  p_token text,
  p_payload jsonb,
  p_expected_revision bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare r public.sagi_events;
begin
  select * into r from public.sagi_events where slug=p_slug for update;
  if not found then raise exception 'EVENT_NOT_FOUND'; end if;
  if crypt(p_token,r.write_token_hash) <> r.write_token_hash then
    raise exception 'INVALID_WRITE_TOKEN';
  end if;
  if p_expected_revision is not null and r.revision <> p_expected_revision then
    raise exception 'REVISION_CONFLICT';
  end if;

  update public.sagi_events
    set payload=coalesce(p_payload,'{}'::jsonb), revision=revision+1, updated_at=now()
    where slug=p_slug
    returning * into r;

  return jsonb_build_object('slug',r.slug,'payload',r.payload,'revision',r.revision,'updated_at',r.updated_at);
end;
$$;

revoke all on function public.sagi_get_event(text) from public;
revoke all on function public.sagi_claim_event(text,text,jsonb) from public;
revoke all on function public.sagi_save_event(text,text,jsonb,bigint) from public;

grant execute on function public.sagi_get_event(text) to anon, authenticated;
grant execute on function public.sagi_claim_event(text,text,jsonb) to anon, authenticated;
grant execute on function public.sagi_save_event(text,text,jsonb,bigint) to anon, authenticated;
