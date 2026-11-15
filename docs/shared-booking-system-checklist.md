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
- [x] Migration now enables RLS on `booking_dates`, revokes broad table privileges from public/anon/authenticated, grants SELECT only on `booking_date` and `status`, and creates a read-only public SELECT policy. Review existing policies/privileges during preflight before applying.
- [ ] Confirm the Supabase Auth user ID/email in the migration preflight matches the actual project account before applying SQL.
- [x] Migration now idempotently adds `booking_dates`, `admin_bookings`, and `admin_users` to the `supabase_realtime` publication (after the new table is created). Confirm publication permissions and successful migration during preflight.
- [ ] Verify all three clients receive changes and that `admin_users` RLS still exposes only the signed-in user's own allow-list row.


## Cross-platform parity review (2026-11-15)
- [x] Main website admin form and private calendar admin form are byte-for-byte identical on the feature branches.
- [x] Web admin form and Android data/repository model contain the same booking fields: date, status, client/host name, phone, event type, and private notes.
- [x] Web and Android use the same Supabase tables (`booking_dates`, `admin_bookings`, `admin_users`) and the same `save_shree_booking` / `clear_shree_booking` RPC names.
- [x] Align Android and web admin field labels and input behaviour: Client / Host Name (100 chars), Phone Number (30 chars), Event Type dropdown (Marriage, Engagement, Anniversary, Meeting, Birthday Party, Others), Private Management Notes (500 chars). Android Save Booking and Clear Booking labels now match web wording.
- [x] Enforce the same allowed Event Type values in the database RPC and admin_bookings table constraint, not only in the client dropdown.
- [ ] Complete emulator/device visual test of the Android form.
- [ ] Verify shared login, create/edit/clear, and realtime propagation across all three clients after the SQL migration is safely applied.


## Admin login diagnosis and hardening (2026-11-15)
- [x] Web admin pages no longer depend on a hard-coded Auth UUID. After password sign-in, they verify the current Auth user against their own row in `admin_users` under RLS.
- [x] Migration now resolves the admin Auth user by the verified email `krshreebanquethall@gmail.com` and requires exactly one matching Auth user; it no longer assumes a fixed UUID.
- [x] Android accepts either the admin username or registered email as the login identifier.
- [ ] Live login still cannot be verified until the migration is applied and the actual Supabase Auth password is confirmed. Do not treat the current deployed page as updated until the PR changes are deployed.

## Latest verification update (2026-11-15)
- [x] Public calendar hardening also revokes any legacy column-level SELECT/INSERT/UPDATE/REFERENCES grants on every existing `booking_dates` column before restoring SELECT on only `booking_date` and `status`. This closes a possible privilege leak that table-level REVOKE alone would not remove.
- [x] Android Supabase debug build completed successfully in GitHub Actions; APK artifact was uploaded and extracted for verification.
- [ ] Install and test the debug APK on a real Android device/emulator after the Supabase migration is safely applied.
- [ ] Verify the live project's current `booking_dates` schema, unique index, RLS policies, grants, Realtime publication, and exact Auth user before any SQL execution.
- [ ] Review/confirm Supabase migration owner privileges and function execution grants in the actual project before rollout.
- [ ] Do not apply SQL, deploy websites, merge PRs, or disable Firebase until the preflight is complete and the owner explicitly approves the rollout.
