#!/bin/bash

# Confluent Platform Cluster Linking Automation Script
# Author: Generated for CP 8.0+ with KRaft mode
# Purpose: Create CP1 (source) and CP2 (destination) clusters with cluster linking

set -e

# Global Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/Users/$(whoami)"
CP_VERSION="8.0.0"
CONFLUENT_TARBALL_URL="https://packages.confluent.io/archive/8.0/confluent-${CP_VERSION}.tar.gz"

# Cluster Configuration
CP1_BASE_DIR="${BASE_DIR}/cp1"
CP2_BASE_DIR="${BASE_DIR}/cp2"
CP1_CONFLUENT_HOME="${CP1_BASE_DIR}/confluent-${CP_VERSION}"
CP2_CONFLUENT_HOME="${CP2_BASE_DIR}/confluent-${CP_VERSION}"

# Network Configuration (simulating client topology)
CP1_KAFKA_PORT=9092
CP1_CONTROLLER_PORT=9093
CP1_SCHEMA_REGISTRY_PORT=8081
CP1_REST_PROXY_PORT=8082
CP1_CONNECT_PORT=8085

CP2_KAFKA_PORT=9094
CP2_CONTROLLER_PORT=9095
CP2_SCHEMA_REGISTRY_PORT=8083
CP2_REST_PROXY_PORT=8084
CP2_CONNECT_PORT=8086

