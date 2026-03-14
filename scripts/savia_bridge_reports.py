"""
Report endpoints for Savia Bridge.

Generates mock/calculated report data for the savia-web dashboard.
Each function returns a dict matching the TypeScript types in
projects/savia-web/src/types/reports.ts.
"""
import datetime
import math
import random

random.seed(42)

_TEAM = ["Alice", "Bob", "Carol", "Dave", "Eve"]
_SPRINTS = [f"Sprint 2026-{i:02d}" for i in range(1, 8)]


def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _wrap(project_id: str, data: dict) -> dict:
    return {
        "project": project_id,
        "generated_at": _now_iso(),
        "data": data,
    }


def velocity(project_id: str, sprints: int = 5) -> dict:
    items = []
    for s in _SPRINTS[-sprints:]:
        planned = random.randint(30, 50)
        completed = planned - random.randint(0, 12)
        items.append({"name": s, "planned": planned, "completed": completed})
    return _wrap(project_id, {"sprints": items})


def burndown(project_id: str) -> dict:
    total = random.randint(35, 50)
    days_list = []
    today = datetime.date.today()
    sprint_start = today - datetime.timedelta(days=today.weekday())
    sprint_days = 10
    remaining = total
    for i in range(sprint_days):
        d = sprint_start + datetime.timedelta(days=i)
        ideal = round(total * (1 - i / (sprint_days - 1)), 1)
        if i > 0:
            done = random.randint(1, 5)
            remaining = max(0, remaining - done)
        days_list.append({
            "date": d.isoformat(),
            "ideal": ideal,
            "actual": remaining,
        })
    return _wrap(project_id, {
        "sprintName": _SPRINTS[-1],
        "days": days_list,
    })


def dora(project_id: str) -> dict:
    return _wrap(project_id, {
        "deployFrequency": {
            "value": round(random.uniform(2, 8), 1),
            "unit": "deploys/week",
            "trend": random.choice(["up", "stable", "down"]),
        },
        "leadTime": {
            "value": round(random.uniform(1.5, 6), 1),
            "unit": "days",
            "trend": random.choice(["up", "stable", "down"]),
        },
        "changeFailureRate": {
            "value": round(random.uniform(2, 18), 1),
            "unit": "%",
            "trend": random.choice(["up", "stable", "down"]),
        },
        "mttr": {
            "value": round(random.uniform(0.5, 4), 1),
            "unit": "hours",
            "trend": random.choice(["up", "stable", "down"]),
        },
    })


def team_workload(project_id: str) -> dict:
    members = []
    for name in _TEAM:
        cap = random.choice([30, 35, 40])
        assigned = random.randint(20, 48)
        members.append({
            "name": name,
            "capacity": cap,
            "assigned": assigned,
        })
    return _wrap(project_id, {"members": members})


def quality(project_id: str) -> dict:
    return _wrap(project_id, {
        "coverage": round(random.uniform(65, 95), 1),
        "coverageTarget": 80,
        "bugs": [
            {"severity": "Critical", "count": random.randint(0, 3)},
            {"severity": "High", "count": random.randint(1, 6)},
            {"severity": "Medium", "count": random.randint(3, 12)},
            {"severity": "Low", "count": random.randint(5, 20)},
        ],
        "escapeRate": round(random.uniform(1, 8), 1),
    })


def debt(project_id: str) -> dict:
    trend = []
    base = random.randint(15, 30)
    today = datetime.date.today()
    for i in range(12):
        d = today - datetime.timedelta(weeks=12 - i)
        base += random.randint(-3, 4)
        base = max(5, base)
        trend.append({"date": d.isoformat(), "count": base})
    items = [
        {"title": "Refactor AuthService", "age": 45, "severity": "High", "effort": "8h"},
        {"title": "Remove deprecated API v1", "age": 90, "severity": "Medium", "effort": "13h"},
        {"title": "Upgrade ORM to v8", "age": 30, "severity": "High", "effort": "5h"},
        {"title": "Fix N+1 in OrderRepository", "age": 15, "severity": "Critical", "effort": "3h"},
        {"title": "Add indexes to logs table", "age": 60, "severity": "Low", "effort": "2h"},
    ]
    return _wrap(project_id, {"trend": trend, "topItems": items})


def cycle_time(project_id: str, sprints: int = 5) -> dict:
    items = []
    for s in _SPRINTS[-sprints:]:
        ct = round(random.uniform(2, 7), 1)
        lt = round(ct + random.uniform(1, 4), 1)
        items.append({"name": s, "cycleTime": ct, "leadTime": lt})
    return _wrap(project_id, {"sprints": items})


def portfolio() -> dict:
    projects = [
        {"name": "Backend API", "health": "healthy", "velocity": 42, "coverage": 87, "debt": 12, "satisfaction": 8.5},
        {"name": "Mobile App", "health": "at-risk", "velocity": 28, "coverage": 72, "debt": 23, "satisfaction": 7.2},
        {"name": "Web Portal", "health": "healthy", "velocity": 35, "coverage": 81, "debt": 8, "satisfaction": 8.0},
        {"name": "Data Pipeline", "health": "critical", "velocity": 15, "coverage": 55, "debt": 31, "satisfaction": 6.1},
    ]
    return {
        "project": "all",
        "generated_at": _now_iso(),
        "data": {"projects": projects},
    }
