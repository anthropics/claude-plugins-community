#!/usr/bin/env python3
"""End-to-end test harness for the `tres-report-create` skill.

Exercises the exact workflow the skill instructs Claude to follow, against the
live TRES MCP server (https://ai.tres.finance/mcp) + BFF prod:

  1. discover every report via `availableReportTypes`
  2. trigger each export (entitiesType -> query, exportFormat = exportType)
  3. poll the `report` query by name until DONE / ERROR / timeout

It prints a pass/fail matrix so you can see, per report type, whether the
skill's recipe actually produces a finished report.

Auth: reads the bearer token from the TRES_BEARER_TOKEN env var. The token and
the presigned S3 `link` are NEVER printed or written to disk.

Usage:
    export TRES_BEARER_TOKEN="<token>"        # no "Bearer " prefix
    python run_report_matrix.py --dry-run     # connect + list reports only
    python run_report_matrix.py               # full trigger + poll matrix
    python run_report_matrix.py --only LEDGER ASSETS   # filter by entitiesType
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

MCP_URL = "https://ai.tres.finance/mcp"
PROTOCOL_VERSION = "2025-06-18"

# entitiesType -> the GraphQL query whose export side-effect produces the report.
ENTITIES_TO_QUERY: dict[str, str] = {
    "LEDGER": "transaction",
    "ASSETS": "organizationBalance",
    "BALANCE": "organizationBalance",
    "HISTORICAL_BALANCE": "organizationBalance",
    "ACCOUNTS": "internalAccount",
    "GENERAL": "internalAccount",
    "STAKING_DATA": "stakingYieldRecord",
    "AUDIT_LOG": "auditLog",
    "LOGIN_HISTORY": "loginHistoryExport",
}

# Queries that accept timestamp_Gte / timestamp_Lte date-range filters.
DATE_RANGED_QUERIES = {"transaction", "auditLog"}


class McpClient:
    """Minimal MCP Streamable-HTTP (JSON-RPC) client, stdlib only."""

    def __init__(self, url: str, token: str):
        self._url = url
        self._token = token
        self._session_id: str | None = None
        self._next_id = 0

    def initialize(self) -> dict:
        result = self._rpc(
            "initialize",
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {},
                "clientInfo": {"name": "report-matrix-harness", "version": "1.0"},
            },
        )
        self._notify("notifications/initialized", {})
        return result

    def list_tools(self) -> list[dict]:
        return self._rpc("tools/list", {}).get("tools", [])

    def call_tool(self, name: str, arguments: dict) -> dict:
        return self._rpc("tools/call", {"name": name, "arguments": arguments})

    def _headers(self) -> dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Authorization": f"Bearer {self._token}",
            "MCP-Protocol-Version": PROTOCOL_VERSION,
        }
        if self._session_id:
            headers["Mcp-Session-Id"] = self._session_id
        return headers

    def _rpc(self, method: str, params: dict) -> dict:
        self._next_id += 1
        payload = {"jsonrpc": "2.0", "id": self._next_id, "method": method, "params": params}
        status, headers, body = self._post(payload)
        session = headers.get("mcp-session-id")
        if session:
            self._session_id = session
        if status >= 400:
            raise RuntimeError(f"{method} -> HTTP {status}: {body[:300]}")
        message = self._parse(body)
        if message is None:
            raise RuntimeError(f"{method} -> no JSON-RPC message in response")
        if "error" in message:
            raise RuntimeError(f"{method} -> JSON-RPC error: {message['error']}")
        return message.get("result", {})

    def _notify(self, method: str, params: dict) -> None:
        payload = {"jsonrpc": "2.0", "method": method, "params": params}
        self._post(payload)

    def _post(self, payload: dict) -> tuple[int, dict[str, str], str]:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(self._url, data=data, headers=self._headers(), method="POST")
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                raw = resp.read().decode("utf-8", "replace")
                hdrs = {k.lower(): v for k, v in resp.headers.items()}
                return resp.status, hdrs, raw
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8", "replace")
            hdrs = {k.lower(): v for k, v in (exc.headers or {}).items()}
            return exc.code, hdrs, raw

    @staticmethod
    def _parse(body: str) -> dict | None:
        body = body.strip()
        if not body:
            return None
        # SSE framing: lines like "data: {json}". Take the last data line.
        if body.startswith("event:") or "\ndata:" in body or body.startswith("data:"):
            last = None
            for line in body.splitlines():
                if line.startswith("data:"):
                    last = line[len("data:"):].strip()
            if last:
                return json.loads(last)
        return json.loads(body)


def _normalize(parsed: dict) -> dict:
    """Unwrap {result: ...} and surface the MCP's `error`/`error_type` failure
    shape (returned for 400s / validation errors) as a standard `errors` list."""
    if isinstance(parsed.get("result"), dict):
        parsed = parsed["result"]
    if "error" in parsed and "errors" not in parsed:
        parsed = {**parsed, "errors": [{"message": parsed["error"], "type": parsed.get("error_type")}]}
    return parsed


def extract_graphql(tool_result: dict) -> dict:
    """Pull the GraphQL JSON ({data, errors}) out of an MCP tools/call result."""
    for item in tool_result.get("content", []):
        if item.get("type") == "text":
            try:
                parsed = json.loads(item.get("text", ""))
            except json.JSONDecodeError:
                continue
            if isinstance(parsed, dict):
                return _normalize(parsed)
    structured = tool_result.get("structuredContent")
    if isinstance(structured, dict):
        return _normalize(structured)
    return {"errors": [{"message": "unparseable tool result", "raw": str(tool_result)[:300]}]}


def find_execute_tool(tools: list[dict]) -> str:
    names = [t.get("name", "") for t in tools]
    for candidate in ("execute", "execute_query", "graphql", "run_query"):
        if candidate in names:
            return candidate
    raise RuntimeError(f"no execute-like tool found; available: {names}")


def run_query(client: McpClient, tool: str, query: str, variables: dict) -> dict:
    result = client.call_tool(tool, {"query": query, "variables": variables})
    return extract_graphql(result)


def build_trigger(query_name: str, export_format: str, export_name: str, gte: str, lte: str,
                  asset_class_id: str | None = None) -> tuple[str, dict]:
    # loginHistoryExport has a distinct shape: required exportFormat/exportName,
    # no currency/limit/timestamps, and returns { success reportId }.
    if query_name == "loginHistoryExport":
        q = (
            "query($exportFormat:String!,$exportName:String!,$outputFormat:ReportOutputFormat){"
            "  loginHistoryExport(exportFormat:$exportFormat,exportName:$exportName,"
            "outputFormat:$outputFormat){ success reportId } }"
        )
        return q, {"exportFormat": export_format, "exportName": export_name, "outputFormat": "CSV"}

    # COST_BASIS_INVENTORY must go through `transaction` and requires exactly one
    # asset class (children_Asset_AssetClass_In: [String]).
    if export_format == "COST_BASIS_INVENTORY":
        q = (
            "query($exportFormat:String,$exportName:String,$currency:String,"
            "$outputFormat:ReportOutputFormat,$children_Asset_AssetClass_In:[String]){"
            "  transaction(limit:1,exportFormat:$exportFormat,exportName:$exportName,"
            "currency:$currency,outputFormat:$outputFormat,"
            "children_Asset_AssetClass_In:$children_Asset_AssetClass_In){ results { id } totalCount } }"
        )
        return q, {"exportFormat": export_format, "exportName": export_name, "currency": "usd",
                   "outputFormat": "CSV", "children_Asset_AssetClass_In": [asset_class_id]}

    common = {
        "limit": 1,
        "offset": 0,
        "exportFormat": export_format,
        "exportName": export_name,
        "currency": "usd",
        "outputFormat": "CSV",
    }
    if query_name in DATE_RANGED_QUERIES:
        q = (
            f"query($limit:Int,$offset:Int,$timestamp_Gte:DateTime,$timestamp_Lte:DateTime,"
            f"$exportFormat:String,$exportName:String,$currency:String,$outputFormat:ReportOutputFormat){{"
            f"  {query_name}(limit:$limit,offset:$offset,timestamp_Gte:$timestamp_Gte,"
            f"timestamp_Lte:$timestamp_Lte,exportFormat:$exportFormat,exportName:$exportName,"
            f"currency:$currency,outputFormat:$outputFormat){{ results {{ id }} totalCount }} }}"
        )
        common["timestamp_Gte"] = gte
        common["timestamp_Lte"] = lte
    else:
        q = (
            f"query($limit:Int,$offset:Int,$exportFormat:String,$exportName:String,"
            f"$currency:String,$outputFormat:ReportOutputFormat){{"
            f"  {query_name}(limit:$limit,offset:$offset,exportFormat:$exportFormat,"
            f"exportName:$exportName,currency:$currency,outputFormat:$outputFormat){{ results {{ id }} totalCount }} }}"
        )
    return q, common


POLL_QUERY = (
    "query($name:String,$ordering:String,$limit:Int){"
    "  report(name:$name,ordering:$ordering,limit:$limit){"
    "    results{ id name status link reportSize exportFormat createdAt } } }"
)


def poll_report(client: McpClient, tool: str, name: str) -> dict:
    gql = run_query(client, tool, POLL_QUERY, {"name": name, "ordering": "-created_at", "limit": 1})
    if gql.get("errors"):
        return {"status": "POLL_ERROR", "errors": gql["errors"]}
    results = (((gql.get("data") or {}).get("report") or {}).get("results")) or []
    if not results:
        return {"status": "NOT_FOUND"}
    return results[0]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="connect + list reports only")
    parser.add_argument("--only", nargs="*", default=None, help="filter by entitiesType")
    parser.add_argument("--poll-rounds", type=int, default=12)
    parser.add_argument("--poll-interval", type=int, default=20)
    args = parser.parse_args()

    token = os.environ.get("TRES_BEARER_TOKEN")
    if not token:
        print("ERROR: set TRES_BEARER_TOKEN env var (no 'Bearer ' prefix).", file=sys.stderr)
        return 2

    client = McpClient(MCP_URL, token)
    info = client.initialize()
    server = info.get("serverInfo", {})
    print(f"Connected to MCP: {server.get('name')} v{server.get('version')} (protocol {info.get('protocolVersion')})")

    tools = client.list_tools()
    print(f"Tools exposed: {[t.get('name') for t in tools]}")
    execute_tool = find_execute_tool(tools)
    print(f"Using execute tool: {execute_tool}\n")

    gql = run_query(
        client, execute_tool,
        "query { availableReportTypes { name exportType entitiesType } }", {},
    )
    if gql.get("errors"):
        print(f"availableReportTypes failed: {gql['errors']}", file=sys.stderr)
        return 1
    reports = (gql.get("data") or {}).get("availableReportTypes") or []
    if args.only:
        wanted = {x.upper() for x in args.only}
        reports = [r for r in reports if (r.get("entitiesType") or "").upper() in wanted]
    print(f"Discovered {len(reports)} report types:")
    for r in reports:
        mapped = ENTITIES_TO_QUERY.get((r.get("entitiesType") or "").upper(), "??? UNMAPPED")
        print(f"  - {r.get('name'):<34} exportType={r.get('exportType'):<32} "
              f"entities={r.get('entitiesType'):<20} -> {mapped}")

    if args.dry_run:
        print("\n[dry-run] stopping before triggering exports.")
        return 0

    now = datetime.now(tz=timezone.utc)
    gte = (now - timedelta(days=730)).strftime("%Y-%m-%dT00:00:00Z")
    lte = now.strftime("%Y-%m-%dT23:59:59Z")
    run_id = now.strftime("%Y%m%d-%H%M%S")

    # COST_BASIS_INVENTORY needs exactly one asset-class id; grab any one.
    ac = run_query(client, execute_tool, "query { assetClass(limit: 1) { results { id } } }", {})
    asset_class_id = next(
        (r["id"] for r in (((ac.get("data") or {}).get("assetClass") or {}).get("results") or [])),
        None,
    )

    # Phase 1: trigger every export.
    print(f"\n=== Phase 1: triggering exports (run {run_id}) ===")
    pending: list[dict] = []
    for r in reports:
        name = r.get("name")
        entities = (r.get("entitiesType") or "").upper()
        export_format = r.get("exportType")
        query_name = ENTITIES_TO_QUERY.get(entities)
        row = {"report": name, "entitiesType": entities, "exportType": export_format,
               "query": query_name, "exportName": f"[skilltest {run_id}] {name}"}
        if not query_name:
            row["trigger"] = "UNMAPPED_ENTITIES"
            row["final"] = "SKIPPED"
            pending.append(row)
            print(f"  ! {name}: no query mapping for entitiesType={entities}")
            continue
        if not export_format:
            row["trigger"] = "NO_EXPORT_TYPE"
            row["final"] = "SKIPPED"
            pending.append(row)
            print(f"  ! {name}: availableReportTypes returned no exportType")
            continue
        query, variables = build_trigger(
            query_name, export_format, row["exportName"], gte, lte, asset_class_id
        )
        try:
            res = run_query(client, execute_tool, query, variables)
        except Exception as exc:  # noqa: BLE001 - harness records every failure
            row["trigger"] = f"EXCEPTION: {exc}"
            row["final"] = "TRIGGER_FAILED"
            pending.append(row)
            print(f"  x {name}: trigger exception: {exc}")
            continue
        if res.get("errors"):
            row["trigger"] = f"GQL_ERROR: {json.dumps(res['errors'])[:200]}"
            row["final"] = "TRIGGER_FAILED"
            print(f"  x {name}: GraphQL error: {json.dumps(res['errors'])[:160]}")
        else:
            row["trigger"] = "OK"
            row["final"] = "PENDING"
            print(f"  > {name}: triggered ({query_name}, {export_format})")
        pending.append(row)

    # Phase 2: poll for completion.
    print(f"\n=== Phase 2: polling (up to {args.poll_rounds} rounds x {args.poll_interval}s) ===")
    open_rows = [r for r in pending if r["final"] == "PENDING"]
    for round_no in range(1, args.poll_rounds + 1):
        if not open_rows:
            break
        time.sleep(args.poll_interval)
        still_open: list[dict] = []
        for row in open_rows:
            rep = poll_report(client, execute_tool, row["exportName"])
            status = rep.get("status")
            if status == "DONE":
                row["final"] = "DONE"
                row["reportSize"] = rep.get("reportSize")
                row["has_link"] = bool(rep.get("link"))
            elif status == "ERROR":
                row["final"] = "ERROR"
            elif status in ("POLL_ERROR", "NOT_FOUND"):
                row["poll_note"] = status
                still_open.append(row)
            else:
                row["last_status"] = status
                still_open.append(row)
        done = sum(1 for r in pending if r["final"] == "DONE")
        err = sum(1 for r in pending if r["final"] == "ERROR")
        print(f"  round {round_no}: done={done} error={err} open={len(still_open)}")
        open_rows = still_open
    for row in open_rows:
        row["final"] = "TIMEOUT"

    # Summary matrix.
    print("\n=== RESULT MATRIX ===")
    print(f"{'REPORT':<34}{'ENTITIES':<18}{'TRIGGER':<14}{'FINAL':<10}{'SIZE/NOTE'}")
    counts: dict[str, int] = {}
    for row in pending:
        counts[row["final"]] = counts.get(row["final"], 0) + 1
        note = ""
        if row.get("reportSize") is not None:
            note = f"size={row['reportSize']} link={'yes' if row.get('has_link') else 'no'}"
        elif row.get("poll_note"):
            note = row["poll_note"]
        elif row["trigger"] not in ("OK",) and row["final"] != "DONE":
            note = row["trigger"][:60]
        print(f"{row['report'][:33]:<34}{row['entitiesType']:<18}"
              f"{('OK' if row['trigger']=='OK' else 'FAIL'):<14}{row['final']:<10}{note}")
    print("\nTotals:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"matrix_{run_id}.json")
    with open(out, "w") as fh:
        json.dump(pending, fh, indent=2, default=str)
    print(f"Full results written to {out}")

    return 0 if counts.get("DONE", 0) == sum(
        1 for r in pending if r["final"] not in ("SKIPPED",)
    ) else 1


if __name__ == "__main__":
    raise SystemExit(main())
