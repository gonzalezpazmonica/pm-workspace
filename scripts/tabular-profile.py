#!/usr/bin/env python3
"""
tabular-profile.py — Statistical profiling for tabular data (SE-296 + SE-324).

Reads CSV/TSV/JSON from stdin or file, and .xlsx via optional openpyxl, and
produces a JSON summary with:
- Column types (numeric, categorical, datetime, text)
- Descriptive statistics (mean, median, std, quartiles for numeric)
- Top values for categorical
- Temporal trends for datetime
- Outlier detection (IQR method)
- Correlation matrix for numeric columns
- Token savings estimate
- [SE-324] Relations: candidate shared-key columns across tables (deterministic)

Usage:
  cat data.csv | python3 tabular-profile.py
  python3 tabular-profile.py data.csv
  python3 tabular-profile.py --sample 5000 data.csv
  python3 tabular-profile.py ventas.xlsx              # one profile per sheet
  python3 tabular-profile.py a.csv b.csv              # relations across files

Output format:
- Single table -> flat: {rows, columns, profiles, correlations, token_estimate}
  (backward compatible with SE-296 consumers).
- Multiple tables (multi-sheet xlsx or several files) -> {tables, relations}.
"""
import sys, json, csv, io, math, os
from collections import Counter
from datetime import datetime

MAX_SAMPLE = 10_000
TOKEN_BUDGET = 200
RELATION_SAMPLE = 2_000  # SE-324: cap de valores unicos por columna (AC-2.4)


class ExcelUnsupported(RuntimeError):
    """Raised when an .xlsx file is requested but openpyxl is not installed."""


def detect_type(values, count):
    """Classify column as numeric, categorical, datetime, or text."""
    non_null = [v for v in values if v and str(v).strip()]
    if len(non_null) < count * 0.5:
        return "text"

    sample = non_null[:min(50, len(non_null))]
    num_ok = 0
    date_ok = 0
    for v in sample:
        s = str(v).strip()
        try:
            float(s)
            num_ok += 1
            continue
        except (ValueError, TypeError):
            pass
        for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y-%m-%dT%H:%M:%S"):
            try:
                datetime.strptime(s, fmt)
                date_ok += 1
                break
            except ValueError:
                continue

    n = len(sample)
    if num_ok / n > 0.8:
        return "numeric"
    if date_ok / n > 0.8:
        return "datetime"
    if len(set(sample)) / n < 0.3 or n > 0:
        if len(set(non_null)) < 50:
            return "categorical"
    return "text"


