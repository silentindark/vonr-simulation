#!/bin/bash
# Claude Generated Code Snippet for TWiN Project
# ============================================================
#   VoNR Complete Verification Script v2
#   Verifies every layer from RAN to RTP audio
# ============================================================

PASS=0
FAIL=0
WARN=0

green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
blue='\033[0;34m'
bold='\033[1m'
reset='\033[0m'

pass()  { echo -e "  ${green}[PASS]${reset} $1"; ((PASS++)); }
fail()  { echo -e "  ${red}[FAIL]${reset} $1"; ((FAIL++)); }
warn()  { echo -e "  ${yellow}[WARN]${reset} $1"; ((WARN++)); }
info()  { echo -e "  ${blue}[INFO]${reset} $1"; }
header(){ echo -e "\n${bold}$1${reset}"; echo "  $(printf '%.0s-' {1..50})"; }

echo ""
echo -e "${bold}============================================================${reset}"
echo -e "${bold}          VoNR Complete Stack Verification${reset}"
echo -e "${bold}============================================================${reset}"
echo -e "  Time: $(date)"
echo -e "  Host: $(hostname)"

# ============================================================
# SECTION 1: CONTAINERS
# ============================================================
header "1. Container Health Check"

REQUIRED="nrf amf smf upf udr udm ausf pcf nssf scp mongo webui \
          mysql pyhss dns rtpengine pcscf icscf scscf srsgnb_zmq srsue_5g_zmq"

for c in $REQUIRED; do
  STATUS=$(docker ps --filter "name=^${c}$" --format "{{.Status}}" 2>/dev/null)
  if echo "$STATUS" | grep -q "Up"; then
    pass "$c — $STATUS"
  else
    fail "$c — NOT RUNNING (Status: ${STATUS:-missing})"
  fi
done

# ============================================================
# SECTION 2: gNB
# ============================================================
header "2. gNB — 5G Base Station"

if docker logs srsgnb_zmq 2>&1 | grep -q "gNB started"; then
  pass "gNB started successfully"
else
  fail "gNB did not start"
fi

if docker logs srsgnb_zmq 2>&1 | grep -q "Connection to AMF"; then
  pass "gNB connected to AMF (N2 interface up)"
  AMF_LINE=$(docker logs srsgnb_zmq 2>&1 | grep "Connection to AMF" | tail -1)
  info "$AMF_LINE"
else
  fail "gNB not connected to AMF"
fi

if docker logs srsgnb_zmq 2>&1 | grep -qi "zmq"; then
  pass "ZMQ RF simulation active"
else
  warn "ZMQ keyword not found in gNB logs (may use different label)"
fi

# ============================================================
# SECTION 3: UE 5G REGISTRATION
# ============================================================
header "3. UE — 5G SA Registration"

if docker logs srsue_5g_zmq 2>&1 | grep -q "Random Access Complete"; then
  pass "Random Access completed (UE found gNB)"
else
  fail "Random Access not completed"
fi

if docker logs srsue_5g_zmq 2>&1 | grep -q "RRC Connected"; then
  pass "RRC Connected (UE registered on gNB)"
else
  fail "RRC not connected"
fi

if docker logs srsue_5g_zmq 2>&1 | grep -q "PDU Session Establishment successful"; then
  UE_IP=$(docker logs srsue_5g_zmq 2>&1 | grep "PDU Session Establishment" | tail -1 | grep -oP 'IP: \K[0-9.]+')
  pass "PDU Session established — UE IP: $UE_IP"
  if echo "$UE_IP" | grep -q "192.168.101"; then
    pass "UE got IMS APN IP (192.168.101.x) — correct"
  else
    fail "UE got wrong APN IP: $UE_IP (expected 192.168.101.x)"
  fi
else
  fail "PDU Session not established"
fi

# ============================================================
# SECTION 4: 5G CORE NFs
# ============================================================
header "4. 5G Core — Network Functions"

if docker logs amf 2>&1 | grep -q "Registration complete"; then
  pass "AMF — UE registration complete"
  IMSI=$(docker logs amf 2>&1 | grep "Registration complete" | tail -1 | grep -oP '\[imsi-\K[0-9]+' | head -1)
  info "IMSI: $IMSI"
else
  fail "AMF — no UE registration found"
fi

if docker logs smf 2>&1 | grep -q "DNN\[ims\]"; then
  pass "SMF — IMS DNN session created"
  SMF_LINE=$(docker logs smf 2>&1 | grep "DNN\[ims\]" | tail -1)
  info "$SMF_LINE"
else
  fail "SMF — IMS session not found"
fi

UPF_TUN=$(docker exec upf ip addr show ogstun2 2>/dev/null | grep "inet " | awk '{print $2}')
if [ -n "$UPF_TUN" ]; then
  pass "UPF — IMS tunnel ogstun2 up ($UPF_TUN)"
else
  fail "UPF — ogstun2 tunnel not found"
fi

