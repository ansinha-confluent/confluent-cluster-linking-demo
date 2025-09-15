#!/bin/bash
# Stop both Confluent Platform clusters

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cluster-env.sh"

echo "Stopping CP1 (Source Cluster)..."
for service in connect kafka schema-registry rest-proxy; do
    if [[ -f "${CP1_BASE_DIR}/${service}.pid" ]]; then
        kill "$(cat "${CP1_BASE_DIR}/${service}.pid")" 2>/dev/null || true
        rm -f "${CP1_BASE_DIR}/${service}.pid"
    fi
done

echo "Stopping CP2 (Destination Cluster)..."
for service in connect kafka schema-registry rest-proxy; do
    if [[ -f "${CP2_BASE_DIR}/${service}.pid" ]]; then
        kill "$(cat "${CP2_BASE_DIR}/${service}.pid")" 2>/dev/null || true
        rm -f "${CP2_BASE_DIR}/${service}.pid"
    fi
done

# Force kill any remaining processes
pkill -f "kafka-server-start" || true
pkill -f "schema-registry-start" || true
pkill -f "kafka-rest-start" || true
pkill -f "connect-distributed" || true

echo "Both clusters stopped successfully"