def profile_numeric(values):
    """Compute descriptive statistics for numeric column."""
    nums = []
    for v in values:
        if v and str(v).strip():
            try:
                nums.append(float(v))
            except (ValueError, TypeError):
                pass
    if not nums:
        return {}

    n = len(nums)
    nums.sort()
    mean = sum(nums) / n
    median = nums[n // 2] if n % 2 else (nums[n // 2 - 1] + nums[n // 2]) / 2
    variance = sum((x - mean) ** 2 for x in nums) / (n - 1) if n > 1 else 0
    std = math.sqrt(variance)

    # Quartiles
    q1 = nums[n // 4]
    q3 = nums[3 * n // 4]
    iqr = q3 - q1

    # Outliers
    lower = q1 - 1.5 * iqr
    upper = q3 + 1.5 * iqr
    outliers = sum(1 for x in nums if x < lower or x > upper)

    # Skewness
    if std > 0:
        skew = sum((x - mean) ** 3 for x in nums) / (n * std ** 3) if n > 1 else 0
    else:
        skew = 0

    return {
        "mean": round(mean, 2),
        "median": round(median, 2),
        "std": round(std, 2),
        "min": round(nums[0], 2),
        "max": round(nums[-1], 2),
        "q25": round(q1, 2),
        "q75": round(q3, 2),
        "skewness": round(skew, 3),
        "outliers": outliers,
        "outlier_pct": round(100 * outliers / n, 1),
    }


def profile_categorical(values):
    """Compute frequency distribution for categorical column."""
    counts = Counter()
    nulls = 0
    for v in values:
        if v and str(v).strip():
            counts[str(v)] += 1
        else:
            nulls += 1
    top = counts.most_common(10)
    return {
        "unique": len(counts),
        "top_values": [{"value": v, "count": c} for v, c in top],
        "nulls": nulls,
    }


def profile_datetime(values):
    """Detect temporal trend and range."""
    dates = []
    for v in values:
        if v and str(v).strip():
            s = str(v).strip()
            for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y-%m-%dT%H:%M:%S"):
                try:
                    dates.append(datetime.strptime(s, fmt))
                    break
                except ValueError:
                    continue
    if len(dates) < 2:
        return {}

    dates.sort()
    min_d = dates[0]
    max_d = dates[-1]
    span = (max_d - min_d).days

    # Simple linear trend: check if values are increasing/decreasing over time
    # We use ordinal position as proxy for trend
    mid = len(dates) // 2
    first_half_avg = sum(d.timestamp() for d in dates[:mid]) / mid
    second_half_avg = sum(d.timestamp() for d in dates[mid:]) / (len(dates) - mid)
    diff = second_half_avg - first_half_avg

    if abs(diff) < 1:
        trend = "uniform"
    elif diff > 0:
        trend = "ascending"
    else:
        trend = "descending"

    return {
        "min": min_d.strftime("%Y-%m-%d"),
        "max": max_d.strftime("%Y-%m-%d"),
        "span_days": span,
        "count": len(dates),
        "trend": trend,
    }


def correlation(xs, ys):
    """Pearson correlation coefficient."""
    n = len(xs)
    if n < 2:
        return 0
    mx = sum(xs) / n
    my = sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    dy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if dx == 0 or dy == 0:
        return 0
    return round(num / (dx * dy), 3)


def read_xlsx(path, sample_size):
    """Read an .xlsx workbook: one table per sheet. SE-324.

    Requires openpyxl (optional dependency). Uses data_only=True so formula
    cells yield their cached computed values, not the formula text (AC-1.2).
    Raises ExcelUnsupported if openpyxl is missing (AC-1.4).
    """
    try:
        import openpyxl
    except ImportError:
        raise ExcelUnsupported(
            "Excel no soportado en este entorno: falta openpyxl"
        )

    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    tables = []
    try:
        for ws in wb.worksheets:
            rows_iter = ws.iter_rows(values_only=True)
            header = next(rows_iter, None)
            if header is None:
                continue
            cols = [str(h).strip() if h is not None else f"col{i+1}"
                    for i, h in enumerate(header)]
            data = []
            for row in rows_iter:
                if all(c is None for c in row):
                    continue
                data.append({cols[i]: (row[i] if i < len(row) else None)
                             for i in range(len(cols))})
                if sample_size and len(data) >= sample_size:
                    break
            if data:
                tables.append({"name": ws.title or "Sheet", "rows": data})
    finally:
        wb.close()
    return tables


def read_tables(sources, sample_size):
    """Read one or more sources into a list of {name, rows, source, sheet?}."""
    tables = []
    for source in sources:
        if source in ("-", "", None):
            text = source if source and source not in ("-", "") else sys.stdin.read()
            if text.strip().startswith("["):
                records = json.loads(text)
                rows = records if sample_size is None else records[:sample_size]
                tables.append({"name": "stdin", "rows": rows, "source": "-"})
            else:
                reader = csv.DictReader(io.StringIO(text))
                rows = list(reader)
                if sample_size is not None:
                    rows = rows[:sample_size]
                tables.append({"name": "stdin", "rows": rows, "source": "-"})
            continue

        ext = os.path.splitext(source)[1].lower()
        if ext in (".xlsx", ".xlsm"):
            for t in read_xlsx(source, sample_size):
                t["source"] = source
                t["sheet"] = t["name"]
                tables.append(t)
        elif ext == ".json":
            with open(source, encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                data = [data]
            rows = data[:sample_size] if sample_size else data
            tables.append({"name": os.path.basename(source),
                           "rows": rows, "source": source})
        else:
            with open(source, newline="", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                rows = list(reader)
            if sample_size:
                rows = rows[:sample_size]
            tables.append({"name": os.path.basename(source),
                           "rows": rows, "source": source})
    return tables


def estimate_tokens(rows):
    """Estimate token count for raw data vs summary."""
    raw = sum(len(str(row)) for row in rows[:min(100, len(rows))])
    raw_total = int(raw / min(100, len(rows)) * len(rows))
    return {
        "raw": raw_total,
        "summary": TOKEN_BUDGET,
        "savings_pct": round(100 * (1 - TOKEN_BUDGET / max(raw_total, 1)), 1),
    }


def profile_table(name, rows, source=None, sheet=None):
    """Compute the flat statistical profile for a single table."""
    columns = list(rows[0].keys()) if rows else []
    column_data = {c: [row.get(c) for row in rows] for c in columns}
    n = len(rows)

    profiles = []
    numeric_data = {}
    for col in columns:
        values = column_data[col]
        ctype = detect_type(values, n)
        profile = {"name": col, "type": ctype, "count": n,
                   "nulls": sum(1 for v in values if not v or not str(v).strip()),
                   "unique": len(set(str(v) for v in values if v))}

        if ctype == "numeric":
            profile.update(profile_numeric(values))
            nums = [float(v) for v in values if v and str(v).strip()
                    if _is_numeric(v)]
            if len(nums) >= 0.5 * n:
                numeric_data[col] = nums
        elif ctype == "categorical":
            profile.update(profile_categorical(values))
        elif ctype == "datetime":
            profile.update(profile_datetime(values))

        profiles.append(profile)

    corrs = []
    num_cols = list(numeric_data.keys())
    for i in range(len(num_cols)):
        for j in range(i + 1, len(num_cols)):
            a, b = num_cols[i], num_cols[j]
            min_len = min(len(numeric_data[a]), len(numeric_data[b]))
            c = correlation(numeric_data[a][:min_len], numeric_data[b][:min_len])
            if abs(c) > 0.3:
                corrs.append({"col1": a, "col2": b, "coefficient": c})

    result = {
        "name": name,
        "rows": n,
        "columns": len(columns),
        "profiles": profiles,
        "correlations": sorted(corrs, key=lambda x: -abs(x["coefficient"]))[:10],
        "token_estimate": estimate_tokens(rows),
    }
    if source:
        result["source"] = source
    if sheet:
        result["sheet"] = sheet
    return result


def _norm(col):
    return str(col).strip().lower()


def _unique_values(rows, col, cap):
    """Capped set of unique non-empty string values for a column (AC-2.4)."""
    vals = set()
    for row in rows:
        v = row.get(col)
        if v is None or not str(v).strip():
            continue
        vals.add(str(v).strip())
        if len(vals) >= cap:
            break
    return vals


def detect_relations(tables):
    """Detect candidate shared-key columns between tables. SE-324 (Slice 2).

    Deterministic: candidate = same normalized column name AND value overlap
    > 0. Cost is O(n*m) over capped unique values per column (AC-2.4).
    Returns a list sorted for reproducibility (AC-2.3).
    """
    col_values = []
    for t in tables:
        if not t["rows"]:
            col_values.append({})
            continue
        cols = {}
        for col in list(t["rows"][0].keys()):
            cols[col] = _unique_values(t["rows"], col, RELATION_SAMPLE)
        col_values.append(cols)

    relations = []
    for i in range(len(tables)):
        for j in range(i + 1, len(tables)):
            ta, tb = tables[i], tables[j]
            for ca in col_values[i]:
                if _norm(ca) not in {_norm(cb) for cb in col_values[j]}:
                    continue
                for cb in col_values[j]:
                    if _norm(ca) != _norm(cb):
                        continue
                    inter = len(col_values[i][ca] & col_values[j][cb])
                    if inter == 0:
                        continue
                    denom = min(len(col_values[i][ca]), len(col_values[j][cb]))
                    overlap = round(100.0 * inter / denom, 1) if denom else 0.0
                    relations.append({
                        "table_a": ta["name"], "column_a": ca,
                        "table_b": tb["name"], "column_b": cb,
                        "overlap_pct": overlap,
                    })

    relations.sort(key=lambda r: (r["table_a"], r["column_a"],
                                  r["table_b"], r["column_b"]))
    return relations


def _is_numeric(v):
    try:
        float(v)
        return True
    except (TypeError, ValueError):
        return False


# ── L21 / SE-342 S5: predicción asistida local ──────────────────────────
# Decisión de la hypothesis l21: sklearn clásico local (PyCaret/AutoGluon
# evaluados en el roadmap Labs). Determinista (semilla fija), cero egress.
def run_predict(argv):
    """tabular-profile.py predict --target COL [--categorical] FILE

    Trains a local model (scikit-learn optional dependency) on one table,
    reports cross-validated metrics and registers the artifact in the L17
    catalog. Deterministic seed. Returns JSON."""
    import json as _json
    import os as _os

    target = None
    categorical = False
    files = []
    i = 0
    while i < len(argv):
        if argv[i] == "--target" and i + 1 < len(argv):
            target = argv[i + 1]; i += 2
        elif argv[i] == "--categorical":
            categorical = True; i += 1
        elif argv[i] in ("--help", "-h"):
            print("Usage: tabular-profile.py predict --target COL [--categorical] FILE")
            return 0
        else:
            files.append(argv[i]); i += 1

    if not target:
        print(_json.dumps({"error": "--target required"}), file=sys.stderr)
        return 2
    if not files:
        files = ["-"]

    try:
        tables = read_tables(files, MAX_SAMPLE)
    except ExcelUnsupported as exc:
        print(_json.dumps({"error": str(exc)}))
        return 1
    table = next((t for t in tables if t["rows"]), None)
    if table is None:
        print(_json.dumps({"error": "no data found"}))
        return 1
    rows = table["rows"]
    if len(rows) < 50:
        print(_json.dumps({"error": "dataset too small for prediction",
                           "rows": len(rows), "min": 50}))
        return 1
    cols = list(rows[0].keys()) if rows and isinstance(rows[0], dict) else []
    if target not in cols:
        print(_json.dumps({"error": f"target column '{target}' not in {cols}"}))
        return 1

    # Optional scikit-learn: degrade explicitly if missing.
    try:
        import numpy as np
        from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor
        from sklearn.model_selection import cross_validate, StratifiedKFold, KFold
    except ImportError as exc:
        print(_json.dumps({"error": "sklearn not installed — run: pip install scikit-learn",
                           "detail": str(exc)}))
        return 1

    # Deterministic numeric matrix; non-numeric features dropped, missing skipped.
    import statistics as _st
    feats = [c for c in cols if c != target and _is_numeric(rows[0].get(c))]
    X, y = [], []
    for r in rows:
        try:
            vals = [float(r.get(c, 0) or 0) for c in feats]
            tv = float(r[target])
        except (TypeError, ValueError, KeyError):
            continue
        X.append(vals); y.append(tv)
    if len(X) < 50:
        print(_json.dumps({"error": "too few usable rows", "rows": len(X)}))
        return 1

    X = np.array(X, dtype=float)
    y = np.array(y, dtype=float)
    rng = 42  # seed fija — determinismo (AC-5.5)
    if categorical:
        y = y.astype(int)
        model = GradientBoostingClassifier(random_state=rng)
        cv = StratifiedKFold(n_splits=3, shuffle=True, random_state=rng)
        cvout = cross_validate(model, X, y, cv=cv, scoring="accuracy",
                               return_train_score=True)
        metrics = {
            "task": "classification",
            "features": feats,
            "rows": int(len(X)),
            "accuracy_cv": float(_st.mean(cvout["test_score"])),
            "accuracy_train": float(_st.mean(cvout["train_score"])),
        }
    else:
        model = GradientBoostingRegressor(random_state=rng)
        cv = KFold(n_splits=3, shuffle=True, random_state=rng)
        cvout = cross_validate(model, X, y, cv=cv,
                               scoring={"rmse": "neg_root_mean_squared_error", "r2": "r2"})
        metrics = {
            "task": "regression",
            "features": feats,
            "rows": int(len(X)),
            "rmse_cv": float(-_st.mean(cvout["test_rmse"])),
            "r2_cv": float(_st.mean(cvout["test_r2"])),
        }

    feat_imp = sorted(zip(feats, model.fit(X, y).feature_importances_),
                      key=lambda p: -p[1])[:5]
    metrics["top_features"] = [{"feature": f, "importance": round(float(s), 4)}
                               for f, s in feat_imp]

    # Register artifact in L17 catalog (best-effort, never fails the command).
    # subprocess list-argv — NO shell=True (avoids command injection via
    # attacker-controlled filename/sheet names).
    path = _os.environ.get("SAVIA_CATALOG_DB", "")
    if path:
        import subprocess as _sp
        _sp.run(
            ["python3", "scripts/savia-catalog.py", "register",
             "--type", "model",
             "--name", "predict:" + _os.path.basename(files[0]),
             "--level", "N2",
             "--source", _os.path.basename(files[0]),
             "--relation", "trained_on",
             "--from-name", table["name"],
             "--from-type", "dataset",
             "--db", path],
            stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
    print(_json.dumps(metrics, ensure_ascii=False, indent=2))
    return 0


# ── L19 / SE-342 S3: monitor de calidad de datos (baseline vs drift) ────
# Determinista, local (~/.savia/data-quality/), cero egress (CRIT-001).
def run_monitor(argv):
    import json as _json
    import os as _os
    from datetime import date

    BASEDIR = _os.environ.get("SAVIA_DQ_DIR", _os.path.expanduser("~/.savia/data-quality"))

    cmd = "check"
    freshness = _os.environ.get("SAVIA_DQ_FRESHNESS_DAYS", "7")
    completeness = _os.environ.get("SAVIA_DQ_COMPLETENESS", "95")
    files = []
    i = 0
    while i < len(argv):
        if argv[i] in ("init", "check"):
            cmd = argv[i]; i += 1
        elif argv[i] == "--freshness-days" and i + 1 < len(argv):
            freshness = argv[i + 1]; i += 2
        elif argv[i] == "--completeness" and i + 1 < len(argv):
            completeness = argv[i + 1]; i += 2
        elif argv[i] in ("--help", "-h"):
            print("Usage: tabular-profile.py monitor <init|check> [--freshness-days N] [--completeness N] FILE")
            return 0
        else:
            files.append(argv[i]); i += 1

    if not files:
        files = ["-"]
    try:
        tables = read_tables(files, MAX_SAMPLE)
    except ExcelUnsupported as exc:
        print(_json.dumps({"error": str(exc)}))
        return 1
    table = next((t for t in tables if t["rows"]), None)
    if table is None:
        print(_json.dumps({"error": "no data found"}))
        return 1
    rows = table["rows"]
    key = _os.path.basename(files[0]) if files and files[0] != "-" else "stdin"

    now = date.today()
    today_iso = now.isoformat()
    # deterministic per-column profile snapshot
    cols = list(rows[0].keys()) if rows and isinstance(rows[0], dict) else []
    col_stats = {}
    for c in cols:
        non_null = sum(1 for r in rows if r.get(c) not in (None, ""))
        col_stats[c] = {
            "type": detect_type([r.get(c) for r in rows], len(rows)),
            "completeness": round(100.0 * non_null / len(rows), 1) if rows else 0,
        }

    baseline = {
        "file": key, "rows": len(rows), "cols": cols,
        "snapshot_date": today_iso, "col_stats": col_stats,
    }
    bfile = _os.path.join(BASEDIR, key.replace("/", "_").replace(".", "_") + ".json")

    if cmd == "init":
        _os.makedirs(BASEDIR, exist_ok=True)
        with open(bfile, "w", encoding="utf-8") as fh:
            _json.dump(baseline, fh, ensure_ascii=False)
        print(_json.dumps({"action": "baseline_saved", "file": key, "rows": len(rows),
                           "cols": len(cols), "baseline": bfile}, ensure_ascii=False))
        return 0

    # check: compare against baseline
    if not _os.path.exists(bfile):
        print(_json.dumps({"error": "no baseline — run 'monitor init' first", "expected": bfile}))
        return 1
    with open(bfile, encoding="utf-8") as fh:
        ref = _json.load(fh)

    issues = []
    # freshness: file age in days vs baseline snapshot date
    import time as _time
    mtime = _os.path.getmtime(files[0]) if files and files[0] != "-" else _time.time()
    mtime_date = date(*_time.localtime(mtime)[:3])
    age_days = (mtime_date - date.fromisoformat(ref["snapshot_date"])).days
    if age_days > int(freshness):
        issues.append({"check": "freshness", "status": "WARN", "days": age_days, "max": int(freshness)})

    # schema drift
    for c in ref["cols"]:
        if c not in cols:
            issues.append({"check": "schema", "status": "WARN", "detail": f"column '{c}' missing"})
    for c in cols:
        if c not in ref["cols"]:
            issues.append({"check": "schema", "status": "WARN", "detail": f"new column '{c}'"})
    # completeness drift
    for c, st in ref["col_stats"].items():
        cur = col_stats.get(c, {}) if c in col_stats else None
        if cur is None:
            continue
        if cur["completeness"] < int(completeness):
            issues.append({"check": "completeness", "status": "FAIL",
                           "column": c, "value": cur["completeness"], "min": int(completeness)})

    verdict = "FAIL" if any(x["check"] == "completeness" for x in issues) else \
              ("WARN" if issues else "PASS")
    out = {"action": "check", "verdict": verdict, "file": key,
           "rows": {"now": len(rows), "baseline": ref["rows"], "delta": len(rows) - ref["rows"]},
           "issues": issues}
    print(_json.dumps(out, ensure_ascii=False, indent=2))
    return 0 if verdict == "PASS" else 1


def main():
    sample = MAX_SAMPLE
    sources = []

    args = sys.argv[1:]

    # L21 (SE-342 S5): predict subcommand — local classic ML, no TFMs, zero egress.
    if args and args[0] == "predict":
        return run_predict(args[1:])
    # L19 (SE-342 S3): data-quality monitor (baseline vs drift).
    if args and args[0] == "monitor":
        return run_monitor(args[1:])

    i = 0
    while i < len(args):
        if args[i] == "--sample" and i + 1 < len(args):
            sample = int(args[i + 1])
            i += 2
        elif args[i] == "--help" or args[i] == "-h":
            print("Usage: tabular-profile.py [--sample N] [file1.csv|file1.xlsx ...]")
            return 0
        else:
            sources.append(args[i])
            i += 1

    if not sources:
        sources = ["-"]

    cap = min(sample, MAX_SAMPLE)
    try:
        tables = read_tables(sources, cap)
    except ExcelUnsupported as exc:
        print(json.dumps({"error": str(exc), "fallback": "raw"}))
        return 1

    tables = [t for t in tables if t["rows"]]
    if not tables:
        print(json.dumps({"error": "no data found"}))
        return 1

    profiled = [profile_table(t["name"], t["rows"], t.get("source"),
                              t.get("sheet")) for t in tables]

    if len(profiled) == 1:
        flat = {k: v for k, v in profiled[0].items() if k != "name"}
        print(json.dumps(flat, ensure_ascii=False, indent=2))
        return 0

    result = {
        "tables": profiled,
        "relations": detect_relations(tables),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
