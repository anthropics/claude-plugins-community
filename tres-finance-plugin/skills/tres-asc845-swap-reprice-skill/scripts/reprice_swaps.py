#!/usr/bin/env python3
"""
ASC 845 Swap Repricing Engine
==============================

Implements equal-value exchange under ASC 845 (Nonmonetary Transactions).
For each swap transaction mapped to a clearing account, reprices inflow legs
so their total fiat value equals the total fiat value of the outflow legs.

Usage:
    # From JSON file:
    python3 reprice_swaps.py --input subtransactions.json --output reprice_plan.json

    # From stdin (piped from a TRES query result):
    cat subtransactions.json | python3 reprice_swaps.py --output reprice_plan.json

    # Dry-run preview only (no output file):
    python3 reprice_swaps.py --input subtransactions.json --preview

Input format:
    JSON array of subtransaction objects, each with at minimum:
    {
        "id": "...",
        "amount": 123.45,
        "balanceFactor": -1.0 or 1.0,
        "fiatValue": 100.00,
        "isManualFiatValue": false,
        "tx": { "id": "...", "identifier": "0x..." },
        "asset": { "assetClass": { "symbol": "SOL" } },
        "belongsTo": { "name": "TVL" },
        "flowRule": [{ "integrationAccount": { "name": "Swaps Clearing Account", "value": "818" } }]
    }

Output format:
    JSON object with:
    {
        "summary": { ... aggregate stats ... },
        "transactions": [
            {
                "tx_id": "...",
                "tx_identifier": "0x...",
                "outflows": [ ... ],
                "inflows": [ ... ],
                "total_outflow_fiat": 1234.56,
                "total_inflow_fiat_before": 1230.00,
                "total_inflow_fiat_after": 1234.56,
                "adjustments": [
                    {
                        "subtx_id": "...",
                        "asset_symbol": "YT-apyUSD",
                        "fiat_before": 30.00,
                        "fiat_after": 30.10,
                        "adjustment": 0.10,
                        "was_manual": false
                    }
                ],
                "case": "one_out_many_in",
                "warnings": []
            }
        ],
        "mutations": [
            {
                "subtx_id": "...",
                "new_fiat_value": "30.10",
                "currency": "usd"
            }
        ],
        "warnings": [ ... global warnings ... ]
    }
"""

import json
import sys
import argparse
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP


def parse_args():
    parser = argparse.ArgumentParser(description="ASC 845 Swap Repricing Engine")
    parser.add_argument("--input", "-i", help="Input JSON file path (or use stdin)")
    parser.add_argument("--output", "-o", help="Output JSON file path for reprice plan")
    parser.add_argument("--preview", action="store_true", help="Preview only, print summary to stdout")
    parser.add_argument("--target-account", default=None,
                        help="Filter: only process subtxs mapped to this ERP account name")
    parser.add_argument("--target-account-value", default=None,
                        help="Filter: only process subtxs mapped to this ERP account value/number")
    parser.add_argument("--activity-tags", nargs="*", default=None,
                        help="Filter: only process subtxs with these classification activities "
                             "(e.g. 'SWAP' 'STAKING LOCKUP'). Omit to include all.")
    parser.add_argument("--currency", default="usd", help="Currency for mutations (default: usd)")
    parser.add_argument("--precision", type=int, default=6,
                        help="Decimal precision for fiat values (default: 6)")
    return parser.parse_args()


def load_subtransactions(input_path):
    """Load subtransaction data from file or stdin."""
    if input_path:
        with open(input_path, "r") as f:
            return json.load(f)
    else:
        return json.load(sys.stdin)


def matches_target_account(subtx, target_name=None, target_value=None):
    """Check if a subtransaction is mapped to the target ERP account."""
    flow_rules = subtx.get("flowRule", [])
    if not flow_rules:
        return False
    for rule in flow_rules:
        acct = rule.get("integrationAccount", {})
        if not acct:
            continue
        if target_name and acct.get("name") == target_name:
            return True
        if target_value and str(acct.get("value")) == str(target_value):
            return True
    # If no target specified, include all
    if target_name is None and target_value is None:
        return True
    return False


def group_by_transaction(subtransactions):
    """Group subtransactions by parent transaction ID."""
    groups = defaultdict(list)
    for stx in subtransactions:
        tx_id = stx.get("tx", {}).get("id", "unknown")
        groups[tx_id].append(stx)
    return groups


def classify_legs(subtxs):
    """Separate subtransactions into outflows and inflows."""
    outflows = [s for s in subtxs if s.get("balanceFactor", 0) == -1.0]
    inflows = [s for s in subtxs if s.get("balanceFactor", 0) == 1.0]
    return outflows, inflows


