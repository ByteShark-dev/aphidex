"""Build the compact Grounded 2 combat recommendation domain for Aphidex.

The extractor outputs are intentionally kept outside the application because
the complete build matrices are hundreds of megabytes.  This importer keeps
only verified weapon, tier, enhancement, projectile and shield facts needed
by the on-device calculator.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/data/g2/combat_recommendations.json"
REPORT = ROOT / "outputs/combat_recommendations_import_report.json"
ICON_DIR = ROOT / "assets/g2/equipment/projectiles"
DEFAULT_PROJECTILES = Path(
    "/mnt/F/ByteShark-Dev/Aphidex_extractor_v1/aphidex_extractor_v1/"
    "output_aphidex_extractor_v1_augusta_projectiles_full"
)
DEFAULT_UPGRADES = Path(
    "/mnt/F/ByteShark-Dev/Aphidex_extractor_v1/aphidex_extractor_v1/"
    "output_aphidex_extractor_v1_augusta_weapon_upgrades"
)


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def number(value):
    return value if isinstance(value, (int, float)) else None


def compact_damage(node: dict | None) -> dict:
    node = node or {}
    detail = node.get("damageTypeDetail") or {}
    return {
        "damage": number(node.get("damage")),
        "physical": detail.get("physical"),
        "element": detail.get("element"),
        "stun": number(node.get("hitStun")),
        "poise": number(node.get("poiseDamage")),
        "statuses": [
            item.get("type") or item.get("row")
            for item in node.get("statusEffectRefs", [])
            if isinstance(item, dict) and (item.get("type") or item.get("row"))
        ],
    }


def compact_attack(attack: dict, *, interval_seconds: float | None = None) -> dict:
    compact = {
        "row": (attack.get("source") or {}).get("row"),
        "base": compact_damage(attack.get("base")),
        "charged": compact_damage(attack.get("charged")),
        "perfect": compact_damage(attack.get("perfectCharged")),
        "stamina": number(attack.get("staminaCost")),
        "chargedStamina": number(attack.get("chargedStaminaCost")),
    }
    # This is the extractor's nominal hit-to-hit interval, never inferred
    # from animation duration. Omit unverified values rather than encoding a
    # false cadence in the compact app domain.
    if interval_seconds is not None and interval_seconds > 0:
        compact["intervalSeconds"] = interval_seconds
    return compact


def compact_route(route: dict) -> dict:
    levels = route.get("levels") or []
    maximum = max(levels, key=lambda item: item.get("level", -1), default={})
    return {
        "tag": route.get("routeTag"),
        "mode": route.get("routeMode"),
        "damageType": route.get("selectedDamageType"),
        "effectUnlock": route.get("effectUnlock"),
        "maxLevel": maximum.get("level", 0),
        "increasePercent": maximum.get("increasePercent"),
        "attacks": [
            {
                "row": (item.get("attack") or {}).get("row"),
                "projectedDamage": number(item.get("projectedDamage")),
                "damageType": item.get("selectedDamageType"),
            }
            for item in maximum.get("attacks", [])
        ],
        "projectionStatus": route.get("projectionStatus"),
    }


def safe_icon_name(row: str, source: Path | None) -> str:
    if source is None or not source.exists():
        return ""
    suffix = source.suffix.lower() or ".png"
    name = re.sub(r"[^A-Za-z0-9_.-]", "_", row) + suffix
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, ICON_DIR / name)
    return f"assets/g2/equipment/projectiles/{name}"


def generate(projectiles_root: Path, upgrades_root: Path) -> dict:
    weapon_path = projectiles_root / "phase2/equipment/weapon/grounded2_weapon_domain_v2.json"
    projectile_path = projectiles_root / "phase2/equipment/weapon/grounded2_projectile_domain_v1.json"
    scope_path = projectiles_root / "phase2/economy/grounded2_equipment_scope_v1.json"
    qa_path = projectiles_root / "final/aphidex_extractor_qa_v1.json"
    upgrades_path = upgrades_root / "phase2/equipment/weapon/grounded2_weapon_domain_v2.json"
    weapons_doc, projectiles_doc, scope, qa, upgrades_doc = map(
        read, (weapon_path, projectile_path, scope_path, qa_path, upgrades_path)
    )
    if not weapons_doc.get("qualityGate", {}).get("pass"):
        raise SystemExit("Weapon quality gate failed")
    if not projectiles_doc.get("qualityGate", {}).get("pass"):
        raise SystemExit("Projectile quality gate failed")
    if not scope.get("qualityGate", {}).get("pass"):
        raise SystemExit("Equipment scope quality gate failed")
    if qa.get("status") not in {"PASS", "PASS_WITH_SOURCE_WARNINGS"}:
        raise SystemExit(f"Final extractor QA is {qa.get('status')!r}")
    if len(weapons_doc.get("weapons", [])) != 58 or len(weapons_doc.get("shields", [])) != 9:
        raise SystemExit("Expected 58 weapons and 9 shields")

    upgrades = {item["technicalId"]: item for item in upgrades_doc["weapons"]}
    weapons = []
    for item in weapons_doc["weapons"]:
        upgrade = upgrades.get(item["technicalId"], {})
        upgrade_intervals = {
            (attack.get("source") or {}).get("row"): number(
                attack.get("attackIntervalSeconds")
            )
            for attack in (upgrade.get("combat") or {}).get("attacks", [])
            if number(attack.get("attackIntervalSeconds")) is not None
            and number(attack.get("attackIntervalSeconds")) > 0
        }
        combat = item.get("combat") or {}
        tier_upgrade = upgrade.get("tierUpgrade")
        if not (tier_upgrade or {}).get("canUpgradeTier"):
            tier_upgrade = None
        weapons.append({
            "id": item["technicalId"],
            "tier": item.get("tier"),
            "twoHanded": item.get("twoHanded"),
            # Same source-driven rule used by extractor full_build_composer v1.2.0.
            "shieldCompatible": not bool(item.get("twoHanded")) and not bool(item.get("isDualWield")),
            "attacks": [
                compact_attack(
                    value,
                    interval_seconds=upgrade_intervals.get(
                        (value.get("source") or {}).get("row")
                    ),
                )
                for value in combat.get("attacks", [])
            ],
            "tierUpgrade": {
                "tag": (tier_upgrade or {}).get("tierUpgradeTag"),
                "targets": (tier_upgrade or {}).get("targetTiers", []),
            } if tier_upgrade else None,
            "enhancementRoutes": [
                compact_route(route)
                for route in (upgrade.get("enhancement") or {}).get("routeOutcomes", [])
            ],
        })

    availability = scope.get("byAmmo") or {}
    projectiles = []
    seen = set()
    for item in projectiles_doc.get("projectiles", []):
        ammo = item.get("ammo") or {}
        row = (ammo.get("source") or {}).get("row")
        if not row or row in seen or not (availability.get(row) or {}).get("includeInCurrentG2Builds"):
            continue
        seen.add(row)
        icon_node = ammo.get("icon") or {}
        local_icon = Path(icon_node["localPng"]) if icon_node.get("localPng") else None
        attack = item.get("attack") or {}
        projectiles.append({
            "id": row,
            "tier": ammo.get("tier"),
            "family": "ammo",
            "icon": safe_icon_name(row, local_icon),
            "attack": compact_attack(attack),
            "launcherIds": sorted({value["technicalId"] for value in item.get("usableBy", [])}),
            "sourceId": item.get("id"),
        })

    payload = {
        "schema": "aphidex.combat-recommendations.v1",
        "version": 1,
        "manifest": {
            "extractorQa": qa.get("status"),
            "sourceWarnings": qa.get("warnings") or qa.get("sourceWarnings") or [],
            "projectileSource": str(projectiles_root),
            "upgradeSource": str(upgrades_root),
            "counts": {
                "weapons": len(weapons),
                "shields": len(weapons_doc["shields"]),
                "projectiles": len(projectiles),
                "tierUpgradeableWeapons": sum(item["tierUpgrade"] is not None for item in weapons),
                "reachableTiers": sum(len(item["tierUpgrade"]["targets"]) for item in weapons if item["tierUpgrade"]),
                "enhancementRoutes": sum(len(item["enhancementRoutes"]) for item in weapons),
            },
            "effectivenessThresholds": {"excellent": 1.5, "strong": 1.15, "neutral": 0.85, "weak": 0.5},
        },
        "maxEnhancementLevel": max((route["maxLevel"] for item in weapons for route in item["enhancementRoutes"]), default=0),
        "weapons": weapons,
        "shields": [{
            "id": item["technicalId"],
            "tier": item.get("tier"),
            "blockDamageMultiplier": (item.get("combat") or {}).get("blockDamageMultiplier"),
            "blockStaminaCost": (item.get("combat") or {}).get("blockStaminaCost"),
            "durability": (item.get("combat") or {}).get("durability"),
        } for item in weapons_doc["shields"]],
        "projectiles": projectiles,
    }
    # The source contains 36 ammo/projectile pairs. Five are intentionally not
    # packaged: three are `not_current_g2` and two are technical display rows.
    if projectiles_doc.get("summary", {}).get("ammoProjectilePairs") != 36 or len(projectiles) != 31:
        raise SystemExit(
            f"Expected 36 source pairs and 31 current player-facing projectiles, got {len(projectiles)}"
        )
    write(OUTPUT, payload)
    report = dict(payload["manifest"])
    report["output"] = str(OUTPUT)
    write(REPORT, report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--projectiles-source", type=Path, default=DEFAULT_PROJECTILES)
    parser.add_argument("--upgrades-source", type=Path, default=DEFAULT_UPGRADES)
    args = parser.parse_args()
    print(json.dumps(generate(args.projectiles_source, args.upgrades_source), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
