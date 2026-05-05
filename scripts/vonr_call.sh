#!/bin/bash
# Claude Generated Code Snippet for TWiN Project
echo "=== Starting VoNR call ==="
docker exec srsue_5g_zmq pkill linphonec 2>/dev/null
sleep 2

docker exec srsue_5g_zmq bash -c '
export HOME=/root/ue2
(sleep 120; echo "quit") | linphonec -c /root/ue2/linphonerc -a \
  > /tmp/ue2.log 2>&1' &

echo "Waiting for UE2 to register (20s)..."
sleep 20

docker exec srsue_5g_zmq bash -c '
export HOME=/root/ue1
(sleep 5;
 echo "call sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org";
 sleep 20; echo "terminate"; sleep 2; echo "quit") |
linphonec -c /root/ue1/linphonerc > /tmp/ue1.log 2>&1'

echo "=== UE1 ===" && docker exec srsue_5g_zmq cat /tmp/ue1.log | \
  grep -E "ringing|connected|Media|ended|error"
echo "=== UE2 ===" && docker exec srsue_5g_zmq cat /tmp/ue2.log | \
  grep -E "answering|connected|Media|ended|error"