def determine_case(outflows, inflows):
    """Determine which repricing case applies."""
    n_out = len(outflows)
    n_in = len(inflows)
    if n_out == 1 and n_in == 1:
        return "one_out_one_in"
    elif n_out == 1 and n_in > 1:
        return "one_out_many_in"
    elif n_out > 1 and n_in == 1:
        return "many_out_one_in"
    elif n_out > 1 and n_in > 1:
        return "many_out_many_in"
    else:
        return "incomplete"


def compute_repricing(outflows, inflows, precision=6):
    """
    Compute new fiat values for inflows based on ASC 845 equal-value exchange.

    Returns list of adjustments and list of warnings.
    """
    adjustments = []
    warnings = []

    # Calculate total outflow fiat
    total_outflow_fiat = Decimal("0")
    for o in outflows:
        fv = o.get("fiatValue")
        if fv is None:
            warnings.append(f"Outflow {o['id']} has null fiatValue — skipping transaction")
            return [], warnings
        total_outflow_fiat += Decimal(str(fv))

    if total_outflow_fiat == 0:
        warnings.append("Total outflow fiat is $0 — nothing to propagate")
        return [], warnings

    # Calculate total inflow fiat (used for proportional allocation)
    total_inflow_fiat = Decimal("0")
    for i in inflows:
        fv = i.get("fiatValue")
        if fv is not None:
            total_inflow_fiat += Decimal(str(fv))

    # Compute new fiat values for each inflow
    case = determine_case(outflows, inflows)

    if case == "one_out_one_in":
        inflow = inflows[0]
        new_fiat = total_outflow_fiat
        adjustments.append({
            "subtx_id": inflow["id"],
            "asset_symbol": inflow.get("asset", {}).get("assetClass", {}).get("symbol", "?"),
            "wallet": inflow.get("belongsTo", {}).get("name", "?"),
            "fiat_before": float(inflow.get("fiatValue", 0) or 0),
            "fiat_after": float(new_fiat.quantize(Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
            "adjustment": float((new_fiat - Decimal(str(inflow.get("fiatValue", 0) or 0))).quantize(
                Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
            "was_manual": inflow.get("isManualFiatValue", False),
        })

    elif case in ("one_out_many_in", "many_out_many_in"):
        # Difference-based allocation proportional to TOKEN AMOUNTS
        # 1. Calculate the gap between outflow and inflow totals
        # 2. Distribute the gap across inflows by their token amounts
        # 3. Add each inflow's share of the gap to its original fiat value
        difference = total_outflow_fiat - total_inflow_fiat

        # Calculate total inflow token amount for proportional split
        total_inflow_tokens = Decimal("0")
        for i in inflows:
            total_inflow_tokens += Decimal(str(i.get("amount", 0) or 0))

        if total_inflow_tokens == 0:
            # No token amounts — distribute difference equally
            warnings.append("All inflow token amounts are 0 — distributing difference equally")
            equal_adj = difference / len(inflows)
            for inflow in inflows:
                inflow_fiat = Decimal(str(inflow.get("fiatValue", 0) or 0))
                new_fiat = inflow_fiat + equal_adj
                adjustments.append({
                    "subtx_id": inflow["id"],
                    "asset_symbol": inflow.get("asset", {}).get("assetClass", {}).get("symbol", "?"),
                    "wallet": inflow.get("belongsTo", {}).get("name", "?"),
                    "fiat_before": float(inflow_fiat),
                    "fiat_after": float(new_fiat.quantize(Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
                    "adjustment": float(equal_adj.quantize(Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
                    "was_manual": inflow.get("isManualFiatValue", False),
                })
        else:
            # Proportional allocation by token amount
            # Each inflow gets: original_fiat + (difference × token_amount / total_tokens)
            # Last inflow gets remainder to absorb rounding drift
            allocated_adjustment = Decimal("0")
            for idx, inflow in enumerate(inflows):
                inflow_fiat = Decimal(str(inflow.get("fiatValue", 0) or 0))
                inflow_tokens = Decimal(str(inflow.get("amount", 0) or 0))
                token_proportion = inflow_tokens / total_inflow_tokens

                if idx == len(inflows) - 1:
                    # Last inflow gets remainder to ensure exact match
                    this_adjustment = difference - allocated_adjustment
                else:
                    this_adjustment = (difference * token_proportion).quantize(
                        Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)
                    allocated_adjustment += this_adjustment

                new_fiat = inflow_fiat + this_adjustment

                adjustments.append({
                    "subtx_id": inflow["id"],
                    "asset_symbol": inflow.get("asset", {}).get("assetClass", {}).get("symbol", "?"),
                    "wallet": inflow.get("belongsTo", {}).get("name", "?"),
                    "fiat_before": float(inflow_fiat),
                    "fiat_after": float(new_fiat.quantize(Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
                    "adjustment": float(this_adjustment.quantize(
                        Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
                    "was_manual": inflow.get("isManualFiatValue", False),
                })

    elif case == "many_out_one_in":
        inflow = inflows[0]
        new_fiat = total_outflow_fiat
        adjustments.append({
            "subtx_id": inflow["id"],
            "asset_symbol": inflow.get("asset", {}).get("assetClass", {}).get("symbol", "?"),
            "wallet": inflow.get("belongsTo", {}).get("name", "?"),
            "fiat_before": float(inflow.get("fiatValue", 0) or 0),
            "fiat_after": float(new_fiat.quantize(Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
            "adjustment": float((new_fiat - Decimal(str(inflow.get("fiatValue", 0) or 0))).quantize(
                Decimal(f"1e-{precision}"), rounding=ROUND_HALF_UP)),
            "was_manual": inflow.get("isManualFiatValue", False),
        })

    # Flag manually-priced inflows
    for adj in adjustments:
        if adj["was_manual"]:
            warnings.append(
                f"Subtx {adj['subtx_id']} ({adj['asset_symbol']}) already has a manual fiat value — "
                f"will be overwritten"
            )

    return adjustments, warnings


def build_reprice_plan(subtransactions, target_name=None, target_value=None,
                       currency="usd", precision=6, activity_tags=None):
    """
    Main engine: takes raw subtransactions, returns a complete reprice plan.

    Args:
        activity_tags: Optional list of classification activity strings to filter by.
                       If provided, only subtransactions whose tx.classification.activity
                       is in this list will be included. If None, all are included.
    """
    # Filter for target account
    filtered = [s for s in subtransactions if matches_target_account(s, target_name, target_value)]

    # Filter by activity tags if specified
    if activity_tags:
        tag_set = set(activity_tags)
        filtered = [
            s for s in filtered
            if s.get("tx", {}).get("classification", {}) is not None
            and s.get("tx", {}).get("classification", {}).get("activity") in tag_set
        ]

    # Group by parent transaction
    groups = group_by_transaction(filtered)

    plan = {
        "summary": {},
        "transactions": [],
        "mutations": [],
        "warnings": [],
    }

    total_outflow_fiat = Decimal("0")
    total_inflow_fiat_before = Decimal("0")
    total_inflow_fiat_after = Decimal("0")
    total_adjustments = 0
    total_skipped = 0
    total_manual_overwrites = 0

    for tx_id, subtxs in sorted(groups.items(), key=lambda x: x[0]):
        outflows, inflows = classify_legs(subtxs)
        case = determine_case(outflows, inflows)

        tx_identifier = subtxs[0].get("tx", {}).get("identifier", "?")

        if case == "incomplete":
            plan["warnings"].append(
                f"TX {tx_identifier}: only has {'outflows' if outflows else 'inflows'} — skipped"
            )
            total_skipped += 1
            continue

        adjustments, warnings = compute_repricing(outflows, inflows, precision)

        if not adjustments and warnings:
            plan["warnings"].extend([f"TX {tx_identifier}: {w}" for w in warnings])
            total_skipped += 1
            continue

        tx_outflow_total = sum(Decimal(str(o.get("fiatValue", 0) or 0)) for o in outflows)
        tx_inflow_before = sum(Decimal(str(i.get("fiatValue", 0) or 0)) for i in inflows)
        tx_inflow_after = sum(Decimal(str(a["fiat_after"])) for a in adjustments)

        total_outflow_fiat += tx_outflow_total
        total_inflow_fiat_before += tx_inflow_before
        total_inflow_fiat_after += tx_inflow_after
        total_adjustments += len(adjustments)

        for adj in adjustments:
            if adj["was_manual"]:
                total_manual_overwrites += 1

        tx_entry = {
            "tx_id": tx_id,
            "tx_identifier": tx_identifier,
            "outflow_count": len(outflows),
            "inflow_count": len(inflows),
            "case": case,
            "total_outflow_fiat": float(tx_outflow_total),
            "total_inflow_fiat_before": float(tx_inflow_before),
            "total_inflow_fiat_after": float(tx_inflow_after),
            "residual_before": float(tx_outflow_total - tx_inflow_before),
            "residual_after": float(tx_outflow_total - tx_inflow_after),
            "adjustments": adjustments,
            "warnings": [f"TX {tx_identifier}: {w}" for w in warnings],
        }
        plan["transactions"].append(tx_entry)

        # Build mutations
        for adj in adjustments:
            # Only create mutation if the value actually changes
            if abs(adj["adjustment"]) > 1e-8:
                plan["mutations"].append({
                    "subtx_id": adj["subtx_id"],
                    "new_fiat_value": str(round(adj["fiat_after"], precision)),
                    "currency": currency,
                })

    plan["summary"] = {
        "total_transactions_processed": len(plan["transactions"]),
        "total_transactions_skipped": total_skipped,
        "total_subtx_adjustments": total_adjustments,
        "total_mutations_needed": len(plan["mutations"]),
        "total_manual_overwrites": total_manual_overwrites,
        "total_outflow_fiat": float(total_outflow_fiat),
        "total_inflow_fiat_before": float(total_inflow_fiat_before),
        "total_inflow_fiat_after": float(total_inflow_fiat_after),
        "net_residual_before": float(total_outflow_fiat - total_inflow_fiat_before),
        "net_residual_after": float(total_outflow_fiat - total_inflow_fiat_after),
        "currency": currency,
    }

    return plan


def print_preview(plan):
    """Print a human-readable preview of the reprice plan."""
    s = plan["summary"]

    print("=" * 80)
    print("ASC 845 SWAP REPRICING PLAN — PREVIEW")
    print("=" * 80)
    print()
    print(f"Transactions processed:     {s['total_transactions_processed']}")
    print(f"Transactions skipped:       {s['total_transactions_skipped']}")
    print(f"Subtx adjustments:          {s['total_subtx_adjustments']}")
    print(f"Mutations to execute:       {s['total_mutations_needed']}")
    print(f"Manual overwrites:          {s['total_manual_overwrites']}")
    print()
    print(f"Total outflow fiat:         ${s['total_outflow_fiat']:>14,.2f}")
    print(f"Total inflow fiat (before): ${s['total_inflow_fiat_before']:>14,.2f}")
    print(f"Total inflow fiat (after):  ${s['total_inflow_fiat_after']:>14,.2f}")
    print(f"Net residual (before):      ${s['net_residual_before']:>14,.2f}")
    print(f"Net residual (after):       ${s['net_residual_after']:>14,.2f}")
    print()

    if plan["warnings"]:
        print("WARNINGS:")
        for w in plan["warnings"][:20]:
            print(f"  ⚠ {w}")
        if len(plan["warnings"]) > 20:
            print(f"  ... and {len(plan['warnings']) - 20} more")
        print()

    # Show sample transactions
    print("SAMPLE TRANSACTIONS (first 10):")
    print(f"{'TX Identifier':<30} {'Case':<20} {'Outflow':>12} {'In Before':>12} {'In After':>12} {'Adj':>12}")
    print("-" * 100)
    for tx in plan["transactions"][:10]:
        ident = tx["tx_identifier"][:28] + ".." if len(tx["tx_identifier"]) > 30 else tx["tx_identifier"]
        print(f"{ident:<30} {tx['case']:<20} "
              f"${tx['total_outflow_fiat']:>11,.2f} "
              f"${tx['total_inflow_fiat_before']:>11,.2f} "
              f"${tx['total_inflow_fiat_after']:>11,.2f} "
              f"${tx['total_inflow_fiat_after'] - tx['total_inflow_fiat_before']:>11,.2f}")

    if len(plan["transactions"]) > 10:
        print(f"  ... and {len(plan['transactions']) - 10} more transactions")
    print()


def main():
    args = parse_args()

    # Load data
    data = load_subtransactions(args.input)

    # Handle nested structures (TRES query results may be wrapped)
    if isinstance(data, dict):
        # Try to extract from standard TRES response shape
        if "data" in data:
            data = data["data"].get("subTransaction", {}).get("results", [])
        elif "results" in data:
            data = data["results"]

    # Build the plan
    plan = build_reprice_plan(
        subtransactions=data,
        target_name=args.target_account,
        target_value=args.target_account_value,
        currency=args.currency,
        precision=args.precision,
        activity_tags=args.activity_tags,
    )

    # Output
    if args.preview:
        print_preview(plan)
    else:
        print_preview(plan)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(plan, f, indent=2)
        print(f"\nReprice plan saved to: {args.output}")
        print(f"Mutations ready: {len(plan['mutations'])} setManualFiatValue calls")


if __name__ == "__main__":
    main()
