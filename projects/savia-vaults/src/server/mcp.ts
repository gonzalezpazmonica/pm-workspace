import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { VaultStorage } from '../storage/index.js';
import { SearchEngine } from '../search/index.js';
import { VaultSecurity } from '../security/index.js';
import type { VaultConfig } from '../types.js';
import * as fs from 'node:fs';
import * as path from 'node:path';

export class MCPVaultServer {
  private config: VaultConfig;
  private storage: VaultStorage;
  private search: SearchEngine;
  private security: VaultSecurity;

  constructor(config: VaultConfig) {
    this.config = config;
    this.storage = new VaultStorage(config);
    this.search = new SearchEngine(config);
    this.security = new VaultSecurity(config);
    this.initVault();
  }

  private initVault(): void {
    const vp = this.config.path;
    fs.mkdirSync(vp, { recursive: true });
    if (!fs.existsSync(path.join(vp, 'INDEX.md'))) {
      fs.writeFileSync(path.join(vp, 'INDEX.md'), `# ${this.config.name}\n\n`);
    }
    if (!fs.existsSync(path.join(vp, 'MAP.md'))) {
      fs.writeFileSync(path.join(vp, 'MAP.md'), `# ${this.config.name} — Routing Map\n\n`);
    }
  }

  async start(): Promise<void> {
    const server = new Server(
      { name: 'savia-vaults', version: '0.2.0' },
      { capabilities: { tools: {} } }
    );

    server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'vault_read',
          description: 'Read a note by path. Returns content with frontmatter and tags.',
          inputSchema: {
            type: 'object',
            properties: { path: { type: 'string', description: 'Relative path to the note' } },
            required: ['path'],
          },
        },
        {
          name: 'vault_write',
          description: 'Create or update a note. Git-committed with content hash.',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Relative path for the note' },
              content: { type: 'string', description: 'Markdown content to write' },
              message: { type: 'string', description: 'Optional commit message' },
            },
            required: ['path', 'content'],
          },
        },
        {
          name: 'vault_search',
          description: 'Full-text search across vault notes with BM25 ranking.',
          inputSchema: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query' },
              maxResults: { type: 'number', description: 'Max results (default 10)' },
              pathPrefix: { type: 'string', description: 'Filter by path prefix' },
            },
            required: ['query'],
          },
        },
        {
          name: 'vault_list',
          description: 'List all notes in the vault as a directory tree.',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Optional subdirectory to list' },
            },
          },
        },
        {
          name: 'vault_stats',
          description: 'Vault statistics: note count, total size, commits.',
          inputSchema: { type: 'object', properties: {} },
        },
        {
          name: 'vault_index',
          description: 'Rebuild the search index.',
          inputSchema: { type: 'object', properties: {} },
        },
        {
          name: 'vault_diff',
          description: 'Show git diff for a note.',
          inputSchema: {
            type: 'object',
            properties: { path: { type: 'string' } },
            required: ['path'],
          },
        },
        {
          name: 'vault_log',
          description: 'Show git history for a note.',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string' },
              maxCount: { type: 'number', description: 'Max entries (default 20)' },
            },
            required: ['path'],
          },
        },
        {
          name: 'vault_tags',
          description: 'List all tags with occurrence counts.',
          inputSchema: { type: 'object', properties: {} },
        },
      ],
    }));

    server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const name = request.params.name;
      const args = (request.params.arguments || {}) as Record<string, unknown>;
      try {
        switch (name) {
          case 'vault_read': {
            const note = await this.storage.read(args.path as string);
            return {
              content: [{
                type: 'text',
                text: JSON.stringify({ path: note.path, name: note.name, frontmatter: note.frontmatter, tags: note.tags, content: note.content }, null, 2),
              }],
            };
          }
          case 'vault_write': {
            const receipt = await this.storage.write(args.path as string, args.content as string, args.message as string);
            return {
              content: [{ type: 'text', text: JSON.stringify(receipt, null, 2) }],
            };
          }
          case 'vault_search': {
            this.search.buildIndex();
            const results = this.search.search({
              query: args.query as string,
              maxResults: (args.maxResults as number) || 10,
              pathPrefix: args.pathPrefix as string | undefined,
            });
            return {
              content: [{ type: 'text', text: JSON.stringify(results, null, 2) }],
            };
          }
          case 'vault_list': {
            const files = await this.storage.list();
            const prefix = args.path as string | undefined;
            const filtered = prefix ? files.filter(f => f.startsWith(prefix)) : files;
            return {
              content: [{ type: 'text', text: JSON.stringify(filtered, null, 2) }],
            };
          }
          case 'vault_stats': {
            const stats = await this.storage.stats();
            return {
              content: [{ type: 'text', text: JSON.stringify(stats, null, 2) }],
            };
          }
          case 'vault_index': {
            this.search.buildIndex();
            const tags = this.search.getTags();
            return {
              content: [{ type: 'text', text: `Index rebuilt. ${tags.size} unique tags indexed.` }],
            };
          }
          case 'vault_diff': {
            const diff = await this.storage.diff(args.path as string);
            return {
              content: [{ type: 'text', text: diff || '(no changes)' }],
            };
          }
          case 'vault_log': {
            const log = await this.storage.log(args.path as string, (args.maxCount as number) || 20);
            return {
              content: [{ type: 'text', text: JSON.stringify(log, null, 2) }],
            };
          }
          case 'vault_tags': {
            this.search.buildIndex();
            const tags = this.search.getTags();
            return {
              content: [{ type: 'text', text: JSON.stringify([...tags.entries()], null, 2) }],
            };
          }
          default:
            return { content: [{ type: 'text', text: `Unknown tool: ${name}` }], isError: true };
        }
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        return { content: [{ type: 'text', text: `Error: ${msg}` }], isError: true };
      }
    });

    const transport = new StdioServerTransport();
    await server.connect(transport);
  }
}
