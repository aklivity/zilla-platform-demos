# Kafka to AutoMQ via Zilla Platform

This demo shows how to migrate from Apache Kafka to AutoMQ using Zilla Platform, without changing client code, security settings, or schemas.

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
export ZILLA_PLATFORM_LICENSE_KEY=<license>
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart up --wait
```

Open the Management Console:

http://localhost:8081/

Complete admin onboarding:

[Follow the onboarding guide](https://docs.aklivity.io/zilla-platform/latest/platform/getting-started/admin-onboarding/). 

Complete setup for your organization and initial environment.

## Step 3: Create Environment and Setup Data Plane

Create an Environment and generate a bootstrap token(`ZILLA_PLATFORM_BOOTSTRAP_TOKEN`): 

Follow the [guide here](https://docs.aklivity.io/zilla-platform/latest/platform/environments/).

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

## Step 4: Attach Kafka Services

### Attach Apache Kafka Cluster

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

## Step 5: Build an API Product

1. Create a [Workspace](https://docs.aklivity.io/zilla-platform/latest/api/design/workspaces/)
2. Create a [Project](https://docs.aklivity.io/zilla-platform/latest/api/design/workspaces/projects/) (Kafka protocol)
3. Extract an [AsyncAPI spec from Kafka topics](https://docs.aklivity.io/zilla-platform/latest/api/design/workspaces/projects/extract/)
4. Create an [API Catalog](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/) and [Plan](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/plans/)
5. Create an [API Product](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/api-products/) 
   1. Name(The Gateway routing expects this name for this demo. If you want to configure another name update `aliases` for `gateway` service in compose):
       ```
       Orders API
       ```
   2. Select workspace, project, spec, and configure server settings:

       ```
       Kafka Bootstrap Server: {server}.staging.platform.net:9094
       Schema Registry URL: https://{server}.staging.platform.net:8082
       ```

## Step 6: Deploy the API Product (Apache Kafka)

Deploy the API Product to a server. Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/publish/api-catalog/api-products/deploy/).

Select `Kafka` as the target service.

## Step 7: Deploy the API Product (AutoMQ)

Create another version `1.0.0` of the Spec (`Workspaces → [Workspace Name] → [Project Name] → Spec → Update version → Save`).

Under `API Catalog → [catalog] → [API product] → New Version` add newly created version and deploy the API Product.

## Step 8: Create Applications

Create an application to obtain, Follow Guide [here](https://docs.aklivity.io/zilla-platform/latest/api/consume/apps/).:

- API Key
- Secret Key

* Select version `0.1.0` for Apache Kafka.
* Select version `1.0.0` for AutoMQ.

### Consume API Product

Once your API Product is deployed, you can interact with it using a Kafka client to produce and consume events securely.

Switching between Kafka and AutoMQ is controlled by the application you are consuming.

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

## Stop the Stack

To stop the environment:

```
docker compose down
```

To stop the Zilla Platform but keep all data:

```text
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down
```

To stop the services & wipe all persisted data:

```text
docker compose down --volumes --remove-orphans
```

```text
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down --volumes --remove-orphans
```
