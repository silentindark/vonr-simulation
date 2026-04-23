#!/bin/bash
docker exec srsue_5g_zmq apt-get install -y linphone-cli tcpdump 2>/dev/null | tail -1
docker exec srsue_5g_zmq bash -c \
  'grep -q "ims.mnc001" /etc/hosts || \
   echo "172.22.0.21 ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts'

docker exec srsue_5g_zmq bash -c '
(sleep 90; echo "quit") | linphonec -c /root/linphone2.cfg -a > /tmp/ue2.log 2>&1' &
sleep 20

docker exec srsue_5g_zmq bash -c '
(sleep 5;
 echo "call sip:9076543211@ims.mnc001.mcc001.3gppnetwork.org";
 sleep 20; echo "terminate"; sleep 2; echo "quit") |
linphonec -c /root/linphone.cfg > /tmp/ue1.log 2>&1'

echo "=== UE1 ===" && docker exec srsue_5g_zmq cat /tmp/ue1.log | \
  grep -E "Establishing|ringing|connected|Media|ended"
echo "=== UE2 ===" && docker exec srsue_5g_zmq cat /tmp/ue2.log | \
  grep -E "Receiving|answering|connected|Media|ended"
