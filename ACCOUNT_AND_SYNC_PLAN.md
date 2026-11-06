# Account and sync decision

## Product rule
A real account is useful only when it unlocks a real benefit: restoring data after phone loss, using the same catalog on multiple devices, or sharing selected data with a teammate. A local-only username/password screen does not provide those benefits and must not be presented as cloud account functionality.

## Decision for the first paid MVP
- Keep the first version offline-first and usable without registration.
- Do not block first use behind phone number, email, password, or OTP.
- Add optional account registration only alongside a working server-backed backup/sync feature.
- Keep local export/import available even for signed-in users.
- Never store passwords in the local SQLite database.

## Account phase requirements
1. Select and verify a backend that is reachable and supportable for the intended Iranian market.
2. Implement email or phone verification, password reset / account recovery, session expiry, and account deletion.
3. Encrypt transport; use per-user authorization rules so one user can never read another user's records.
4. Add explicit sync conflict handling and last-sync status.
5. Explain what data leaves the device and obtain consent before enabling cloud sync.
6. Test offline edits, reconnect, duplicate records, reinstall, lost-device recovery, and account deletion.

## Release gate
Do not ship account registration until authentication, per-user data isolation, recovery, privacy disclosures, and real sync are tested end-to-end. A decorative login screen is not an account system.
