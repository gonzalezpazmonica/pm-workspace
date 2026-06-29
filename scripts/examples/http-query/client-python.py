"""HTTP QUERY client examples — RFC 10008"""
import asyncio
import httpx


async def query_resource(url: str, criteria: dict) -> dict:
    """Send HTTP QUERY request with body (RFC 10008).

    QUERY is safe, idempotent and cacheable — correct for read queries
    whose criteria don't fit in a URL query string.
    """
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method='QUERY',
            url=url,
            json=criteria,
            headers={'Content-Type': 'application/json'},
        )
        response.raise_for_status()
        return response.json()


def query_resource_sync(url: str, criteria: dict) -> dict:
    """Synchronous QUERY via httpx (for scripts/non-async contexts)."""
    with httpx.Client() as client:
        response = client.request(
            method='QUERY',
            url=url,
            json=criteria,
            headers={'Content-Type': 'application/json'},
        )
        response.raise_for_status()
        return response.json()


# requests library also supports custom methods:
# import requests
# response = requests.request(
#     'QUERY', 'http://localhost:3000/search',
#     json={'status': 'active', 'limit': 10},
#     headers={'Content-Type': 'application/json'},
# )


async def main():
    results = await query_resource(
        'http://localhost:3000/search',
        {'status': 'active', 'tags': ['production'], 'limit': 10},
    )
    print('QUERY results:', results)


if __name__ == '__main__':
    asyncio.run(main())
