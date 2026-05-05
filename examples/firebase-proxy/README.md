# Firebase proxy for `VertexProxyClient`

A ~100-line TypeScript Cloud Function that lets shipped mobile apps call Vertex AI Gemini through `VertexProxyClient` without bundling GCP credentials.

## What it does

1. Validates the bearer token in the `Authorization` header as a Firebase Auth ID token.
2. Forwards the payload to Vertex AI's `:streamGenerateContent` endpoint under the function's own service account.
3. Returns the upstream response body verbatim — `VertexProxyClient` parses the same `[{candidates: [{content: {parts: [{text}]}}]}]` shape that `VertexDirectClient` already handles.

## Deploy

```bash
cd examples/firebase-proxy
npm install firebase-admin firebase-functions google-auth-library
firebase init functions  # if not already configured
firebase deploy --only functions:genuiformProxy
```

Set the project ID and location:

```bash
firebase functions:config:set vertex.location=europe-west1
# or, simpler — use environment vars in functions:
gcloud run services update genuiformproxy \
  --region=europe-west1 \
  --update-env-vars=GCP_PROJECT_ID=$YOUR_PROJECT,VERTEX_LOCATION=europe-west1
```

Grant the function's runtime service account the `roles/aiplatform.user` IAM role on the project.

## Use from Flutter

```dart
final client = VertexProxyClient(
  endpoint: 'https://europe-west1-$YOUR_PROJECT.cloudfunctions.net/genuiformProxy',
  authProvider: () async => await FirebaseAuth.instance.currentUser?.getIdToken(),
);
```

## Why a proxy?

`VertexDirectClient` requires a Vertex API key (or short-lived OAuth token) at the client. Embedding that in a shipped mobile app exposes it to extraction. The proxy keeps GCP credentials server-side and authenticates per-user via Firebase Auth — the standard pattern for mobile-first GCP apps.
