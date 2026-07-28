# VoNR Demo using Open5GS
### End-to-End Voice over New Radio Simulation
**Sudharshan Mothukuru (RP1141), NeWS Lab, IIT Hyderabad**

> **What this is:** A complete, working VoNR (Voice over 5G New Radio) simulation on a single Ubuntu machine. Two software phones make a real voice call over a fully simulated 5G Standalone network with IMS — no hardware, no SIM cards, no spectrum license.

---

## Quick Start (TL;DR)

```bash
./start_vonr.sh          # start everything (~3 min)
./vonr_call.sh           # make a VoNR call
./vonr_full_kpi_logs.sh  # measure call quality KPIs
./verify_vonr_complete.sh # verify 55 checks pass
./stop_vonr.sh           # stop before shutdown
```

---

## Table of Contents

- [Verified Results](#verified-results)
- [Architecture](#architecture)
- [Deviations from Original Proposal](#deviations-from-original-proposal)
- [Prerequisites](#prerequisites)
- [Step 1 — Install Dependencies](#step-1--install-dependencies)
- [Step 2 — Clone and Configure](#step-2--clone-and-configure)
- [Step 3 — Start the Stack](#step-3--start-the-stack)
- [Step 4 — Make a VoNR Call](#step-4--make-a-vonr-call)
- [Step 5 — Full KPI Measurement](#step-5--full-kpi-measurement)
- [Step 6 — Verify Everything](#step-6--verify-everything)
- [Step 7 — Stop Before Shutdown](#step-7--stop-before-shutdown)
- [Critical Bugs Fixed](#critical-bugs-fixed)
- [Troubleshooting](#troubleshooting)
- [Scripts Reference](#scripts-reference)
- [Subscriber Configuration](#subscriber-configuration)
- [References](#references)

---

## Verified Results

All results from live capture on May 5, 2026 — `vonr.pcap` (20-second call, Opus codec, ZMQ simulation).

### Call Quality (RTP)

| Metric | Stream 1 (UE→RTPEngine) | Stream 2 (RTPEngine→UE) | 3GPP Limit |
|--------|------------------------|------------------------|------------|
| Packets | 978 | 978 | — |
| Packet Loss | **0.0%** | **0.0%** | < 1% |
| Mean Delta | **19.988ms** | **19.988ms** | ~20ms (50pps) |
| Mean Jitter | **9.912ms** | **9.910ms** | < 50ms |
| Max Jitter | **10.604ms** | **10.601ms** | < 50ms |
| Codec | **Opus** | **Opus** | — |

### Call Timing

| Metric | Measured |
|--------|----------|
| Call Setup Time (INVITE → 200 OK) | **0.061 seconds** |
| Call Duration | **19.877 seconds** |
| IMS Registration Latency | **~318ms** |

### Verification

```
Total checks : 55
Passed       : 55
Failed       : 0
Warnings     : 0
VoNR stack is fully operational!
```

### SIP Call Flow (from pcap)

```
0.44s    →  200 OK  (initial registration)
20.00s   →  REGISTER
20.19s   ←  401 Unauthorized (challenge)
20.42s   →  REGISTER (with credentials)
          ←  200 OK (registered)
24.87s   →  INVITE  (UE1 calls UE2)
24.94s   ←  180 Ringing
24.94s   ←  200 OK  (UE2 answers)
25.16s   →  ACK
25.21s      RTP audio flows (Opus, 50 pps)
44.75s   →  BYE
44.76s   ←  200 OK  (call ended cleanly)
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Single Ubuntu Host                           │
│                                                                     │
│  ┌─────────────┐   ZMQ    ┌─────────────┐   N2/N3  ┌───────────┐    │
│  │  srsRAN UE  │◄────────►│ srsRAN gNB  │◄────────►│  Open5GS  │    │
│  │ linphonec   │          │ (ZMQ RF sim)│          │  5G Core  │    │
│  │ UE1: :5070  │          │ 172.22.0.37 │          │ AMF / SMF │    │
│  │ UE2: :5071  │          └─────────────┘          │ UPF / NRF │    │
│  │ 172.22.0.34 │                                   └─────┬─────┘    │
│  └──────┬──────┘                                         │          │
│         │ SIP over IMS APN                       ogstun2 │          │
│         │ 192.168.101.2                    192.168.101.1 │          │
│         ▼                                                │          │
│  ┌─────────────────────────────────┐                    │           │
│  │  Kamailio IMS  (172.22.0.x)     │◄───────────────────┘           │
│  │  P-CSCF :5060  →  I-CSCF :4060 │                                 │
│  │  I-CSCF        →  S-CSCF :6060 │                                 │ 
│  └──────┬──────────────┬───────────┘                                │
│         │ Diameter Cx  │ RTP relay                                  │
│         ▼              ▼                                            │
│  ┌──────────┐   ┌─────────────┐                                     │
│  │  pyHSS   │   │  RTPEngine  │  ← relays Opus audio packets        │
│  │  MySQL   │   │ 172.22.0.16 │                                     │
│  └──────────┘   └─────────────┘                                     │
│                                                                     │
│  Docker Network: 172.22.0.0/24    26 containers total               │
└─────────────────────────────────────────────────────────────────────┘
```

**Three-phase call flow:**

1. **5G Registration** — srsUE attaches to gNB (ZMQ) → AMF authenticates via 5G-AKA → SMF creates IMS PDU session → UE gets IP `192.168.101.2` on `ogstun2`
2. **IMS Registration** — linphonec sends `SIP REGISTER` → P-CSCF → I-CSCF queries pyHSS via Diameter UAR → S-CSCF challenges with 401 → UE responds with credentials → `200 OK`
3. **VoNR Call** — `SIP INVITE` → `180 Ringing` → `200 OK` → `ACK` → RTP audio (Opus, 50 pps, 20ms intervals) relayed via RTPEngine → `SIP BYE` → `200 OK`

---

## Deviations from Original Proposal

> Two tools were changed from the original proposal. Both are upgrades, not failures.

| Original Plan | What Was Used | Why |
|---|---|---|
| **UERANSIM** | **srsRAN (ZMQ)** | srsRAN simulates full L1/L2/L3 stack (HARQ, MAC, RLC, PDCP) — more realistic protocol behavior |
| **RTPProxy** | **RTPEngine** | RTPEngine is actively maintained and already integrated in docker_open5gs |
| **Wireshark** | **tshark + tcpdump** | Same libpcap engine, works headless in Docker; tshark gives scriptable KPI extraction |

---

## Prerequisites

- **OS:** Ubuntu 22.04 LTS (tested), Ubuntu 20.04 works
- **Hardware:** 8-core CPU, 16GB RAM, 50GB disk
- **Network:** Internet for initial setup only

---

## Step 1 — Install Dependencies

```bash
# Docker
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker Compose V2 (must be v2.x)
docker compose version

# Network tools
sudo apt install -y tshark tcpdump net-tools linphone-cli

# Allow tcpdump without password (needed for RTP capture scripts)
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/tcpdump" | sudo tee /etc/sudoers.d/tcpdump
sudo chmod 440 /etc/sudoers.d/tcpdump

# Enable IP forwarding permanently
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

---

## Step 2 — Clone and Configure

```bash
# Clone the base stack
git clone https://github.com/herlesupreeth/docker_open5gs.git
cd docker_open5gs

# CRITICAL FIX — disable N5 QoS before first build
# Without this, SIP REGISTER returns 412 error
sed -i '/WITH_N5/s/^/#DISABLED /' pcscf/pcscf_init.sh

# Clone this repo's scripts into home directory
git clone https://github.com/sudharshan1916/VoNR_Private.git /tmp/vonr
cp /tmp/vonr/scripts/*.sh ~/
chmod +x ~/start_vonr.sh ~/vonr_call.sh ~/stop_vonr.sh
chmod +x ~/verify_vonr_complete.sh ~/vonr_full_kpi_logs.sh
```

---

## Step 3 — Start the Stack

```bash
~/start_vonr.sh
```

The script does this automatically:

| Step | Action |
|------|--------|
| 1 | Stop conflicting systemd services + disable ufw |
| 2 | Remove any leftover containers |
| 3 | Start 25 core containers via `sa-vonr-ibcf-deploy.yaml` |
| 4 | Wait 30s for initialization |
| 5 | Fix pyHSS `operation_log` schema (ALTER TABLE) |
| 6 | Start srsRAN gNB → wait 15s |
| 7 | Start srsRAN UE → wait 20s |
| 8 | Add routing rules on P/I/S-CSCF to reach UE subnet |
| 9 | Add NAT/MASQUERADE on UPF for IMS traffic |
| 10 | Install linphonec + tcpdump inside UE container |
| 11 | Add IMS DNS entries to UE `/etc/hosts` |
| 12 | Create linphonec configs for UE1 (port 5070) and UE2 (port 5071) |

**Expected output at end:**
```
=== VoNR stack ready ===
PDU Session Establishment successful. IP: 192.168.101.2
Run: ~/vonr_call.sh
```

>  If you see `IP: 192.168.100.x` — the UE got the internet APN. See [Troubleshooting](#troubleshooting).

---

## Step 4 — Make a VoNR Call

```bash
~/vonr_call.sh
```

**Expected output:**
```
=== UE1 ===
Call 1 to sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org ringing.
Call 1 with sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org connected.
Media streams established with sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org for call 1 (audio).
Call 1 with sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org ended (No error).

=== UE2 ===
-------auto answering to call-------
Call 1 with sip:9076543210@ims.mnc001.mcc001.3gppnetwork.org connected.
Media streams established with sip:9076543210@ims.mnc001.mcc001.3gppnetwork.org for call 1 (audio).
Call 1 with sip:9076543210@ims.mnc001.mcc001.3gppnetwork.org ended (No error).
```

If you see `ringing → connected → Media streams established → ended (No error)` on **both UEs** — VoNR is working.

---

## Step 5 — Full KPI Measurement

```bash
~/vonr_full_kpi_logs.sh
```

This script captures a complete VoNR call, copies the pcap to `~/vonr.pcap`, and prints:

- **SIP call flow** — every REGISTER, INVITE, 180, 200, ACK, BYE with timestamps
- **Call setup time** — time from INVITE to 200 OK (our result: **0.061 seconds**)
- **Call duration** — time from INVITE to BYE (our result: **19.877 seconds**)
- **RTP KPIs** — packets, loss, mean delta, jitter per stream

**Expected output (abbreviated):**
```
SIP CALL FLOW
==============================
24.87s   INVITE
24.94s   180 Ringing
24.94s   200 OK
25.16s   ACK
44.75s   BYE
44.76s   200 OK

Call Setup Time: 0.061 seconds
Call Duration:   19.877 seconds

RTP KPI SUMMARY
==============================
Packets: 978     Lost: 0 (0.0%)
Mean Jitter: 9.912ms    Max Jitter: 10.604ms
Mean Delta: 19.988ms    Codec: opus
```

---

## Step 6 — Verify Everything

```bash
~/verify_vonr_complete.sh
```

Runs automated checks across all layers. **Expected: 55/55 PASS**.

| Section | Checks |
|---------|--------|
| 1. Containers | All 21 required NFs are Up |
| 2. gNB | Started, AMF connected, ZMQ active |
| 3. UE 5G | Random Access, RRC Connected, IMS IP 192.168.101.2 |
| 4. 5G Core | AMF, SMF IMS DNN, UPF ogstun2 tunnel, NAT rule |
| 5. IMS Routing | Routes to UE subnet on P/I/S-CSCF |
| 6. Diameter | pyHSS peers connected |
| 7. Subscriber DB | AUC, subscriber, IMS subscriber, APNs |
| 8. SIP Registration | Both UEs registered, no 412 errors |
| 9. Live Call Test | Ringing → connected → media → clean BYE |
| 11. QoS | ogstun QFI=9 and ogstun2 QFI=1 active |

---

## Step 7 — Stop Before Shutdown

```bash
~/stop_vonr.sh
```

Always run this before shutting down. Cleanly stops all containers.

---

## Critical Bugs Fixed

> These bugs exist in the upstream `docker_open5gs` repo. All fixes are applied automatically by `start_vonr.sh`. Documented here so you understand what was changed and why.

---

### Bug 1 — pyHSS IMSI/MSISDN Mismatch Most Critical

**Symptom:** SIP REGISTER never gets a response. I-CSCF Diameter UAR returns empty `server_name` AVP.

**Root cause:** pyHSS passes the public SIP identity (MSISDN = `9076543210`) as the key to query `WHERE imsi = ?`. But the database stores the real IMSI (`001011234567895`). The SQL returns zero rows, silently.

**Fix — set `imsi = MSISDN` in all three IMS tables:**
```sql
UPDATE auc SET imsi='9076543210' WHERE id=1;
UPDATE subscriber SET imsi='9076543210' WHERE id=1;
UPDATE ims_subscriber SET imsi='9076543210' WHERE id=1;
```

**How to debug:** Check pyHSS SQLAlchemy logs:
```bash
docker logs pyhss 2>&1 | grep "WHERE imsi" | tail -3
```

---

### Bug 2 — N5 QoS Authorization Failure (412 Error)

**Symptom:** `412 Precondition Failed — N5 QoS authorization failed` on every SIP REGISTER.

**Root cause:** `pcscf/pcscf_init.sh` enables `WITH_N5` flag when `DEPLOY_MODE=5G`. PCF N5 interface is not configured for IMS in the default stack.

**Fix — apply before building containers:**
```bash
sed -i '/WITH_N5/s/^/#DISABLED /' pcscf/pcscf_init.sh
```

**Verify fix:**
```bash
docker logs pcscf 2>&1 | grep "412" | wc -l   # must be 0
```

---

### Bug 3 — srsUE Reads Wrong Config File

**Symptom:** Setting `apn = ims` in the mounted config has no effect. UE always gets `192.168.100.x` (internet APN) instead of `192.168.101.x` (IMS APN).

**Root cause:** The container reads `/etc/srsran/ue.conf` at runtime — NOT the mounted file at `/mnt/srslte/ue_5g_zmq.conf`.

**Fix — edit both:**
```bash
sed -i 's/apn = internet/apn = ims/' srslte/ue_5g_zmq.conf
docker exec srsue_5g_zmq sed -i 's/apn = internet/apn = ims/' /etc/srsran/ue.conf
```

---

### Bug 4 — pyHSS operation_log Schema Error

**Symptom:** pyHSS crashes with `IntegrityError: NOT NULL constraint failed: operation_log.item_id` when processing SAR messages.

**Fix — run after every fresh container start:**
```bash
docker exec mysql mysql -u root -pchangeme ims_hss_db \
  -e "ALTER TABLE operation_log MODIFY item_id INTEGER NULL;"
```
Already included in `start_vonr.sh`.

---

### Bug 5 — Diameter Peer Reconnection Timing

**Symptom:** After restarting icscf/scscf, Diameter UAR returns `Connection refused` on port 3875.

**Root cause:** pyHSS Diameter server needs ~15 seconds to start listening after container start.

**Fix — always start in this order:**
```bash
docker compose -f sa-vonr-ibcf-deploy.yaml up -d   # starts pyHSS
sleep 30                                             # wait for Diameter to listen
docker compose -f srsgnb_zmq.yaml up -d
docker compose -f srsue_5g_zmq.yaml up -d
```
Already handled in `start_vonr.sh`.

---

### Bug 6 — baresip Cannot Read stdin in Docker

**Symptom:** baresip starts but ignores all typed commands. Calls cannot be made.

**Root cause:** Docker security context blocks `epoll` on file descriptor 0 (stdin).

**Fix:** Use **linphonec** instead. It reads stdin correctly inside Docker containers.

---

### Bug 7 — linphonec Overwrites Config with Wrong Defaults

**Symptom:** `verify_server_certs=1` appears in config after each run, silently blocking SIP registration.

**Root cause:** linphonec writes its state database to `$HOME/.local/share/linphone/` and overwrites your config on startup if HOME is shared.

**Fix — give each UE its own HOME directory:**
```bash
docker exec srsue_5g_zmq mkdir -p /root/ue1/.local/share/linphone
docker exec srsue_5g_zmq mkdir -p /root/ue2/.local/share/linphone

# Run UE1
docker exec srsue_5g_zmq bash -c 'export HOME=/root/ue1; linphonec -c /root/ue1/linphonerc'

# Run UE2
docker exec srsue_5g_zmq bash -c 'export HOME=/root/ue2; linphonec -c /root/ue2/linphonerc'
```

---

### Bug 8 — DNS Resolution Fails for IMS Domain

**Symptom:** `belle-sip-error: DNS resolution failed for scscf.ims.mnc001.mcc001.3gppnetwork.org`

**Fix:**
```bash
docker exec srsue_5g_zmq bash -c '
echo "172.22.0.21 ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts
echo "172.22.0.20 scscf.ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts
echo "172.22.0.19 icscf.ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts'
```
Already included in `start_vonr.sh`.

---

### Bug 9 — tcpdump Inside Container Captures 0 Packets

**Symptom:** `tcpdump -i eth0` inside srsue_5g_zmq container captures nothing during an active call.

**Root cause:** Docker iptables forwarding — inter-container traffic does not pass through the container's `eth0` in a way tcpdump can intercept.

**Fix:** Capture on the Docker network inside the container using `-i any`:
```bash
docker exec -u root srsue_5g_zmq bash -c \
  "tcpdump -i any -w /tmp/vonr.pcap port 5060 or udp"
```
This is exactly what `vonr_full_kpi_logs.sh` does — it captures on `-i any` instead of `-i eth0`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `IP: 192.168.100.x` not `101.x` | Wrong APN in ue.conf | `docker exec srsue_5g_zmq sed -i 's/apn = internet/apn = ims/' /etc/srsran/ue.conf` then restart |
| SIP REGISTER never reaches P-CSCF | Missing DNS entries | Add ims.mnc001... to `/etc/hosts` inside container |
| 412 on SIP REGISTER | N5 QoS enabled | `sed -i '/WITH_N5/s/^/#/' pcscf/pcscf_init.sh` and restart pcscf |
| Call errors without ringing | UE2 not registered yet | Wait 20s after starting UE2 before calling |
| Diameter UAR returns empty | pyHSS IMSI/MSISDN bug | Set `imsi = MSISDN` in all 3 DB tables |
| pyHSS crashes on SAR | operation_log schema | `ALTER TABLE operation_log MODIFY item_id INTEGER NULL` |
| Containers conflict on start | Old containers still running | `docker stop $(docker ps -q) && docker rm $(docker ps -aq)` |
| linphonec ignores config | Wrong HOME directory | Use `export HOME=/root/ue1` before running linphonec |
| tcpdump captures 0 packets | Wrong interface | Use `-i any` not `-i eth0` inside container |
| Call setup > 16 seconds | ICE/STUN negotiation | Expected in linphonec — disable ICE in linphonerc for faster setup |

---

## Scripts Reference

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `start_vonr.sh` | Start full stack (26 containers + all config) | After every reboot |
| `vonr_call.sh` | Make a VoNR call between UE1 and UE2 | Quick call test |
| `vonr_full_kpi_logs.sh` | Full KPI measurement — SIP flow, setup time, RTP metrics | For measurements |
| `verify_vonr_complete.sh` | 55-point automated verification | Confirm everything works |
| `stop_vonr.sh` | Stop all containers cleanly | Before shutdown |

---

## Subscriber Configuration

### Open5GS 5G Core — via WebUI at `http://localhost:9999` (admin / 1423)

| Field | Value |
|-------|-------|
| IMSI | `001011234567895` |
| Key (Ki) | `8baf473f2f8fd09487cccbd7097c6862` |
| OPC | `8E27B6AF0E692E750F32667A3B14605D` |
| AMF | `8000` |
| APN 1 | `internet` — QCI 9, ARP 8 |
| APN 2 | `ims` — QCI 5, ARP 1 + PCC rule QCI 1 GBR 128/128 kbps |

### IMS pyHSS — via MySQL direct insert

> **Important:** The `imsi` column must be set to the **MSISDN value** (not the real IMSI) due to the pyHSS bug described in Bug 1.

```sql
-- Connect: docker exec -it mysql mysql -u root -pchangeme ims_hss_db

-- APN entries
INSERT INTO apn (apn_id, apn) VALUES (1, 'internet'), (3, 'ims');

-- Authentication credentials (imsi = MSISDN intentionally)
INSERT INTO auc (id, imsi, ki, opc, sqn, auth_scheme)
VALUES (1, '9076543210', '8baf473f2f8fd09487cccbd7097c6862',
        '8E27B6AF0E692E750F32667A3B14605D', 0, 'milenage');

-- Subscriber (imsi = MSISDN intentionally, apn_list = '1,3')
INSERT INTO subscriber (id, imsi, msisdn, auc_id, default_apn, apn_list)
VALUES (1, '9076543210', '9076543210', 1, 1, '1,3');

-- IMS subscriber with S-CSCF address
INSERT INTO ims_subscriber (id, imsi, msisdn, scscf)
VALUES (1, '9076543210', '9076543210',
        'sip:scscf.ims.mnc001.mcc001.3gppnetwork.org:6060');

-- Second subscriber (UE2)
INSERT INTO auc (id, imsi, ki, opc, sqn, auth_scheme)
VALUES (2, '9076543211', '8baf473f2f8fd09487cccbd7097c6862',
        '8E27B6AF0E692E750F32667A3B14605D', 0, 'milenage');
INSERT INTO subscriber (id, imsi, msisdn, auc_id, default_apn, apn_list)
VALUES (2, '9076543211', '9076543211', 2, 1, '1,3');
INSERT INTO ims_subscriber (id, imsi, msisdn, scscf)
VALUES (2, '9076543211', '9076543211',
        'sip:scscf.ims.mnc001.mcc001.3gppnetwork.org:6060');
```

---

## References

| Resource | Link |
|----------|------|
| Base Docker stack | https://github.com/herlesupreeth/docker_open5gs |
| Open5GS docs | https://open5gs.org/open5gs/docs/ |
| srsRAN Project (gNB) | https://docs.srsran.com/projects/project |
| srsRAN 4G (srsUE) | https://docs.srsran.com/projects/4g |
| Kamailio IMS | https://www.kamailio.org/wiki/ |
| pyHSS | https://github.com/nickvsnetworking/pyhss |
| RTPEngine | https://github.com/sipwise/rtpengine |
| 3GPP TS 23.228 | IMS Stage 2 architecture |
| 3GPP TS 23.501 | 5G System architecture |
| 3GPP TS 26.114 | Voice quality requirements (jitter < 50ms, loss < 1%) |
| ITU-T G.107 | E-model for MOS score computation |

