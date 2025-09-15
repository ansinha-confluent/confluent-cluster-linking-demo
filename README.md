# Confluent Platform Cluster Linking Demo

A complete automation script for setting up two Confluent Platform 8.0+ clusters with bidirectional cluster linking and auto-mirroring capabilities using KRaft mode.

## 🚀 Features

- **Two Independent Clusters**: CP1 (source) and CP2 (destination) running on different ports
- **Bidirectional Cluster Linking**: Automatic replication in both directions
- **Auto-Mirroring**: Topics with `test-` prefix are automatically mirrored
- **KRaft Mode**: Uses Kafka's native KRaft consensus protocol (no ZooKeeper)
- **Complete Stack**: Kafka, Schema Registry, REST Proxy, and Connect workers
- **Management Scripts**: Easy start/stop/status commands
- **Production-Ready Configuration**: Optimized settings for cluster linking

## 📋 Prerequisites

- macOS (tested on macOS with zsh)
- RHEL Ent some times defaults to a different shell so as long as you run bash it should ideally work.
- Internet connection (to download Confluent Platform)
- Ports available: 9092-9095, 8081-8086, 8090-8091
- At least 4GB free disk space
- Java 8+ (will be included with Confluent Platform)

## 🏗️ Architecture

```
┌─────────────────┐                    ┌─────────────────┐
│      CP1        │◄──────────────────►│      CP2        │
│   (Source)      │   2 Cluster Link   │ (Destination)   │
│                 │                    │                 │
│ Kafka: 9092     │                    │ Kafka: 9094     │
│ Schema: 8081    │                    │ Schema: 8083    │
│ REST: 8082      │                    │ REST: 8084      │
│ Connect: 8085   │                    │ Connect: 8086   │
└─────────────────┘                    └─────────────────┘
```

## 🚀 Quick Start

### 1. Setup Clusters

```bash
# Clone the repository
git clone <your-repo-url>
cd confluent-cluster-linking-demo

# Make scripts executable
chmod +x *.sh

# Run the complete setup (takes 5-10 minutes)
./setup-confluent-clusters.sh
```

### 2. Test Auto-Mirroring

```bash
# Test CP1 → CP2 mirroring
echo 'Hello from CP1' | ~/cp1/confluent-8.0.0/bin/kafka-console-producer \
  --bootstrap-server localhost:9092 --topic test-demo

# Verify on CP2 (should auto-mirror)
~/cp2/confluent-8.0.0/bin/kafka-console-consumer \
  --bootstrap-server localhost:9094 --topic test-demo \
  --from-beginning --max-messages 1

# Test CP2 → CP1 mirroring
echo 'Hello from CP2' | ~/cp2/confluent-8.0.0/bin/kafka-console-producer \
  --bootstrap-server localhost:9094 --topic test-reverse

# Verify on CP1 (should auto-mirror)
~/cp1/confluent-8.0.0/bin/kafka-console-consumer \
  --bootstrap-server localhost:9092 --topic test-reverse \
  --from-beginning --max-messages 1
```

If it shows issues in one of the cluster links just wait for a bit and rerun it it takes a little bit of time (~10 mins) for it become live then everything works fine.

### 3. Management Commands

```bash
# Check cluster status
./status-clusters.sh

# Stop all clusters
./stop-clusters.sh

# Restart all clusters
./start-clusters.sh
```

## 📁 File Structure

```
confluent-cluster-linking-demo/
├── setup-confluent-clusters.sh      # Main setup script
├── start-clusters.sh                # Start both clusters
├── stop-clusters.sh                 # Stop both clusters  
├── status-clusters.sh               # Check cluster status
├── cluster-env.sh                   # Environment variables
├── cluster-link-cp1-to-cp2.properties   # Forward link config
├── cluster-link-cp2-to-cp1.properties   # Reverse link config
├── topic-filters.json               # Auto-mirroring filters
└── README.md                        # This file
```

## 🔧 Configuration Details

### Cluster Endpoints

**CP1 (Source Cluster):**
- Kafka: `localhost:9092`
- Schema Registry: `http://localhost:8081`
- REST Proxy: `http://localhost:8082`
- Connect Worker: `http://localhost:8085`
- Data: `~/cp1/data`
- Logs: `~/cp1/logs`

**CP2 (Destination Cluster):**
- Kafka: `localhost:9094`
- Schema Registry: `http://localhost:8083`
- REST Proxy: `http://localhost:8084`
- Connect Worker: `http://localhost:8086`
- Data: `~/cp2/data`
- Logs: `~/cp2/logs`

### Auto-Mirroring Rules

- **Included Topics**: Topics with `test-` prefix
- **Excluded Topics**: All other topics (including system topics)
- **Direction**: Bidirectional (CP1 ↔ CP2)
- **Timing**: Automatic with periodic scanning

### Cluster Links

- **Forward Link**: `cp1-to-cp2` (on CP2, mirrors from CP1)
- **Reverse Link**: `cp2-to-cp1` (on CP1, mirrors from CP2)
- **Mode**: `DESTINATION` with `OUTBOUND` connection

## 🛠️ Advanced Usage

### Manual Mirror Management

```bash
# List all cluster links
~/cp2/confluent-8.0.0/bin/kafka-cluster-links \
  --bootstrap-server localhost:9094 --list

# List mirror topics
~/cp2/confluent-8.0.0/bin/kafka-mirrors \
  --bootstrap-server localhost:9094 --list

# Create manual mirror topic
~/cp2/confluent-8.0.0/bin/kafka-mirrors \
  --bootstrap-server localhost:9094 --create \
  --mirror-topic my-topic --link cp1-to-cp2
```

### Monitoring and Troubleshooting

```bash
# Check cluster link status
~/cp2/confluent-8.0.0/bin/kafka-cluster-links \
  --bootstrap-server localhost:9094 --describe --link cp1-to-cp2

# Monitor logs
tail -f ~/cp1/logs/kafka.log
tail -f ~/cp2/logs/kafka.log

# Check Connect workers
curl http://localhost:8085/connectors
curl http://localhost:8086/connectors
```

## 🔍 Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 9092-9095 and 8081-8086 are free
2. **Auto-Mirroring Delays**: AutoCreateMirror can take 30-60 seconds
3. **Process Issues**: Use `./stop-clusters.sh` to clean up before restart

### Log Locations

- **CP1**: `~/cp1/logs/`
- **CP2**: `~/cp2/logs/`
- **Connect Logs**: `connect.log` in respective log directories

### Reset Everything

```bash
# Stop clusters
./stop-clusters.sh

# Remove all data (careful!)
rm -rf ~/cp1 ~/cp2

# Re-run setup
./setup-confluent-clusters.sh
```

## 🎯 Use Cases

- **Multi-Region Replication**: Simulate cross-region data replication
- **Disaster Recovery**: Test backup and recovery scenarios
- **Hybrid Cloud**: Practice on-premises to cloud migration
- **Development & Testing**: Local development with production-like setup
- **Learning**: Understand Confluent Platform cluster linking concepts

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is open source and available under the MIT License.

## 📞 Support

For issues related to:
- **Scripts**: Open a GitHub issue
- **Confluent Platform**: Check [Confluent Documentation](https://docs.confluent.io/)
- **Cluster Linking**: See [Cluster Linking Guide](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/index.html)

---
