#!/usr/bin/env python3
"""List recently active local Codex projects and resume their latest thread."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import sqlite3
import subprocess
from collections import OrderedDict
from datetime import datetime
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="List Codex projects active within the last N hours."
    )
    parser.add_argument("--hours", type=float, default=24, help="Lookback window (default: 24)")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON")
    parser.add_argument(
        "--resume",
        type=int,
        metavar="N",
        help="Resume numbered project N using its most recent thread",
    )
    parser.add_argument(
        "--db",
        type=Path,
        help="Codex state database (default: $CODEX_HOME/state_5.sqlite)",
    )
    return parser.parse_args()


def database_path(explicit: Path | None) -> Path:
    if explicit:
        return explicit.expanduser()
    codex_home = Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()
    return codex_home / "state_5.sqlite"


def load_projects(db: Path, hours: float) -> list[dict]:
    if hours <= 0:
        raise ValueError("--hours must be greater than zero")
    if not db.is_file():
        raise FileNotFoundError(f"Codex database not found: {db}")

    uri = f"file:{db.resolve()}?mode=ro"
    with sqlite3.connect(uri, uri=True) as connection:
        connection.row_factory = sqlite3.Row
        rows = connection.execute(
            """
            SELECT id, cwd, COALESCE(NULLIF(name, ''), NULLIF(title, ''),
                       NULLIF(first_user_message, ''), 'Untitled thread') AS title,
                   recency_at, archived
            FROM threads
            WHERE recency_at >= CAST(strftime('%s', 'now') AS INTEGER) - (? * 3600)
              AND COALESCE(thread_source, 'user') = 'user'
            ORDER BY recency_at DESC
            """,
            (hours,),
        ).fetchall()

    grouped: OrderedDict[str, dict] = OrderedDict()
    for row in rows:
        cwd = row["cwd"]
        project = grouped.setdefault(
            cwd,
            {
                "name": Path(cwd).name or cwd,
                "path": cwd,
                "last_active": row["recency_at"],
                "latest_thread_id": row["id"],
                "latest_title": row["title"],
                "threads": [],
            },
        )
        project["threads"].append(
            {
                "id": row["id"],
                "title": row["title"],
                "last_active": row["recency_at"],
                "archived": bool(row["archived"]),
            }
        )
    return list(grouped.values())


def resume(project: dict) -> None:
    cwd = Path(project["path"])
    if not cwd.is_dir():
        raise FileNotFoundError(f"Project directory no longer exists: {cwd}")
    subprocess.run(["codex", "resume", project["latest_thread_id"]], cwd=cwd, check=True)


def print_projects(projects: list[dict], hours: float) -> None:
    print(f"Codex 最近 {hours:g} 小时：{len(projects)} 个项目")
    if not projects:
        return

    for number, project in enumerate(projects, 1):
        active = datetime.fromtimestamp(project["last_active"]).strftime("%m-%d %H:%M")
        thread_count = len(project["threads"])
        archived = " · 已归档" if project["threads"][0]["archived"] else ""
        print(f"\n{number}. {project['name']} · {active} · {thread_count} 个会话{archived}")
        print(f"   {project['latest_title']}")
        print(f"   {project['path']}")
        command = (
            f"cd {shlex.quote(project['path'])} && "
            f"codex resume {shlex.quote(project['latest_thread_id'])}"
        )
        print(f"   {command}")

    print("\n继续项目：python3 codex_recent.py --resume 编号")


def main() -> int:
    args = parse_args()
    try:
        projects = load_projects(database_path(args.db), args.hours)
        if args.resume is not None:
            if not 1 <= args.resume <= len(projects):
                raise ValueError(f"--resume must be between 1 and {len(projects)}")
            resume(projects[args.resume - 1])
        elif args.json:
            print(json.dumps(projects, ensure_ascii=False, indent=2))
        else:
            print_projects(projects, args.hours)
    except (FileNotFoundError, sqlite3.Error, subprocess.CalledProcessError, ValueError) as error:
        print(f"error: {error}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
