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
