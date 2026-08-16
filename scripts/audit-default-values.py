#!/usr/bin/env python3
"""Compare Swift localization fallbacks with their Japanese String Catalog values."""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = REPO_ROOT / "ios"
MAIN_CATALOG = IOS_ROOT / "DopaBreak" / "Localizable.xcstrings"
TARGET_CATALOGS = {
    "DopaBreak": MAIN_CATALOG,
    "MonitorExtension": IOS_ROOT / "MonitorExtension" / "Localizable.xcstrings",
    "ShieldConfigExtension": IOS_ROOT / "ShieldConfigExtension" / "Localizable.xcstrings",
    "WidgetsExtension": IOS_ROOT / "WidgetsExtension" / "Localizable.xcstrings",
}
PLACEHOLDER = "\N{OBJECT REPLACEMENT CHARACTER}"
UNKNOWN_SPECIFIER = "?"
LITERAL_PERCENT = "\ue000"
TYPED_SENTINEL_RE = re.compile(r"\x00([^\x00]+)\x00")
FORMAT_SPECIFIER_RE = re.compile(
    r"%#@(?P<plural>[^@]+)@|%(?:\d+\$)?[-+ 0#']*(?:\d+|\*)?"
    r"(?:\.\d+|\.\*)?(?P<length>hh|h|ll|l|L|z|j|t)?"
    r"(?P<conversion>[diuoxXfFeEgGaAcCsSp@])"
)


@dataclass(frozen=True)
class LocalizedCall:
    path: Path
    line: int
    key: str
    default_value: str


@dataclass(frozen=True)
class AuditIssue:
    kind: str
    path: Path
    line: int
    key: str
    default_value: str
    catalog_value: str | None


def typed_sentinel(specifier: str) -> str:
    return f"\x00{specifier}\x00"


def format_specifier_type(match: re.Match[str]) -> str:
    if match.group("plural") is not None:
        return "#@"
    return f"{match.group('length') or ''}{match.group('conversion')}"


def skip_line_comment(source: str, index: int) -> int:
    newline = source.find("\n", index + 2)
    return len(source) if newline == -1 else newline


def skip_block_comment(source: str, index: int) -> int:
    depth = 1
    cursor = index + 2
    while cursor < len(source) and depth:
        if source.startswith("/*", cursor):
            depth += 1
            cursor += 2
        elif source.startswith("*/", cursor):
            depth -= 1
            cursor += 2
        else:
            cursor += 1
    return cursor


def skip_swift_string(source: str, index: int) -> int:
    if source.startswith('"""', index):
        end = source.find('"""', index + 3)
        return len(source) if end == -1 else end + 3

    cursor = index + 1
    while cursor < len(source):
        if source[cursor] == "\\":
            if cursor + 1 < len(source) and source[cursor + 1] == "(":
                cursor = find_matching(source, cursor + 1, "(", ")") + 1
            else:
                cursor += 2
        elif source[cursor] == '"':
            return cursor + 1
        else:
            cursor += 1
    return len(source)


def find_matching(source: str, start: int, opening: str, closing: str) -> int:
    depth = 0
    cursor = start
    while cursor < len(source):
        if source.startswith("//", cursor):
            cursor = skip_line_comment(source, cursor)
            continue
        if source.startswith("/*", cursor):
            cursor = skip_block_comment(source, cursor)
            continue
        if source[cursor] == '"':
            cursor = skip_swift_string(source, cursor)
            continue
        if source[cursor] == opening:
            depth += 1
        elif source[cursor] == closing:
            depth -= 1
            if depth == 0:
                return cursor
        cursor += 1
    return len(source) - 1


def code_mask(source: str) -> str:
    masked = list(source)
    cursor = 0
    while cursor < len(source):
        end = cursor
        if source.startswith("//", cursor):
            end = skip_line_comment(source, cursor)
        elif source.startswith("/*", cursor):
            end = skip_block_comment(source, cursor)
        elif source[cursor] == '"':
            end = skip_swift_string(source, cursor)
        if end > cursor:
            for index in range(cursor, end):
                if masked[index] != "\n":
                    masked[index] = " "
            cursor = end
        else:
            cursor += 1
    return "".join(masked)


