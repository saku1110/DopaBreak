"""DopaBreak acquisition planning model. Hypotheses, not measured performance.

Run with Python 3; writes only the adjacent JSON report. No network or app access.
All acquisition rates use NEW DOWNLOADS, including downloads never first opened.
Annual contribution reserves a full year of variable servicing cost at purchase.
"""
import json
from pathlib import Path

MARKETS = {
    "JP": dict(currency="JPY", annual=4980, tax=0.10, fee=0.15,
               refund=0.04, annual_variable_cost=200),
    "US": dict(currency="USD", annual=39.99, tax=0, fee=0.15,
               refund=0.04, annual_variable_cost=1.50),
    "KR": dict(currency="KRW", annual=49000, tax=0.10, fee=0.15,
               refund=0.04, annual_variable_cost=2000),
}


def annual_contribution(market):
    return (market["annual"] / (1 + market["tax"])
            * (1 - market["fee"]) * (1 - market["refund"])
            - market["annual_variable_cost"])


results = {"as_of": "2026-09-08", "status": "planning_assumptions",
           "markets": {}, "jp_scenarios": []}
for country, market in MARKETS.items():
    contribution = annual_contribution(market)
    results["markets"][country] = {
        "inputs": market,
        "annual_contribution_before_acquisition": contribution,
        "download_cost_limits": [
            {"download_to_annual_paid": p,
             "break_even": p * contribution,
             "retain_30_percent_of_contribution": p * contribution * 0.70,
             "target_cpt_at_50_percent_tap_to_download": p * contribution * .70 * .50}
            for p in [.02, .04, .06, .08, .10]],
    }

jp = annual_contribution(MARKETS["JP"])
for name, trial_start, trial_paid, download_cost in [
    ("weak", .05, .30, 350),
    ("base", .08, .50, 250),
    ("strong", .12, .60, 150),
]:
    spend = 100000
    p = trial_start * trial_paid
    downloads = spend / download_cost
    payers = downloads * p
    results["jp_scenarios"].append({
        "name": name, "spend": spend, "download_to_trial": trial_start,
        "trial_to_annual_paid": trial_paid, "download_to_annual_paid": p,
        "cost_per_download": download_cost, "downloads": downloads,
        "annual_payers_before_refunds": payers, "paid_cac": spend / payers,
        "contribution_after_ad_spend": payers * jp - spend,
        "contribution_roas": payers * jp / spend,
    })

monthly = 980 / 1.1 * .85 * .96 - 20
results["jp_plan_mix"] = {
    "annual_share_of_new_payers_assumption": .80,
    "monthly_contribution_per_billing": monthly,
    "first_billing_contribution_with_annual_cost_reserved": .8 * jp + .2 * monthly,
    "first_12_months_contribution": {
        str(n): .8 * jp + .2 * monthly * n for n in [3, 6, 9]},
    "note": "Months are expected paid billings within 12 months, not guaranteed retention.",
}
results["jp_sensitivity"] = {
    "annual_contribution_if_fee_30_percent": annual_contribution({**MARKETS["JP"], "fee": .30}),
    "two_annual_periods_contribution_by_first_renewal_probability": {
        str(r): jp * (1 + r) for r in [.25, .40, .60]},
    "note": "Second annual term starts at month 12 after first payment; undiscounted and not immediate cash.",
}
results["published_benchmark_stress_tests"] = []
for source, country, usd_cost in [
    ("Adapty 2026-07-13", "JP", 1.49),
    ("MobileAction 2026 report, 2025 data", "JP", 2.89),
    ("Adapty 2026-07-13", "US", 2.51),
    ("MobileAction 2026 report, 2025 data", "US", 3.85),
]:
    cost = usd_cost * 150 if country == "JP" else usd_cost
    unit = annual_contribution(MARKETS[country])
    results["published_benchmark_stress_tests"].append({
        "source": source, "country": country, "cost_per_download_usd": usd_cost,
        "planning_usdjpy_not_spot_fx": 150,
        "break_even_download_to_annual_paid": cost / unit,
        "retain_30_percent_required_conversion": cost / (.70 * unit),
    })

out = Path(__file__).with_suffix(".json")
out.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
print(out)
print("JP annual contribution:", round(jp, 2))
for row in results["jp_scenarios"]:
    print(row["name"], "ad contribution:", round(row["contribution_after_ad_spend"], 2))
