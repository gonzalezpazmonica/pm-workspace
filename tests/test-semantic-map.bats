#!/usr/bin/env bats
# BATS tests for scripts/semantic-map.sh
# SPEC: SPEC-SEMANTIC-CONTEXT-MAPS

SCRIPT="scripts/semantic-map.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export TEST_OUTPUT_DIR="$BATS_TEST_TMPDIR/smap-output"
  mkdir -p "$TEST_OUTPUT_DIR"

  # ── TypeScript mock file (>50 lines) ──────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/UserService.ts" << 'TSEOF'
import { Injectable } from '@nestjs/common';
import { UserRepository } from './user.repository';
import { CacheService } from '../cache/cache.service';
import { EventBus } from '../events/event-bus';
import { z } from 'zod';

export interface IUserService {
  createUser(dto: CreateUserDto): Promise<User>;
  findById(id: string): Promise<User | null>;
}

export type CreateUserDto = {
  name: string;
  email: string;
  role?: Role;
};

export class UserService implements IUserService {
  constructor(
    private readonly repo: UserRepository,
    private readonly cache: CacheService,
    private readonly eventBus: EventBus,
  ) {}

  async createUser(dto: CreateUserDto): Promise<User> {
    const validated = userSchema.parse(dto);
    const user = await this.repo.save(validated);
    await this.cache.set(`user:${user.id}`, user);
    this.eventBus.emit('UserCreated', { userId: user.id });
    return user;
  }

  async findById(id: string): Promise<User | null> {
    const cached = await this.cache.get(`user:${id}`);
    if (cached) return cached;
    const user = await this.repo.findOne(id);
    if (user) await this.cache.set(`user:${id}`, user);
    return user;
  }

  async updateUser(id: string, dto: Partial<CreateUserDto>): Promise<User> {
    const user = await this.repo.update(id, dto);
    await this.cache.invalidate(`user:${id}`);
    this.eventBus.emit('UserUpdated', { userId: id });
    return user;
  }

  async deleteUser(id: string): Promise<void> {
    await this.repo.delete(id);
    await this.cache.invalidate(`user:${id}`);
    this.eventBus.emit('UserDeleted', { userId: id });
  }

  export const userSchema = z.object({
    name: z.string().min(1),
    email: z.string().email(),
    role: z.enum(['admin', 'user', 'viewer']).optional(),
  });
}

export function createDefaultUser(): User {
  return { id: '', name: 'Default', email: 'default@example.com' };
}

export enum Role {
  Admin = 'admin',
  User = 'user',
  Viewer = 'viewer',
}

// Internal helpers (not exported)
function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function generateId(): string {
  return Math.random().toString(36).substring(2, 15);
}

// More implementation details
const DEFAULT_CACHE_TTL = 3600;
const MAX_RETRIES = 3;

function retryOperation<T>(fn: () => Promise<T>, retries: number): Promise<T> {
  return fn().catch(err => {
    if (retries <= 0) throw err;
    return retryOperation(fn, retries - 1);
  });
}
TSEOF

  # ── Short TypeScript file (<50 lines) ─────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/constants.ts" << 'SHORTEOF'
export const MAX_USERS = 100;
export const DEFAULT_ROLE = 'user';
export const API_VERSION = 'v1';

export type Config = {
  maxUsers: number;
  defaultRole: string;
};
SHORTEOF

  # ── C# mock file (>50 lines) ──────────────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/OrderService.cs" << 'CSEOF'
using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using OrderApp.Domain.Models;
using OrderApp.Domain.Repositories;
using OrderApp.Infrastructure.Cache;

namespace OrderApp.Application.Services
{
    public class OrderService : IOrderService
    {
        private readonly IOrderRepository _repository;
        private readonly ICacheService _cache;
        private readonly ILogger<OrderService> _logger;

        public OrderService(
            IOrderRepository repository,
            ICacheService cache,
            ILogger<OrderService> logger)
        {
            _repository = repository;
            _cache = cache;
            _logger = logger;
        }

        public async Task<Order> CreateOrderAsync(CreateOrderDto dto)
        {
            _logger.LogInformation("Creating order for customer {Id}", dto.CustomerId);
            var order = new Order(dto);
            await _repository.SaveAsync(order);
            await _cache.SetAsync($"order:{order.Id}", order);
            return order;
        }