def split_arguments(body: str) -> list[str]:
    arguments: list[str] = []
    start = 0
    cursor = 0
    depths = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    while cursor < len(body):
        if body.startswith("//", cursor):
            cursor = skip_line_comment(body, cursor)
            continue
        if body.startswith("/*", cursor):
            cursor = skip_block_comment(body, cursor)
            continue
        if body[cursor] == '"':
            cursor = skip_swift_string(body, cursor)
            continue
        if body[cursor] in depths:
            depths[body[cursor]] += 1
        elif body[cursor] in pairs:
            depths[pairs[body[cursor]]] -= 1
        elif body[cursor] == "," and all(depth == 0 for depth in depths.values()):
            arguments.append(body[start:cursor])
            start = cursor + 1
        cursor += 1
    arguments.append(body[start:])
    return arguments


def swift_interpolation_type(expression: str) -> str:
    """Infer only explicit Swift interpolation types; unknown expressions stay auditable."""
    arguments = split_arguments(expression)
    value_expression = arguments[0].strip() if arguments else expression.strip()

    for argument in arguments[1:]:
        match = re.match(r"\s*specifier\s*:\s*", argument)
        if not match:
            continue
        specifier_literal = decode_swift_literal(argument[match.end() :])
        if specifier_literal is None:
            continue
        specifiers = list(FORMAT_SPECIFIER_RE.finditer(specifier_literal))
        if len(specifiers) == 1:
            return format_specifier_type(specifiers[0])

    while True:
        prefix = re.match(r"^(?:try[!?]?|await)\s+", value_expression)
        if not prefix:
            break
        value_expression = value_expression[prefix.end() :].lstrip()

    if re.match(r'^(?:Swift\.)?(?:String|Substring|NSString)\s*\(', value_expression):
        return "@"
    if value_expression.startswith('"'):
        return "@"
    if re.search(
        r"\bas[!?]?\s+(?:Swift\.)?(?:String|Substring|NSString)\??\s*$",
        value_expression,
    ):
        return "@"

    constructor_types = {
        "Int": "lld",
        "Int8": "hhd",
        "Int16": "hd",
        "Int32": "d",
        "Int64": "lld",
        "UInt": "llu",
        "UInt8": "hhu",
        "UInt16": "hu",
        "UInt32": "u",
        "UInt64": "llu",
        "Float": "f",
        "Double": "lf",
        "CGFloat": "lf",
    }
    constructor = re.match(
        r"^(?:Swift\.)?(Int8|Int16|Int32|Int64|Int|UInt8|UInt16|UInt32|UInt64|UInt|Float|Double|CGFloat)\s*\(",
        value_expression,
    )
    if constructor:
        return constructor_types[constructor.group(1)]
    if re.fullmatch(r"[-+]?\d+", value_expression):
        return "lld"
    if re.fullmatch(r"[-+]?(?:\d+\.\d*|\d*\.\d+)(?:[eE][-+]?\d+)?", value_expression):
        return "lf"
    return UNKNOWN_SPECIFIER


def decode_swift_literal(expression: str) -> str | None:
    expression = expression.strip()
    if not expression.startswith('"') or expression.startswith('"""'):
        return None

    output: list[str] = []
    cursor = 1
    while cursor < len(expression):
        character = expression[cursor]
        if character == '"':
            return "".join(output) if not expression[cursor + 1 :].strip() else None
        if character != "\\":
            output.append(character)
            cursor += 1
            continue

        if cursor + 1 >= len(expression):
            return None
        escaped = expression[cursor + 1]
        if escaped == "(":
            end = find_matching(expression, cursor + 1, "(", ")")
            if end <= cursor + 1:
                return None
            output.append(
                typed_sentinel(
                    swift_interpolation_type(expression[cursor + 2 : end])
                )
            )
            cursor = end + 1
            continue
        escape_values = {
            "0": "\0",
            "n": "\n",
            "r": "\r",
            "t": "\t",
            '"': '"',
            "'": "'",
            "\\": "\\",
        }
        if escaped == "u" and expression.startswith("u{", cursor + 1):
            end = expression.find("}", cursor + 3)
            if end == -1:
                return None
            try:
                output.append(chr(int(expression[cursor + 3 : end], 16)))
            except ValueError:
                return None
            cursor = end + 1
            continue
        if escaped not in escape_values:
            return None
        output.append(escape_values[escaped])
        cursor += 2
    return None


