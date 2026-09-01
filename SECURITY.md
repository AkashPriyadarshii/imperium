# Security — imperium

## Threat model
Single-user, offline. The phone is the trust boundary. The highest-value asset is the user's life log (food, health, finances, mood). Threats: device loss/theft, accidental destructive actions, an attacker with physical access to an unlocked phone.

## Posture
- **No network.** No calls, no telemetry, no crash-reporting to a server. Nothing leaves the device by design.
- **Local storage only.** App-private directory via path_provider (Android scoped storage). No WRITE_EXTERNAL_STORAGE. Exports go to Downloads via MediaStore.
- **No auth** — there is no server to authenticate against. Optional biometric gate at launch is best-effort (local_auth, biometricOnly, passes through on no-sensor).

## Key protections implemented
1. **Armored reset** — reset-all destroys the life log, so it is staged: warning screen → typed confirm word → final barrier → **automatic backup to Downloads before wipe**. No single-tap total loss.
2. **Backup** — export to JSON anytime; import merges by id (no dupes). "Backup reminder" nudges periodic export.
3. **Biometric lock (optional)** — gates app open; never hard-blocks a sensor-less device.
4. **Import validation** — batch/JSON import validates schema and fails fast per row; unknown category keys are offered for mapping, never silently dropped; no silent partial writes.

## Reporting
Private repo, sole maintainer. Report issues directly to the owner (Akash Priyadarshi). No public bounty.

## Deliberately out of scope (v0.1)
- Encryption at rest / SQLCipher: phone-level encryption assumed (Android full-disk). Revisit if the device is shared.
- Network security: irrelevant — no network.

## What to add before shipping
A pre-release pass: confirm zero network egress (no flutter_local_notifications/permission network usage; no dependency that calls home), validate the armored-reset path on a real device, verify import can't be weaponized (overflow, bad types).
