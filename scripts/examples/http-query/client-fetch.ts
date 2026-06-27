// HTTP QUERY client examples — RFC 10008
// Uses native fetch() available in Node.js 18+ and all modern browsers

/**
 * Send an HTTP QUERY request with JSON body.
 * RFC 10008 — seguro, idempotente, cacheable, con body.
 */
async function queryResource(url: string, criteria: object): Promise<unknown> {
  const response = await fetch(url, {
    method: 'QUERY',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(criteria),
  });

  if (!response.ok) {
    throw new Error(`QUERY failed: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

// Example usage
async function main() {
  const results = await queryResource('http://localhost:3000/search', {
    status: 'active',
    tags: ['production'],
    limit: 10,
  });
  console.log('QUERY results:', results);
}

// Axios example (when axios.query() is available — axios >= 2026-04-28):
// import axios from 'axios';
// const results = await axios.query('/api/search', {
//   data: { status: 'active', tags: ['production'], limit: 100 }
// });

// axios fallback for older versions:
// const results = await axios.request({
//   method: 'QUERY',
//   url: '/api/search',
//   data: { status: 'active', tags: ['production'] },
// });

main().catch(console.error);
