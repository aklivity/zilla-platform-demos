# Kafka to AutoMQ via Zilla Platform

## Prerequisites

* **Docker Engine** `24.0+`
* **Docker Compose** plugin `2.34.0+`
* At least **4 vCPUs** and **4 GB RAM**
* A valid **Zilla Platform License**

## Get a License

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

## Start the Zilla Platform

### Launch the Quickstart Platform

```bash
export ZILLA_PLATFORM_LICENSE_KEY=<license>
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart up --wait
```

Open the Management Console:

http://localhost:8081/

## Admin Onboarding

[Follow the onboarding guide](https://docs.aklivity.io/zilla-platform/latest/platform/getting-started/admin-onboarding/). Complete setup for your organization and initial environment.

## Setup Data Plane

After completing your admin onboarding, follow the [guide here](https://docs.aklivity.io/zilla-platform/latest/platform/environments/) to create an Environment and generate Bootstrap token required to attach Gateway with Platform.

::: info
Creating an environment generates the `ZILLA_PLATFORM_BOOTSTRAP_TOKEN`, which is later used to launch and attach the Zilla Platform Gateway.
:::

### Start the Environment

The **compose.yaml** is a ready-to-run sandbox that bundles:

- A **Zilla Platform Gateway**
- A **Kafka Cluster**
- A **AutoMQ Cluster**
- A **Schema Registry**
- **Mirrormaker** Service (**Kafka** → **AutoMQ**)

Before starting the environment, export your license and bootstrap credentials:

```
export ZILLA_PLATFORM_LICENSE_KEY=<your-license-key>
export ZILLA_PLATFORM_BOOTSTRAP_TOKEN=<your-bootstrap-token>
```

Start the environment and wait for all services to become ready:

```bash
docker compose up --wait
```

You should now have a TLS enabled Zilla Platform Gateway running using the generated certificates.

### Attach Kafka & AutoMQ Cluster to Zilla Platform

### Attach Kafka Cluster

Add a Kafka service with:

```
kafka.env.data.plane.net:9092
```

Schema Registry:

```
http://schema-registry.env.data.plane.net:8081
```

### Attach AutoMQ Cluster

Add another Kafka service with AutoMQ Cluster:

```
automq.env.data.plane.net:9095
```

Schema Registry:

```
http://schema-registry.env.data.plane.net:8081
```

More details: https://docs.aklivity.io/zilla-platform/latest/platform/environments/services/kafka/

## Build API Product

### Workspace

Create a workspace to organize projects. Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/design/workspaces/).

### Create a Project

Choose a name and protocol (Kafka). Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/design/workspaces/projects/).

### Extract a Spec

Generate an API spec from Kafka topics and schemas. Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/design/workspaces/projects/extract/).

### Create an API Catalog

Organize API Products and Plans. Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/).

### Create a Plan

Define rate limits and security (API Key). Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/plans/).

### Create an API Product

Name it:

```
Orders API
```

(The Gateway routing expects this name.)

Select workspace, project, spec, and configure server settings. Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/api-products/).

Example:

```
Kafka Bootstrap Server: {server}.staging.platform.net:9094
Schema Registry URL: https://{server}.staging.platform.net:8081
```

### Deploy the Product

Deploy the API Product to a server. Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/api-products/deploy/).

### Create an Application

Create an application to obtain:

- API Key
- Secret Key

Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/consume/apps/).

## Consume API Product

Once your API Product is deployed, you can interact with it using a Kafka client to produce and consume events securely. This section walks you through setting up a Kafka client, connecting with the credentials generated from your application, and verifying message flow through the Zilla Platform.

### Kafka Client Properties

You can find TLS & SASL information under:

`APIs & Apps → Applications → [application] → Connection Guide → Credentials → Kafka Client Properties`

This configuration enables secure TLS communication and authenticates the client using your API key and secret key.

You can find Kafka Bootstrap server & Schema Registry URL under:

`APIs & Apps → Applications → [application] → Connection Guide → Connection Endpoints`

