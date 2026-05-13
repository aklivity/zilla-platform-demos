# Zilla Platform RAG Pipeline Demo

A production-shaped RAG pipeline demonstrating how **Zilla eliminates custom middleware** for AI applications — no Kafka producer code, no SSE server, no auth middleware, no tier-routing logic. Every infrastructure concern is declared in `zilla.yaml`; the AI services contain pure AI logic.

---

## What problems Zilla solves

| Problem                                                     | How Zilla solves it                                                                                     |
|-------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| Clients need to write to Kafka without a Kafka SDK          | `http-kafka` produce — `POST /chunks` and `POST /queries` write to Kafka over plain HTTPS               |
| LLM responses are slow — HTTP connections time out          | Async pipeline: client gets `204` immediately, streams the answer via SSE when ready                    |
| Bad data corrupts the vector store and wastes API calls     | Inline schema validation rejects malformed chunks `400` at the gateway before they enter Kafka          |
| Users must not see documents above their access tier        | Gateway extracts JWT `roles`, stamps `user-tier` as a Kafka header — the client body cannot override it |
| Enterprise results must never leak to standard streams      | `sse-kafka` header filter: result `tier` must match the caller's JWT identity before delivery           |
| Retried ingestion creates duplicate embeddings              | `Idempotency-Key` becomes the Kafka message key — same key, same partition, no duplicate processing     |
| Every AI service needs its own Kafka producer and auth code | Zilla owns the HTTP↔Kafka boundary — AI services only read and write Kafka topics                       |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                             Zilla Platform                               │
│                                                                          │
│  POST /chunks   ──► http-kafka (produce) ──► rag.chunks topic            │
│                      key = ${idempotencyKey}                             │
│                      schema: chunk_schema (inline catalog)               │
│                                                                          │
│  POST /queries  ──► http-kafka (produce) ──► rag.queries topic           │
│                      key = ${idempotencyKey}                             │
│                      overrides:                                          │
│                        user-tier = ${guarded['authn_jwt'].identity}      │
│                                    ↑ JWT roles claim, set by Zilla       │
│                                                                          │
│  GET /results/{queryId}                                                  │
│    ──► sse (server)                                                      │
│      ──► sse-kafka (proxy)                                               │
│            filters:                                                      │
│              headers:                                                    │
│                tier = ${guarded['authn_jwt'].identity}                   │
│                       ↑ only delivers results matching caller's JWT      │
│                                                                          │
│       JWT guard · Inline schema validation · SASL/SCRAM                  │
└──────────────────────────────────────────────────────────────────────────┘
         │                    │                    ▲
    rag.chunks           rag.queries          rag.results
    (schema              (header:             (header:
     validated)           user-tier)           tier)
         │                    │                    │
         ▼                    ▼                    │
   ┌──────────┐       ┌──────────────┐             │
   │ Embedder │       │  RAG Chain   │─────────────┘
   │          │       │              │
   │ OpenAI   │       │ reads        │
   │ embed    │       │ user-tier    │
   │    ↓     │       │ from header  │
   │ Qdrant   │◄──────│ Qdrant search│
   │ upsert   │  vec  │ + vis filter │
   └──────────┘ search└──────┬───────┘
                             │
                          OpenAI LLM (gpt-4o-mini)
```

### Tier flow — end to end

```
-H "Authorization: Bearer $TOKEN_ENT"       (JWT roles: "enterprise")
  → Zilla validates JWT
  → overrides: user-tier = "enterprise"      (Kafka message header)
  → RAG chain: hdrs.get("user-tier") = "enterprise"
  → Qdrant filter: visibility IN [public, internal, confidential]
  → result produced: headers = {tier: "enterprise"}
  → sse-kafka filter: tier == JWT identity   → delivered to enterprise stream only
