# Phone OTP (no Firebase)

Auth uses your **Node API** only:

1. **Send OTP** — `POST .../send-otp` stores a 6-digit code in memory (5 min). In **non-production**, the JSON may include `_devOtp` for testing.
2. **Verify** — `POST .../verify-otp` with `phone`, `countryCode`, `otp`.

**Master OTP (no SMS):** set `MASTER_OTP=123456` in `astro-backend/.env` and restart the server. Any phone can sign in with that 6-digit code (treat as a backdoor; use a strong value).

When you add real SMS later, you can extend the backend again.

**Deploy:** Production must run this repo’s `verify-otp` (body: `phone`, `countryCode`, `otp` only). After updating the server, rebuild/reinstall the mobile app if you still see wrong errors.
