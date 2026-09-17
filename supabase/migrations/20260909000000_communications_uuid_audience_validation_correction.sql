-- Correct class-audience UUID validation without changing the command authorization boundary.
-- The prior migration rejected valid PostgreSQL UUIDs whose version nibble was not 1-5,
-- including deterministic legacy class IDs. Replacing the private validator is forward-only.

create or replace function app_private.validate_communications_targets(p_targets jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  target_count integer;
  distinct_count integer;
  v_class_group_id_text text;
  v_class_group_id uuid;
begin
  if p_targets is null or jsonb_typeof(p_targets) <> 'array' or jsonb_array_length(p_targets) = 0 then
    raise exception 'at least one audience is required' using errcode = '23514';
  end if;

  if exists (
    select 1 from jsonb_array_elements(p_targets) item
    where jsonb_typeof(item) <> 'object'
      or item - 'target_kind' - 'role_code' - 'class_group_id' <> '{}'::jsonb
  ) then
    raise exception 'audiences must have only target_kind, role_code, and class_group_id' using errcode = '23514';
  end if;

  with targets as (
    select target_kind, role_code, class_group_id
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text)
  )
  select count(*), count(distinct jsonb_build_array(target_kind, role_code, class_group_id))
  into target_count, distinct_count from targets;

  if target_count <> distinct_count then
    raise exception 'duplicate audiences are not allowed' using errcode = '23505';
  end if;

  if exists (
    select 1 from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text)
    where not (
      (target_kind = 'school' and role_code is null and class_group_id is null)
      or (target_kind = 'role' and role_code in ('admin', 'teacher', 'parent', 'student') and class_group_id is null)
      or (target_kind = 'class' and role_code is null and class_group_id is not null)
    )
  ) then
    raise exception 'invalid normalized audience' using errcode = '23514';
  end if;

  -- PostgreSQL's UUID cast is the syntax authority. Do not impose RFC-version
  -- bits: valid legacy/deterministic IDs remain subject to the current-class check.
  for v_class_group_id_text in
    select class_group_id
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text)
    where target_kind = 'class'
  loop
    begin
      v_class_group_id := v_class_group_id_text::uuid;
    exception when invalid_text_representation then
      raise exception 'invalid normalized audience' using errcode = '23514';
    end;

    if not app_private.is_current_class_group(v_class_group_id) then
      raise exception 'class audiences must use a current class group' using errcode = '23514';
    end if;
  end loop;
end;
$$;
revoke all on function app_private.validate_communications_targets(jsonb) from public, anon, authenticated;