```

The client never declares their tier. It is extracted from the JWT by Zilla and injected as a Kafka header — tamper-proof.

---

## Services (Data Plane)

| Service           | Image                                     | Role                                                         |
|-------------------|-------------------------------------------|--------------------------------------------------------------|
| `gateway`         | `ghcr.io/aklivity/zilla-platform/gateway` | Protocol mediation, JWT auth, schema validation, SSE         |
| `kafka`           | `bitnamilegacy/kafka:3.5`                 | Event backbone (KRaft, SASL_PLAINTEXT)                       |
| `schema-registry` | `confluentinc/cp-schema-registry:8.1.0`   | JSON schema storage for downstream consumers                 |
| `kafka-init`      | `bitnamilegacy/kafka:3.5`                 | One-shot: topics, schemas, ACLs, quotas                      |
| `gateway-init`    | `eclipse-temurin:17-jdk`                  | One-shot: self-signed TLS certificates                       |
| `qdrant`          | `qdrant/qdrant:v1.12.0`                   | Vector store for semantic retrieval                          |
| `embedder`        | `python:3.12-slim`                        | Consumes `rag.chunks` → OpenAI Embeddings → Qdrant upsert    |
| `rag-chain`       | `python:3.12-slim`                        | Consumes `rag.queries` → vector search → LLM → `rag.results` |

### What each AI service does

**Embedder** — reads every document chunk that arrives on `rag.chunks`, asks OpenAI to turn the text into a list of 1536 numbers (a vector), and stores that vector in Qdrant alongside the original text and `visibility` label. Similar text gets similar numbers, so similar chunks become neighbours in Qdrant. Runs once per chunk. Knows nothing about queries or users.

**Qdrant** — a vector database. Stores every chunk's vector and metadata. When the RAG chain searches it, it finds the chunks whose vectors are numerically closest to the query vector — which means closest in meaning. The tier visibility filter ensures a `standard` user's search never touches `confidential` points.

**RAG chain** — the AI core. Reads a query from `rag.queries`, reads the `user-tier` Kafka header (set by Zilla from the JWT), embeds the question, searches Qdrant with a visibility filter, builds a context from the retrieved chunks, calls the LLM with that context, and writes the answer to `rag.results` with a `tier` header.

---

## Prerequisites

* **Docker Engine** `24.0+`
* **Docker Compose** plugin `2.34.0+`
* At least **4 vCPUs** and **4 GB RAM**
* A valid **Zilla Platform License**
* **Python 3.x** (for `gen_token.py`)
* An **OpenAI API key**

---

## Get a License

Request a license key at https://www.aklivity.io/request-access, then set it in your `.env`:

```
ZILLA_PLATFORM_LICENSE_KEY=<license>
```

If the license is missing or invalid, you'll see:

```
License is invalid, contact support@aklivity.io to request a new license
```

---

## Setup

### 1. Start Zilla Platform

```bash
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart up --wait
```

Once ready, open the **Zilla Platform Management Console** at http://localhost:8081/

The first time you open the console, complete the one-time admin registration.
See the [Admin Onboarding guide](https://docs.aklivity.io/zilla-platform/latest/platform/getting-started/admin-onboarding/).

### 2. Create `.env`

```bash
cat > .env <<'EOF'
OPENAI_API_KEY=sk-...
ZILLA_PLATFORM_LICENSE_KEY=
ZILLA_PLATFORM_VERSION=latest
LLM_MODEL=gpt-4o-mini
KAFKA_SASL_USER=admin
KAFKA_SASL_PASSWORD=admin-secret
KAFKA_PRODUCER_USER=producer-app
KAFKA_PRODUCER_PASSWORD=producer-secret
KAFKA_CONSUMER_USER=consumer-app
KAFKA_CONSUMER_PASSWORD=consumer-secret
EOF
```

### 3. Start the stack

```bash
docker compose up --wait
```

---

## Generate test JWT tokens

```bash
pip install pyjwt cryptography

TOKEN_FREE=$(python3 gen_token.py free-user@example.com free)
TOKEN_STD=$(python3 gen_token.py std-user@example.com standard)
TOKEN_ENT=$(python3 gen_token.py ent-user@example.com enterprise)
```

Two JWT claims serve different purposes:

| Claim   | Value                                    | Used by                                                             |
|---------|------------------------------------------|---------------------------------------------------------------------|
| `scope` | `"proxy:publish proxy:stream"`           | Zilla JWT guard — authorises the HTTP routes                        |
| `roles` | `"standard"` / `"enterprise"` / `"free"` | Zilla `identity` → Kafka `user-tier` header → RAG chain tier filter |

---

## Running the demo

The gateway listens on **HTTPS port 7143** (TLS/HTTP2, self-signed cert). Use `-k` for local dev.

### Step 1 — Ingest document chunks

```bash
# Public chunk — visible to all tiers
curl -k -s -o /dev/null -w "%{http_code}\n" \
  -X POST https://localhost:7143/chunks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_STD" \
  -H "Idempotency-Key: chunk-0" \
  -d '{
    "doc_id": "zilla-overview", "chunk_index": 0,
    "text": "Zilla is a multi-protocol edge gateway for Kafka.",
    "visibility": "public"
  }'
# → 204

