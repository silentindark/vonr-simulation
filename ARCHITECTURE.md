# VoNR Architecture

## System Overview

```mermaid
graph TB
    subgraph RAN["🔵 Radio Access Network (ZMQ Simulated)"]
        UE["srsRAN UE\n5G SA Mode"]
        GNB["srsRAN gNB\n5G NR Base Station"]
        UE <-->|"ZMQ RF Simulation"| GNB
    end

    subgraph CORE["🟠 Open5GS 5G Core (SA)"]
        AMF["AMF\nAccess & Mobility"]
        SMF["SMF\nSession Management"]
        UPF["UPF\nUser Plane"]
        NRF["NRF\nNetwork Repository"]
        UDM["UDM\nSubscriber Data"]
        AUSF["AUSF\nAuthentication"]
        PCF["PCF\nPolicy Control"]
        NRF --> AMF & SMF & UPF
        UDM --> AUSF
    end

    subgraph IMS["🟣 Kamailio IMS"]
        PCSCF["P-CSCF\nProxy CSCF\n(UE entry point)"]
        ICSCF["I-CSCF\nInterrogating CSCF\n(HSS query)"]
        SCSCF["S-CSCF\nServing CSCF\n(Auth & Routing)"]
        PCSCF -->|"SIP"| ICSCF -->|"SIP"| SCSCF
    end

    subgraph BACKEND["🔴 IMS Backend"]
        PYHSS["pyHSS\nIMS HSS\n(Diameter Cx/Sh)"]
        MYSQL["MySQL\nIMS Subscriber DB"]
        RTPENGINE["RTPEngine\nRTP Media Relay"]
        PYHSS --- MYSQL
    end

    subgraph CLIENTS["🟢 SIP Clients (inside UE container)"]
        UE1["linphonec UE1\nMSISDN: 9076543210\nPort 5070"]
        UE2["linphonec UE2\nMSISDN: 9076543211\nPort 5071"]
        UE1 <-->|"RTP Audio\n(Opus codec)"| UE2
    end

    GNB <-->|"N2 (NGAP)"| AMF
    GNB <-->|"N3 (GTP-U)"| UPF
    UPF <-->|"N4 (PFCP)"| SMF
    UPF -->|"IMS APN\n192.168.101.0/24"| PCSCF
    ICSCF <-->|"Diameter Cx\n(UAR/MAR/SAR)"| PYHSS
    SCSCF <-->|"Diameter Cx"| PYHSS
    SCSCF --> RTPENGINE
    UE1 <-->|"SIP REGISTER\nSIP INVITE"| PCSCF
    UE2 <-->|"SIP REGISTER\nSIP INVITE"| PCSCF
```

---

## SIP Call Flow

```mermaid
sequenceDiagram
    participant UE1 as linphonec UE1
    participant PCSCF as P-CSCF
    participant ICSCF as I-CSCF
    participant SCSCF as S-CSCF
    participant HSS as pyHSS
    participant UE2 as linphonec UE2

    Note over UE1,UE2: IMS Registration Phase

    UE1->>PCSCF: SIP REGISTER
    PCSCF->>ICSCF: SIP REGISTER
    ICSCF->>HSS: Diameter UAR (User Auth Request)
    HSS-->>ICSCF: Diameter UAA (S-CSCF address)
    ICSCF->>SCSCF: SIP REGISTER
    SCSCF->>HSS: Diameter MAR (Multimedia Auth Request)
    HSS-->>SCSCF: Diameter MAA (auth vectors)
    SCSCF-->>PCSCF: 401 Unauthorized (challenge)
    PCSCF-->>UE1: 401 Unauthorized
    UE1->>PCSCF: SIP REGISTER (with credentials)
    PCSCF->>SCSCF: SIP REGISTER
    SCSCF->>HSS: Diameter SAR (Server Assignment)
    HSS-->>SCSCF: Diameter SAA (OK)
    SCSCF-->>PCSCF: 200 OK
    PCSCF-->>UE1: 200 OK ✅ Registered

    Note over UE1,UE2: VoNR Call Phase

    UE1->>PCSCF: SIP INVITE sip:9076543211@ims...
    PCSCF->>ICSCF: SIP INVITE
    ICSCF->>HSS: Diameter LIR (Location Info Request)
    HSS-->>ICSCF: Diameter LIA (S-CSCF address)
    ICSCF->>SCSCF: SIP INVITE
    SCSCF->>PCSCF: SIP INVITE (to UE2)
    PCSCF->>UE2: SIP INVITE
    UE2-->>PCSCF: 180 Ringing
    PCSCF-->>SCSCF: 180 Ringing
    SCSCF-->>UE1: 180 Ringing 🔔
    UE2-->>PCSCF: 200 OK (answer)
    PCSCF-->>UE1: 200 OK
    UE1->>UE2: SIP ACK
    Note over UE1,UE2: RTP Audio Stream (Opus) ✅
    UE1->>PCSCF: SIP BYE
    PCSCF->>UE2: SIP BYE
    UE2-->>UE1: 200 OK
    Note over UE1,UE2: Call ended cleanly ✅
```

