#!/bin/bash
# Claude Generated Code Snippet for TWiN Project
echo "=== Stopping VoNR stack ==="

cd ~/docker_open5gs

docker exec srsue_5g_zmq pkill linphonec 2>/dev/null

docker compose -f srsue_5g_zmq.yaml down 2>/dev/null
docker compose -f srsgnb_zmq.yaml down 2>/dev/null
docker compose -f sa-vonr-ibcf-deploy.yaml down 2>/dev/null

echo "=== All containers stopped ==="
docker ps
