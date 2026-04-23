# JinnLabs Fleet — Edge Device Bring-Up

Tooling and runbooks for flashing, configuring, and deploying Jetson Orin Nano devices to JinnLabs store deployments.

## Repo contents

- `pilot-install.sh` — per-device configure script. Install Tailscale, join tailnet, seed team SSH keys. Run once per freshly-flashed card after `oem-config` completes.
- `team_authorized_keys` — SSH pubkeys for team members authorized to access production edge devices. Source of truth for `authorized_keys` on every deployed Nano.
- `ONBOARDING_CHECKLIST.md` — per-device onboarding form. Copy/fill for each new device.
- `RUNBOOK.md` — full flash → verify → deploy procedure.

## Quick usage

On a freshly-flashed Jetson Orin Nano, after completing `oem-config` and connecting WiFi:

```bash
TS_AUTHKEY=tskey-auth-xxx curl -fsSL https://raw.githubusercontent.com/JinnLabs-ai/fleet/main/pilot-install.sh | sudo -E bash
```

Replace `tskey-auth-xxx` with a reusable, tag:nano-tagged Tailscale auth key generated at https://login.tailscale.com/admin/settings/keys. **Revoke the key after each batch run.**

## Security notes

- **Never commit auth keys** to this repo. The install script reads `TS_AUTHKEY` from the environment.
- Team SSH pubkeys in `team_authorized_keys` are safe to commit (public by design).
- Keep this repo **private** — it's internal tooling that reveals fleet architecture.

## Scaling targets

With this workflow and 2 USB card readers, one operator can go from blank SD cards to deployed-on-Tailscale devices in ~20 min per batch of 6 cards. Throughput goal: 20+ devices/day.