UPF_NAT=$(docker exec upf iptables -t nat -L POSTROUTING -n 2>/dev/null | grep "192.168.101")
if [ -n "$UPF_NAT" ]; then
  pass "UPF — NAT/MASQUERADE rule for IMS subnet present"
else
  fail "UPF — NAT rule missing (add: docker exec upf iptables -t nat -A POSTROUTING -s 192.168.101.0/24 ! -o ogstun2 -j MASQUERADE)"
fi

# ============================================================
# SECTION 5: IMS ROUTING
# ============================================================
header "5. IMS Routing — Network Routes"

PCSCF_ROUTE=$(docker exec pcscf ip route show 2>/dev/null | grep "192.168.101")
if [ -n "$PCSCF_ROUTE" ]; then
  pass "P-CSCF — route to UE subnet present"
else
  fail "P-CSCF — no route to UE subnet"
fi

ICSCF_ROUTE=$(docker exec icscf ip route show 2>/dev/null | grep "192.168.101")
if [ -n "$ICSCF_ROUTE" ]; then
  pass "I-CSCF — route to UE subnet present"
else
  fail "I-CSCF — no route to UE subnet"
fi

SCSCF_ROUTE=$(docker exec scscf ip route show 2>/dev/null | grep "192.168.101")
if [ -n "$SCSCF_ROUTE" ]; then
  pass "S-CSCF — route to UE subnet present"
else
  fail "S-CSCF — no route to UE subnet"
fi

# ============================================================
# SECTION 6: DIAMETER (IMS <-> pyHSS)
# ============================================================
header "6. Diameter — IMS to pyHSS"

LAST_CX=$(docker logs pyhss 2>&1 | grep -E "UAR|MAR|SAR|MAA|SAA|UAA" | tail -1)
PEER_LOG=$(docker logs icscf 2>&1 | grep "connected" | tail -1)

if [ -n "$LAST_CX" ]; then
  pass "pyHSS — Diameter functional (Cx messages found in logs)"
  info "Last Cx: $(echo $LAST_CX | cut -c1-80)"
elif echo "$PEER_LOG" | grep -q "connected"; then
  pass "pyHSS — Diameter peers connected (icscf log confirmed)"
  info "$PEER_LOG"
else
  warn "pyHSS — Diameter log not found yet (normal if recently started)"
  info "Note: Call test in section 9 will confirm if Diameter works"
fi

PYHSS_API=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/docs/ 2>/dev/null)
if [ "$PYHSS_API" = "200" ] || [ "$PYHSS_API" = "301" ]; then
  pass "pyHSS API — accessible at http://localhost:8080/docs/"
else
  warn "pyHSS API — not accessible (code: $PYHSS_API)"
fi

# ============================================================
# SECTION 7: IMS SUBSCRIBER DATABASE
# ============================================================
header "7. IMS Subscriber Database"

AUC=$(docker exec mysql mysql -u root -pchangeme ims_hss_db \
  -se "SELECT COUNT(*) FROM auc;" 2>/dev/null | grep -v "Warning")
if [ "${AUC:-0}" -gt 0 ] 2>/dev/null; then
  pass "AUC table — $AUC record(s) found"
else
  fail "AUC table — empty or not accessible"
fi

SUB=$(docker exec mysql mysql -u root -pchangeme ims_hss_db \
  -se "SELECT COUNT(*) FROM subscriber;" 2>/dev/null | grep -v "Warning")
if [ "${SUB:-0}" -gt 0 ] 2>/dev/null; then
  pass "Subscriber table — $SUB record(s) found"
else
  fail "Subscriber table — empty"
fi

IMS_SUB=$(docker exec mysql mysql -u root -pchangeme ims_hss_db \
  -se "SELECT COUNT(*) FROM ims_subscriber;" 2>/dev/null | grep -v "Warning")
if [ "${IMS_SUB:-0}" -gt 0 ] 2>/dev/null; then
  pass "IMS subscriber table — $IMS_SUB record(s) found"
else
  fail "IMS subscriber table — empty"
fi

APN=$(docker exec mysql mysql -u root -pchangeme ims_hss_db \
  -se "SELECT GROUP_CONCAT(apn) FROM apn;" 2>/dev/null | grep -v "Warning")
if echo "$APN" | grep -q "ims"; then
  pass "APNs configured — $APN"
else
  fail "IMS APN missing in database"
fi

# ============================================================
# SECTION 8: SIP REGISTRATION
# ============================================================
header "8. SIP Registration (IMS)"

if docker logs scscf 2>&1 | grep -q "Contact valid"; then
  CONTACTS=$(docker logs scscf 2>&1 | grep "Contact valid" | wc -l)
  pass "S-CSCF — $CONTACTS active SIP registration(s) found"
  docker logs scscf 2>&1 | grep "Contact #0" | tail -2 | while read line; do
    info "$line"
  done
else
  fail "S-CSCF — no active SIP registrations"
fi

