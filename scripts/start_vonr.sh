#!/bin/bash
# Claude Generated Code Snippet for TWiN Project
echo "=== Starting VoNR stack ==="
sudo systemctl stop open5gs-* 2>/dev/null
sudo sysctl -w net.ipv4.ip_forward=1
sudo ufw disable 2>/dev/null

cd ~/docker_open5gs
docker stop $(docker ps -q) 2>/dev/null
docker rm $(docker ps -aq) 2>/dev/null

set -a; source .env; set +a
docker compose -f sa-vonr-ibcf-deploy.yaml up -d
echo "Waiting 30s for core..."
sleep 30

docker exec mysql mysql -u root -pchangeme ims_hss_db \
  -e "ALTER TABLE operation_log MODIFY item_id INTEGER NULL;" 2>/dev/null

docker compose -f srsgnb_zmq.yaml up -d
sleep 15
docker compose -f srsue_5g_zmq.yaml up -d
sleep 20

docker exec pcscf ip route add 192.168.101.0/24 via 172.22.0.8 2>/dev/null
docker exec icscf ip route add 192.168.101.0/24 via 172.22.0.8 2>/dev/null
docker exec scscf ip route add 192.168.101.0/24 via 172.22.0.8 2>/dev/null
docker exec upf iptables -t nat -A POSTROUTING \
  -s 192.168.101.0/24 ! -o ogstun2 -j MASQUERADE 2>/dev/null

docker exec srsue_5g_zmq apt-get install -y linphone-cli tcpdump 2>/dev/null | tail -1

docker exec srsue_5g_zmq mkdir -p /root/ue1/.local/share/linphone
docker exec srsue_5g_zmq mkdir -p /root/ue2/.local/share/linphone

docker exec srsue_5g_zmq bash -c 'echo "172.22.0.21 ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts'
docker exec srsue_5g_zmq bash -c 'echo "172.22.0.20 scscf.ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts'
docker exec srsue_5g_zmq bash -c 'echo "172.22.0.19 icscf.ims.mnc001.mcc001.3gppnetwork.org" >> /etc/hosts'

docker exec srsue_5g_zmq bash -c 'cat > /root/ue1/linphonerc << EOF
[sip]
sip_port=5070
sip_tcp_port=5070
default_proxy=0
verify_server_certs=0
verify_server_cn=0
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

docker exec srsue_5g_zmq bash -c 'cat > /root/ue2/linphonerc << EOF
[sip]
sip_port=5071
sip_tcp_port=5071
default_proxy=0
verify_server_certs=0
verify_server_cn=0
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

echo ""
echo "=== VoNR stack ready ==="
docker logs srsue_5g_zmq 2>&1 | grep "PDU Session" | tail -1
echo "Run: ~/vonr_call.sh"
