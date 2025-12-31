# CalTrac Gemini API Worker

Cloudflare Worker that securely proxies requests to Google's Gemini API for food image analysis.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Login to Cloudflare:
   ```bash
   npx wrangler login
   ```

3. Add your Gemini API key as a secret:
   ```bash
   npx wrangler secret put GEMINI_API_KEY
   ```
   Then paste your Gemini API key when prompted.

4. Deploy the worker:
   ```bash
   npm run deploy
   ```

5. Note your worker URL (e.g., `https://caltrac-gemini-api.<your-subdomain>.workers.dev`)

6. Update the `gemini_service.dart` in the Flutter app with your worker URL.

## Local Development

```bash
npm run dev
```

## API Usage

POST to your worker URL with:
```json
{
  "image": "<base64-encoded-image>",
  "mimeType": "image/jpeg"
}
```

Response:
```json
{
  "food_name": "Grilled Chicken Salad",
  "calories": 350,
  "protein": 35,
  "carbs": 15,
  "fat": 18,
  "serving_size": "1 plate",
  "confidence": "high",
  "notes": "Includes mixed greens, cherry tomatoes, and olive oil dressing"
}
```
