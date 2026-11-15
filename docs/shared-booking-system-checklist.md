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


## Live Supabase read-only preflight (2026-11-15)

Project matched: `shree-banquet-admin` (`agshupnzhpeqiwezsnyp`), region `ap-south-1`, project status `ACTIVE_HEALTHY`.

- [x] Confirmed `public.booking_dates` exists with `booking_date date`, `status text`, `created_at`, and `updated_at`; primary key / valid unique index is on `booking_date` alone.
- [x] Confirmed 5 existing main calendar rows (4 `booked`, 1 `pending`); the existing status check allows `pending` and `booked`, matching the RPC's database values. Existing rows are not modified by preflight.
- [x] Confirmed `public.private_booking_dates` is a separate legacy table with 2 `booked` rows. It is not touched by the shared migration.
- [x] Confirmed RLS is enabled on both existing calendar tables.
- [x] Confirmed exactly one confirmed Supabase Auth account matches `krshreebanquethall@gmail.com`; migration can seed the admin allow-list without a hard-coded UUID.
- [x] Confirmed `public.admin_users` and `public.admin_bookings` do not currently exist.
- [x] Confirmed `supabase_realtime` publication exists and publishes INSERT/UPDATE/DELETE, but currently has no tables. Migration adds the three shared tables.
- [x] Reviewed current `booking_dates` policies and grants. Existing public/admin policies and column-level grants are explicitly removed/replaced by the migration; only `booking_date` and `status` are re-granted to public client roles.
- [x] Confirmed migration execution context is database role `postgres`.
- [x] Reviewed existing `ensure_rls` event trigger and `rls_auto_enable()` function. The function is SECURITY DEFINER with `search_path=pg_catalog`, but had default EXECUTE access for anon/authenticated. Latest migration commit revokes client EXECUTE without removing the installed event trigger.
- [ ] Existing Auth security setting: leaked-password protection is disabled. Recommend enabling it in Supabase Auth settings as a separate owner-approved security setting.
- [ ] Existing performance advisor reports auth/RLS initplan warnings on old policies for `booking_dates` and `private_booking_dates`. New `booking_dates` policy uses the safe public read path; legacy `private_booking_dates` remains unchanged pending a separate decision.
- [x] Supabase health advisor returned no health lints.
- [x] No Supabase migration has been applied; this preflight used read-only SQL only.

Latest migration hardening commit: `3c4d6899a1c705bba6981a6fa946ec502241dc08`.
Production database, deployed websites, Android release, and Firebase have not been changed. Keep PRs open/draft and wait for explicit approval before applying SQL or deploying.


## Legacy status-only records in admin views (2026-11-15)
- [x] Web admin upcoming list now combines public status dates with private detail records; a pre-existing status-only date appears as "Details not added" instead of disappearing.
- [x] Android admin private-records list now performs the same merge and shows "Details not added" for status-only dates.
- [x] Main website and private calendar `admin.html` were fetched again after the patch and verified byte-for-byte identical.
- [ ] Device-level visual confirmation remains pending; Android CI run #51 is building the updated screen code.


## Production Supabase migration applied and verified (2026-11-15)
- [x] Applied migration `shared_admin_bookings_202611150001` to project `agshupnzhpeqiwezsnyp`; Supabase migration history records version `20261115151040`.
- [x] Verified `admin_users` and `admin_bookings` created with RLS enabled; allow-list contains the one intended admin account.
- [x] Verified Realtime publication now includes `booking_dates`, `admin_bookings`, and `admin_users`.
- [x] Verified anonymous role can read only the date/status columns of `booking_dates`; it cannot read `created_at`, `admin_bookings`, or `admin_users`, and cannot execute save/clear RPCs.
- [x] Verified a non-admin authenticated subject sees zero rows in `admin_bookings`; `is_shree_admin()` is false for an unlisted user.
- [x] Verified SECURITY DEFINER RPCs have fixed empty search_path and are executable by authenticated users only; the existing RLS event-trigger function is no longer executable by anon/authenticated.
- [x] Verified original records preserved: `booking_dates` 5 rows (4 booked, 1 pending); `private_booking_dates` 2 rows; new `admin_bookings` 0 rows before any new admin entry.
- [x] Android CI run #51 passed for commit `23496b559f0926d58e10ae4c9885c7326d244894`; APK artifact `14167352680`, SHA-256 `b44d8ae1f9384e71afddd88ac83c1fc8143f08d9d704cc9ba43905798b88856b`.
- [ ] Admin password login and real cross-client create/edit/clear/realtime test still require device/browser session testing. Do not report these as completed.
- [ ] Security advisor still reports authenticated execution of the three intended SECURITY DEFINER admin functions; each function checks allow-list authorization, and anon is denied. Auth leaked-password protection remains disabled.