# Log directories
CP1_LOGS_DIR="${CP1_BASE_DIR}/logs"
CP2_LOGS_DIR="${CP2_BASE_DIR}/logs"
CP1_DATA_DIR="${CP1_BASE_DIR}/data"
CP2_DATA_DIR="${CP2_BASE_DIR}/data"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING $(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to cleanup existing installations
cleanup_existing() {
    log "Cleaning up existing installations..."
    
    # Kill any existing processes
    pkill -f "kafka-server-start" || true
    pkill -f "schema-registry-start" || true
    pkill -f "kafka-rest-start" || true
    pkill -f "connect-distributed" || true
    
    # Wait for processes to terminate
    sleep 5
    
    # Remove existing directories
    rm -rf "${CP1_BASE_DIR}" "${CP2_BASE_DIR}"
    
    log "Cleanup completed"
}

# Function to create directory structure
create_directories() {
    log "Creating directory structure..."
    
    # Create base directories
    mkdir -p "${CP1_BASE_DIR}" "${CP2_BASE_DIR}"
    mkdir -p "${CP1_LOGS_DIR}" "${CP2_LOGS_DIR}"
    mkdir -p "${CP1_DATA_DIR}" "${CP2_DATA_DIR}"
    
    # Create subdirectories for data
    mkdir -p "${CP1_DATA_DIR}/kraft-combined-logs"
    mkdir -p "${CP2_DATA_DIR}/kraft-combined-logs"
    
    log "Directory structure created"
}

# Function to download and extract Confluent Platform
download_and_extract() {
    log "Downloading and extracting Confluent Platform ${CP_VERSION}..."
    
    # Check if tarball already exists
    TARBALL_PATH="${BASE_DIR}/confluent-${CP_VERSION}.tar.gz"
    if [[ ! -f "${TARBALL_PATH}" ]]; then
        info "Downloading Confluent Platform tarball..."
        curl -L -o "${TARBALL_PATH}" "${CONFLUENT_TARBALL_URL}"
    else
        info "Using existing tarball: ${TARBALL_PATH}"
    fi
    
    # Extract for CP1
    info "Extracting to CP1 directory..."
    tar -xzf "${TARBALL_PATH}" -C "${CP1_BASE_DIR}"
    
    # Extract for CP2
    info "Extracting to CP2 directory..."
    tar -xzf "${TARBALL_PATH}" -C "${CP2_BASE_DIR}"
    
    log "Extraction completed"
}

# Function to generate cluster UUID
generate_cluster_uuid() {
    "${CP1_CONFLUENT_HOME}/bin/kafka-storage" random-uuid
}

# Function to create CP1 configuration files
create_cp1_configs() {
    log "Creating CP1 (Source Cluster) configuration files..."
    
    local cluster_uuid=$(generate_cluster_uuid)
    
    # Create server.properties for CP1
    cat > "${CP1_CONFLUENT_HOME}/etc/kafka/server.properties" << EOF
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.

############################# Server Basics #############################
# The role of this server. Setting this puts us in KRaft mode
process.roles=broker,controller

# The node id associated with this instance's roles
node.id=1

# The cluster id
controller.cluster.id=${cluster_uuid}

############################# Socket Server Settings #############################
listeners=PLAINTEXT://:${CP1_KAFKA_PORT},CONTROLLER://:${CP1_CONTROLLER_PORT}
advertised.listeners=PLAINTEXT://localhost:${CP1_KAFKA_PORT}
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL

# Controller settings
controller.quorum.voters=1@localhost:${CP1_CONTROLLER_PORT}

# Network settings
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

############################# Log Basics #############################
log.dirs=${CP1_DATA_DIR}/kraft-combined-logs
num.partitions=1
num.recovery.threads.per.data.dir=1

############################# Internal Topic Settings #############################
offsets.topic.replication.factor=1
offsets.topic.num.partitions=50
offsets.topic.min.isr=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
share.coordinator.state.topic.replication.factor=1
share.coordinator.state.topic.min.isr=1

############################# Confluent License Settings #############################
confluent.license.topic.replication.factor=1
confluent.license.topic.min.isr=1

############################# Cluster Linking Settings #############################
# Source cluster configuration
link.mode=SOURCE
# Enable auto-creation of mirror topics
confluent.cluster.link.enable=true
confluent.cluster.link.metadata.topic.replication.factor=1

############################# Log Retention Policy #############################
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

############################# Other Settings #############################
group.initial.rebalance.delay.ms=0
auto.create.topics.enable=true
default.replication.factor=1
min.insync.replicas=1

############################# Embedded REST API Settings #############################
# Configure REST server to use port 8090 (required for auto-mirroring coordination)
confluent.http.server.listeners=http://0.0.0.0:8090
confluent.http.server.advertised.listeners=http://localhost:8090

############################# Additional Auto-Mirroring Settings #############################
# Additional settings to ensure reverse auto-mirroring works properly
confluent.cluster.link.io.timeout.ms=60000
confluent.cluster.link.request.timeout.ms=30000
confluent.cluster.link.retry.backoff.ms=1000

############################# Connect Framework for AutoCreateMirror #############################
# AutoCreateMirror requires Connect framework to be available
EOF

    # Create Schema Registry configuration for CP1
    cat > "${CP1_CONFLUENT_HOME}/etc/schema-registry/schema-registry.properties" << EOF
listeners=http://0.0.0.0:${CP1_SCHEMA_REGISTRY_PORT}
kafkastore.bootstrap.servers=PLAINTEXT://localhost:${CP1_KAFKA_PORT}
kafkastore.topic=_schemas
debug=false
EOF

    # Create Kafka REST configuration for CP1
    cat > "${CP1_CONFLUENT_HOME}/etc/kafka-rest/kafka-rest.properties" << EOF
listeners=http://0.0.0.0:${CP1_REST_PROXY_PORT}
bootstrap.servers=PLAINTEXT://localhost:${CP1_KAFKA_PORT}
schema.registry.url=http://localhost:${CP1_SCHEMA_REGISTRY_PORT}
EOF

    # Create Connect worker configuration for CP1 with EXPLICIT port enforcement
    cat > "${CP1_CONFLUENT_HOME}/etc/kafka/connect-distributed.properties" << EOF
# Kafka Connect Distributed Worker Configuration for CP1
# This worker will execute AutoCreateMirror tasks for cluster linking
# CRITICAL: Force port ${CP1_CONNECT_PORT} to avoid conflicts

# Kafka cluster connection
bootstrap.servers=localhost:${CP1_KAFKA_PORT}

# Connect worker settings
group.id=connect-cluster-cp1
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false

# Connect internal topic settings
config.storage.topic=connect-configs-cp1
config.storage.replication.factor=1
config.storage.partitions=1

offset.storage.topic=connect-offsets-cp1
offset.storage.replication.factor=1
offset.storage.partitions=25

status.storage.topic=connect-status-cp1
status.storage.replication.factor=1
status.storage.partitions=5

# REST API settings - CRITICAL PORT CONFIGURATION
rest.host.name=localhost
rest.port=${CP1_CONNECT_PORT}
rest.advertised.host.name=localhost
rest.advertised.port=${CP1_CONNECT_PORT}
# Override any default port settings
listeners=http://localhost:${CP1_CONNECT_PORT}

# Connect plugins and settings
plugin.path=${CP1_CONFLUENT_HOME}/share/java,${CP1_CONFLUENT_HOME}/share/confluent-hub-components

# Consumer settings
consumer.bootstrap.servers=localhost:${CP1_KAFKA_PORT}
consumer.group.id=connect-cluster-cp1

# Producer settings
producer.bootstrap.servers=localhost:${CP1_KAFKA_PORT}

# Worker settings
tasks.max=8
connector.client.config.override.policy=All

# Debug settings
log4j.logger.org.apache.kafka.connect=DEBUG
EOF

    # Store cluster UUID for CP1
    echo "${cluster_uuid}" > "${CP1_BASE_DIR}/cluster-uuid.txt"
    
    log "CP1 configuration files created with cluster UUID: ${cluster_uuid}"
}

# Function to create CP2 configuration files
create_cp2_configs() {
    log "Creating CP2 (Destination Cluster) configuration files..."
    
    local cluster_uuid=$(generate_cluster_uuid)
    
    # Create server.properties for CP2
    cat > "${CP2_CONFLUENT_HOME}/etc/kafka/server.properties" << EOF
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.

############################# Server Basics #############################
# The role of this server. Setting this puts us in KRaft mode
process.roles=broker,controller

# The node id associated with this instance's roles
node.id=1

# The cluster id
controller.cluster.id=${cluster_uuid}

############################# Socket Server Settings #############################
listeners=PLAINTEXT://:${CP2_KAFKA_PORT},CONTROLLER://:${CP2_CONTROLLER_PORT}
advertised.listeners=PLAINTEXT://localhost:${CP2_KAFKA_PORT}
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL

# Controller settings
controller.quorum.voters=1@localhost:${CP2_CONTROLLER_PORT}

# Network settings
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

############################# Log Basics #############################
log.dirs=${CP2_DATA_DIR}/kraft-combined-logs
num.partitions=1
num.recovery.threads.per.data.dir=1

############################# Internal Topic Settings #############################
offsets.topic.replication.factor=1
offsets.topic.num.partitions=50
offsets.topic.min.isr=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
share.coordinator.state.topic.replication.factor=1
share.coordinator.state.topic.min.isr=1

############################# Confluent License Settings #############################
confluent.license.topic.replication.factor=1
confluent.license.topic.min.isr=1

############################# Cluster Linking Settings #############################
# Destination cluster configuration
link.mode=DESTINATION
# Enable auto-creation of mirror topics
confluent.cluster.link.enable=true
confluent.cluster.link.topic.auto.create=true
confluent.cluster.link.metadata.topic.replication.factor=1

############################# Log Retention Policy #############################
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

############################# Other Settings #############################
group.initial.rebalance.delay.ms=0
auto.create.topics.enable=true
default.replication.factor=1
min.insync.replicas=1

############################# Embedded REST API Settings #############################
# Configure REST server to use port 8091 to avoid conflict with CP1 (port 8090)
confluent.http.server.listeners=http://0.0.0.0:8091
confluent.http.server.advertised.listeners=http://localhost:8091

############################# Additional Auto-Mirroring Settings #############################
# Additional settings to ensure bidirectional auto-mirroring works properly
confluent.cluster.link.io.timeout.ms=60000
confluent.cluster.link.request.timeout.ms=30000
confluent.cluster.link.retry.backoff.ms=1000

############################# Connect Framework for AutoCreateMirror #############################
# AutoCreateMirror requires Connect framework to be available
EOF

    # Create Schema Registry configuration for CP2
    cat > "${CP2_CONFLUENT_HOME}/etc/schema-registry/schema-registry.properties" << EOF
listeners=http://0.0.0.0:${CP2_SCHEMA_REGISTRY_PORT}
kafkastore.bootstrap.servers=PLAINTEXT://localhost:${CP2_KAFKA_PORT}
kafkastore.topic=_schemas
debug=false
EOF

    # Create Kafka REST configuration for CP2
    cat > "${CP2_CONFLUENT_HOME}/etc/kafka-rest/kafka-rest.properties" << EOF
listeners=http://0.0.0.0:${CP2_REST_PROXY_PORT}
bootstrap.servers=PLAINTEXT://localhost:${CP2_KAFKA_PORT}
schema.registry.url=http://localhost:${CP2_SCHEMA_REGISTRY_PORT}
EOF

    # Create Connect worker configuration for CP2 with EXPLICIT port enforcement
    cat > "${CP2_CONFLUENT_HOME}/etc/kafka/connect-distributed.properties" << EOF
# Kafka Connect Distributed Worker Configuration for CP2
# This worker will execute AutoCreateMirror tasks for cluster linking
# CRITICAL: Force port ${CP2_CONNECT_PORT} to avoid conflicts

# Kafka cluster connection
bootstrap.servers=localhost:${CP2_KAFKA_PORT}

# Connect worker settings
group.id=connect-cluster-cp2
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false

# Connect internal topic settings
config.storage.topic=connect-configs-cp2
config.storage.replication.factor=1
config.storage.partitions=1

offset.storage.topic=connect-offsets-cp2
offset.storage.replication.factor=1
offset.storage.partitions=25

status.storage.topic=connect-status-cp2
status.storage.replication.factor=1
status.storage.partitions=5

# REST API settings - CRITICAL PORT CONFIGURATION
rest.host.name=localhost
rest.port=${CP2_CONNECT_PORT}
rest.advertised.host.name=localhost
rest.advertised.port=${CP2_CONNECT_PORT}
# Override any default port settings
listeners=http://localhost:${CP2_CONNECT_PORT}

# Connect plugins and settings
plugin.path=${CP2_CONFLUENT_HOME}/share/java,${CP2_CONFLUENT_HOME}/share/confluent-hub-components

# Consumer settings
consumer.bootstrap.servers=localhost:${CP2_KAFKA_PORT}
consumer.group.id=connect-cluster-cp2

# Producer settings
producer.bootstrap.servers=localhost:${CP2_KAFKA_PORT}

# Worker settings
tasks.max=8
connector.client.config.override.policy=All

# Debug settings
log4j.logger.org.apache.kafka.connect=DEBUG
EOF

    # Store cluster UUID for CP2
    echo "${cluster_uuid}" > "${CP2_BASE_DIR}/cluster-uuid.txt"
    
    log "CP2 configuration files created with cluster UUID: ${cluster_uuid}"
}

# Function to format storage for KRaft
format_storage() {
    log "Formatting KRaft storage for both clusters..."
    
    # Format CP1 storage
    info "Formatting CP1 storage..."
    local cp1_uuid=$(cat "${CP1_BASE_DIR}/cluster-uuid.txt")
    "${CP1_CONFLUENT_HOME}/bin/kafka-storage" format -t "${cp1_uuid}" -c "${CP1_CONFLUENT_HOME}/etc/kafka/server.properties" --standalone
    
    # Format CP2 storage
    info "Formatting CP2 storage..."
    local cp2_uuid=$(cat "${CP2_BASE_DIR}/cluster-uuid.txt")
    "${CP2_CONFLUENT_HOME}/bin/kafka-storage" format -t "${cp2_uuid}" -c "${CP2_CONFLUENT_HOME}/etc/kafka/server.properties" --standalone
    
    log "Storage formatting completed"
}

# Function to start CP1 services
start_cp1_services() {
    log "Starting CP1 (Source Cluster) services..."
    
    # Start Kafka
    info "Starting CP1 Kafka server..."
    nohup "${CP1_CONFLUENT_HOME}/bin/kafka-server-start" "${CP1_CONFLUENT_HOME}/etc/kafka/server.properties" > "${CP1_LOGS_DIR}/kafka.log" 2>&1 &
    echo $! > "${CP1_BASE_DIR}/kafka.pid"
    
    # Wait for Kafka to start
    sleep 10
    
    # Start Schema Registry
    info "Starting CP1 Schema Registry..."
    nohup "${CP1_CONFLUENT_HOME}/bin/schema-registry-start" "${CP1_CONFLUENT_HOME}/etc/schema-registry/schema-registry.properties" > "${CP1_LOGS_DIR}/schema-registry.log" 2>&1 &
    echo $! > "${CP1_BASE_DIR}/schema-registry.pid"
    
    # Start REST Proxy
    info "Starting CP1 REST Proxy..."
    nohup "${CP1_CONFLUENT_HOME}/bin/kafka-rest-start" "${CP1_CONFLUENT_HOME}/etc/kafka-rest/kafka-rest.properties" > "${CP1_LOGS_DIR}/rest-proxy.log" 2>&1 &
    echo $! > "${CP1_BASE_DIR}/rest-proxy.pid"
    
    # Start Kafka Connect Worker for AutoCreateMirror tasks
    info "Starting CP1 Kafka Connect Worker (for AutoCreateMirror tasks)..."
    nohup "${CP1_CONFLUENT_HOME}/bin/connect-distributed" "${CP1_CONFLUENT_HOME}/etc/kafka/connect-distributed.properties" > "${CP1_LOGS_DIR}/connect.log" 2>&1 &
    echo $! > "${CP1_BASE_DIR}/connect.pid"
    
    # Wait for all services to start
    sleep 15
    
    # Verify Connect worker process is still running
    if [[ -f "${CP1_BASE_DIR}/connect.pid" ]] && kill -0 "$(cat "${CP1_BASE_DIR}/connect.pid")" 2>/dev/null; then
        info "CP1 Connect worker process is running (PID: $(cat "${CP1_BASE_DIR}/connect.pid"))"
    else
        error "CP1 Connect worker failed to start or crashed. Check ${CP1_LOGS_DIR}/connect.log"
        if [[ -f "${CP1_LOGS_DIR}/connect.log" ]]; then
            error "Last 20 lines of CP1 Connect log:"
            tail -20 "${CP1_LOGS_DIR}/connect.log" | while IFS= read -r line; do error "  $line"; done
        fi
    fi
    
    log "CP1 services started successfully (including Connect worker on port ${CP1_CONNECT_PORT})"
}

# Function to start CP2 services
start_cp2_services() {
    log "Starting CP2 (Destination Cluster) services..."
    
    # Start Kafka
    info "Starting CP2 Kafka server..."
    nohup "${CP2_CONFLUENT_HOME}/bin/kafka-server-start" "${CP2_CONFLUENT_HOME}/etc/kafka/server.properties" > "${CP2_LOGS_DIR}/kafka.log" 2>&1 &
    echo $! > "${CP2_BASE_DIR}/kafka.pid"
    
    # Wait for Kafka to start
    sleep 10
    
    # Start Schema Registry
    info "Starting CP2 Schema Registry..."
    nohup "${CP2_CONFLUENT_HOME}/bin/schema-registry-start" "${CP2_CONFLUENT_HOME}/etc/schema-registry/schema-registry.properties" > "${CP2_LOGS_DIR}/schema-registry.log" 2>&1 &
    echo $! > "${CP2_BASE_DIR}/schema-registry.pid"
    
    # Start REST Proxy
    info "Starting CP2 REST Proxy..."
    nohup "${CP2_CONFLUENT_HOME}/bin/kafka-rest-start" "${CP2_CONFLUENT_HOME}/etc/kafka-rest/kafka-rest.properties" > "${CP2_LOGS_DIR}/rest-proxy.log" 2>&1 &
    echo $! > "${CP2_BASE_DIR}/rest-proxy.pid"
    
    # Start Kafka Connect Worker for AutoCreateMirror tasks
    info "Starting CP2 Kafka Connect Worker (for AutoCreateMirror tasks)..."
    nohup "${CP2_CONFLUENT_HOME}/bin/connect-distributed" "${CP2_CONFLUENT_HOME}/etc/kafka/connect-distributed.properties" > "${CP2_LOGS_DIR}/connect.log" 2>&1 &
    echo $! > "${CP2_BASE_DIR}/connect.pid"
    
    # Wait for all services to start
    sleep 15
    
    # Verify Connect worker process is still running
    if [[ -f "${CP2_BASE_DIR}/connect.pid" ]] && kill -0 "$(cat "${CP2_BASE_DIR}/connect.pid")" 2>/dev/null; then
        info "CP2 Connect worker process is running (PID: $(cat "${CP2_BASE_DIR}/connect.pid"))"
    else
        error "CP2 Connect worker failed to start or crashed. Check ${CP2_LOGS_DIR}/connect.log"
        if [[ -f "${CP2_LOGS_DIR}/connect.log" ]]; then
            error "Last 20 lines of CP2 Connect log:"
            tail -20 "${CP2_LOGS_DIR}/connect.log" | while IFS= read -r line; do error "  $line"; done
        fi
    fi
    
    log "CP2 services started successfully (including Connect worker on port ${CP2_CONNECT_PORT})"
}

# Function to verify cluster health
verify_cluster_health() {
    local cluster_name="$1"
    local bootstrap_server="$2"
    local confluent_home="$3"
    
    info "Verifying ${cluster_name} cluster health..."
    
    # Test broker connectivity
    if "${confluent_home}/bin/kafka-broker-api-versions" --bootstrap-server "${bootstrap_server}" > /dev/null 2>&1; then
        info "${cluster_name}: Kafka broker is healthy"
    else
        error "${cluster_name}: Kafka broker is not responding"
        return 1
    fi
    
    # List topics
    local topics=$("${confluent_home}/bin/kafka-topics" --bootstrap-server "${bootstrap_server}" --list 2>/dev/null)
    info "${cluster_name}: Available topics: ${topics}"
    
    return 0
}

# Function to create test topics
create_test_topics() {
    log "Creating test topics on both clusters (Note: These will NOT auto-mirror since they don't have 'test-' prefix)..."
    
    # Create topics on CP1 
    info "Creating topics on CP1..."
    "${CP1_CONFLUENT_HOME}/bin/kafka-topics" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" --create --topic "source-topic-A" --partitions 3 --replication-factor 1
    "${CP1_CONFLUENT_HOME}/bin/kafka-topics" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" --create --topic "source-topic-B" --partitions 3 --replication-factor 1
    
    # Create topics on CP2
    info "Creating topics on CP2..."
    "${CP2_CONFLUENT_HOME}/bin/kafka-topics" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" --create --topic "dest-topic-A" --partitions 3 --replication-factor 1
    "${CP2_CONFLUENT_HOME}/bin/kafka-topics" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" --create --topic "dest-topic-B" --partitions 3 --replication-factor 1
    
    log "Test topics created successfully"
}

# Function to setup cluster linking with auto-mirroring
setup_cluster_linking() {
    log "Setting up BIDIRECTIONAL cluster linking with auto-mirroring..."
    
    # Wait for both clusters to be fully ready
    sleep 15
    
    # Create cluster link configuration files
    info "Creating cluster link configuration files..."
    
    # Forward direction: CP1 → CP2 (link created on CP2, pointing to CP1)
    cat > "${BASE_DIR}/cluster-link-cp1-to-cp2.properties" << EOF
bootstrap.servers=localhost:${CP1_KAFKA_PORT}
auto.create.mirror.topics.enable=true
EOF
    
    # Reverse direction: CP2 → CP1 (link created on CP1, pointing to CP2)
    cat > "${BASE_DIR}/cluster-link-cp2-to-cp1.properties" << EOF
bootstrap.servers=localhost:${CP2_KAFKA_PORT}
auto.create.mirror.topics.enable=true
EOF
    
    # Topic filters configuration for auto-mirroring (prefixed pattern for test topics)
    cat > "${BASE_DIR}/topic-filters.json" << 'EOF'
{"topicFilters":[{"name":"test-","patternType":"PREFIXED","filterType":"INCLUDE"}]}
EOF
    
    # Create FORWARD cluster link: CP1 → CP2 (created on CP2, mirrors from CP1)
    info "Creating forward cluster link cp1-to-cp2 on CP2 (mirrors CP1 → CP2)..."
    "${CP2_CONFLUENT_HOME}/bin/kafka-cluster-links" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" \
        --create --link "cp1-to-cp2" \
        --config-file "${BASE_DIR}/cluster-link-cp1-to-cp2.properties" \
        --topic-filters-json-file "${BASE_DIR}/topic-filters.json"
    
    # Wait for forward link to be established
    sleep 10
    
    # Create REVERSE cluster link: CP2 → CP1 (created on CP1, mirrors from CP2)
    info "Creating reverse cluster link cp2-to-cp1 on CP1 (mirrors CP2 → CP1)..."
    "${CP1_CONFLUENT_HOME}/bin/kafka-cluster-links" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" \
        --create --link "cp2-to-cp1" \
        --config-file "${BASE_DIR}/cluster-link-cp2-to-cp1.properties" \
        --topic-filters-json-file "${BASE_DIR}/topic-filters.json"
    
    # Wait for reverse link to be established
    sleep 10
    
    info "✅ BIDIRECTIONAL auto-mirroring cluster links established:"
    info "   - Forward: CP1 → CP2 (topics with 'test-' prefix auto-mirrored)"
    info "   - Reverse: CP2 → CP1 (topics with 'test-' prefix auto-mirrored)"
    info "   - Note: AutoCreateMirror tasks may take a few moments to become active"
    
    log "Cluster linking with bidirectional auto-mirroring setup completed"
}

# Function to verify cluster linking
verify_cluster_linking() {
    log "Verifying cluster linking setup..."
    
    # List cluster links on CP2
    info "Cluster links on CP2:"
    "${CP2_CONFLUENT_HOME}/bin/kafka-cluster-links" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" --list || true
    
    # List cluster links on CP1  
    info "Cluster links on CP1:"
    "${CP1_CONFLUENT_HOME}/bin/kafka-cluster-links" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" --list || true
    
    # List mirror topics on CP2
    info "Mirror topics on CP2:"
    "${CP2_CONFLUENT_HOME}/bin/kafka-mirrors" --bootstrap-server "localhost:${CP2_KAFKA_PORT}" --list || true
    
    # List mirror topics on CP1
    info "Mirror topics on CP1:"
    "${CP1_CONFLUENT_HOME}/bin/kafka-mirrors" --bootstrap-server "localhost:${CP1_KAFKA_PORT}" --list || true
    
    log "Cluster linking verification completed"
}

# Function to create management scripts
create_management_scripts() {
    log "Creating cluster management scripts..."
    
    # Create start script
    cat > "${BASE_DIR}/start-clusters.sh" << 'EOF'
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
EOF

    # Create stop script
    cat > "${BASE_DIR}/stop-clusters.sh" << 'EOF'
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
EOF

    # Create status script
    cat > "${BASE_DIR}/status-clusters.sh" << 'EOF'
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
EOF

    # Create environment variables script
    cat > "${BASE_DIR}/cluster-env.sh" << EOF
#!/bin/bash
# Environment variables for Confluent Platform clusters

export CP1_BASE_DIR="${CP1_BASE_DIR}"
export CP2_BASE_DIR="${CP2_BASE_DIR}"
export CP1_CONFLUENT_HOME="${CP1_CONFLUENT_HOME}"
export CP2_CONFLUENT_HOME="${CP2_CONFLUENT_HOME}"

export CP1_KAFKA_PORT=${CP1_KAFKA_PORT}
export CP1_CONTROLLER_PORT=${CP1_CONTROLLER_PORT}
export CP1_SCHEMA_REGISTRY_PORT=${CP1_SCHEMA_REGISTRY_PORT}
export CP1_REST_PROXY_PORT=${CP1_REST_PROXY_PORT}
export CP1_CONNECT_PORT=${CP1_CONNECT_PORT}

export CP2_KAFKA_PORT=${CP2_KAFKA_PORT}
export CP2_CONTROLLER_PORT=${CP2_CONTROLLER_PORT}
export CP2_SCHEMA_REGISTRY_PORT=${CP2_SCHEMA_REGISTRY_PORT}
export CP2_REST_PROXY_PORT=${CP2_REST_PROXY_PORT}
export CP2_CONNECT_PORT=${CP2_CONNECT_PORT}

export CP1_LOGS_DIR="${CP1_LOGS_DIR}"
export CP2_LOGS_DIR="${CP2_LOGS_DIR}"
export CP1_DATA_DIR="${CP1_DATA_DIR}"
export CP2_DATA_DIR="${CP2_DATA_DIR}"
EOF

    # Make all scripts executable
    chmod +x "${BASE_DIR}/start-clusters.sh"
    chmod +x "${BASE_DIR}/stop-clusters.sh"
    chmod +x "${BASE_DIR}/status-clusters.sh"
    chmod +x "${BASE_DIR}/cluster-env.sh"
    
    log "Management scripts created successfully"
}

# Function to display final information
display_final_info() {
    log "Confluent Platform cluster setup completed successfully!"
    
    echo ""
    echo "=== CLUSTER INFORMATION ==="
    echo "CP1 (Source Cluster):"
    echo "  - Kafka: localhost:${CP1_KAFKA_PORT}"
    echo "  - Schema Registry: http://localhost:${CP1_SCHEMA_REGISTRY_PORT}"
    echo "  - REST Proxy: http://localhost:${CP1_REST_PROXY_PORT}"
    echo "  - Connect Worker: http://localhost:${CP1_CONNECT_PORT} (for AutoCreateMirror tasks)"
    echo "  - Mode: SOURCE (outgoing traffic only)"
    echo "  - Data Directory: ${CP1_DATA_DIR}"
    echo "  - Logs Directory: ${CP1_LOGS_DIR}"
    echo ""
    echo "CP2 (Destination Cluster):"
    echo "  - Kafka: localhost:${CP2_KAFKA_PORT}"
    echo "  - Schema Registry: http://localhost:${CP2_SCHEMA_REGISTRY_PORT}"
    echo "  - REST Proxy: http://localhost:${CP2_REST_PROXY_PORT}"
    echo "  - Connect Worker: http://localhost:${CP2_CONNECT_PORT} (for AutoCreateMirror tasks)"
    echo "  - Mode: DESTINATION (bidirectional traffic)"
    echo "  - Data Directory: ${CP2_DATA_DIR}"
    echo "  - Logs Directory: ${CP2_LOGS_DIR}"
    echo ""
    echo "=== CLUSTER LINKING ==="
    echo "  - CP1 → CP2: cp1-to-cp2 link"
    echo "  - CP2 → CP1: cp2-to-cp1 link"
    echo "  - Auto-replication enabled for topics with 'test-' prefix"
    echo ""
    echo "=== MANAGEMENT COMMANDS ==="
    echo "  Start clusters: ${BASE_DIR}/start-clusters.sh"
    echo "  Stop clusters:  ${BASE_DIR}/stop-clusters.sh"
    echo "  Check status:   ${BASE_DIR}/status-clusters.sh"
    echo ""
    echo "=== TEST AUTO-MIRRORING ==="
    echo "  To test auto-mirroring, create topics with 'test-' prefix:"
    echo ""
    echo "  # Create topic on CP1 (will auto-mirror to CP2):"
    echo "  echo 'Hello from CP1' | ${CP1_CONFLUENT_HOME}/bin/kafka-console-producer --bootstrap-server localhost:${CP1_KAFKA_PORT} --topic test-demo"
    echo ""
    echo "  # Consume from CP2 (auto-mirrored topic):"
    echo "  ${CP2_CONFLUENT_HOME}/bin/kafka-console-consumer --bootstrap-server localhost:${CP2_KAFKA_PORT} --topic test-demo --from-beginning --max-messages 1"
    echo ""
    echo "All logs are available in:"
    echo "  CP1: ${CP1_LOGS_DIR}/"
    echo "  CP2: ${CP2_LOGS_DIR}/"
}

# Main execution function
main() {
    log "Starting Confluent Platform cluster setup with cluster linking..."
    
    cleanup_existing
    create_directories
    download_and_extract
    create_cp1_configs
    create_cp2_configs
    format_storage
    start_cp1_services
    start_cp2_services
    
    # Verify cluster health
    verify_cluster_health "CP1" "localhost:${CP1_KAFKA_PORT}" "${CP1_CONFLUENT_HOME}"
    verify_cluster_health "CP2" "localhost:${CP2_KAFKA_PORT}" "${CP2_CONFLUENT_HOME}"
    
    create_test_topics
    setup_cluster_linking
    verify_cluster_linking
    create_management_scripts
    
    display_final_info
    
    log "Setup completed successfully! 🎉"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
