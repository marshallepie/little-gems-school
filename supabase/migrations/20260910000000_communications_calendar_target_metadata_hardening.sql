-- Keep audience matching inside SECURITY DEFINER feed predicates; recipients must
-- not enumerate the audience metadata that caused a feed row to be visible.
-- Manager-only target reads remain provided by the narrowly scoped policies from
-- 20260908000000_internal_communications_calendar_commands.sql.
drop policy if exists announcement_targets_audience_read on public.announcement_targets;
drop policy if exists event_targets_audience_read on public.event_targets;

-- Commands are the only authenticated mutation boundary. Their SECURITY DEFINER
-- implementation continues to write these tables after validating the caller.
revoke insert, update, delete on public.announcements from authenticated;
revoke insert, update, delete on public.announcement_targets from authenticated;
revoke insert, update, delete on public.events from authenticated;
revoke insert, update, delete on public.event_targets from authenticated;
