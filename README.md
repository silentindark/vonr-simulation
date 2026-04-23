# VoNR Simulation Stack

> **Voice over New Radio (VoNR)** — fully software-simulated end-to-end 5G voice call stack running on a single Ubuntu machine. No physical hardware required.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Stack Components](#stack-components)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
  - [1. System Preparation](#1-system-preparation)
  - [2. Clone and Configure](#2-clone-and-configure)
  - [3. Critical Pre-fixes](#3-critical-pre-fixes)
  - [4. Build and Deploy](#4-build-and-deploy)
  - [5. Subscriber Provisioning](#5-subscriber-provisioning)
  - [6. Start the RAN](#6-start-the-ran)
  - [7. IMS Registration and Call](#7-ims-registration-and-call)
- [Measured Results](#measured-results)
- [QoS and QFI Handling](#qos-and-qfi-handling)
- [Known Issues and Fixes](#known-issues-and-fixes)
- [Hardware Transition Plan](#hardware-transition-plan)
- [Repository Structure](#repository-structure)

---

## Overview

This repository implements a complete **VoNR (Voice over New Radio)** testbed using open-source components. VoNR is the 5G equivalent of VoLTE — voice calls delivered natively over 5G New Radio using IMS (IP Multimedia Subsystem).

The setup uses **ZMQ-based RF simulation** via srsRAN, which provides a realistic L1/L2/L3 protocol stack without any physical radio hardware or SDR devices.

**What is demonstrated:**
- 5G SA (Standalone) UE registration via srsRAN + Open5GS
- IMS registration flow: P-CSCF → I-CSCF → S-CSCF → pyHSS (Diameter Cx)
- End-to-end VoNR call: INVITE → Ringing → Connected → Media (RTP/Opus) → BYE
- Separate QoS flows: IMS (QFI=1, GBR) vs Internet (QFI=9, non-GBR)
- Captured and analyzed RTP metrics: 0% packet loss, 9.2ms jitter, MOS 3.58

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Single Ubuntu Host                        │
│                                                             │
│  ┌──────────────┐   ZMQ   ┌──────────────┐   N2/N3         │
│  │  srsRAN UE   │◄───────►│  srsRAN gNB  │◄──────────┐     │
│  │  (5G SA)     │         │  (5G NR)     │           │     │
│  └──────┬───────┘         └──────────────┘           │     │
│         │ tun_srsue                         ┌─────────▼───┐ │
│         │ 192.168.101.2                     │  Open5GS    │ │
│         │ (IMS APN)                         │  5G Core    │ │
│         │                                   │  AMF/SMF    │ │
│  ┌──────▼───────┐                           │  UPF/NRF    │ │
│  │  linphonec   │◄── SIP ──────────────────►│  UDM/UDR    │ │
│  │  UE1 (5070)  │                           │  AUSF/PCF   │ │
│  │  UE2 (5071)  │         ┌─────────────────┴─────────────┘ │
│  └──────────────┘         │                                  │
│         │ RTP             │  ┌─────────────────────────────┐ │
│         └─────────────────┼─►│     Kamailio IMS            │ │
│                           │  │  P-CSCF → I-CSCF → S-CSCF  │ │
│                           │  └──────────────┬──────────────┘ │
│                           │                 │ Diameter Cx     │
│                           │  ┌──────────────▼──────────────┐ │
│                           │  │  pyHSS + MySQL + RTPEngine  │ │
│                           │  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**SIP Call Flow:**
```
UE1 → P-CSCF → I-CSCF → S-CSCF → pyHSS (UAR/SAR via Diameter)
                                ↓
UE2 ← P-CSCF ← I-CSCF ← S-CSCF
         ↕ RTPEngine ↕
      (RTP audio media)
```

---

## Stack Components

| Layer | Component | Version | Role |
|---|---|---|---|
| 5G RAN (gNB) | srsRAN Project | commit 11c9bba | 5G NR base station (ZMQ transport) |
| 5G RAN (UE) | srsRAN 4G | commit ec29b0c | 5G SA UE (ZMQ transport) |
| 5G Core | Open5GS | latest | AMF, SMF, UPF, NRF, UDM, UDR, AUSF, PCF, NSSF, BSF |
| IMS P-CSCF | Kamailio | 5.2.4+ | Proxy-CSCF (UE entry point for SIP) |
| IMS I-CSCF | Kamailio | 5.2.4+ | Interrogating-CSCF (HSS query) |
| IMS S-CSCF | Kamailio | 5.2.4+ | Serving-CSCF (authentication, routing) |
| IMS HSS | pyHSS | latest | Home Subscriber Server (Diameter Cx/Sh) |
| Media Relay | RTPEngine | mr7.4.1.5 | RTP media relay and transcoding |
| SIP Client | linphonec | 4.4.21 | Software phone (UE simulator) |
| Database | MySQL | 8.0 | IMS subscriber database |
| Database | MongoDB | 6.0 | Open5GS subscriber database |

---

## Prerequisites

### Hardware
| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 8 cores | 16 cores |
| RAM | 16 GB | 32 GB |
| Storage | 100 GB SSD | 200 GB SSD |
| OS | Ubuntu 22.04 | Ubuntu 22.04 LTS |

### Software
```bash
# Docker Engine
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER && newgrp docker

# Docker Compose V2 (manual install - apt package unavailable on Ubuntu 24.04)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
  -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# Verify
docker compose version   # Must be v2.x — NOT docker-compose (v1)

# Analysis tools
sudo apt-get install -y tshark
```

> ⚠️ **Important:** Use `docker compose` (V2 plugin), NOT `docker-compose` (V1). They are different tools.

---

## Quick Start

```bash
# Clone
git clone https://github.com/sudharshan1916/vonr-simulation
cd vonr-simulation

# Deploy full stack
bash scripts/deploy.sh

# Make a VoNR call
bash scripts/call_test.sh
```

---

## Detailed Setup

### 1. System Preparation

```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.forwarding=1

# Disable firewall (interferes with Docker networking)
sudo ufw disable

# Fix Docker DNS (critical for campus/restricted networks)
# Find real DNS:
resolvectl status | grep "Current DNS Server"
# Then configure:
echo '{"dns": ["YOUR_DNS_IP", "8.8.8.8"]}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

# Stop native Open5GS if installed (causes port conflicts on 9090)
sudo systemctl stop open5gs-* 2>/dev/null
sudo systemctl disable open5gs-* 2>/dev/null
```

### 2. Clone and Configure

```bash
git clone https://github.com/herlesupreeth/docker_open5gs
cd docker_open5gs

# Find your host IP
ip route get 8.8.8.8 | awk '{print $7; exit}'

# Edit .env — only change these three values
sed -i 's/DOCKER_HOST_IP=.*/DOCKER_HOST_IP=YOUR_HOST_IP/' .env
sed -i 's/SGWU_ADVERTISE_IP=.*/SGWU_ADVERTISE_IP=YOUR_HOST_IP/' .env
sed -i 's/UPF_ADVERTISE_IP=.*/UPF_ADVERTISE_IP=YOUR_HOST_IP/' .env
```

> ⚠️ Do NOT change any container IP addresses in `.env` — leave all `172.22.0.X` values at their defaults.

### 3. Critical Pre-fixes

Apply these **before** deploying. Skipping causes hard-to-debug failures.

```bash
# Fix 1: Disable N5 QoS in P-CSCF (prevents 412 registration errors)
sed -i '/WITH_N5/s/^/#DISABLED /' pcscf/pcscf_init.sh

# Fix 2: Set IMS APN in srsUE config
sed -i 's/apn = internet/apn = ims/' srslte/ue_5g_zmq.conf

# Fix 3: Add NET_ADMIN capability to IMS containers (needed for routing)
sed -i '/container_name: icscf/a\    cap_add:\n      - NET_ADMIN' sa-vonr-ibcf-deploy.yaml
sed -i '/container_name: scscf/a\    cap_add:\n      - NET_ADMIN' sa-vonr-ibcf-deploy.yaml
```

### 4. Build and Deploy

```bash
# Pull pre-built images
docker pull ghcr.io/herlesupreeth/docker_open5gs:master && \
  docker tag ghcr.io/herlesupreeth/docker_open5gs:master docker_open5gs
docker pull ghcr.io/herlesupreeth/docker_kamailio:master && \
  docker tag ghcr.io/herlesupreeth/docker_kamailio:master docker_kamailio
docker pull ghcr.io/herlesupreeth/docker_pyhss:master && \
  docker tag ghcr.io/herlesupreeth/docker_pyhss:master docker_pyhss
docker pull ghcr.io/herlesupreeth/docker_mysql:master && \
  docker tag ghcr.io/herlesupreeth/docker_mysql:master docker_mysql
docker pull ghcr.io/herlesupreeth/docker_srslte:master && \
  docker tag ghcr.io/herlesupreeth/docker_srslte:master docker_srslte
docker pull ghcr.io/herlesupreeth/docker_srsran:master && \
  docker tag ghcr.io/herlesupreeth/docker_srsran:master docker_srsran

# Build remaining images
set -a; source .env; set +a
docker compose -f sa-vonr-ibcf-deploy.yaml build

# Deploy
docker compose -f sa-vonr-ibcf-deploy.yaml up -d

# Fix pyHSS database bug (run after containers start)
sleep 30
docker exec mysql mysql -u root -pchangeme ims_hss_db \
  -e "ALTER TABLE operation_log MODIFY item_id INTEGER NULL;"
docker compose -f sa-vonr-ibcf-deploy.yaml restart pyhss
```

### 5. Subscriber Provisioning

**Open5GS WebUI** at `http://YOUR_HOST_IP:9999` (admin/1423) — Add subscriber:

| Field | Value |
|---|---|
| IMSI | 001011234567895 |
| K | 8baf473f2f8fd09487cccbd7097c6862 |
| OPC | 8E27B6AF0E692E750F32667A3B14605D |
| AMF | 8000 |
| APN 1 | internet — QCI 9, ARP 8 + PCC rules QCI 1 & 2 |
| APN 2 | ims — QCI 5, ARP 1 + PCC rules QCI 1 & 2 |

**pyHSS** at `http://YOUR_HOST_IP:8080/docs/` — Create APNs and AUC via Swagger UI, then provision IMS subscriber via MySQL:

```bash
# Create subscriber
docker exec mysql mysql -u root -pchangeme ims_hss_db -e "
INSERT INTO subscriber (imsi, enabled, auc_id, default_apn, apn_list, msisdn, ue_ambr_dl, ue_ambr_ul)
VALUES ('9076543210', 1, 1, 1, '1,3', '9076543210', 0, 0);"

# Create IMS subscriber
docker exec mysql mysql -u root -pchangeme ims_hss_db -e "
INSERT INTO ims_subscriber (imsi, msisdn, msisdn_list, scscf_peer, scscf_realm, scscf, ifc_path, sh_profile)
VALUES ('9076543210', '9076543210', '[9076543210]',
  'scscf.ims.mnc001.mcc001.3gppnetwork.org',
  'ims.mnc001.mcc001.3gppnetwork.org',
  'sip:scscf.ims.mnc001.mcc001.3gppnetwork.org:6060',
  'default_ifc.xml', 'default_sh_user_data.xml');"
```

> ⚠️ **pyHSS Bug:** The `imsi` field in `ims_subscriber`, `subscriber`, and `auc` tables must contain the MSISDN value (`9076543210`), not the real IMSI (`001011234567895`). pyHSS passes the public SIP identity (MSISDN) as the IMSI in its Diameter UAR query.

### 6. Start the RAN

```bash
# Start gNB
docker compose -f srsgnb_zmq.yaml up -d
sleep 15
# Verify: docker logs srsgnb_zmq | grep "gNB started"

# Start UE
docker compose -f srsue_5g_zmq.yaml up -d
sleep 20
# Verify IMS APN attached (must show 192.168.101.X, NOT 192.168.100.X)
docker logs srsue_5g_zmq 2>&1 | grep "PDU Session"

# Add routing rules (required after every restart)
docker exec pcscf ip route add 192.168.101.0/24 via 172.22.0.8 2>/dev/null
docker exec icscf ip route add 192.168.101.0/24 via 172.22.0.8 2>/dev/null
docker exec scscf ip route add 192.168.101.0/24 via 172.22.0.8 2>/dev/null
docker exec upf iptables -t nat -A POSTROUTING \
  -s 192.168.101.0/24 ! -o ogstun2 -j MASQUERADE 2>/dev/null
```

### 7. IMS Registration and Call

```bash
# Install SIP client inside UE container
docker exec srsue_5g_zmq apt-get install -y linphone-cli

# Add DNS entry
docker exec srsue_5g_zmq bash -c \
  'echo "172.22.0.21 ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts'

# Create UE1 config (caller, port 5070)
docker exec srsue_5g_zmq bash -c 'cat > /root/linphone.cfg << EOF
[sip]
sip_port=5070
sip_tcp_port=5070
default_proxy=0
[proxy_0]
reg_proxy=sip:172.22.0.21
reg_identity=sip:9076543210@ims.mnc001.mcc001.3gppnetwork.org
reg_expires=300
reg_sendregister=1
publish=0
[auth_info_0]
username=9076543210
userid=9076543210
passwd=8baf473f2f8fd09487cccbd7097c6862
realm=ims.mnc001.mcc001.3gppnetwork.org
EOF'

# Create UE2 config (receiver, port 5071)
docker exec srsue_5g_zmq bash -c 'cat > /root/linphone2.cfg << EOF
[sip]
sip_port=5071
sip_tcp_port=5071
default_proxy=0
[proxy_0]
reg_proxy=sip:172.22.0.21
reg_identity=sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org
reg_expires=300
reg_sendregister=1
publish=0
[auth_info_0]
username=9076543211
userid=9076543211
passwd=8baf473f2f8fd09487cccbd7097c6862
realm=ims.mnc001.mcc001.3gppnetwork.org
EOF'

# Start UE2 receiver (with auto-answer)
docker exec srsue_5g_zmq bash -c '
(sleep 90; echo "quit") | linphonec -c /root/linphone2.cfg -a > /tmp/ue2.log 2>&1' &

# Wait for UE2 to fully register
sleep 20

# UE1 makes the VoNR call
docker exec srsue_5g_zmq bash -c '
(sleep 5;
 echo "call sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org";
 sleep 20;
 echo "terminate";
 sleep 2;
 echo "quit") | linphonec -c /root/linphone.cfg > /tmp/ue1.log 2>&1'

# Verify
docker exec srsue_5g_zmq cat /tmp/ue1.log | grep -E "ringing|connected|Media|ended"
docker exec srsue_5g_zmq cat /tmp/ue2.log | grep -E "answering|connected|Media|ended"
```

**Expected output:**
```
# UE1 (caller)
Call 1 to sip:9076543211@... ringing.
Call 1 with sip:9076543211@... connected.
Media streams established with sip:9076543211@... for call 1 (audio).
Call 1 with sip:9076543211@... ended (No error).

# UE2 (receiver)
-------auto answering to call-------
Call 1 with sip:9076543210@... connected.
Media streams established with sip:9076543210@... for call 1 (audio).
Call 1 with sip:9076543210@... ended (No error).
```

---

## Measured Results

Metrics captured via tshark from a live VoNR call (pcap in `results/captures/`):

| Metric | Measured | 3GPP Requirement | Status |
|---|---|---|---|
| Packet Loss (UL) | **0.0%** | < 1% | ✅ Pass |
| Packet Loss (DL) | **0.0%** | < 1% | ✅ Pass |
| Mean Jitter (UL) | **9.203 ms** | < 50 ms | ✅ Pass |
| Mean Jitter (DL) | **9.197 ms** | < 50 ms | ✅ Pass |
| Max Jitter | **10.516 ms** | < 50 ms | ✅ Pass |
| MOS Score | **3.58** | > 3.5 | ✅ Pass |
| Registration Latency | **318 ms** | < 500 ms | ✅ Pass |
| Call Teardown | **10 ms** | < 500 ms | ✅ Pass |
| Codec | **Opus** | AMR-WB / G.711 | ✅ Good |
| Call Setup Latency | ~16 s | < 2 s | ⚠️ High* |

> *Call setup latency is high due to ICE/STUN negotiation in linphonec under software simulation. Disabling ICE in linphonec config reduces this significantly. Real hardware deployments typically achieve 400–800 ms.

**MOS Score Calculation (E-model):**
```
MOS = 4.5 - (mean_jitter × 0.1) - (packet_loss% × 0.3)
    = 4.5 - (9.203 × 0.1) - (0 × 0.3)
    = 3.58  →  "Good" quality
```

---

## QoS and QFI Handling

VoNR separates voice and data traffic using dedicated QoS flows:

| QFI | 5QI | Type | APN | Interface |
|---|---|---|---|---|
| 1 | 1 | GBR (Guaranteed) | ims | ogstun2 (192.168.101.0/24) |
| 9 | 9 | Non-GBR (Best Effort) | internet | ogstun (192.168.100.0/24) |

```bash
# Verify QoS separation — two separate UPF tunnel interfaces
docker exec upf ip addr show ogstun   # Internet (QFI 9)
docker exec upf ip addr show ogstun2  # IMS voice (QFI 1)

# Confirm SMF assigned IMS DNN correctly
docker logs smf 2>&1 | grep "DNN\[ims\]"
```

---

## Known Issues and Fixes

| Issue | Root Cause | Fix |
|---|---|---|
| `412 Register N5 QoS Failed` | P-CSCF init enables WITH_N5 when DEPLOY_MODE=5G | Disable in `pcscf/pcscf_init.sh` |
| UAR returns empty (no server_name) | pyHSS queries IMSI column with MSISDN value | Set `imsi=MSISDN` in all 3 DB tables |
| UE gets 192.168.100.X (wrong APN) | Container reads `/etc/srsran/ue.conf`, not mounted file | Edit both host file and container file |
| pyHSS API returns 400 | `item_id` NOT NULL constraint bug | `ALTER TABLE operation_log MODIFY item_id INTEGER NULL` |
| 0 Diameter peers after restart | pyHSS doesn't re-accept connections automatically | Restart pyhss first, then icscf/scscf |
| Port 9090 in use | Native Open5GS services running | `systemctl stop open5gs-*` |
| baresip stdio fails | epoll on stdin not permitted in container | Use linphonec instead |
| Call cancelled (487) | UE2 not registered before UE1 calls | Wait 20s after UE2 starts before calling |

---

## Hardware Transition Plan

| Phase | RAN | Description |
|---|---|---|
| **Phase 1** (current) | srsRAN ZMQ | Full software simulation, no hardware needed |
| **Phase 2** | UERANSIM | Better multi-UE support, more stable signaling |
| **Phase 3** | USRP B210 + real SIM | Over-the-air transmission, real 5G UE |

**Phase 2 — Switch to UERANSIM:**
```bash
docker compose -f srsgnb_zmq.yaml down
docker compose -f srsue_5g_zmq.yaml down
docker compose -f nr-gnb.yaml up -d
docker compose -f nr-ue.yaml up -d
```

**Phase 3 — Real hardware requirements:**
- SDR: USRP B210 (~$1,500) or LimeSDR Mini (~$200)
- Programmable SIM: sysmoISIM-SJA5
- UE: Android phone with 5G SA support (Pixel 6/7)

---

## Repository Structure

```
vonr-simulation/
├── README.md
├── config/
│   ├── .env                    # Environment variables
│   ├── kamailio/
│   │   ├── pcscf.cfg           # P-CSCF Kamailio config
│   │   ├── pcscf_init.sh       # P-CSCF init script (WITH_N5 fix applied)
│   │   └── scscf.cfg           # S-CSCF Kamailio config
│   └── srsran/
│       └── ue_5g_zmq.conf      # srsRAN UE config (apn=ims)
├── scripts/
│   ├── deploy.sh               # Full stack deployment
│   └── call_test.sh            # VoNR call test with metrics
└── results/
    ├── captures/
    │   └── call_metrics.pcap   # Captured VoNR call (40KB)
    └── metrics/
        └── rtp_metrics.txt     # Measured RTP quality metrics
```

---

## References

- [3GPP TS 23.228](https://www.3gpp.org/ftp/Specs/archive/23_series/23.228/) — IMS Stage 2
- [3GPP TS 23.501](https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/) — 5G System Architecture
- [Open5GS Documentation](https://open5gs.org/open5gs/docs/)
- [srsRAN Project](https://docs.srsran.com/projects/project)
- [Kamailio IMS](https://www.kamailio.org/wiki/)
- [docker_open5gs](https://github.com/herlesupreeth/docker_open5gs) by herlesupreeth
- [pyHSS](https://github.com/nickvsnetworking/pyhss) by nickvsnetworking