def literal_alternatives(expression: str) -> list[str]:
    direct = decode_swift_literal(expression)
    if direct is not None:
        return [direct]

    if "?" not in expression or ":" not in expression:
        return []
    values: list[str] = []
    cursor = 0
    while cursor < len(expression):
        if expression[cursor] != '"':
            cursor += 1
            continue
        end = skip_swift_string(expression, cursor)
        value = decode_swift_literal(expression[cursor:end])
        if value is None:
            return []
        values.append(value)
        cursor = end
    return values


def parse_arguments(body: str) -> tuple[list[str], dict[str, str]]:
    unlabeled: list[str] = []
    labeled: dict[str, str] = {}
    for argument in split_arguments(body):
        match = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*", argument)
        if match:
            labeled[match.group(1)] = argument[match.end() :]
        else:
            unlabeled.append(argument)
    return unlabeled, labeled


def localized_calls(path: Path) -> tuple[list[LocalizedCall], list[tuple[int, str]]]:
    source = path.read_text(encoding="utf-8")
    masked = code_mask(source)
    calls: list[LocalizedCall] = []
    unresolved: list[tuple[int, str]] = []
    for match in re.finditer(
        r"\b(?P<callee>String|LocalizedStringResource)\s*\(", masked
    ):
        opening = match.end() - 1
        closing = find_matching(source, opening, "(", ")")
        unlabeled, labeled = parse_arguments(source[opening + 1 : closing])
        if "defaultValue" not in labeled:
            continue
        if match.group("callee") == "String":
            key_expression = labeled.get("localized")
        else:
            key_expression = unlabeled[0] if unlabeled else None
        if key_expression is None:
            continue
        line = source.count("\n", 0, match.start()) + 1
        keys = literal_alternatives(key_expression)
        default_values = literal_alternatives(labeled["defaultValue"])
        if (
            not keys
            or any(TYPED_SENTINEL_RE.search(key) for key in keys)
            or len(keys) != len(default_values)
        ):
            unresolved.append((line, source[match.start() : closing + 1].splitlines()[0].strip()))
            continue
        calls.extend(
            LocalizedCall(path, line, key, default_value)
            for key, default_value in zip(keys, default_values)
        )
    return calls, unresolved


def catalog_for(path: Path) -> Path | None:
    relative_parts = path.relative_to(IOS_ROOT).parts
    return TARGET_CATALOGS.get(relative_parts[0])


def japanese_values(entry: dict[str, object]) -> list[str]:
    japanese = entry.get("localizations", {}).get("ja", {})
    values: list[str] = []

    def collect(value: object) -> None:
        if isinstance(value, dict):
            string_unit = value.get("stringUnit")
            if isinstance(string_unit, dict) and isinstance(string_unit.get("value"), str):
                values.append(string_unit["value"])
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)

    collect(japanese)
    return list(dict.fromkeys(values))


def normalized(value: str) -> str:
    value = value.replace("%%", LITERAL_PERCENT)
    value = FORMAT_SPECIFIER_RE.sub(
        lambda match: typed_sentinel(format_specifier_type(match)), value
    )
    return value.replace(LITERAL_PERCENT, "%")


def generic_normalized(value: str) -> str:
    return TYPED_SENTINEL_RE.sub(PLACEHOLDER, value)


def specifier_sequence(value: str) -> tuple[str, ...]:
    return tuple(match.group(1) for match in TYPED_SENTINEL_RE.finditer(value))


def compatible_specifiers(source: tuple[str, ...], catalog: tuple[str, ...]) -> bool:
    return len(source) == len(catalog) and all(
        source_type == UNKNOWN_SPECIFIER or source_type == catalog_type
        for source_type, catalog_type in zip(source, catalog)
    )


def display_specifier_sequence(sequence: tuple[str, ...]) -> str:
    return "[" + ", ".join(sequence) + "]"


def is_in_hidden_directory(path: Path) -> bool:
    relative_parts = path.relative_to(IOS_ROOT).parts
    return any(part.startswith(".") for part in relative_parts[:-1])


def display(value: str | None) -> str:
    return "<missing>" if value is None else json.dumps(value, ensure_ascii=False)


