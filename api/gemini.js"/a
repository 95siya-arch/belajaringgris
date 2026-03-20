// ============================================================
//  api/gemini.js — Secure Gemini API Proxy
//  
//  This runs on Vercel's servers. Your GEMINI_API_KEY 
//  stays on the server — students can never see it.
//
//  Set your key in Vercel:
//  Dashboard → Your Project → Settings → Environment Variables
//  Name: GEMINI_API_KEY
//  Value: your key from aistudio.google.com
// ============================================================

const GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

// Simple rate limiting — prevent abuse
const requestCounts = new Map();
const RATE_LIMIT = 30;        // max requests per window per IP
const RATE_WINDOW = 60 * 1000; // 1 minute window

function isRateLimited(ip) {
  const now = Date.now();
  const entry = requestCounts.get(ip) || { count: 0, start: now };
  if (now - entry.start > RATE_WINDOW) {
    requestCounts.set(ip, { count: 1, start: now });
    return false;
  }
  if (entry.count >= RATE_LIMIT) return true;
  entry.count++;
  requestCounts.set(ip, entry);
  return false;
}

export default async function handler(req, res) {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // CORS — only allow requests from your own domain
  const origin = req.headers.origin || '';
  const allowed = [
    'https://belajaringgris.id',
    'https://www.belajaringgris.id',
    'https://belajaringgris.vercel.app',
    'http://localhost:3000',
    'http://127.0.0.1:5500'   // VS Code Live Server for local testing
  ];
  if (allowed.some(a => origin.startsWith(a)) || origin === '') {
    res.setHeader('Access-Control-Allow-Origin', origin || '*');
  } else {
    return res.status(403).json({ error: 'Forbidden' });
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Rate limiting
  const ip = req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown';
  if (isRateLimited(ip)) {
    return res.status(429).json({ error: 'Too many requests. Please wait a moment.' });
  }

  // Check API key is configured
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ 
      error: 'Gemini API key not configured. Add GEMINI_API_KEY in Vercel environment variables.' 
    });
  }

  // Get prompt and maxTokens from request body
  const { prompt, maxTokens = 1200 } = req.body;
  if (!prompt || typeof prompt !== 'string') {
    return res.status(400).json({ error: 'Missing prompt' });
  }
  if (prompt.length > 8000) {
    return res.status(400).json({ error: 'Prompt too long' });
  }

  // Call Gemini
  try {
    const response = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          maxOutputTokens: Math.min(maxTokens, 2000), // cap at 2000
          temperature: 0.7
        }
      })
    });

    const data = await response.json();

    if (data.error) {
      console.error('Gemini error:', data.error);
      return res.status(502).json({ error: data.error.message || 'Gemini API error' });
    }

    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
    return res.status(200).json({ text });

  } catch (err) {
    console.error('Gemini proxy error:', err);
    return res.status(500).json({ error: 'Server error calling Gemini' });
  }
}
