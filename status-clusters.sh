#!/bin/bash
# Check status of both Confluent Platform clusters

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cluster-env.sh"

echo "=== CP1 (Source Cluster) Status ==="
echo "Kafka: localhost:${CP1_KAFKA_PORT}"
echo "Schema Registry: localhost:${CP1_SCHEMA_REGISTRY_PORT}"
echo "REST Proxy: localhost:${CP1_REST_PROXY_PORT}"

if "${CP1_CONFLUENT_HOME}/bin/kafka-broker-api-versions" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" > /dev/null 2>&1; then
    echo "✅ CP1 Kafka is healthy"
    echo "Topics:"
    "${CP1_CONFLUENT_HOME}/bin/kafka-topics" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" --list
else
    echo "❌ CP1 Kafka is not responding"
fi

echo ""
echo "=== CP2 (Destination Cluster) Status ==="
echo "Kafka: localhost:${CP2_KAFKA_PORT}"
echo "Schema Registry: localhost:${CP2_SCHEMA_REGISTRY_PORT}"
echo "REST Proxy: localhost:${CP2_REST_PROXY_PORT}"

if "${CP2_CONFLUENT_HOME}/bin/kafka-broker-api-versions" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" > /dev/null 2>&1; then
    echo "✅ CP2 Kafka is healthy"
    echo "Topics:"
    "${CP2_CONFLUENT_HOME}/bin/kafka-topics" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" --list
else
    echo "❌ CP2 Kafka is not responding"
fi

echo ""
echo "=== Cluster Links Status ==="
echo "CP1 cluster links:"
"${CP1_CONFLUENT_HOME}/bin/kafka-cluster-links" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" --list 2>/dev/null || echo "No links found"

echo "CP2 cluster links:"
"${CP2_CONFLUENT_HOME}/bin/kafka-cluster-links" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" --list 2>/dev/null || echo "No links found"
