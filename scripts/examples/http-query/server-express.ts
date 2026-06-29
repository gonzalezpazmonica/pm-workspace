import express from 'express';

const app = express();
app.use(express.json());

// HTTP QUERY handler — RFC 10008
// Express supports QUERY with Node.js >= 21.7.2 (app.query is available)
(app as any).query('/search', (req: any, res: any) => {
  // req.body contains parsed JSON body (requires express.json() middleware)
  const criteria = req.body;
  res.setHeader('Accept-Query', 'application/json');
  res.json({ results: [], query: criteria });
});

// Fallback via app.all if app.query() is not available
app.all('/search-fallback', (req: any, res: any) => {
  if (req.method !== 'QUERY') {
    res.status(405).set('Allow', 'GET, QUERY, OPTIONS').end();
    return;
  }
  res.setHeader('Accept-Query', 'application/json');
  res.json({ results: [], query: req.body });
});

app.listen(3000, () => {
  console.log('Express QUERY server running on :3000');
  console.log('Test: curl -X QUERY http://localhost:3000/search \\');
  console.log('  -H "Content-Type: application/json" -d \'{"status":"active"}\'');
});