# Internal chunk — standard + enterprise only
curl -k -s -o /dev/null -w "%{http_code}\n" \
  -X POST https://localhost:7143/chunks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_STD" \
  -H "Idempotency-Key: chunk-1" \
  -d '{
    "doc_id": "zilla-overview", "chunk_index": 1,
    "text": "Zilla Platform publishes governed API Data Products with versioning and self-service subscriptions.",
    "visibility": "internal"
  }'
# → 204

# Confidential chunk — enterprise only
curl -k -s -o /dev/null -w "%{http_code}\n" \
  -X POST https://localhost:7143/chunks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ENT" \
  -H "Idempotency-Key: chunk-2" \
  -d '{
    "doc_id": "zilla-overview", "chunk_index": 2,
    "text": "Zilla Plus includes Secure Public Access, AWS MSK integration, and virtual Kafka clusters.",
    "visibility": "confidential"
  }'
# → 204
```

Watch the embedder process them:

```bash
docker compose logs -f embedder
# Upserted 3 points
```

### Step 2 — Schema validation (shift-left)

```bash
# Missing required field "chunk_index" — rejected at the gateway, never enters Kafka
curl -k -s -o /dev/null -w "%{http_code}\n" \
  -X POST https://localhost:7143/chunks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_STD" \
  -H "Idempotency-Key: chunk-bad" \
  -d '{"doc_id": "test", "text": "missing chunk_index"}'
# → 400  (embedder logs stay silent — message never entered Kafka)
```

### Step 3 — Query and SSE result streaming

No `user_tier` in the body — the tier is extracted from the JWT by Zilla.

**Terminal A — open the SSE stream:**

```bash
curl -k -N \
  -H "Authorization: Bearer $TOKEN_STD" \
  "https://localhost:7143/results/q-std-1"
```

**Terminal B — submit the query:**

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  -X POST https://localhost:7143/queries \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_STD" \
  -H "Idempotency-Key: q-std-1" \
  -d '{"query_id": "q-std-1", "question": "What is Zilla?"}'
# → 204
```

Terminal A receives the answer. RAG chain log shows:

```
query_id=q-std-1 user=anonymous roles=['standard'] vis=['public', 'internal']
```

### Step 4 — Tier-based access

```bash
# Terminal A — enterprise SSE stream
curl -k -N -H "Authorization: Bearer $TOKEN_ENT" "https://localhost:7143/results/q-ent-1"

# Terminal B — enterprise query
curl -k -X POST https://localhost:7143/queries \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ENT" \
  -H "Idempotency-Key: q-ent-1" \
  -d '{"query_id": "q-ent-1", "question": "What are Zilla Plus features?"}'
# → Terminal A receives richer answer including confidential chunk
```

### Step 5 — Cross-tier isolation

Standard SSE stream open. Enterprise query submitted. Standard stream receives nothing.

```bash
# Terminal A — standard user waiting
curl -k -N -H "Authorization: Bearer $TOKEN_STD" "https://localhost:7143/results/q-cross-1"

# Terminal B — enterprise user submits same query ID
curl -k -X POST https://localhost:7143/queries \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_ENT" \
  -H "Idempotency-Key: q-cross-1" \
  -d '{"query_id": "q-cross-1", "question": "What is Zilla?"}'

# Terminal A stays silent — sse-kafka filter blocks enterprise result from standard stream
# Terminal C — enterprise user opens their own stream (receives immediately)
curl -k -N -H "Authorization: Bearer $TOKEN_ENT" "https://localhost:7143/results/q-cross-1"
```

### Step 6 — Tamper test

```bash
# Standard token — client tries to claim enterprise tier in body
# Zilla ignores the body field; stamps tier from JWT identity
curl -k -X POST https://localhost:7143/queries \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_STD" \
  -H "Idempotency-Key: q-tamper-1" \
  -d '{"query_id": "q-tamper-1", "question": "What is Zilla?", "user_tier": "enterprise"}'

# RAG chain log: roles=['standard']  ← Zilla stamped from JWT, body ignored
```

---

## Explore in the Zilla Platform Console

The Zilla Platform console gives live visibility into the Kafka cluster and Gateway — no separate tooling needed.

### Kafka topics

Navigate to: **Environments → `QuickStart Environment` → Services → `QuickStart Kafka` → Topics**

You'll see the three RAG topics:

| Topic         | What you'll see in Messages                                               |
|---------------|---------------------------------------------------------------------------|
| `rag.chunks`  | Ingested document chunks, schema-validated JSON, key = `Idempotency-Key`  |
| `rag.queries` | Submitted questions with `user-tier` header stamped by Zilla from the JWT |
| `rag.results` | LLM answers with `tier` header, key = `query_id`                          |

