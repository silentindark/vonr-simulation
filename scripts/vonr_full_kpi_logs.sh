#!/bin/bash
# Claude Generated Code Snippet for TWiN Project

echo "===  VoNR Full KPI Measurement ==="

# Cleanup old processes
docker exec srsue_5g_zmq pkill tcpdump 2>/dev/null
docker exec srsue_5g_zmq pkill linphonec 2>/dev/null
sleep 2

# Start packet capture (FIXED: run as root)
echo "[INFO] Starting packet capture..."
docker exec -u root srsue_5g_zmq bash -c \
"tcpdump -i any -w /tmp/vonr.pcap port 5060 or udp" &
sleep 3

echo "=== Starting VoNR call ==="

# Start UE2 (receiver)
docker exec srsue_5g_zmq bash -c '
export HOME=/root/ue2
(sleep 120; echo "quit") | linphonec -c /root/ue2/linphonerc -a \
> /tmp/ue2.log 2>&1' &

echo "Waiting for UE2 to register (20s)..."
sleep 20

# Start UE1 (caller)
docker exec srsue_5g_zmq bash -c '
export HOME=/root/ue1
(sleep 5;
 echo "call sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org";
 sleep 20; echo "terminate"; sleep 2; echo "quit") |
linphonec -c /root/ue1/linphonerc > /tmp/ue1.log 2>&1'

# Stop capture
echo "[INFO] Stopping packet capture..."
docker exec srsue_5g_zmq pkill tcpdump
sleep 2

# Copy pcap
docker cp srsue_5g_zmq:/tmp/vonr.pcap ./vonr.pcap

# ================= CALL LOGS =================
echo ""
echo "=== UE1 ==="
docker exec srsue_5g_zmq cat /tmp/ue1.log | \
grep -E "ringing|connected|Media|ended|error"

echo "=== UE2 ==="
docker exec srsue_5g_zmq cat /tmp/ue2.log | \
grep -E "answering|connected|Media|ended|error"

# ================= SIP FLOW =================
echo ""
echo "=============================="
echo " SIP CALL FLOW"
echo "=============================="

tshark -r vonr.pcap -Y sip \
-T fields -e frame.time_relative -e sip.Method -e sip.Status-Code | \
grep -E "INVITE|180|183|200|ACK|BYE"

# ================= CALL SETUP TIME =================
echo ""
echo "---- CALL SETUP TIME ----"

INVITE_TIME=$(tshark -r vonr.pcap \
-Y 'sip.Method=="INVITE"' \
-T fields -e frame.time_relative | head -1)

OK_TIME=$(tshark -r vonr.pcap \
-Y 'sip.Status-Code==200 && sip.CSeq.method=="INVITE"' \
-T fields -e frame.time_relative | head -1)

if [[ -n "$INVITE_TIME" && -n "$OK_TIME" ]]; then
    CST=$(echo "$OK_TIME - $INVITE_TIME" | bc)
    echo "Call Setup Time: $CST seconds"
else
    echo "Call Setup Time: Not found"
fi

# ================= CALL DURATION =================
echo ""
echo "----  CALL DURATION ----"

START=$(tshark -r vonr.pcap \
-Y 'sip.Method=="INVITE"' \
-T fields -e frame.time_relative | head -1)

END=$(tshark -r vonr.pcap \
-Y 'sip.Method=="BYE"' \
-T fields -e frame.time_relative | head -1)

if [[ -n "$START" && -n "$END" ]]; then
    DURATION=$(echo "$END - $START" | bc)
    echo "Call Duration: $DURATION seconds"
else
    echo "Call Duration: Not found"
fi

# ================= RTP KPI =================
echo ""
echo "=============================="
echo " RTP KPI SUMMARY"
echo "=============================="

tshark -r vonr.pcap -q -z rtp,streams > rtp_streams.txt
cat rtp_streams.txt

echo ""
echo "----  KEY METRICS ----"

awk '
/opus/ {
    printf "Packets: %s\n", $9;
    printf "Packet Loss: %s\n", $11;
    printf "Mean Latency: %s ms\n", $12;
    printf "Mean Jitter: %s ms\n", $15;
    printf "Max Jitter: %s ms\n", $16;
    print "--------------------------";
}
' rtp_streams.txt

echo ""
echo "===  Done ==="
