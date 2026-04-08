
## Get a License

Request a license key at https://www.aklivity.io/request-access, then set it in your environment:

```bash
export ZILLA_PLATFORM_LICENSE_KEY=<license>
```

If the license is missing or invalid, you'll see:

```
License is invalid, contact support@aklivity.io to request a new license
```

## Start the Zilla Platform

Pull and start the full platform stack — management console, control plane, Gateway, Kafka, and Schema Registry:

```bash
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart up --wait && \
docker compose up --wait
```

Once ready, open the [**Zilla Platform Management Console**](http://localhost:8081/) in your browser.

> **Note:** The Quickstart Environment is pre-created. The Gateway auto-registers via `ZILLA_PLATFORM_BOOTSTRAP_TOKEN`, giving you a TLS-enabled Gateway with auto-generated certificates.

## Admin Setup

The first time you open the console, complete the one-time admin registration to create your organization and initial environment.

See the [Admin Onboarding guide](/platform/getting-started/admin-onboarding/README.md) for step-by-step details.

## Publish an Event to Kafka

Generate a JWT with `proxy:publish` scope, then POST an event to the topic:

```bash
export JWT_TOKEN=$(jwt encode \
  --alg "RS256" \
  --kid "example" \
  --iss "https://auth.example.com" \
  --aud "https://api.example.com" \
  --sub "example" \
  --exp=+3000s \
  --no-iat \
  --payload "scope=proxy:publish" \
  --secret @private.pem)

curl -k -v -X POST \
  --cacert test-ca.crt \
  https://localhost:7143/orders.created \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"orderId":"test-123","status":"created","timestamp":1234567890000}'
```

## Stream Events via SSE

Generate a JWT with `proxy:stream` scope, then subscribe to the topic using Server-Sent Events:

```bash
export JWT_TOKEN=$(jwt encode \
  --alg "RS256" \
  --kid "example" \
  --iss "https://auth.example.com" \
  --aud "https://api.example.com" \
  --sub "example" \
  --exp=+3000s \
  --no-iat \
  --payload "scope=proxy:stream" \
  --secret @private.pem)

curl -v -N \
  --http2 \
  --cacert test-ca.crt \
  -H "Accept: text/event-stream" \
  "https://localhost:7143/orders.created?access_token=${JWT_TOKEN}"
```

## Stop the stack

Choose the appropriate command based on what you want to preserve.

Stop the data plane environment only (keeps platform data):

```bash
docker compose down
```

Stop the Zilla Platform (keeps all persisted data for next time):

```bash
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down
```

Wipe everything and start fresh (removes all volumes):

```bash
docker compose down --volumes --remove-orphans && \
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down --volumes --remove-orphans
```