---

## QoS Flow Architecture

```mermaid
graph LR
    subgraph UE["UE Container"]
        TUN1["tun_srsue\n192.168.101.2\n(IMS APN)"]
    end

    subgraph UPF["UPF"]
        OGSTUN2["ogstun2\n192.168.101.1/24\nQFI=1 GBR\n(Voice bearer)"]
        OGSTUN["ogstun\n192.168.100.1/24\nQFI=9 Non-GBR\n(Internet)"]
    end

    subgraph IMS["IMS Layer"]
        PCSCF2["P-CSCF\n172.22.0.21"]
        RTPE["RTPEngine\n172.22.0.16"]
    end

    TUN1 <-->|"GTP-U tunnel\nQFI=1 (voice)\nGBR: 128/128 kbps\nARP priority: 2"| OGSTUN2
    OGSTUN2 <-->|"SIP signaling"| PCSCF2
    OGSTUN2 <-->|"RTP audio\nOpus codec\n50 pps / 20ms"| RTPE

    style OGSTUN2 fill:#e8f5e9,stroke:#388e3c
    style OGSTUN fill:#fff3e0,stroke:#f57c00
    style TUN1 fill:#e3f2fd,stroke:#1976d2
```

---

## Container Network Map

```mermaid
graph TB
    subgraph NET["Docker Network: 172.22.0.0/24"]
        direction TB
        subgraph ROW1["RAN"]
            GNB2["srsgnb_zmq\n172.22.0.37"]
            UEC["srsue_5g_zmq\n172.22.0.34"]
        end
        subgraph ROW2["5G Core"]
            AMF2["amf\n172.22.0.10"]
            SMF2["smf\n172.22.0.7"]
            UPF2["upf\n172.22.0.8"]
            NRF2["nrf\n172.22.0.12"]
            UDM2["udm\n172.22.0.13"]
            AUSF2["ausf\n172.22.0.11"]
            PCF2["pcf\n172.22.0.27"]
        end
        subgraph ROW3["IMS"]
            PCSCF2["pcscf\n172.22.0.21"]
            ICSCF2["icscf\n172.22.0.19"]
            SCSCF2["scscf\n172.22.0.20"]
        end
        subgraph ROW4["Backend"]
            PYHSS2["pyhss\n172.22.0.18"]
            MYSQL2["mysql\n172.22.0.17"]
            RTPE2["rtpengine\n172.22.0.16"]
            MONGO2["mongo\n172.22.0.2"]
            DNS2["dns\n172.22.0.15"]
        end
    end

    GNB2 --> AMF2
    GNB2 --> UPF2
    AMF2 --> UDM2
    SMF2 --> UPF2
    PCSCF2 --> ICSCF2 --> SCSCF2
    ICSCF2 --> PYHSS2
    SCSCF2 --> PYHSS2
    PYHSS2 --- MYSQL2
    SCSCF2 --> RTPE2
    UEC --> PCSCF2
```

---

## Measured Performance

```mermaid
xychart-beta
    title "RTP Stream Quality Metrics"
    x-axis ["Min Jitter", "Mean Jitter", "Max Jitter"]
    y-axis "Milliseconds (ms)" 0 --> 50
    bar [0.59, 9.20, 10.52]
    line [0.59, 9.20, 10.52]
```

| Metric | Measured | 3GPP Limit | Status |
|--------|----------|------------|--------|
| Packet Loss | 0.0% | < 1% | ✅ Pass |
| Mean Jitter | 9.2 ms | < 50 ms | ✅ Pass |
| Max Jitter | 10.5 ms | < 50 ms | ✅ Pass |
| MOS Score | 3.58 | > 3.5 | ✅ Pass |
| Registration | 318 ms | < 500 ms | ✅ Pass |
| Teardown | 10 ms | < 500 ms | ✅ Pass |
| Codec | Opus | AMR-WB | ✅ Good |