Click into any topic → **Messages** to inspect the message in real time as you run the demo steps.

### Consumer groups

Navigate to: **Environments → `QuickStart Environment` → Services → `QuickStart Kafka` → Consumer Groups**

| Group               | Consumes      | What lag means                                   |
|---------------------|---------------|--------------------------------------------------|
| `embedder-service`  | `rag.chunks`  | Non-zero lag = embedder still processing chunks  |
| `rag-chain-service` | `rag.queries` | Non-zero lag = RAG chain still answering queries |

---

## API reference

| Endpoint             | Method    | JWT scope       | Description                                                                                        |
|----------------------|-----------|-----------------|----------------------------------------------------------------------------------------------------|
| `/chunks`            | POST      | `proxy:publish` | Ingest a document chunk. Schema validated by Zilla. `Idempotency-Key` deduplicates.                |
| `/queries`           | POST      | `proxy:publish` | Submit a question. Zilla injects `user-tier` Kafka header from JWT. No `user_tier` in body needed. |
| `/results/{queryId}` | GET (SSE) | `proxy:stream`  | SSE stream filtered by `tier` header matching caller's JWT identity.                               |

### Chunk payload schema (enforced at the HTTP edge)

```json
{
  "doc_id":      "string (required)",
  "chunk_index": "integer (required)",
  "text":        "string, max 4096 chars (required)",
  "source_url":  "string (optional)",
  "visibility":  "public | internal | confidential  (default: internal)",
  "metadata":    "object (optional)"
}
```

### Query payload schema

```json
{
  "query_id":  "string (optional — falls back to Idempotency-Key)",
  "question":  "string, max 2048 chars (required)",
  "top_k":     "integer 1–20 (optional)",
  "user_id":   "string (optional)"
}
```

> Do not include `user_tier` in the query body. It is injected by Zilla from the JWT and any body field is ignored.

### Visibility tiers

| JWT `roles`  | Kafka `user-tier` header | Qdrant visibility filter             | SSE receives            |
|--------------|--------------------------|--------------------------------------|-------------------------|
| `free`       | `free`                   | `public` only                        | free results only       |
| `standard`   | `standard`               | `public`, `internal`                 | standard results only   |
| `enterprise` | `enterprise`             | `public`, `internal`, `confidential` | enterprise results only |

### Result payload

```json
{
  "query_id":    "q-std-1",
  "answer":      "Zilla is a multi-protocol edge gateway...",
  "sources":     [{"doc_id": "zilla-overview", "chunk_index": 0, "source_url": "...", "score": 0.91}],
  "model":       "gpt-4o-mini",
  "latency_ms":  1240,
  "user_id":     "std-user@example.com",
  "user_tier":   "standard",
  "token_usage": {"prompt_tokens": 312, "completion_tokens": 87, "total_tokens": 399}
}
```

---

## Kafka topics

| Topic         | Partitions | Key               | Notable header         | Written by | Read by   |
|---------------|------------|-------------------|------------------------|------------|-----------|
| `rag.chunks`  | 4          | `Idempotency-Key` | —                      | Zilla      | Embedder  |
| `rag.queries` | 4          | `Idempotency-Key` | `user-tier` (from JWT) | Zilla      | RAG chain |
| `rag.results` | 4          | `query_id`        | `tier`                 | RAG chain  | Zilla SSE |

---

## Key Zilla config reference

| Capability               | `zilla.yaml` snippet                                         |
|--------------------------|--------------------------------------------------------------|
| JWT validation           | `guards.authn_jwt` with RSA + EC keys                        |
| Identity extraction      | `identity: "roles"` → `${guarded['authn_jwt'].identity}`     |
| Tier injection           | `overrides: user-tier: ${guarded['authn_jwt'].identity}`     |
| Inline schema validation | `catalogs.rag_schemas` with `chunk_schema` + `query_schema`  |
| Idempotent produce       | `key: ${idempotencyKey}` on produce routes                   |
| SSE streaming            | `sse_server` → `sse_kafka_mapping`                           |
| Tier-filtered delivery   | `filters: - headers: tier: ${guarded['authn_jwt'].identity}` |
| SASL/SCRAM               | `sasl: mechanism: scram-sha-512` on `kafka_client`           |

---

## Tear down

Stop everything (keeps volumes for next run):

```bash
docker compose down && \
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down
```

Full reset — wipe all data (re-ingestion required):

```bash
docker compose down -v --remove-orphans && \
docker compose -f oci://ghcr.io/aklivity/zilla-platform/quickstart down --volumes --remove-orphans
```

---