        public async Task<Order?> GetByIdAsync(Guid id)
        {
            var cached = await _cache.GetAsync<Order>($"order:{id}");
            if (cached != null) return cached;
            return await _repository.FindByIdAsync(id);
        }

        public async Task<bool> CancelOrderAsync(Guid id)
        {
            var order = await GetByIdAsync(id);
            if (order == null) return false;
            order.Cancel();
            await _repository.UpdateAsync(order);
            await _cache.RemoveAsync($"order:{id}");
            return true;
        }

        private void ValidateOrder(CreateOrderDto dto)
        {
            if (dto.Items == null || dto.Items.Count == 0)
                throw new ArgumentException("Order must have items");
        }

        private decimal CalculateTotal(List<OrderItem> items)
        {
            return items.Sum(i => i.Price * i.Quantity);
        }
    }

    public interface IOrderService
    {
        Task<Order> CreateOrderAsync(CreateOrderDto dto);
        Task<Order?> GetByIdAsync(Guid id);
        Task<bool> CancelOrderAsync(Guid id);
    }

    public record CreateOrderDto(Guid CustomerId, List<OrderItemDto> Items);
}
CSEOF

  # ── Python mock file (>50 lines) ──────────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/user_service.py" << 'PYEOF'
import logging
from typing import Optional, List
from dataclasses import dataclass
from abc import ABC, abstractmethod

from .repository import UserRepository
from .cache import CacheService
from .events import EventBus

logger = logging.getLogger(__name__)

MAX_RETRIES = 3
DEFAULT_TTL = 3600

@dataclass
class CreateUserDto:
    name: str
    email: str
    role: str = "user"

@dataclass
class UpdateUserDto:
    name: Optional[str] = None
    email: Optional[str] = None

class UserServiceBase(ABC):
    @abstractmethod
    def create_user(self, dto: CreateUserDto):
        pass

    @abstractmethod
    def find_by_id(self, user_id: str):
        pass

class UserService(UserServiceBase):
    def __init__(self, repo: UserRepository, cache: CacheService, bus: EventBus):
        self._repo = repo
        self._cache = cache
        self._bus = bus

    def create_user(self, dto: CreateUserDto):
        user = self._repo.save(dto)
        self._cache.set(f"user:{user.id}", user)
        self._bus.emit("UserCreated", user.id)
        return user

    def find_by_id(self, user_id: str):
        cached = self._cache.get(f"user:{user_id}")
        if cached:
            return cached
        return self._repo.find_one(user_id)

    def find_all(self) -> List:
        return self._repo.find_all()

    async def delete_user(self, user_id: str):
        await self._repo.delete(user_id)
        self._cache.invalidate(f"user:{user_id}")

    def update_user(self, user_id: str, dto: UpdateUserDto):
        user = self._repo.update(user_id, dto)
        self._cache.invalidate(f"user:{user_id}")
        return user

    def _validate_email(self, email: str) -> bool:
        return "@" in email

    def _generate_welcome(self, name: str) -> str:
        return f"Welcome {name}"

def create_default_service():
    return UserService(None, None, None)

# internal helper
def _hash_password(pwd):
    return pwd

def _sanitize_name(name):
    return name.strip()

def _normalize_role(role):
    return role.lower() if role else "user"

def _build_cache_key(prefix, user_id):
    return f"{prefix}:{user_id}"

class UserValidator:
    def validate_name(self, name):
        return len(name) > 0

    def validate_email(self, email):
        return "@" in email and "." in email

    def validate_role(self, role):
        return role in ("admin", "user", "viewer")
PYEOF

  # ── Go mock file (>50 lines) ──────────────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/handler.go" << 'GOEOF'
package handler

import (
	"context"
	"encoding/json"
	"net/http"

	"myapp/internal/service"
	"myapp/internal/repository"
)

type UserHandler struct {
	svc service.UserService
}

func NewUserHandler(svc service.UserService) *UserHandler {
	return &UserHandler{svc: svc}
}

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var dto CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&dto); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	user, err := h.svc.Create(r.Context(), dto)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(user)
}

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	user, err := h.svc.FindByID(r.Context(), id)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	json.NewEncoder(w).Encode(user)
}

type CreateUserRequest struct {
	Name  string `json:"name"`
	Email string `json:"email"`
}

