# DB Schema — fixture-project

## Table: users
| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| email | varchar | false |
| password_hash | varchar | false |
| roles | jsonb | false |
| disabled | boolean | false |
| last_login_at | timestamp | true |
| created_at | timestamp | false |

## Table: orders
| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| user_id | uuid | false |
| total | decimal | false |
| status | varchar | false |
| notes | text | true |
| created_at | timestamp | false |
