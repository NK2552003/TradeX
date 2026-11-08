"""Compare provider payloads with persisted PostgREST rows without logging data."""
from datetime import datetime
import math


def same_value(expected, actual):
    if isinstance(expected, dict):
        return isinstance(actual, dict) and all(
            key in actual and same_value(value, actual[key]) for key, value in expected.items())
    if isinstance(expected, list):
        return isinstance(actual, list) and len(expected) == len(actual) and all(
            same_value(a, b) for a, b in zip(expected, actual))
    if isinstance(expected, bool) or isinstance(actual, bool):
        return type(expected) is type(actual) and expected == actual
    if isinstance(expected, (int, float)) and isinstance(actual, (int, float)):
        if isinstance(expected, int) and isinstance(actual, int):
            return expected == actual
        return math.isclose(expected, actual, rel_tol=1e-12, abs_tol=1e-12)
    if isinstance(expected, str) and isinstance(actual, str) and 'T' in expected:
        try:
            return datetime.fromisoformat(expected.replace('Z', '+00:00')) == datetime.fromisoformat(actual.replace('Z', '+00:00'))
        except ValueError:
            pass
    return expected == actual


def row_key(row, keys):
    def normalized(value):
        if isinstance(value, str) and 'T' in value:
            try:
                return datetime.fromisoformat(value.replace('Z', '+00:00'))
            except ValueError:
                pass
        return value
    return tuple(normalized(row.get(key)) for key in keys)


def confirm_rows(expected, actual, conflict, table):
    keys = conflict.split(',')
    if not isinstance(actual, list) or len(actual) != len(expected) or not all(isinstance(r, dict) for r in actual):
        raise ValueError(f'Unconfirmed write to {table}: missing rows')
    indexed = {row_key(row, keys): row for row in actual}
    if len(indexed) != len(expected):
        raise ValueError(f'Unconfirmed write to {table}: duplicate row identities')
    for row in expected:
        stored = indexed.get(row_key(row, keys))
        if stored is None or not same_value(row, stored):
            raise ValueError(f'Unconfirmed write to {table}: stored values differ from fetched data')