func parseID(r *http.Request) string {
	return r.URL.Query().Get("id")
}

func writeJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
GOEOF

  # ── Rust mock file (>50 lines) ────────────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/service.rs" << 'RSEOF'
use std::sync::Arc;
use tokio::sync::Mutex;

use crate::repository::UserRepository;
use crate::cache::CacheService;
use crate::events::EventBus;

pub struct UserService {
    repo: Arc<dyn UserRepository>,
    cache: Arc<Mutex<CacheService>>,
    bus: EventBus,
}

pub trait UserServiceTrait {
    fn create_user(&self, dto: CreateUserDto) -> Result<User, Error>;
    fn find_by_id(&self, id: &str) -> Result<Option<User>, Error>;
}

pub enum Error {
    NotFound,
    Validation(String),
    Internal(String),
}

pub struct CreateUserDto {
    pub name: String,
    pub email: String,
}

impl UserService {
    pub fn new(repo: Arc<dyn UserRepository>, cache: Arc<Mutex<CacheService>>, bus: EventBus) -> Self {
        Self { repo, cache, bus }
    }

    pub async fn create_user(&self, dto: CreateUserDto) -> Result<User, Error> {
        let user = self.repo.save(dto).await?;
        let mut cache = self.cache.lock().await;
        cache.set(&format!("user:{}", user.id), &user);
        self.bus.emit("UserCreated", &user.id);
        Ok(user)
    }

    pub async fn find_by_id(&self, id: &str) -> Result<Option<User>, Error> {
        let cache = self.cache.lock().await;
        if let Some(user) = cache.get(&format!("user:{}", id)) {
            return Ok(Some(user));
        }
        self.repo.find_by_id(id).await
    }

    fn validate_email(email: &str) -> bool {
        email.contains('@')
    }
}

pub fn create_default_config() -> Config {
    Config { max_retries: 3, timeout_ms: 5000 }
}

pub const MAX_USERS: usize = 1000;
RSEOF

  # ── Java mock file (>50 lines) ────────────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/UserController.java" << 'JAVAEOF'
package com.example.controller;

import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Autowired;
import com.example.service.UserService;
import com.example.model.User;
import com.example.dto.CreateUserDto;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserService userService;

    @PostMapping
    public User createUser(@RequestBody CreateUserDto dto) {
        return userService.createUser(dto);
    }

    @GetMapping("/{id}")
    public Optional<User> getUser(@PathVariable Long id) {
        return userService.findById(id);
    }

    @GetMapping
    public List<User> listUsers() {
        return userService.findAll();
    }

    @DeleteMapping("/{id}")
    public void deleteUser(@PathVariable Long id) {
        userService.deleteById(id);
    }

    public record CreateUserDto(String name, String email, String role) {}

    private void validateRequest(CreateUserDto dto) {
        if (dto.name() == null || dto.name().isBlank()) {
            throw new IllegalArgumentException("Name required");
        }
    }

    private String sanitizeName(String name) {
        return name.trim().replaceAll("\\s+", " ");
    }

    // internal helper
    private boolean isAdmin(Long userId) {
        return userId != null && userId == 1L;
    }

    // Another padding line
    private void logAction(String action) {
        System.out.println("Action: " + action);
    }
}
JAVAEOF

  # ── Unsupported language file ─────────────────────────────────────────────
  cat > "$BATS_TEST_TMPDIR/schema.graphql" << 'GQLEOF'
type Query {
  user(id: ID!): User
  users: [User!]!
}

type User {
  id: ID!
  name: String!
  email: String!
  role: Role!
}

enum Role {
  ADMIN
  USER
  VIEWER
}

type Mutation {
  createUser(name: String!, email: String!): User!
  deleteUser(id: ID!): Boolean!
}

input CreateUserInput {
  name: String!
  email: String!
  role: Role
}

type Subscription {
  userCreated: User!
}

schema {
  query: Query
  mutation: Mutation
  subscription: Subscription
}

# Comments and more
directive @auth on FIELD_DEFINITION

type PageInfo {
  hasNext: Boolean!
  cursor: String
}

type UserEdge {
  node: User!
  cursor: String!
}

type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
}
GQLEOF

  # ── Empty file ────────────────────────────────────────────────────────────
  touch "$BATS_TEST_TMPDIR/empty.ts"
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
}

