# Device Onboarding Checklist

Copy this template for each new edge device. Fill in as you go. Keep filled-out copies in `devices/<hostname>.md` (or your store onboarding spreadsheet).

---

**Device identity**
- [ ] Store name: __________________________________________________
- [ ] Store ID / FOA ID: _____________________________________________
- [ ] Physical hardware model: Jetson Orin Nano Dev Kit 945-13766
- [ ] Deployed-at-store hostname (rename in Tailscale admin): `jinn-nano-_____________`
- [ ] Tailscale IP (100.x.y.z): ________________________________________
- [ ] Tailscale MagicDNS FQDN: `jinn-nano-____________.tailf6ac93.ts.net`
- [ ] MAC address (permanent): ________________________________________
- [ ] Jetson module serial: ___________________________________________
- [ ] SD card brand/size/serial: ______________________________________

**Bench verification** (check each before shipping)
- [ ] Flashed with JP6.2 Orin Nano image (sha256: `239035634896…`)
- [ ] Hash-verified via `sudo cmp` — MATCH
- [ ] Boot test passed (no ext4 errors, reached GNOME desktop)
- [ ] `oem-config` completed with `jinn-sync` user, password `jinnabc123`
- [ ] Power mode set to **MAXN_SUPER**
- [ ] WiFi connected on bench LAN
- [ ] `pilot-install.sh` ran to `=== DONE ===`
- [ ] Device registered on Tailscale admin as `jinn-nano-<mac-suffix>` with `tag:nano`
- [ ] SSH smoke test: `ssh jinn-sync@<tailscale-ip>` works from operator's Mac (pubkey, no password)
- [ ] Permanent-MAC config installed (`/etc/NetworkManager/conf.d/01-jinnlabs-mac-permanent.conf`)
- [ ] Rebooted after bench config — hostname stayed stable
- [ ] Renamed on Tailscale admin to store-specific name

**Ready for shipment**
- [ ] Labeled physically: `<hostname>` sticker or tape
- [ ] Power supply included
- [ ] DisplayPort cable and USB keyboard NOT included (not needed once deployed)
- [ ] Store deployment date scheduled: __________________
- [ ] Operator signature / initials: __________________

**Post-deployment verification** (after store install)
- [ ] Device came online in Tailscale from store network
- [ ] `ssh jinn-sync@<tailscale-ip>` works from operator's machine
- [ ] Workload deployed (list services): ________________________________
- [ ] Store cameras streaming through this device

---

Notes / issues encountered:
