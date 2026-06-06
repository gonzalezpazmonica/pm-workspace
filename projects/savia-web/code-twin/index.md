---
total_modules: 8
total_token_cost: 2720
last_full_sync: "2026-06-06T10:00:00Z"
---
# Code Twin Index — savia-web

| module_id | layer | path | provides | tokens |
|-----------|-------|------|----------|--------|
| TechStack | cross-cutting | meta/tech-stack.md | Vue3,Pinia,Vite,TypeScript | 200 |
| DomainEntities | domain | domain/entities.md | SpecItem,PbiItem,TaskItem | 380 |
| ApiRoutes | api | api/routes.md | Bridge,/backlog,/auth | 400 |
| FrontendStores | frontend | frontend/stores.md | useAuthStore,useBacklogStore | 460 |
| FrontendComposables | frontend | frontend/composables.md | useBridge,useSSE | 280 |
| FrontendRouter | frontend | frontend/router.md | routes,guards | 250 |
| AuthService | application | application/auth-service.md | login,logout,getProfile | 420 |
| DbSchema | infrastructure | infrastructure/db/schema.md | users,projects,tasks | 330 |
