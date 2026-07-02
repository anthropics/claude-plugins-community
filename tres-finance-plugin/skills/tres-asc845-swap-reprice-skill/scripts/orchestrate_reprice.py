#!/usr/bin/env python3
"""
ASC 845 Swap Repricing — Orchestrator
=======================================

End-to-end script designed to be called by Claude with TRES query results.
This script does NOT call the TRES API directly (that's Claude's job via MCP tools).
Instead, it processes subtransaction data that Claude feeds it and produces:

1. A human-readable preview
2. A JSON reprice plan
3. A ready-to-execute list of setManualFiatValue mutation variables

Workflow for Claude:
    1. Query TRES subTransaction (paginated, with flowRule) via user-tres-finance MCP
    2. Save results to a JSON file (e.g. swap_reprice_input.json)
    3. Run this script from the skill scripts directory
    4. Review output with user
    5. Execute mutations from the plan after user confirmation

Usage:
    cd "${CLAUDE_PLUGIN_ROOT}/skills/tres-asc845-swap-reprice-skill/scripts" && \
    python3 orchestrate_reprice.py \
        --input /path/to/swap_reprice_input.json \
        --account-name "Swaps Clearing Account" \
        --output /path/to/reprice_plan.json \
        --mutations-output /path/to/reprice_mutations.json
"""

import json
import sys
import argparse
from reprice_swaps import build_reprice_plan, print_preview


def generate_graphql_mutations(plan, batch_size=50):
    """
    Generate GraphQL mutation strings ready for Claude to execute via TRES MCP.
    Returns batches of mutations for sequential execution.
    """
    mutations = plan.get("mutations", [])
    if not mutations:
        return []

    batches = []
    for i in range(0, len(mutations), batch_size):
        batch = mutations[i:i + batch_size]
        batches.append(batch)

    return batches


def generate_execution_script(plan, output_path):
    """
    Generate a JSON file with all mutation details Claude needs to execute.
    """
    execution = {
        "summary": plan["summary"],
        "mutation_template": {
            "query": """mutation SetManualFiatValue($id: ID!, $newFiatValue: String!, $currency: String) {
  setManualFiatValue(id: $id, newFiatValue: $newFiatValue, currency: $currency) {
    subTransaction {
      id
      fiatValue
      isManualFiatValue
    }
  }
}""",
            "note": "Execute one per inflow subtransaction. Claude should call user-tres-finance execute for each."
        },
        "mutations": [
            {
                "variables": {
                    "id": m["subtx_id"],
                    "newFiatValue": m["new_fiat_value"],
                    "currency": m["currency"],
                },
                "description": f"Reprice subtx {m['subtx_id']} to ${m['new_fiat_value']}"
            }
            for m in plan.get("mutations", [])
        ],
        "total_mutations": len(plan.get("mutations", [])),
    }

    with open(output_path, "w") as f:
        json.dump(execution, f, indent=2)

    return execution


def main():
    parser = argparse.ArgumentParser(description="ASC 845 Swap Repricing Orchestrator")
    parser.add_argument("--input", "-i", required=True, help="Input JSON with subtransaction data")
    parser.add_argument("--output", "-o", default="reprice_plan.json",
                        help="Output path for reprice plan (default: reprice_plan.json in cwd)")
    parser.add_argument("--mutations-output", default="reprice_mutations.json",
                        help="Output path for executable mutations (default: reprice_mutations.json in cwd)")
    parser.add_argument("--account-name", default=None, help="Target ERP account name")
    parser.add_argument("--account-value", default=None, help="Target ERP account number/value")
    parser.add_argument("--activity-tags", nargs="*", default=None,
                        help="Filter by classification activities (e.g. 'SWAP' 'STAKING LOCKUP')")
    parser.add_argument("--currency", default="usd", help="Currency (default: usd)")
    parser.add_argument("--precision", type=int, default=6, help="Decimal precision")
    args = parser.parse_args()

    # Load subtransaction data
    print("Loading subtransaction data...")
    with open(args.input, "r") as f:
        raw = json.load(f)

    # Handle various input formats
    if isinstance(raw, list) and len(raw) > 0 and isinstance(raw[0], dict) and "type" in raw[0]:
        # TRES MCP response wrapper: [{"type": "text", "text": "{...}"}]
        text_content = raw[0].get("text", "{}")
        data = json.loads(text_content)
    elif isinstance(raw, dict):
        data = raw
    else:
        data = raw

    # Extract subtransaction results
    if isinstance(data, dict):
        if "data" in data:
            subtxs = data["data"].get("subTransaction", {}).get("results", [])
        elif "results" in data:
            subtxs = data["results"]
        else:
            subtxs = data
    elif isinstance(data, list):
        subtxs = data
    else:
        print("ERROR: Could not parse input data")
        sys.exit(1)

    print(f"Loaded {len(subtxs)} subtransactions")

    # Build reprice plan
    print(f"Filtering for account: {args.account_name or args.account_value or 'ALL'}")
    if args.activity_tags:
        print(f"Filtering for activities: {', '.join(args.activity_tags)}")
    plan = build_reprice_plan(
        subtransactions=subtxs,
        target_name=args.account_name,
        target_value=args.account_value,
        currency=args.currency,
        precision=args.precision,
        activity_tags=args.activity_tags,
    )

    # Show preview
    print()
    print_preview(plan)

    # Save plan
    with open(args.output, "w") as f:
        json.dump(plan, f, indent=2)
    print(f"Full reprice plan saved to: {args.output}")

    # Generate executable mutations
    execution = generate_execution_script(plan, args.mutations_output)
    print(f"Executable mutations saved to: {args.mutations_output}")
    print(f"Ready to execute {execution['total_mutations']} setManualFiatValue calls")

    # Print case distribution
    case_counts = {}
    for tx in plan["transactions"]:
        c = tx["case"]
        case_counts[c] = case_counts.get(c, 0) + 1
    print(f"\nCase distribution:")
    for case, count in sorted(case_counts.items()):
        print(f"  {case}: {count} transactions")


if __name__ == "__main__":
    main()