### Producing and Consuming Events

Export API Key, Secret Key, Kafka bootstrap server & Schema Registry URL:

```
export ACCESS_KEY="<API_KEY>"
export SECRET_KEY="<SECRET_KEY>"

export KAFKA_BOOTSTRAP_SERVER="<KAFKA_BOOTSTRAP_SERVER>"
export SCHEMA_REGISTRY_URL="<SCHEMA_REGISTRY_URL>"
```

Use the following commands to produce and consume event from your API Product.

#### Producer

```
echo '{"orderId":"test-123","status":"created","timestamp":1234567890000}' | \
docker compose \
  run --rm kafka-tools \
  kafka-json-schema-console-producer \
  --bootstrap-server ${KAFKA_BOOTSTRAP_SERVER} \
  --topic orders.created \
  --producer-property security.protocol=SASL_SSL \
  --producer-property sasl.mechanism=PLAIN \
  --producer-property sasl.jaas.config="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${ACCESS_KEY}\" password=\"${SECRET_KEY}\";" \
  --producer-property ssl.truststore.location=/etc/tls/client/trust.jks \
  --producer-property ssl.truststore.password=generated \
  --property schema.registry.url=${SCHEMA_REGISTRY_URL} \
  --property schema.registry.ssl.truststore.location=/etc/tls/client/trust.jks \
  --property schema.registry.ssl.truststore.password=generated \
  --property basic.auth.credentials.source=USER_INFO \
  --property schema.registry.basic.auth.user.info="${ACCESS_KEY}:${SECRET_KEY}" \
  --property auto.register.schemas=false \
  --property use.latest.version=true \
  --property value.schema.file=/etc/schemas/orders.schema.json  
```

#### Consumer

```
docker compose \
  run --rm kafka-tools \
  kafka-json-schema-console-consumer \
  --bootstrap-server ${KAFKA_BOOTSTRAP_SERVER} \
  --topic orders.created \
  --from-beginning \
  --consumer-property security.protocol=SASL_SSL \
  --consumer-property sasl.mechanism=PLAIN \
  --consumer-property sasl.jaas.config="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${ACCESS_KEY}\" password=\"${SECRET_KEY}\";" \
  --consumer-property ssl.truststore.location=/etc/tls/client/trust.jks \
  --consumer-property ssl.truststore.password=generated \
  --property schema.registry.url=${SCHEMA_REGISTRY_URL} \
  --property schema.registry.ssl.truststore.location=/etc/tls/client/trust.jks \
  --property schema.registry.ssl.truststore.password=generated \
  --property basic.auth.credentials.source=USER_INFO \
  --property schema.registry.basic.auth.user.info="${ACCESS_KEY}:${SECRET_KEY}"
```

#### Produce Invalid Events

```bash  
echo '{"orderId":"test-123","status":"created"}' | \
docker compose \
  run --rm kafka-init \
  '/opt/bitnami/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server ${KAFKA_BOOTSTRAP_SERVER} \
      --topic orders.created \
      --producer-property security.protocol=SASL_SSL \
      --producer-property sasl.mechanism=PLAIN \
      --producer-property sasl.jaas.config="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"'"${ACCESS_KEY}"'\" password=\"'"${SECRET_KEY}"'\";" \
      --producer-property ssl.truststore.location=/etc/tls/client/trust.jks \
      --producer-property ssl.truststore.password=generated'
```

Since the timestamp field is missing, this event does not comply with the registered schema and will be rejected by the Zilla Gateway before reaching Kafka.

##### Expected Output

```
org.apache.kafka.common.InvalidRecordException: This record has failed the validation on broker and hence will be rejected.
```

## Stop the Stack

To stop Quickstart environment:

```
docker compose down
```

To stop the Zilla Platform but keep all data:

```text
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down
```

Wipe all persisted data and start fresh:

```text
docker compose down --volumes --remove-orphans
```

```text
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down --volumes --remove-orphans
```
