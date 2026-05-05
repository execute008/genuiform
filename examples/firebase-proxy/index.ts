// Firebase Cloud Function reference implementation for VertexProxyClient.
//
// Deploy with `firebase deploy --only functions:genuiformProxy`. The function:
//   1. Validates the Firebase Auth ID token in the Authorization header.
//   2. Forwards the genuiform payload to Vertex AI under its own service-account
//      credentials, keeping the GCP key off the client device.
//   3. Returns the Vertex response body verbatim.
//
// Expected payload (from VertexProxyClient.generate):
//   { systemPrompt, messages, responseSchema, model, temperature }

import { onRequest } from 'firebase-functions/v2/https';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { GoogleAuth } from 'google-auth-library';

initializeApp();

const PROJECT_ID = process.env.GCP_PROJECT_ID!;
const LOCATION = process.env.VERTEX_LOCATION ?? 'europe-west1';

const googleAuth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

export const genuiformProxy = onRequest(
  { region: LOCATION, cors: false, timeoutSeconds: 60 },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const authHeader = req.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      res.status(401).send('Missing bearer token');
      return;
    }

    try {
      await getAuth().verifyIdToken(token);
    } catch (err) {
      res.status(401).send('Invalid bearer token');
      return;
    }

    const { systemPrompt, messages, responseSchema, model, temperature } =
      req.body ?? {};
    if (!systemPrompt || !messages || !responseSchema || !model) {
      res.status(400).send('Missing required fields');
      return;
    }

    // Map Message.role wireValue to Vertex Gemini's role vocabulary.
    const contents = (messages as Array<{ role: string; content: string }>).map(
      (m) => ({
        role: m.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: m.content }],
      })
    );

    const url =
      `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}` +
      `/locations/${LOCATION}/publishers/google/models/${model}:streamGenerateContent`;

    const accessToken = await googleAuth.getAccessToken();

    let upstream: Response;
    try {
      upstream = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents,
          systemInstruction: { parts: [{ text: systemPrompt }] },
          generationConfig: {
            temperature: temperature ?? 0.7,
            responseMimeType: 'application/json',
            responseSchema,
          },
        }),
      });
    } catch (err) {
      res.status(502).send(`Vertex fetch failed: ${(err as Error).message}`);
      return;
    }

    const body = await upstream.text();
    res.status(upstream.status).type('application/json').send(body);
  }
);
