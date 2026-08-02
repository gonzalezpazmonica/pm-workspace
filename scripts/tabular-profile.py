#!/usr/bin/env python3
"""
tabular-profile.py — Statistical profiling for tabular data.

Reads CSV/TSV/JSON from stdin or file, produces a JSON summary with:
- Column types (numeric, categorical, datetime, text)
- Descriptive statistics (mean, median, std, quartiles for numeric)
- Top values for categorical
- Temporal trends for datetime
- Outlier detection (IQR method)
- Correlation matrix for numeric columns
- Token savings estimate

Usage:
  cat data.csv | python3 tabular-profile.py
  python3 tabular-profile.py data.csv
  python3 tabular-profile.py --sample 5000 data.csv
"""
import sys, json, csv, io, math, os
from collections import Counter
from datetime import datetime

MAX_SAMPLE = 10_000
TOKEN_BUDGET = 200

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


def read_data(source, sample_size):
    """Read tabular data from stdin, file, or string."""
    if source in ("-", "", None) or source.startswith("{"):
        text = source if source and source not in ("-", "") else sys.stdin.read()
        if text.strip().startswith("["):
            records = json.loads(text)
            return records if sample_size is None else records[:sample_size]
        reader = csv.DictReader(io.StringIO(text))
        rows = list(reader)
        return rows if sample_size is None else rows[:sample_size]

    path = source
    ext = os.path.splitext(path)[1].lower()
    with open(path, newline="") as f:
        if ext == ".json":
            data = json.load(f)
            if isinstance(data, list):
                return data[:sample_size] if sample_size else data
            return data
        reader = csv.DictReader(f)
        rows = list(reader)
        return rows[:sample_size] if sample_size else rows


def estimate_tokens(rows):
    """Estimate token count for raw data vs summary."""
    raw = sum(len(str(row)) for row in rows[:min(100, len(rows))])
    raw_total = int(raw / min(100, len(rows)) * len(rows))
    return {
        "raw": raw_total,
        "summary": TOKEN_BUDGET,
        "savings_pct": round(100 * (1 - TOKEN_BUDGET / max(raw_total, 1)), 1),
    }


def main():
    sample = MAX_SAMPLE
    source = "-"

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--sample" and i + 1 < len(args):
            sample = int(args[i + 1])
            i += 2
        elif args[i] == "--help" or args[i] == "-h":
            print("Usage: tabular-profile.py [--sample N] [file.csv]")
            return 0
        else:
            source = args[i]
            i += 1

    rows = read_data(source, min(sample, MAX_SAMPLE))
    if not rows:
        print(json.dumps({"error": "no data found"}))
        return 1

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
        "rows": n,
        "columns": len(columns),
        "profiles": profiles,
        "correlations": sorted(corrs, key=lambda x: -abs(x["coefficient"]))[:10],
        "token_estimate": estimate_tokens(rows),
    }

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def _is_numeric(v):
    try:
        float(str(v).strip())
        return True
    except (ValueError, TypeError):
        return False


if __name__ == "__main__":
    sys.exit(main())
