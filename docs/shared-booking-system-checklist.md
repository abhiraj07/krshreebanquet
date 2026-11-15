# Shree Banquet Hall — Shared Booking System Checklist

## Goal
One Supabase-backed booking system shared by the public website, private admin calendar website, and Android app.

## Public website
- [ ] Show calendar dates and only the status: Available / Pending / Booked.
- [ ] Never expose client name, phone, event type, notes, or admin-only history.
- [ ] Keep existing public website design and enquiry/WhatsApp flow intact.
- [ ] Read only the safe public calendar view/table.

## Admin access
- [ ] Username login: admin980123 + password.
- [ ] No Google/Gmail sign-in.
- [ ] Admin-only pages require Supabase Auth and server-side RLS authorization.

## Shared admin booking fields
- [ ] Booking date
- [ ] Status: Available / Pending / Booked
- [ ] Client/host name
- [ ] Phone number
- [ ] Event type
- [ ] Private notes

## Booking operations
- [ ] Create/update booking
- [ ] Clear booking
- [ ] Keep public status in sync with private booking details atomically
- [ ] Realtime refresh across all clients

## Safety / rollout
- [ ] Keep all work on feature branch until explicitly approved.
- [ ] Do not deploy or merge without explicit approval.
- [ ] Verify schema and Auth admin identity before applying SQL.
- [ ] Fresh start is acceptable; existing booking history does not need migration.
- [ ] Test that anonymous/public access cannot read private booking fields.


## Integration blockers found during cross-review (2026-11-15)
- [ ] The legacy `/admin.html` page currently writes directly to `booking_dates` and does not update `admin_bookings`. Do not use this legacy page for booking changes after the shared migration; doing so can leave public status and private details inconsistent.
- [ ] Before rollout, either replace the legacy admin page with a safe handoff to the private admin calendar (after its deployed URL is confirmed), or update it to use a workflow that cannot overwrite existing private details with blank values.
- [ ] Confirm the existing `booking_dates` RLS policies permit anonymous SELECT of only the public-safe fields and do not permit anonymous INSERT/UPDATE/DELETE.
- [ ] Confirm the Supabase Auth user ID/email in the migration preflight matches the actual project account before applying SQL.
- [ ] Enable Supabase Realtime for `booking_dates` and `admin_bookings` after migration, then test all three clients.
