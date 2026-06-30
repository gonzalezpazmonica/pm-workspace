"""
HTTP QUERY server example — FastAPI / Starlette (RFC 10008)

FastAPI does not yet have @app.query() decorator — workaround via api_route.
Run: uvicorn server-fastapi:app --reload --port 3001
"""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI(title="HTTP QUERY example", version="1.0.0")


@app.api_route('/search', methods=['QUERY'])
async def search(request: Request):
    """Handle HTTP QUERY request — RFC 10008."""
    if not request.headers.get('content-type'):
        return JSONResponse(status_code=400, content={'error': 'Content-Type required'})

    body = await request.json()
    return JSONResponse(
        content={'results': [], 'query': body},
        headers={'Accept-Query': 'application/json'},
    )


@app.get('/search')
async def search_get():
    """GET variant — returns resource description."""
    return {'message': 'Use QUERY method with a JSON body to search'}


if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=3001)
