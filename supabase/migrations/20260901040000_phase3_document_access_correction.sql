-- Append-only Phase 3 correction: document access is permission- or audience-bound,
-- never creator-bound. The SECURITY DEFINER helper safely reads both RLS-protected
-- document tables without policy recursion.
create or replace function app_private.can_access_document(target_document_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.documents d
    where d.id = target_document_id
      and (
        app_private.has_admin_permission('documents.manage')
        or (
          d.status = 'available'
          and exists (
            select 1
            from public.document_targets dt
            where dt.document_id = d.id
              and app_private.matches_audience(dt.target_kind, dt.role_code, dt.class_group_id)
          )
        )
      )
  );
$$;

revoke all on function app_private.can_access_document(uuid) from public, anon;
grant execute on function app_private.can_access_document(uuid) to authenticated;
