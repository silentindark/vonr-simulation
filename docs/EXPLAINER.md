# Understanding VoNR — A Beginner's Guide

> **Who is this for?** Anyone who wants to understand what VoNR is, why it matters, and how this project works — even if you have never studied networking before.

---

## Table of Contents

- [What Problem Are We Solving?](#what-problem-are-we-solving)
- [Key Definitions](#key-definitions)
- [How a Phone Call Works (The Simple Version)](#how-a-phone-call-works-the-simple-version)
- [What is 5G?](#what-is-5g)
- [What is VoNR?](#what-is-vonr)
- [The Building Blocks of This Project](#the-building-blocks-of-this-project)
- [How the Components Talk to Each Other](#how-the-components-talk-to-each-other)
- [Step-by-Step: What Happens During a VoNR Call](#step-by-step-what-happens-during-a-vonr-call)
- [Why We Used Software Instead of Real Hardware](#why-we-used-software-instead-of-real-hardware)
- [What the Results Mean](#what-the-results-mean)
- [Glossary](#glossary)

---

## What Problem Are We Solving?

Imagine you are calling a friend. You pick up your phone, dial their number, and within a few seconds you are talking to them. Simple, right?

Behind the scenes, something incredibly complex is happening. Your voice is being converted into tiny pieces of digital data, those pieces are being sent wirelessly through the air at the speed of light, bounced through multiple computers across the country, and reassembled at your friend's phone — all in real time, with no noticeable delay.

Now imagine doing all of that over a **5G network**, the newest and fastest wireless technology available. That is exactly what **VoNR** (Voice over New Radio) is.

This project builds a complete VoNR system from scratch using free, open-source software — no expensive phone towers, no physical SIM cards, no carrier subscription needed. We simulate the entire system on a single computer.

---

## Key Definitions

Before we go further, here are the most important terms explained in plain language:

### Network
A **network** is a collection of devices that can communicate with each other. Your home Wi-Fi is a network. The internet is a very large network of networks.

### Protocol
A **protocol** is an agreed set of rules for how two devices communicate. Think of it like a language — if two people both speak English, they can understand each other. If two computers both use the same protocol, they can exchange information.

### IP (Internet Protocol)
**IP** is the fundamental protocol of the internet. Every device on the internet has an **IP address** — a unique number (like `192.168.1.1`) that identifies it, similar to a postal address for your house.

### Packet
Instead of sending one large chunk of data, computers break information into small pieces called **packets**. Each packet travels independently through the network and is reassembled at the destination. This is more efficient and reliable than sending everything at once.

### 4G LTE
**4G LTE** (Long Term Evolution) is the fourth generation of wireless mobile communication technology. It is what most smartphones used before 5G. It is fast enough for streaming video and making phone calls.

### 5G (Fifth Generation)
**5G** is the latest generation of wireless technology. It is:
- **Faster** — up to 100x faster than 4G
- **Lower latency** — responses happen almost instantly (as low as 1ms delay)
- **More capacity** — can handle millions of devices in a small area

### NR (New Radio)
**NR** stands for New Radio — the specific radio technology used by 5G. It defines how data is transmitted over the air between your phone and the base station (the antenna tower).

### VoLTE (Voice over LTE)
**VoLTE** is how phone calls work over 4G LTE networks. Instead of using old circuit-switched technology (like traditional landline calls), voice is converted into data packets and sent over the internet-like 4G data connection.

### VoNR (Voice over New Radio)
**VoNR** is the 5G version of VoLTE. Phone calls are made directly over the 5G NR air interface using the 5G Core network. It offers better quality, lower delay, and faster call setup than VoLTE.

### Base Station (gNB)
A **base station** (called **gNB** in 5G — "g" for next generation, "NB" for NodeB) is the antenna tower that your phone connects to wirelessly. It acts as the gateway between your phone and the rest of the network.

### UE (User Equipment)
**UE** is the technical term for your phone or any device that connects to the mobile network. In our project, we simulate a UE using software called **srsRAN**.

### Core Network (5GC)
The **5G Core (5GC)** is the set of computers and software that manage everything behind the base station — who you are, what services you can use, how your data is routed, and how billing works.

### IMS (IP Multimedia Subsystem)
**IMS** is a framework for delivering voice calls and video calls over IP (internet) networks. It is the engine that makes VoLTE and VoNR possible. It handles:
- Registering your phone so the network knows where you are
- Routing calls to the right person
- Setting up the audio/video connection

### SIP (Session Initiation Protocol)
**SIP** is the protocol used by IMS to set up, manage, and end phone calls. Think of it like the "dialing" part of a phone call — it signals the other person's phone to ring, negotiates how the call will work, and ends the call when you hang up. SIP does NOT carry the actual voice — it only manages the session.

### RTP (Real-time Transport Protocol)
**RTP** is the protocol that actually carries the voice (or video) data during a call. Once SIP has set up the call, RTP streams the audio packets back and forth between the two phones in real time.

### Codec
A **codec** (coder-decoder) is software that compresses and decompresses audio. During a call, your voice is recorded, compressed by a codec, sent as packets, received by the other phone, decompressed, and played back. We use the **Opus** codec — the same one used by WhatsApp, Zoom, and Discord because it is high quality and very efficient.

### QoS (Quality of Service)
**QoS** is a mechanism that prioritises certain types of network traffic over others. Voice calls need to be prioritised over regular web browsing because even a tiny delay or packet loss in a voice call makes it sound choppy and broken.

### QFI (QoS Flow Identifier)
A **QFI** is a number that labels a packet so the network knows how to treat it. In our project:
- **QFI = 1** → Voice traffic (highest priority, guaranteed delivery speed)
- **QFI = 9** → Regular internet traffic (best effort, lower priority)

### Jitter
**Jitter** is the variation in delay between packets arriving. If packet 1 arrives 20ms after it was sent, and packet 2 arrives 35ms after it was sent, the jitter is 15ms. High jitter makes voice calls sound choppy. The 3GPP standard requires jitter to be below 50ms for acceptable voice quality.

### MOS (Mean Opinion Score)
**MOS** is a score from 1 to 5 that measures voice call quality based on human perception:
- 5 = Excellent (like talking in person)
- 4 = Good (normal telephone quality)
- **3.5 = Minimum acceptable** (our result: 3.58 ✅)
- Below 3 = Poor quality

### Packet Loss
**Packet loss** is when packets sent over the network never arrive at the destination. In a voice call, lost packets cause gaps in the audio. Our result: **0% packet loss** ✅

### Latency
**Latency** (also called delay or ping) is the time it takes for a packet to travel from sender to receiver. In voice calls, high latency makes conversations feel like talking on a walkie-talkie — you finish speaking before the other person hears you.

### Docker
**Docker** is a tool that lets you run software in isolated "containers" — like mini-computers inside your computer. Each component of our system (the 5G core, the IMS, the database) runs in its own Docker container. This makes the system easy to set up and reproduce on any machine.

### ZMQ (ZeroMQ)
**ZMQ** is a messaging library. In our project, it replaces the actual radio signal between the phone and the base station. Instead of transmitting real radio waves, the UE and gNB send data through ZMQ sockets over the network. This gives us a realistic simulation without any physical hardware.

---

## How a Phone Call Works (The Simple Version)

```
You speak → Microphone converts voice to digital data
         → Codec compresses the data
         → SIP signals the other person's phone to ring
         → Other person answers → SIP confirms connection
         → RTP streams audio data back and forth in real time
         → Codec decompresses data on the other end
         → Speaker plays the audio
         → You hang up → SIP ends the session
```

The key insight is that **modern phone calls are just internet data**, treated with special priority to ensure quality.

---

## What is 5G?

Think of mobile networks like generations of roads:

| Generation | Era | Speed | Analogy |
|---|---|---|---|
| 1G | 1980s | Voice only | Dirt road — only horses |
| 2G | 1990s | Voice + SMS | Paved road — cars and bikes |
| 3G | 2000s | Basic internet | Highway — cars at moderate speed |
| 4G LTE | 2010s | Fast internet, VoLTE | Motorway — fast cars |
| **5G** | **2020s** | **Ultra-fast, ultra-low latency** | **High-speed rail — extremely fast, dedicated lanes** |

5G introduces two important architectural changes:

**1. Standalone (SA) mode** — 5G with its own completely new core network (5GC). This is what our project uses. It is like building a brand new railway system from scratch.

**2. Non-Standalone (NSA) mode** — 5G radio but still using the old 4G core network. Like putting a high-speed train on old tracks — faster, but limited.

VoNR requires **Standalone 5G** because it needs the new 5G Core to manage voice quality properly.

---

## What is VoNR?

VoNR = Voice + 5G New Radio

It is the answer to the question: *"How do we make phone calls natively on 5G?"*

### VoLTE vs VoNR — What Changed?

| Aspect | VoLTE (4G) | VoNR (5G) |
|---|---|---|
| Core Network | EPC (4G Core) | 5GC (5G Core) |
| Call Setup Speed | ~1-2 seconds | ~0.3-0.5 seconds |
| Voice Quality | HD Voice | HD Voice + better codecs |
| Latency | ~50ms | ~10ms |
| Architecture | Bearer-based | QoS Flow-based |
| IMS | Same IMS | Same IMS |

The good news: **IMS stays the same**. The part that changes is the underlying network — from 4G Core to 5G Core.

---

## The Building Blocks of This Project

Our project has 6 main components. Here is what each one does in plain language:

### 1. srsRAN UE — The Simulated Phone
**What it is:** Software that pretends to be a 5G smartphone.

**What it does:** It connects to the simulated base station, registers with the network, and establishes a data connection. It is like the "phone" in our system, but running as a program on a computer.

**Real world equivalent:** Your iPhone or Android phone with a 5G SIM card.

---

### 2. srsRAN gNB — The Simulated Base Station
**What it is:** Software that pretends to be a 5G cell tower.

**What it does:** It receives the "signal" from the UE (over ZMQ instead of real radio waves) and forwards data to the 5G Core network.

**Real world equivalent:** The 5G antenna tower you see on rooftops and street corners.

---

### 3. Open5GS — The 5G Core Network
**What it is:** An open-source implementation of the entire 5G Core network.

**What it does:** It manages everything about who you are and what you are allowed to do:
- **AMF** — Knows where your phone is and manages your connection (like a post office that tracks your current address)
- **SMF** — Sets up data sessions and assigns you an IP address (like a receptionist who gives you a desk)
- **UPF** — Routes your actual data packets (like the mail carrier who delivers your letters)
- **UDM/UDR** — Stores your subscriber information (like the membership database)
- **AUSF** — Verifies your identity (like the bouncer checking your ID)
- **NRF** — Acts as a directory so components can find each other (like a phonebook for network functions)
- **PCF** — Sets quality rules for your traffic (like a traffic controller)

**Real world equivalent:** All the computers inside a mobile carrier's data centre (Airtel, Jio, Vodafone, etc.)

---

### 4. Kamailio IMS — The Voice Call Engine
**What it is:** An open-source SIP server that implements IMS.

**What it does:** Handles everything related to making and receiving voice calls:

- **P-CSCF (Proxy-CSCF)** — The first point of contact for your phone when it wants to make a call. Think of it as the front desk receptionist. Your phone registers here first.

- **I-CSCF (Interrogating-CSCF)** — When a call comes in for you, this component asks the database "which server is this person registered on?" and routes the call there. Think of it as the operator who looks up your extension.

- **S-CSCF (Serving-CSCF)** — The main IMS server that actually handles your registration, authenticates you, and routes your calls. Think of it as your personal call manager.

**Real world equivalent:** The voice call infrastructure inside a carrier like Jio or Airtel.

---

### 5. pyHSS — The Subscriber Database for IMS
**What it is:** An open-source Home Subscriber Server.

**What it does:** Stores all the information about IMS subscribers — their phone numbers, authentication keys, which server they are registered on, and what services they are allowed to use. When the I-CSCF or S-CSCF needs to know something about a user, they ask pyHSS using a protocol called **Diameter**.

**Real world equivalent:** The database at your carrier that holds your account information, phone number, and authentication credentials.

---

### 6. RTPEngine — The Voice Traffic Manager
**What it is:** A media proxy for RTP streams.

**What it does:** Sits in the middle of a voice call and relays the audio packets between the two phones. This helps with:
- Routing audio through the correct network path
- Handling different audio formats if needed
- Collecting quality statistics (jitter, packet loss)

**Real world equivalent:** A telephone exchange that routes audio between callers.

---

## How the Components Talk to Each Other

Each component uses a specific protocol to talk to others. Here is a simplified view:

```
Your Phone (UE)
     |
     | [Air interface → ZMQ in our simulation]
     |
Base Station (gNB)
     |
     | [N2 interface → NGAP protocol] ──────────────► AMF (registers UE)
     | [N3 interface → GTP-U protocol] ─────────────► UPF (routes data)
     |
UPF (User Plane Function)
     |
     | [Routes IMS traffic to IMS network]
     |
P-CSCF (first IMS contact)
     |
     | [SIP protocol]
     |
I-CSCF ──── [Diameter protocol] ───► pyHSS (asks: where is this user?)
     |
     | [SIP protocol]
     |
S-CSCF ──── [Diameter protocol] ───► pyHSS (asks: authenticate this user)
     |
     | [SIP protocol, back to phone]
     |
Your Phone ←──── [RTP protocol] ────► Other Phone
                  (actual voice audio)
```

---

## Step-by-Step: What Happens During a VoNR Call

Let us trace exactly what happens when UE1 (phone 9076543210) calls UE2 (phone 9076543211).

### Phase 1: The Phone Connects to 5G (Registration)

1. **srsRAN UE** sends a registration request wirelessly (via ZMQ) to **srsRAN gNB**
2. **gNB** forwards it to **AMF** in the 5G Core
3. **AMF** talks to **AUSF** and **UDM** to verify the phone's identity (like checking a password)
4. **AMF** assigns the phone to the network and confirms registration
5. **SMF** sets up a data connection (PDU session) for the IMS service and assigns the UE an IP address (`192.168.101.2`)
6. The UE now has a 5G internet connection on the IMS network

### Phase 2: The Phone Registers with IMS (SIP Registration)

7. **linphonec** (the SIP client software on UE1) sends a `SIP REGISTER` message to **P-CSCF**
8. P-CSCF forwards it to **I-CSCF**
9. I-CSCF asks **pyHSS** via Diameter: *"Is this user allowed? Which server should serve them?"*
10. pyHSS replies: *"Yes, use S-CSCF at this address"*
11. I-CSCF forwards to **S-CSCF**
12. S-CSCF asks pyHSS for authentication data
13. S-CSCF challenges the phone: *"Prove who you are"* (sends a `401 Unauthorized`)
14. linphonec responds with a cryptographic proof (like a signed password)
15. S-CSCF verifies it and tells pyHSS: *"This user is registered on me"*
16. S-CSCF sends back `200 OK` → **UE1 is now registered on IMS** ✅

### Phase 3: Making the Call (SIP INVITE)

17. UE1's linphonec sends `SIP INVITE sip:9076543211@ims...` to P-CSCF
18. P-CSCF forwards to I-CSCF
19. I-CSCF asks pyHSS: *"Where is 9076543211 registered?"*
20. pyHSS responds with S-CSCF address
21. I-CSCF forwards INVITE to S-CSCF
22. S-CSCF routes INVITE to UE2's P-CSCF → UE2's phone

### Phase 4: The Phone Rings

23. UE2 receives the INVITE and sends back `180 Ringing`
24. This travels back through S-CSCF → I-CSCF → P-CSCF → UE1
25. UE1 hears the ringing tone 🔔

### Phase 5: Call Connected

26. UE2 answers → sends `200 OK`
27. UE1 sends `ACK` to confirm
28. **RTP audio stream begins** — voice packets flow directly between UE1 and UE2 via RTPEngine
29. The codec (Opus) compresses voice at both ends, sends 50 packets per second, each 20ms of audio

### Phase 6: Hanging Up

30. UE1 hangs up → sends `SIP BYE`
31. BYE travels through the IMS chain to UE2
32. UE2 sends `200 OK`
33. RTP stream stops
34. **Call ended cleanly** ✅

---

## Why We Used Software Instead of Real Hardware

Real 5G hardware is expensive and requires regulatory approval to transmit radio signals. Here is a comparison:

| Approach | Cost | Setup Time | Realism | Our Choice |
|---|---|---|---|---|
| Real 5G tower + phones | $50,000+ | Months | 100% real | ❌ |
| SDR radio (USRP B210) | $1,500 | Days | High | Future phase |
| ZMQ simulation (this project) | $0 | Hours | Medium-High | ✅ |
| Fully abstract (UERANSIM) | $0 | Hours | Medium | Alternative |

**ZMQ simulation** gives us:
- The **exact same protocol stack** as real hardware (SIP, RTP, GTP, Diameter all work identically)
- **Realistic L1/L2/L3 layers** — srsRAN simulates the physical and MAC layers properly
- **Zero cost** — runs on any Ubuntu laptop or server
- **Reproducibility** — anyone can recreate the exact same experiment

The only thing missing is actual radio wave propagation — but for testing the voice call stack (which is what VoNR is about), this does not matter.

---

## What the Results Mean

After running a real VoNR call and capturing the traffic, we measured:

### Packet Loss: 0.0%
Every single voice packet arrived at the destination. In a real network, even 1% loss starts to make calls sound broken. **0% means perfect delivery.**

### Jitter: 9.2ms average
Packets arrived with very consistent timing — only 9.2 milliseconds of variation on average. The 3GPP standard allows up to 50ms. **Our result is 5× better than required.**

### MOS Score: 3.58
This is like a restaurant review for voice quality. Anything above 3.5 is considered acceptable. A score of 3.58 falls in the **"Good"** category — similar to what you would experience on a normal phone call.

### Why is Call Setup 16 Seconds?
This is the one metric that is higher than ideal. In a real 5G network, calls connect in under 1 second. Our 16-second delay is caused by the software SIP client (linphonec) spending time negotiating ICE/STUN (network traversal protocols) which are not needed in a controlled lab environment. Disabling ICE reduces this to ~2 seconds, much closer to the real target.

---

## Glossary

A complete reference of all technical terms used in this project, alphabetically ordered.

| Term | Full Form | Simple Definition |
|---|---|---|
| 5GC | 5G Core | The brain of the 5G network — manages users, sessions, and routing |
| 5QI | 5G QoS Identifier | A number (like 1 or 9) that tells the network how important a packet is |
| AMF | Access and Mobility Management Function | Tracks where your phone is and manages its connection to the network |
| APN | Access Point Name | The name of the network gateway your phone connects to (e.g., "ims" or "internet") |
| ARP | Allocation and Retention Priority | A priority level (1-15) that decides which connections get dropped first if the network is congested |
| AUSF | Authentication Server Function | Verifies your identity — like a bouncer checking your ID |
| BSF | Binding Support Function | Helps PCF track which session belongs to which subscriber |
| CSCF | Call Session Control Function | The general name for IMS servers (P, I, and S variants) |
| Codec | Coder-Decoder | Software that compresses and decompresses audio/video |
| Cx | — | The Diameter interface between IMS and the HSS |
| Diameter | — | A protocol used for authentication and subscriber data exchange between network functions |
| DNN | Data Network Name | The 5G equivalent of APN — names the network a PDU session connects to |
| Docker | — | A tool for running software in isolated containers (mini-computers inside your computer) |
| EPC | Evolved Packet Core | The old 4G core network (replaced by 5GC in standalone 5G) |
| GBR | Guaranteed Bit Rate | A QoS type where the network guarantees a minimum speed for your data |
| gNB | Next Generation NodeB | The technical name for a 5G base station (cell tower) |
| GTP | GPRS Tunneling Protocol | The protocol used to carry user data between the base station and the UPF |
| HSS | Home Subscriber Server | The database that stores all subscriber information in IMS |
| I-CSCF | Interrogating-CSCF | The IMS server that queries the HSS to find where a user is registered |
| IMS | IP Multimedia Subsystem | The framework that enables voice and video calls over IP networks |
| IP | Internet Protocol | The fundamental addressing system of the internet |
| Jitter | — | Variation in delay between packets arriving — high jitter causes choppy audio |
| Latency | — | The time delay for a packet to travel from sender to receiver |
| MCC | Mobile Country Code | A 3-digit code identifying a country (e.g., 001 = test network, 404 = India) |
| MNC | Mobile Network Code | A 2-3 digit code identifying a mobile network within a country |
| MOS | Mean Opinion Score | A 1-5 score measuring voice call quality |
| MSISDN | Mobile Station ISDN Number | Your phone number in international format |
| N2 | — | The interface between gNB and AMF (carries control signaling) |
| N3 | — | The interface between gNB and UPF (carries user data) |
| N4 | — | The interface between SMF and UPF (carries session rules) |
| NAT | Network Address Translation | A technique that lets multiple devices share one public IP address |
| NF | Network Function | Any software component in the 5G Core (AMF, SMF, UPF, etc.) |
| NGAP | Next Generation Application Protocol | The protocol used on the N2 interface between gNB and AMF |
| NRF | Network Repository Function | A directory that lets network functions discover and register with each other |
| NSSF | Network Slice Selection Function | Selects the right network slice for a subscriber |
| OPC | Operator Code | A derived key used with Ki for authentication |
| Opus | — | A modern audio codec used by WhatsApp, Zoom, Discord, and our VoNR call |
| P-CSCF | Proxy-CSCF | The first IMS contact point for a UE — acts as a proxy for all SIP messages |
| Packet | — | A small chunk of data sent over a network |
| PCF | Policy Control Function | Defines QoS rules for data sessions |
| PCO | Protocol Configuration Options | Extra configuration information sent during PDU session setup (e.g., P-CSCF address) |
| PDU Session | Protocol Data Unit Session | A data connection between the UE and a specific network (like the IMS network) |
| PFCP | Packet Forwarding Control Protocol | The protocol between SMF and UPF for managing how packets are forwarded |
| Protocol | — | An agreed set of rules for how two systems communicate |
| pyHSS | Python Home Subscriber Server | An open-source IMS HSS implementation written in Python |
| QFI | QoS Flow Identifier | A number that labels packets so the network knows how to prioritise them |
| QoS | Quality of Service | Mechanisms that prioritise important traffic (like voice calls) over less important traffic |
| RF | Radio Frequency | The electromagnetic waves used to transmit data wirelessly |
| RTP | Real-time Transport Protocol | The protocol that carries actual audio/video data during a call |
| RTCP | RTP Control Protocol | A companion to RTP that reports statistics (jitter, loss) about the stream |
| RTPEngine | — | Software that relays RTP streams between callers |
| S-CSCF | Serving-CSCF | The main IMS server that authenticates users and routes calls |
| SA | Standalone | 5G mode using a complete 5G Core — required for VoNR |
| SBI | Service-Based Interface | The API-based interface used by 5GC network functions to communicate |
| SDR | Software Defined Radio | Hardware that can simulate a radio using software (e.g., USRP B210) |
| SIM | Subscriber Identity Module | The card in your phone that stores your identity and authentication keys |
| SIP | Session Initiation Protocol | The protocol used to set up, manage, and end VoIP calls |
| SMF | Session Management Function | Sets up and manages data sessions, assigns IP addresses |
| SSRC | Synchronization Source | A unique ID for each RTP stream |
| Subnet | — | A portion of a network with a specific IP address range |
| TCP | Transmission Control Protocol | A reliable protocol that guarantees packet delivery (used for web browsing) |
| UDM | Unified Data Management | Stores subscriber data in the 5G Core |
| UDR | Unified Data Repository | The database layer behind UDM |
| UE | User Equipment | Technical term for any device that connects to a mobile network (your phone) |
| UDP | User Datagram Protocol | A fast but unreliable protocol (used for voice/video calls — speed matters more than guaranteed delivery) |
| UPF | User Plane Function | Routes actual user data packets through the 5G Core |
| VoIP | Voice over IP | Making phone calls over the internet |
| VoLTE | Voice over LTE | Phone calls over 4G using IMS |
| VoNR | Voice over New Radio | Phone calls over 5G using IMS — what this project implements |
| WebUI | Web User Interface | The browser-based dashboard for managing Open5GS subscribers |
| ZMQ | ZeroMQ | A messaging library used to simulate the radio link between UE and gNB |