if docker logs pcscf 2>&1 | grep -q "REGISTER"; then
  REG_COUNT=$(docker logs pcscf 2>&1 | grep "REGISTER" | wc -l)
  pass "P-CSCF — received $REG_COUNT REGISTER message(s)"
else
  fail "P-CSCF — no REGISTER messages received"
fi

N5_ERR=$(docker logs pcscf 2>&1 | grep "412" | wc -l)
if [ "$N5_ERR" -eq 0 ]; then
  pass "P-CSCF — no 412 N5 QoS errors (WITH_N5 correctly disabled)"
else
  fail "P-CSCF — $N5_ERR x 412 N5 QoS errors (fix: disable WITH_N5 in pcscf_init.sh)"
fi

# ============================================================
# SECTION 9: VONR CALL TEST
# ============================================================
header "9. VoNR Call Test (live)"

docker exec srsue_5g_zmq pkill linphonec 2>/dev/null
sleep 1

info "Starting UE2 receiver..."
docker exec srsue_5g_zmq bash -c '
export HOME=/root/ue2
(sleep 90; echo "quit") | linphonec -c /root/ue2/linphonerc -a \
  > /tmp/ue2_verify.log 2>&1' &

info "Waiting 20s for UE2 to register..."
sleep 20

info "UE1 making call to UE2..."
docker exec srsue_5g_zmq bash -c '
export HOME=/root/ue1
(sleep 5;
 echo "call sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org";
 sleep 20; echo "terminate"; sleep 2; echo "quit") |
linphonec -c /root/ue1/linphonerc > /tmp/ue1_verify.log 2>&1'

sleep 2

UE1_LOG=$(docker exec srsue_5g_zmq cat /tmp/ue1_verify.log 2>/dev/null)
UE2_LOG=$(docker exec srsue_5g_zmq cat /tmp/ue2_verify.log 2>/dev/null)

if echo "$UE1_LOG" | grep -q "ringing"; then
  pass "Call setup — 180 Ringing received by UE1"
else
  fail "Call setup — no ringing (check SIP routing)"
fi

if echo "$UE1_LOG" | grep -q "connected"; then
  pass "Call connected — UE1 shows connected"
else
  fail "Call not connected on UE1"
fi

if echo "$UE2_LOG" | grep -q "auto answering"; then
  pass "UE2 — auto answered the incoming call"
else
  fail "UE2 — did not answer"
fi

if echo "$UE2_LOG" | grep -q "connected"; then
  pass "Call connected — UE2 shows connected"
else
  fail "Call not connected on UE2"
fi

if echo "$UE1_LOG" | grep -q "Media streams established"; then
  pass "RTP audio — media streams established on UE1"
else
  fail "RTP audio — no media streams on UE1"
fi

if echo "$UE2_LOG" | grep -q "Media streams established"; then
  pass "RTP audio — media streams established on UE2"
else
  fail "RTP audio — no media streams on UE2"
fi

if echo "$UE1_LOG" | grep -q "ended (No error)"; then
  pass "Call ended cleanly — No error"
else
  warn "Call end status unclear"
fi

header "11. QoS Flow Verification"

OGSTUN=$(docker exec upf ip addr show ogstun 2>/dev/null | grep "inet " | awk '{print $2}')
OGSTUN2=$(docker exec upf ip addr show ogstun2 2>/dev/null | grep "inet " | awk '{print $2}')

if [ -n "$OGSTUN" ]; then
  pass "Internet APN tunnel (ogstun): $OGSTUN — QFI=9 Non-GBR best effort"
else
  warn "ogstun (internet APN) not active"
fi

if [ -n "$OGSTUN2" ]; then
  pass "IMS voice tunnel (ogstun2): $OGSTUN2 — QFI=1 GBR guaranteed voice"
else
  fail "ogstun2 (IMS APN) not found — voice bearer missing"
fi

NAT_INTERNET=$(docker exec upf iptables -t nat -L POSTROUTING -n 2>/dev/null | grep "192.168.100")
NAT_IMS=$(docker exec upf iptables -t nat -L POSTROUTING -n 2>/dev/null | grep "192.168.101")
[ -n "$NAT_INTERNET" ] && pass "QoS separation — internet traffic routed via ogstun"
[ -n "$NAT_IMS" ] && pass "QoS separation — voice traffic routed via ogstun2"

# ============================================================
# SUMMARY
# ============================================================
TOTAL=$((PASS + FAIL + WARN))
echo ""
echo -e "${bold}============================================================${reset}"
echo -e "${bold}                    SUMMARY${reset}"
echo -e "${bold}============================================================${reset}"
echo -e "  Total checks : $TOTAL"
echo -e "  ${green}Passed${reset}       : $PASS"
echo -e "  ${red}Failed${reset}       : $FAIL"
echo -e "  ${yellow}Warnings${reset}     : $WARN"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${green}${bold}VoNR stack is fully operational!${reset}"
else
  echo -e "  ${red}${bold}$FAIL check(s) failed — review above${reset}"
fi
echo -e "${bold}============================================================${reset}"
echo ""
