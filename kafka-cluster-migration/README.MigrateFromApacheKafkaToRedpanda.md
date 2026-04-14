# Apache Kafka to Redpanda Migration with Zilla Platform

This demo shows how to add flexibility to your Kafka architecture using Zilla Platform.

It demonstrates how teams can migrate from Apache Kafka to Redpanda, without changing client code, security settings, or schemas.

## Migration Steps

* Start with **Apache Kafka** & **Redpanda** cluster
* Replicate data between clusters using **MirrorMaker**
* Generate **AsyncAPI** contracts from existing topics
* Create a governed **Data Product** for the event streams
* **Deploy** the Data Product on Apache Kafka
* **Redeploy** the same Data Product on Redpanda
* Move producers and consumers gradually, with **no downtime**

## Prerequisites

* **Docker Engine** `24.0+`
* **Docker Compose** plugin `2.34.0+`
* At least **4 vCPUs** and **4 GB RAM**
* A valid **Zilla Platform License**

## Step 1: Get a License

Request a license key:  
https://www.aklivity.io/request-access

Set the license in your environment:

```bash
export ZILLA_PLATFORM_LICENSE_KEY=<license>
```

If the license is missing or invalid:

```
License is invalid, contact support@aklivity.io to request a new license
```

## Step 2: Start Zilla Platform

### Launch the Quickstart Platform

```bash
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart up --wait
```

Open the Management Console:

http://localhost:8081/

Complete admin onboarding:

[Follow the onboarding guide](https://docs.aklivity.io/zilla-platform/latest/platform/getting-started/admin-onboarding/).

Complete setup for your organization and initial environment.

## Step 3: Setup Data Plane

### Start the Environment

The **compose.yaml** is a ready-to-run sandbox that bundles:

- A **Zilla Platform Gateway**
- An **Apache Kafka** Cluster
- A **Redpanda** Cluster
- A **Schema Registry**
- **MirrorMaker** Services (**Apache Kafka** → **Redpanda**)

Before starting the environment, export your license key:

```
export ZILLA_PLATFORM_LICENSE_KEY=<license>
```

Build the mirror-maker image:

```bash
docker compose build
```

Start the environment and wait for all services to become ready:

```bash
docker compose --profile redpanda up --wait
```

## Step 4: Attach Redpanda Cluster

Add a Kafka service with:

```
redpanda.env.data.plane.net:9096
```

## Step 5: Build an API Product

1. Extract an [AsyncAPI spec from Kafka topics](https://docs.aklivity.io/zilla-platform/latest/api/design/workspaces/projects/extract/)
2. Create an [API Product](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/api-products/)
   1. Name (The Gateway routing expects this name for this demo. If you want to configure another name update `aliases` for `gateway` service in compose):
       ```
       Orders API
       ```
   2. Select workspace, project, spec, and configure server settings:

       ```
       staging.platform.net:9094
       ```

## Step 6: Deploy the API Product (Apache Kafka)

Deploy the API Product to a server. Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/api-products/deploy/).

Select `Kafka` as the target service.

## Step 7: Consume the API Product

Create a Subscription for your Application to generate the credentials needed to access the deployed API Product.

- API Key
- Secret Key

Export API Key, Secret Key:

```
export ACCESS_KEY="<API_KEY>"
export SECRET_KEY="<SECRET_KEY>"
```

### Produce and Consume Events

You can find Kafka Bootstrap server & Schema Registry URL under:

`APIs & Apps → Applications → [application] → [Subscription] → Connection Guide`

Use the following commands to produce and consume events from your API Product.

#### Producer

```
echo '{"orderId":"test-123","status":"created","timestamp":1234567890000}' | \
docker compose \
  run --rm kafka-init \
  '/opt/bitnami/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server orders-api-v0.staging.platform.net:9094 \
      --topic orders.created \
      --producer-property security.protocol=SASL_SSL \
      --producer-property sasl.mechanism=PLAIN \
      --producer-property sasl.jaas.config="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"'"${ACCESS_KEY}"'\" password=\"'"${SECRET_KEY}"'\";" \
      --producer-property ssl.truststore.location=/etc/tls/client/trust.jks \
      --producer-property ssl.truststore.password=generated'
```

#### Consumer

```
docker compose \
  run --rm kafka-init \
  '/opt/bitnami/kafka/bin/kafka-console-consumer.sh \
      --bootstrap-server orders-api-v0.staging.platform.net:9094 \
      --topic orders.created \
      --from-beginning \
      --consumer-property security.protocol=SASL_SSL \
      --consumer-property sasl.mechanism=PLAIN \
      --consumer-property sasl.jaas.config="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"'"${ACCESS_KEY}"'\" password=\"'"${SECRET_KEY}"'\";" \
      --consumer-property ssl.truststore.location=/etc/tls/client/trust.jks \
      --consumer-property ssl.truststore.password=generated'
```

## Step 8: Verify Replication

Using Zilla Platform explore the topics on different Kafka services (Redpanda) to verify the messages are replicated.

`Environments → [Environment Name] → Services → [Service Name] → Topics → [orders.created] → Messages`

## Step 9: Remove Apache Kafka Deployment

Remove the Apache Kafka deployment:

`API Catalog → [catalog] → [API product] → Deployments → Remove`

## Step 10: Redeploy API Product on Redpanda

`API Catalog → [catalog] → [API product] → Deploy`

Select `Target service` as `Redpanda`.

Your clients continue working without any changes:
* Same bootstrap server
* Same API key and secret
* [Same produce/consume commands](#produce-and-consume-events)

## Stop the Stack

To stop the environment:

```
docker compose --profile redpanda down
```

To stop the Zilla Platform but keep all data:

```text
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down
```

To stop the services & wipe all persisted data:

```text
docker compose --profile redpanda down --volumes --remove-orphans
```

```text
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down --volumes --remove-orphans
```
