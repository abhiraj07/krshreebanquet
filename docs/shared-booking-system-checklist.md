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
- [x] Main website `/admin.html` has been replaced on the feature branch with the exact same admin page/form as the private calendar website. Both files were fetched again and verified byte-for-byte identical. It now uses the shared `save_shree_booking` and `clear_shree_booking` RPC workflow; the legacy direct-write form is no longer in the feature-branch version.
- [ ] After deployment, verify the main website Admin Login and the private calendar URL both load the same shared admin experience and authenticate against the same Supabase Auth user.
- [ ] Confirm the existing `booking_dates` RLS policies permit anonymous SELECT of only the public-safe fields and do not permit anonymous INSERT/UPDATE/DELETE.
- [ ] Confirm the Supabase Auth user ID/email in the migration preflight matches the actual project account before applying SQL.
- [ ] Enable Supabase Realtime for `booking_dates`, `admin_bookings`, and `admin_users` after migration. The Android admin allow-list check currently uses `selectAsFlow` on `admin_users`, so omitting that table from the Realtime publication can prevent admin authorization from initializing.
- [ ] Verify all three clients receive changes and that `admin_users` RLS still exposes only the signed-in user's own allow-list row.


## Cross-platform parity review (2026-11-15)
- [x] Main website admin form and private calendar admin form are byte-for-byte identical on the feature branches.
- [x] Web admin form and Android data/repository model contain the same booking fields: date, status, client/host name, phone, event type, and private notes.
- [x] Web and Android use the same Supabase tables (`booking_dates`, `admin_bookings`, `admin_users`) and the same `save_shree_booking` / `clear_shree_booking` RPC names.
- [x] Align Android and web admin field labels and input behaviour: Client / Host Name (100 chars), Phone Number (30 chars), Event Type (60 chars, free text), Private Management Notes (500 chars). Android Save Booking and Clear Booking labels now match web wording.
- [ ] Complete emulator/device visual test of the Android form.
- [ ] Verify shared login, create/edit/clear, and realtime propagation across all three clients after the SQL migration is safely applied.
