"""Shared local asset paths, strict JSON, and lossless article merging."""
import json
import math
import os
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / 'assets/data'


def read_json(path, fallback):
    path = Path(path)
    return json.loads(path.read_text()) if path.exists() else fallback


def clean(value):
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [clean(v) for v in value]
    return value


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(clean(value), indent=2, ensure_ascii=False, default=str, allow_nan=False) + '\n')
    os.replace(temporary, path)


def merge_news(*groups):
    rows = {}
    for group in groups:
        for article in group:
            key = article.get('link') or article.get('title')
            if not key:
                continue
            previous = rows.get(key, {})
            rows[key] = {**previous, **{k: v for k, v in article.items() if v is not None}}
            rows[key]['related_tickers'] = sorted(set(previous.get('related_tickers') or []) | set(article.get('related_tickers') or []) | ({article['ticker']} if article.get('ticker') else set()))
    return sorted(rows.values(), key=lambda a: a.get('published_at') or '', reverse=True)
