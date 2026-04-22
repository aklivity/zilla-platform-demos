# Kafka Migration with Zilla Platform

This demo shows how to add flexibility to your Kafka architecture using Zilla Platform.

It demonstrates how teams can migrate between different Kafka flavors — such as Confluent, Apache Kafka, AutoMQ, and Redpanda — without changing client code, security settings, or schemas.

Zilla Platform sits in front of your Kafka clusters as a governed API gateway. It exposes a single stable endpoint for producers and consumers, allowing the backend Kafka cluster to be swapped out transparently. MirrorMaker replicates data between clusters during the transition, and Zilla Platform redeploys the same API Product to the new cluster when you are ready to cut over.

## Migration Use Cases

| Use Case                 | Source       | Target       | Docker Profile | Guide                                                 |
|--------------------------|--------------|--------------|----------------|-------------------------------------------------------|
| Confluent → Apache Kafka | Confluent    | Apache Kafka | `confluent`    | [README](README.MigrateFromConfluentToApacheKafka.md) |
| Apache Kafka → AutoMQ    | Apache Kafka | AutoMQ       | `automq`       | [README](README.MigrateFromApacheKafkaToAutoMQ.md)    |
| Apache Kafka → Redpanda  | Apache Kafka | Redpanda     | `redpanda`     | [README](README.MigrateFromApacheKafkaToRedpanda.md)  |

## Prerequisites

* **Docker Engine** `24.0+`
* **Docker Compose** plugin `2.34.0+`
* At least **4 vCPUs** and **4 GB RAM**
* A valid **Zilla Platform License**

## How It Works

Each migration follows the same pattern:

1. Start both the **source** and **target** Kafka clusters alongside a Zilla Platform Gateway
2. **MirrorMaker** continuously replicates topics from source to target
3. An **AsyncAPI** contract is extracted from the source cluster's topics and Schema Registry
4. A **Data Product** is created and initially deployed against the source cluster
5. Producers and consumers connect via Zilla Platform — they are unaware of the backend cluster
6. Replication is verified on the target cluster
7. The Data Product is **redeployed** to the target cluster with no client changes required
8. The source cluster deployment is removed

Refer to the individual migration guides above for step-by-step instructions.
