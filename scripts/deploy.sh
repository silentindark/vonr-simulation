#!/bin/bash
set -e
cd ~/docker_open5gs
set -a; source .env; set +a
sudo sysctl -w net.ipv4.ip_forward=1
sudo ufw disable 2>/dev/null
docker compose -f sa-vonr-ibcf-deploy.yaml up -d
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
echo "Deployment complete."
