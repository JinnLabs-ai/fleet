# Fleet Flash Runbook

End-to-end procedure to take a blank SD card to a deployed, Tailscale-connected Jetson Orin Nano.

## Prerequisites (do once per batch)

1. **Source image** — `~/Desktop/jp62-orin-nano-sd-blob.img` (22 GiB uncompressed)
   - sha256: `239035634896b6f4e99ea7ca4460978f1f4ba9f58889dc6a803b04618dbb07d7`
   - **Get it on any laptop (recommended):**
     ```bash
     ./scripts/get-jetson-image.sh        # downloads from Azure Blob + verifies sha256
     ```
     This is the stock NVIDIA JetPack 6.2 Orin Nano image, hosted at
     `jinndatastorage / jinn-jetson-images / jp62-orin-nano-sd-blob.img` (private —
     the helper mints a short-lived read-only SAS using your `az login`). Requires
     `az login` (access to the `jinn-dev` resource group) + `azcopy`
     (`brew install azure-cli azcopy`).
   - **Fallback if you can't reach the blob:** unzip `jp62-orin-nano-sd-card-image.zip`
     from NVIDIA's JetPack 6.2 downloads page (it is the same stock image; verify the
     sha256 above matches after unzipping).
2. **Tailscale auth key** — generate at https://login.tailscale.com/admin/settings/keys
   - Reusable: yes
   - Ephemeral: no
   - Tags: `tag:nano`
   - Expiration: 7 days
   - Copy the `tskey-auth-...` string to 1Password for use below.
3. **ACL** — confirm your tailnet ACL has:
   - `harjeev@jinnlabs.ai` listed in `tagOwners` for `tag:nano`
   - An SSH rule permitting `autogroup:member` → `tag:nano` as `jinn-sync`/`root` with `action: accept`
4. **Hardware** — Mac with USB card reader (and optionally the built-in SDXC slot), known-good 256 GB SD cards (SanDisk Extreme recommended, not generic LSLX256).

## Per-batch procedure

### 1. Flash (Mac, ~13 min parallel for 3 cards)

Identify targets:
```bash
diskutil list external
```

For each card, unmount and flash:
```bash
diskutil unmountDisk /dev/disk<N>
sudo dd if=~/Desktop/jp62-orin-nano-sd-blob.img of=/dev/rdisk<N> bs=8m status=progress
```

Run 3 in parallel (separate terminal windows or `&` + `wait`). Expected: `24000856064 bytes transferred` on each.

### 2. Hash verify (Mac, ~13 min parallel, MANDATORY)

```bash
sudo cmp -n 24000856064 ~/Desktop/jp62-orin-nano-sd-blob.img /dev/rdisk<N> && echo MATCH || echo MISMATCH
```

Any card that reports `MISMATCH` must be shelved. Silent corruption has been observed on generic LSLX256 cards.

### 3. Bench-configure on Orin Nano (~10 min per card)

For each card:

1. Power off the Orin Nano. Unscrew SoM (2 screws). Insert SD under the SoM. SoM back on.
2. Plug in DisplayPort monitor + USB keyboard. Power on.
3. Walk through `oem-config`:
   - Username: `jinn-sync`
   - Password: `jinnabc123`
   - Chromium: **No**
   - Ubuntu updates: **Skip / Remind me later**
   - Power mode: **MAXN_SUPER**
   - APP partition: **default / max**
4. On desktop, connect WiFi.
5. Open a terminal and run:
   ```bash
   TS_AUTHKEY=tskey-auth-xxx curl -fsSL https://raw.githubusercontent.com/JinnLabs-ai/fleet/main/pilot-install.sh | sudo -E bash
   ```
6. Wait for `=== DONE ===`. Note the hostname printed.
7. `sudo reboot` (to activate the permanent-MAC setting).

### 4. Verify on Tailscale admin

- Open https://login.tailscale.com/admin/machines
- Search: `jinn-nano-<mac-suffix>`
- Confirm: `tagged-devices` in owner column, `tag:nano` in Tags column.
- From your Mac: `ssh jinn-sync@<tailscale-ip>` should succeed via pubkey (no password).

### 5. Before shipping to a store

- In Tailscale admin, rename the device from `jinn-nano-<mac-suffix>` to `jinn-nano-<storename>` matching fleet convention (see existing `edge-nano-7-11-*` devices).
- Fill out `ONBOARDING_CHECKLIST.md` for this device.
- Update the store onboarding spreadsheet with: Tailscale IP, hostname, store ID, deploy date.

### 6. End-of-batch cleanup

- Revoke the Tailscale auth key at https://login.tailscale.com/admin/settings/keys
- Delete stale/test nodes from Tailscale admin
- Label/bag each configured card before handoff to the deploy team

## Troubleshooting

### apt lock held by packagekitd
The install script handles this — waits up to 60 sec. If it still fails:
```bash
sudo systemctl stop packagekit; sudo killall packagekitd; sleep 2
# re-run the curl | sudo -E bash
```

### Interface name isn't wlan0
JP6.2 Orin uses predictable names like `wlP1p1s0`. The script auto-detects via `ip route show default` — works regardless of name.

### ext4 corruption errors on first boot
Card silently corrupted during flash. Shelve it. Root cause usually a bad SD card (especially generic LSLX256 brand).

### Hostname changes every boot
NetworkManager is randomizing the MAC. The script installs `/etc/NetworkManager/conf.d/01-jinnlabs-mac-permanent.conf` to pin it, but requires a reboot to take effect. If hostname drift persists after reboot, check that file exists and contains `wifi.cloned-mac-address=permanent`.

### "Tailscale SSH enabled but ACL doesn't allow anyone"
Your ACL's `ssh` block needs an entry:
```json
{"action": "accept", "src": ["autogroup:member"], "dst": ["tag:nano"], "users": ["jinn-sync", "root"]}
```

### Tag didn't apply to device
The auth key's creator must be in `tagOwners` for the requested tag. Add `harjeev@jinnlabs.ai` (or whoever generated the key) to `tagOwners.tag:nano` in the ACL, save, then `tailscale up --reset --auth-key=... --advertise-tags=tag:nano` on the device.