def main() -> int:
    catalog_cache: dict[Path, dict[str, object]] = {}
    all_calls: list[LocalizedCall] = []
    unresolved_calls: list[tuple[Path, int, str]] = []
    specifier_reports: list[str] = []

    swift_paths = (
        path
        for path in IOS_ROOT.rglob("*.swift")
        if not is_in_hidden_directory(path)
    )
    for path in sorted(swift_paths):
        calls, unresolved = localized_calls(path)
        all_calls.extend(calls)
        unresolved_calls.extend((path, line, snippet) for line, snippet in unresolved)

    issues: list[AuditIssue] = []
    for call in all_calls:
        catalog_path = catalog_for(call.path)
        if catalog_path is None:
            issues.append(
                AuditIssue("unknown-target", call.path, call.line, call.key, call.default_value, None)
            )
            source_specifiers = specifier_sequence(normalized(call.default_value))
            if source_specifiers:
                relative = call.path.relative_to(REPO_ROOT)
                specifier_reports.append(
                    f"specifier-sequence: {relative}:{call.line} [{call.key}] "
                    f"default={display_specifier_sequence(source_specifiers)} "
                    "catalog=<unknown-target>"
                )
            continue
        if catalog_path not in catalog_cache:
            catalog_cache[catalog_path] = json.loads(catalog_path.read_text(encoding="utf-8"))["strings"]
        entry = catalog_cache[catalog_path].get(call.key)
        if not isinstance(entry, dict):
            issues.append(
                AuditIssue("missing-key", call.path, call.line, call.key, call.default_value, None)
            )
            continue
        values = japanese_values(entry)
        if not values:
            issues.append(
                AuditIssue("missing-ja", call.path, call.line, call.key, call.default_value, None)
            )
            continue
        source_value = normalized(call.default_value)
        source_specifiers = specifier_sequence(source_value)
        catalog_values = [(value, normalized(value)) for value in values]
        catalog_sequences = list(
            dict.fromkeys(specifier_sequence(value) for _, value in catalog_values)
        )
        if source_specifiers or any(catalog_sequences):
            relative = call.path.relative_to(REPO_ROOT)
            displayed_catalog_sequences = " / ".join(
                display_specifier_sequence(sequence) for sequence in catalog_sequences
            )
            specifier_reports.append(
                f"specifier-sequence: {relative}:{call.line} [{call.key}] "
                f"default={display_specifier_sequence(source_specifiers)} "
                f"catalog={displayed_catalog_sequences}"
            )

        matching_values = [
            (value, normalized_value)
            for value, normalized_value in catalog_values
            if generic_normalized(source_value) == generic_normalized(normalized_value)
        ]
        if not matching_values:
            issues.append(
                AuditIssue("mismatch", call.path, call.line, call.key, call.default_value, values[0])
            )
            continue
        if not any(
            compatible_specifiers(source_specifiers, specifier_sequence(normalized_value))
            for _, normalized_value in matching_values
        ):
            issues.append(
                AuditIssue(
                    "specifier-type",
                    call.path,
                    call.line,
                    call.key,
                    call.default_value,
                    matching_values[0][0],
                )
            )

    for report in specifier_reports:
        print(report)
    for issue in issues:
        relative = issue.path.relative_to(REPO_ROOT)
        print(f"{issue.kind}: {relative}:{issue.line} [{issue.key}]")
        print(f"  defaultValue: {display(issue.default_value)}")
        print(f"  catalog ja:   {display(issue.catalog_value)}")
        if issue.kind == "specifier-type" and issue.catalog_value is not None:
            print(
                "  specifiers:   "
                f"default={display_specifier_sequence(specifier_sequence(normalized(issue.default_value)))} "
                f"catalog={display_specifier_sequence(specifier_sequence(normalized(issue.catalog_value)))}"
            )
    for path, line, snippet in unresolved_calls:
        relative = path.relative_to(REPO_ROOT)
        print(f"unresolved-call: {relative}:{line}: {snippet}")

    print(
        "Summary: "
        f"calls={len(all_calls)}, mismatches={sum(issue.kind == 'mismatch' for issue in issues)}, "
        f"missing={sum(issue.kind in {'missing-key', 'missing-ja'} for issue in issues)}, "
        f"unresolved={len(unresolved_calls)}, "
        f"specifier-type={sum(issue.kind == 'specifier-type' for issue in issues)}, "
        f"unknown-target={sum(issue.kind == 'unknown-target' for issue in issues)}"
    )
    return 1 if issues or unresolved_calls else 0


if __name__ == "__main__":
    sys.exit(main())
