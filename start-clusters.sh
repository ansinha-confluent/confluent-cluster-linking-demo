#!/bin/bash
# Start both Confluent Platform clusters

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cluster-env.sh"

echo "Starting CP1 (Source Cluster)..."
if [[ -f "${CP1_BASE_DIR}/kafka.pid" ]] && kill -0 "$(cat "${CP1_BASE_DIR}/kafka.pid")" 2>/dev/null; then
    echo "CP1 Kafka is already running"
else
    nohup "${CP1_CONFLUENT_HOME}/bin/kafka-server-start" "${CP1_CONFLUENT_HOME}/etc/kafka/server.properties" > "${CP1_LOGS_DIR}/kafka.log" 2>&1 &
    echo $! > "${CP1_BASE_DIR}/kafka.pid"
    sleep 10
fi

# Start CP1 additional services
nohup "${CP1_CONFLUENT_HOME}/bin/schema-registry-start" "${CP1_CONFLUENT_HOME}/etc/schema-registry/schema-registry.properties" > "${CP1_LOGS_DIR}/schema-registry.log" 2>&1 &
echo $! > "${CP1_BASE_DIR}/schema-registry.pid"

nohup "${CP1_CONFLUENT_HOME}/bin/kafka-rest-start" "${CP1_CONFLUENT_HOME}/etc/kafka-rest/kafka-rest.properties" > "${CP1_LOGS_DIR}/rest-proxy.log" 2>&1 &
echo $! > "${CP1_BASE_DIR}/rest-proxy.pid"

nohup "${CP1_CONFLUENT_HOME}/bin/connect-distributed" "${CP1_CONFLUENT_HOME}/etc/kafka/connect-distributed.properties" > "${CP1_LOGS_DIR}/connect.log" 2>&1 &
echo $! > "${CP1_BASE_DIR}/connect.pid"

echo "Starting CP2 (Destination Cluster)..."
if [[ -f "${CP2_BASE_DIR}/kafka.pid" ]] && kill -0 "$(cat "${CP2_BASE_DIR}/kafka.pid")" 2>/dev/null; then
    echo "CP2 Kafka is already running"
else
    nohup "${CP2_CONFLUENT_HOME}/bin/kafka-server-start" "${CP2_CONFLUENT_HOME}/etc/kafka/server.properties" > "${CP2_LOGS_DIR}/kafka.log" 2>&1 &
    echo $! > "${CP2_BASE_DIR}/kafka.pid"
    sleep 10
fi

# Start CP2 additional services
nohup "${CP2_CONFLUENT_HOME}/bin/schema-registry-start" "${CP2_CONFLUENT_HOME}/etc/schema-registry/schema-registry.properties" > "${CP2_LOGS_DIR}/schema-registry.log" 2>&1 &
echo $! > "${CP2_BASE_DIR}/schema-registry.pid"

nohup "${CP2_CONFLUENT_HOME}/bin/kafka-rest-start" "${CP2_CONFLUENT_HOME}/etc/kafka-rest/kafka-rest.properties" > "${CP2_LOGS_DIR}/rest-proxy.log" 2>&1 &
echo $! > "${CP2_BASE_DIR}/rest-proxy.pid"

nohup "${CP2_CONFLUENT_HOME}/bin/connect-distributed" "${CP2_CONFLUENT_HOME}/etc/kafka/connect-distributed.properties" > "${CP2_LOGS_DIR}/connect.log" 2>&1 &
echo $! > "${CP2_BASE_DIR}/connect.pid"

echo "Both clusters started successfully (including Connect workers for auto-mirroring)"