# ── Script integrity ──────────────────────────────────────────────────────────

@test "script exists" {
  [[ -f "$SCRIPT" ]]
}

@test "script starts with bash shebang" {
  head -1 "$SCRIPT" | grep -q '#!/usr/bin/env bash'
}

@test "script has set -uo pipefail" {
  head -20 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "script shows usage when no arguments" {
  run bash "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Usage"* ]]
}

# ── Auto language detection ───────────────────────────────────────────────────

@test "detects TypeScript from .ts extension" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"lang: ts"* ]]
}

@test "detects C# from .cs extension" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/OrderService.cs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"lang: cs"* ]]
}

@test "detects Python from .py extension" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/user_service.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"lang: py"* ]]
}

@test "detects Go from .go extension" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/handler.go"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"lang: go"* ]]
}

@test "detects Rust from .rs extension" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/service.rs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"lang: rs"* ]]
}

@test "detects Java from .java extension" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserController.java"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"lang: java"* ]]
}

# ── Happy path: TypeScript extraction ─────────────────────────────────────────

@test "TS: extracts export class" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"UserService"* ]]
}

@test "TS: extracts export interface" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"IUserService"* ]]
}

@test "TS: extracts export type" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"CreateUserDto"* ]]
}

@test "TS: extracts export function" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"createDefaultUser"* ]]
}

@test "TS: extracts export enum" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Role"* ]]
}

@test "TS: extracts dependencies" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Dependencies"* ]]
  [[ "$output" == *"cache"* ]]
}

@test "TS: contains Public Interface section" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"## Public Interface"* ]]
}

@test "TS: contains Semantic Map header" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Semantic Map"* ]]
}

@test "TS: detects architecture patterns" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Architecture Patterns"* ]]
}

@test "TS: detects extension points" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Extension Points"* ]]
}

# ── Short file bypass (SCM-01) ────────────────────────────────────────────────

@test "short file: outputs file as-is (no Semantic Map header)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/constants.ts"
  [[ "$status" -eq 0 ]]
  # Should NOT have Semantic Map header
  [[ "$output" != *"Semantic Map"* ]]
  # Should contain original content
  [[ "$output" == *"MAX_USERS"* ]]
  [[ "$output" == *"DEFAULT_ROLE"* ]]
}

@test "empty file: handled without error" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/empty.ts"
  [[ "$status" -eq 0 ]]
}

# ── Unsupported language fallback ─────────────────────────────────────────────

@test "fallback: unsupported language outputs fallback header" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/schema.graphql"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"fallback: true"* ]]
}

@test "fallback: includes content from file" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/schema.graphql"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Query"* ]]
}

# ── C# extraction ────────────────────────────────────────────────────────────

@test "CS: extracts public class" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/OrderService.cs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OrderService"* ]]
}

@test "CS: extracts public methods" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/OrderService.cs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"CreateOrderAsync"* ]]
}

@test "CS: extracts using dependencies" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/OrderService.cs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Dependencies"* ]]
}

@test "CS: extracts public interface" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/OrderService.cs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"IOrderService"* ]]
}

# ── Python extraction ─────────────────────────────────────────────────────────

@test "PY: extracts class definitions" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/user_service.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"UserService"* ]]
}

@test "PY: extracts function definitions" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/user_service.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"create_user"* ]]
}

@test "PY: extracts import dependencies" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/user_service.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"logging"* ]]
}

# ── Go extraction ─────────────────────────────────────────────────────────────

@test "GO: extracts exported functions (uppercase)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/handler.go"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"NewUserHandler"* ]]
}

@test "GO: extracts exported types" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/handler.go"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"UserHandler"* ]]
}

@test "GO: extracts import dependencies" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/handler.go"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"net/http"* ]]
}

# ── Rust extraction ───────────────────────────────────────────────────────────

@test "RS: extracts pub struct" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/service.rs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"UserService"* ]]
}

@test "RS: extracts pub trait" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/service.rs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"UserServiceTrait"* ]]
}

@test "RS: extracts pub fn" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/service.rs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"create_default_config"* ]]
}

@test "RS: extracts use dependencies" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/service.rs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"tokio"* ]]
}

# ── Java extraction ───────────────────────────────────────────────────────────

@test "JAVA: extracts public class" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserController.java"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"UserController"* ]]
}

@test "JAVA: extracts public methods" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserController.java"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"createUser"* ]]
}

@test "JAVA: extracts import dependencies" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserController.java"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"springframework"* ]]
}

# ── Cache functionality ───────────────────────────────────────────────────────

@test "cache: writes .smap file to output dir" {
  run bash "$SCRIPT" --output-dir "$TEST_OUTPUT_DIR" "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  # Should have created a .smap file
  local smap_count
  smap_count=$(find "$TEST_OUTPUT_DIR" -name "*.smap" | wc -l)
  [[ "$smap_count" -ge 1 ]]
}

@test "cache: second run serves from cache (fast)" {
  # First run: generate
  bash "$SCRIPT" --output-dir "$TEST_OUTPUT_DIR" "$BATS_TEST_TMPDIR/UserService.ts" > /dev/null

  # Second run: should be from cache
  local start_time
  start_time=$(date +%s%N 2>/dev/null || date +%s)
  run bash "$SCRIPT" --output-dir "$TEST_OUTPUT_DIR" "$BATS_TEST_TMPDIR/UserService.ts"
  local end_time
  end_time=$(date +%s%N 2>/dev/null || date +%s)

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Semantic Map"* ]]

  # If nanosecond resolution available, check <500ms (generous for CI)
  if [[ "$start_time" =~ [0-9]{10,} ]]; then
    local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
    [[ "$elapsed_ms" -lt 500 ]]
  fi
}

@test "cache: same content produces same hash" {
  bash "$SCRIPT" --output-dir "$TEST_OUTPUT_DIR" "$BATS_TEST_TMPDIR/UserService.ts" > /dev/null

  # Copy file to different name
  cp "$BATS_TEST_TMPDIR/UserService.ts" "$BATS_TEST_TMPDIR/UserServiceCopy.ts"
  local dir2="$BATS_TEST_TMPDIR/smap-output2"
  mkdir -p "$dir2"
  bash "$SCRIPT" --output-dir "$dir2" "$BATS_TEST_TMPDIR/UserServiceCopy.ts" > /dev/null

  # Both should produce .smap files with the same hash prefix
  local hash1 hash2
  hash1=$(ls "$TEST_OUTPUT_DIR"/*.smap | head -1 | xargs basename | sed 's/.smap//')
  hash2=$(ls "$dir2"/*.smap | head -1 | xargs basename | sed 's/.smap//')
  [[ "$hash1" == "$hash2" ]]

  rm -rf "$dir2"
}

# ── Language override ─────────────────────────────────────────────────────────

@test "lang override: --lang ts forces TypeScript parsing" {
  # Rename a TS file to .txt
  cp "$BATS_TEST_TMPDIR/UserService.ts" "$BATS_TEST_TMPDIR/UserService.txt"
  run bash "$SCRIPT" --lang ts "$BATS_TEST_TMPDIR/UserService.txt"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"lang: ts"* ]]
  [[ "$output" == *"UserService"* ]]
}

# ── Multiple files ────────────────────────────────────────────────────────────

@test "multiple files: processes all and separates with ---" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts" "$BATS_TEST_TMPDIR/OrderService.cs"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"UserService"* ]]
  [[ "$output" == *"OrderService"* ]]
  [[ "$output" == *"---"* ]]
}

# ── Performance ───────────────────────────────────────────────────────────────

@test "performance: single file completes in <2s" {
  local start_time
  start_time=$(date +%s)
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/UserService.ts"
  local end_time
  end_time=$(date +%s)
  local elapsed=$(( end_time - start_time ))

  [[ "$status" -eq 0 ]]
  [[ "$elapsed" -lt 2 ]]
}

# ── Nonexistent file ──────────────────────────────────────────────────────────

@test "nonexistent file: returns error" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/does-not-exist.ts"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"not found"* ]]
}

# ── Max tokens option ─────────────────────────────────────────────────────────

@test "max-tokens: respects --max-tokens flag" {
  # With very small token limit, output should be truncated
  run bash "$SCRIPT" --max-tokens 50 "$BATS_TEST_TMPDIR/UserService.ts"
  [[ "$status" -eq 0 ]]
  # Output should be relatively short (50 tokens ~ 200 chars)
  local char_count
  char_count=$(printf '%s' "$output" | wc -c)
  [[ "$char_count" -lt 400 ]]
}
