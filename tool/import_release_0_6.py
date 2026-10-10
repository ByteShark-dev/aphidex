"""Apply only source-backed Release 0.6 data from Aphidex extractor v1.

The legacy 1.3 importer is intentionally Windows/editorial-asset dependent.
This small companion importer is portable and deliberately narrow: it validates
the final extractor manifest, records a deterministic diff, synchronizes the
combat fields Aphidex already renders, and adds the source-backed Release 0.6
entities and the sixth Buggy.  It never removes catalogue entries.
"""
from __future__ import annotations

import argparse
import copy
import json
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"
DEFAULT_EXTRACTOR = Path(
    "/mnt/F/ByteShark-Dev/Aphidex_extractor_v1/aphidex_extractor_v1/"
    "output_aphidex_extractor_v1_missing_export_verification"
)
LANGUAGES = ("en", "es", "ru")
RELEASE_0_6_IDS = {
    "Centipede": "g2_centipede",
    "SpiderDivingBellOGRE": "g2_ogre_diving_bell_spider",
    "TermiteKing": "g2_termite_king",
    "TermiteKingOGRE": "g2_ogre_termite_king",
    "TermiteNymph": "g2_termite_nymph",
    "TermiteQueen": "g2_termite_queen",
    "TermiteSoldier": "g2_termite_soldier",
    "TermiteSoldierORC": "g2_orc_termite_soldier",
    "TermiteWorker": "g2_termite_worker",
    "TermiteWorkerORC": "g2_orc_termite_worker",
}
RELEASE_NAMES = {
    "Centipede": "Centipede",
    "SpiderDivingBellOGRE": "Diving Bell Spider O.G.R.E.",
    "TermiteKing": "Termite King",
    "TermiteKingOGRE": "Termite King O.G.R.E.",
    "TermiteNymph": "Termite Nymph",
    "TermiteQueen": "Termite Queen",
    "TermiteSoldier": "Termite Soldier",
    "TermiteSoldierORC": "Termite Soldier O.R.C.",
    "TermiteWorker": "Termite Worker",
    "TermiteWorkerORC": "Termite Worker O.R.C.",
}
BUGGY_IDS = {
    "Ant_Soldier_Brown_Augusta_Buggy": "g2_buggy_red_soldier_ant",
    "Spider_OrbWeaver_Augusta_Buggy": "g2_buggy_orb_weaver",
    "Ant_Soldier_Black_Augusta_Buggy": "g2_buggy_black_soldier_ant",
    "ToeBiter_Nymph_Buggy": "g2_buggy_toe_biter",
    "Ladybug_Augusta_Buggy": "g2_buggy_ladybug",
    "PotatoBug_Buggy": "g2_buggy_potato_beetle",
}
POTATO_BUGGY_NAME = "Potato Beetle Buggy"
ELEMENTAL = {"fresh", "salty", "sour", "spicy"}


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def technical_label(value: str) -> str:
    value = value.replace("ORC", "O.R.C.").replace("OGRE", "O.G.R.E.")
    out = []
    for char in value:
        if out and char.isupper() and out[-1].isalnum() and not out[-1].isupper():
            out.append(" ")
        out.append(char)
    return "".join(out).replace("_", " ").strip()


def normalized_bonuses(rows):
    grouped = defaultdict(float)
    for row in rows or []:
        percent = row.get("percent")
        for damage_type in row.get("damageTypes") or []:
            if percent is not None:
                grouped[str(damage_type).lower()] = max(grouped[str(damage_type).lower()], float(percent))
    return [{"type": key, "bonusPct": round(value)} for key, value in sorted(grouped.items())]


def normalized_attacks(rows, existing=None):
    existing_by_id = {
        row.get("technicalId"): row
        for row in existing or []
        if row.get("technicalId")
    }
    result = []
    seen = set()
    for row in rows or []:
        if row.get("resolved") is not True:
            continue
        technical_id = str(row.get("id") or row.get("ability") or "")
        # A repeated ability row is a source implementation detail, not a UI move.
        if not technical_id or technical_id in seen:
            continue
        seen.add(technical_id)
        damage = row.get("damage") or {}
        types = [str(value).lower() for value in damage.get("types") or []]
        status_ids = [str(value) for value in damage.get("statusEffects") or []]
        normalized = {
            "name": technical_label(str(row.get("ability") or technical_id)),
            "technicalId": technical_id,
            "tags": sorted(set(types + (["ranged"] if row.get("ranged") else []) + (["projectile"] if row.get("indirectCombat") else []))),
            "damageTypes": types,
            "damage": damage.get("amount"),
            "cooldownSeconds": row.get("cooldown"),
            "range": row.get("range"),
            "stun": damage.get("hitStun"),
            "statusEffects": status_ids,
            "statusEffectDetails": [{"id": value, "value": None, "durationSeconds": None} for value in status_ids],
            "ranged": bool(row.get("ranged")),
            "projectile": bool(row.get("indirectCombat")),
            "hitResolutionType": row.get("hitResolutionType"),
            "actionType": "projectile" if row.get("indirectCombat") else "ranged" if row.get("ranged") else "aoe" if row.get("hitResolutionType") == "AOE" else "melee",
            "blockability": "unblockable" if any("unblockable" in value for value in types) else "unknown",
        }
        # The extractor resolves mechanical fields, not localized move names.
        # Preserve an established UI label/note when the technical move ID is
        # unchanged instead of replacing it with a guessed identifier split.
        previous = existing_by_id.get(technical_id)
        if previous:
            for field in ("name", "notes"):
                if field in previous:
                    normalized[field] = previous[field]
        result.append(normalized)
    # An absent or unresolved source move is not evidence that it was removed.
    # Retain the app's explicit unknown entries until the extractor resolves it.
    for previous in existing or []:
        technical_id = previous.get("technicalId")
        if technical_id and technical_id not in seen:
            result.append(copy.deepcopy(previous))
    return result


def normalized_loot(technical_id: str, loot_domain: dict):
    profile = next((item for item in (loot_domain.get("technicalCreatures", {}).get(technical_id, {}).get("profiles") or []) if item.get("role") == "primary"), None)
    if not profile:
        return [], []
    rows = [row for row in (profile.get("loot") or {}).get("rolls", []) if row.get("parseStatus") == "resolved" and row.get("rollKind") == "item" and row.get("itemRow")]
    grouped = defaultdict(list)
    for row in rows:
        grouped[row["itemRow"]].append(row)
    loot = []
    advanced = []
    for item_id, item_rows in sorted(grouped.items()):
        chances = [float(row.get("baseDropChance") or row.get("dropChance") or 0) for row in item_rows]
        counts = [int(row.get("count") or 0) for row in item_rows]
        loot.append({"section": "rare" if max(chances) <= .05 else "loot", "item": technical_label(item_id), "minCount": sum(count for count, chance in zip(counts, chances) if chance >= 1), "maxCount": sum(counts)})
        for row, chance in zip(item_rows, chances):
            advanced.append({"item": technical_label(item_id), "countLabel": str(row.get("count") or 0), "chancePct": round(chance * 100), "rollCount": 1, "notes": None})
    return loot, advanced


def localized_attacks(rows, language: str):
    """Select legacy localized UI copy when writing a language-specific detail."""
    resolved = copy.deepcopy(rows)
    for row in resolved:
        for field in ("name", "notes"):
            if isinstance(row.get(field), dict):
                text = row[field]
                row[field] = text.get(language) or text.get("en") or next(
                    iter(text.values()), ""
                )
    return resolved


def release_detail(technical_id: str, source: dict, language: str, order: int):
    stats = source.get("stats") or {}
    stun = stats.get("stun") or {}
    health = stats.get("health")
    weaknesses = normalized_bonuses(source.get("weaknesses"))
    return {
        "id": RELEASE_0_6_IDS[technical_id], "speciesKey": RELEASE_0_6_IDS[technical_id].removeprefix("g2_"),
        "technicalId": technical_id, "bestiaryId": technical_id, "name": RELEASE_NAMES[technical_id],
        "game": "g2", "tier": int(source.get("tier") or 0), "danger": "unknown", "isBoss": technical_id == "Centipede",
        "order": order, "defaultGold": False, "favoriteKey": RELEASE_0_6_IDS[technical_id], "goldLinkId": None,
        "cardNormal": "", "cardGold": "", "hasCreatureCard": False, "hasGoldCreatureCard": False,
        "hasSelectableCardVariants": False, "defaultCardVariant": None, "photo": "assets/global/Aphidex_Proximamente.webp",
        "listIconAsset": "", "mapMarkerAsset": "", "customAsset": "", "temperament": "unknown",
        "collectionGroup": "unknown", "entityType": "interactable" if technical_id == "TermiteQueen" else "creature",
        "isKillable": technical_id != "TermiteQueen", "health": None if health is None else {"rating": 1 if health < 400 else 2 if health < 700 else 3 if health < 1100 else 4 if health < 2000 else 5, "value": round(health)},
        "healthDisplay": "invulnerable" if technical_id == "TermiteQueen" else "normal",
        "elementalWeaknesses": [row for row in weaknesses if row["type"] in ELEMENTAL],
        "damageWeaknesses": [row for row in weaknesses if row["type"] not in ELEMENTAL],
        "resistancesV2": normalized_bonuses(source.get("resistances")),
        "immunities": sorted({str(value).lower() for row in source.get("immunities") or [] for value in (row.get("damageTypes", []) if isinstance(row, dict) else [row])}),
        "weaknesses": [], "resistances": [], "weakPoints": [{"part": str(part).lower(), "susceptibleDamage": "unknown", "susceptibleDamageTypes": [], "weaponFamilies": [], "provenance": "extractor_region_only"} for part in source.get("weakpoints") or []],
        "attacks": normalized_attacks(source.get("attacks")), "combatStats": {"health": None if health is None else round(health), "stunThreshold": None if stun.get("max") is None else round(stun["max"]), "stunCooldownSeconds": None if stun.get("cooldown") is None else round(stun["cooldown"])},
        "loot": [], "advancedLootTable": [], "locations": [], "environments": [], "eventAppearances": [],
        "appearanceType": "unknown", "encounterVariants": [], "availabilityStatus": "implemented_unconfirmed",
        "sourceProvenance": {"extractorStatus": "implemented_unconfirmed", "extractorTechnicalId": technical_id, "source": "Release 0.6 current Bestiary/CharacterData; no encounter or summon proof"},
        "dataRevision": "extractor_release_0_6",
    }


def compact_buggy(row: dict):
    return {
        "technicalId": row["identity"]["characterRow"],
        "baseActor": row["identity"].get("baseActor"),
        "sourceAsset": row["identity"].get("sourceAsset"),
        "stats": row.get("base", {}).get("stats") or {},
        "recipe": row.get("hatcheryRecipe") or {},
        "hatching": row.get("hatching") or {},
        "handling": row.get("handling") or {},
        "raceVariant": row.get("raceVariant"),
        "quality": row.get("quality") or {},
    }


def summary_index(detail: dict):
    return {key: detail.get(key) for key in ("id", "speciesKey", "game", "name", "tier", "danger", "isBoss", "order", "defaultGold", "favoriteKey", "goldLinkId", "cardNormal", "cardGold", "listIconAsset", "mapMarkerAsset", "customAsset", "hasCreatureCard", "hasGoldCreatureCard", "hasSelectableCardVariants", "defaultCardVariant", "weaknesses", "resistances", "temperament", "collectionGroup", "technicalId", "bestiaryId", "groupId", "cardTier", "bossCardStyle", "entityType", "hideHealth", "health", "availabilityStatus") if key in detail}


def compute_diff(source: dict, app_creatures: dict, buggy_rows: list[dict]):
    by_technical = {row.get("technicalId"): row for row in app_creatures["creatures"] if row.get("technicalId")}
    stats = attacks = resistances = loot = 0
    changed = []
    for technical_id, current in by_technical.items():
        if current.get("publicId") in BUGGY_IDS.values():
            continue
        extracted = source.get(technical_id)
        if not extracted:
            continue
        fields = []
        health = (extracted.get("stats") or {}).get("health")
        if health is not None and (current.get("combatStats") or {}).get("health") != round(health):
            stats += 1; fields.append("stats")
        if normalized_attacks(extracted.get("attacks")) != current.get("attacks", []):
            attacks += 1; fields.append("attacks")
        weakness = normalized_bonuses(extracted.get("weaknesses"))
        resistance = normalized_bonuses(extracted.get("resistances"))
        current_weakness = sorted(
            current.get("elementalWeaknesses", []) + current.get("damageWeaknesses", []),
            key=lambda row: row["type"],
        )
        if weakness != current_weakness or resistance != current.get("resistancesV2", []):
            resistances += 1; fields.append("resistancesWeaknesses")
        if fields:
            changed.append({"publicId": current.get("publicId"), "technicalId": technical_id, "fields": fields})
    return {"schema": "aphidex-release-0-6-diff-v1", "extractorStatus": "PASS_WITH_SOURCE_WARNINGS", "releaseEntitiesMissing": sorted(set(RELEASE_0_6_IDS) - set(by_technical)), "newBuggy": "PotatoBug_Buggy", "sourceBuggyCount": len(buggy_rows), "changes": {"stats": stats, "attacks": attacks, "resistancesWeaknesses": resistances, "loot": loot}, "creatures": changed}


def equipment_summary(extractor: Path) -> dict:
    """Report the validated equipment domain without fabricating a field merge.

    The extractor's drift check establishes that this release has no equipment
    identity drift.  Aphidex already has the matching roster, so retaining its
    editorial fields is safer than copying incomplete source-only rows.
    """
    equipment = read_json(DATA / "g2" / "equipment.json")
    items = equipment["items"]
    slots = defaultdict(int)
    for item in items:
        slots[item.get("slot")] += 1
    weapons = read_json(
        extractor / "phase2" / "equipment" / "baselines" /
        "grounded2_weapon_domain_v1.json"
    )["summary"]
    armor = read_json(
        extractor / "phase2" / "equipment" / "baselines" /
        "grounded2_armor_domain_v1.json"
    )["summary"]
    trinkets = read_json(
        extractor / "phase2" / "equipment" / "baselines" /
        "grounded2_trinket_domain_v1.json"
    )["summary"]
    drift = read_json(
        extractor / "phase2" / "equipment" / "equipment_baseline_drift_v1.json"
    )
    return {
        "driftStatus": drift["status"],
        "identityDrift": drift["structure"],
        "source": {
            "weapons": weapons["weapons"],
            "shields": weapons["shields"],
            "armorPieces": armor["playerArmorPieces"],
            "armorSets": armor["threePieceSets"],
            "trinkets": trinkets["playerTrinkets"],
        },
        "aphidex": {
            "weapons": slots["EEquipmentSlot::MainHand"],
            "shields": slots["EEquipmentSlot::OffHand"],
            "armorPieces": sum(
                slots[slot]
                for slot in (
                    "EEquipmentSlot::Head",
                    "EEquipmentSlot::Chest",
                    "EEquipmentSlot::Legs",
                )
            ),
            "armorSets": len(equipment["armorSets"]),
            "trinkets": slots["EEquipmentSlot::Glider"],
        },
    }


def apply(args):
    extractor = args.extractor_root.resolve()
    qa = read_json(extractor / "final" / "aphidex_extractor_qa_v1.json")
    if qa.get("status") not in {"PASS", "PASS_WITH_SOURCE_WARNINGS"}:
        raise ValueError(f"Extractor QA did not pass: {qa.get('status')!r}")
    manifest = read_json(extractor / "final" / "aphidex_extractor_manifest_v1.json")
    if manifest.get("status") != qa.get("status"):
        raise ValueError("Extractor manifest and QA status disagree")
    creature_payload = read_json(extractor / "phase1" / "aphidex_grounded2_v5_1_1.json")
    source = {row["id"]: row for row in creature_payload["creatures"]}
    loot_domain = read_json(extractor / "phase1" / "loot" / "grounded2_loot_domain_v1_2.json")
    bestiary = read_json(extractor / "phase1" / "grounded2_bestiary_v5_1_1.json")
    app_creatures = read_json(DATA / "g2" / "creatures.json")
    legacy_by_public_id = {
        row["id"]: row for row in read_json(DATA / "enemies_g2.json")
    }
    diff = compute_diff(source, app_creatures, bestiary["buggies"]["buggies"])
    diff["equipment"] = equipment_summary(extractor)
    if not args.apply:
        print(json.dumps(diff, ensure_ascii=False, indent=2))
        return

    # Sync fields that have a direct extractor owner, retaining editorial-only fields.
    for row in app_creatures["creatures"]:
        legacy = legacy_by_public_id.get(row.get("publicId"), {})
        if row.get("publicId") in BUGGY_IDS.values():
            # Buggy values belong in buggyProfile, not in the normal creature
            # combat panel. Restore the established presentation fields.
            for field in (
                "health", "healthDisplay", "combatStats", "attacks", "loot",
                "advancedLootTable", "elementalWeaknesses", "damageWeaknesses",
                "resistancesV2", "immunities",
            ):
                if field in legacy:
                    row[field] = copy.deepcopy(legacy[field])
            continue
        extracted = source.get(row.get("technicalId"))
        if not extracted:
            continue
        stats = extracted.get("stats") or {}
        stun = stats.get("stun") or {}
        health = stats.get("health")
        if health is not None:
            row["health"] = {"rating": 1 if health < 400 else 2 if health < 700 else 3 if health < 1100 else 4 if health < 2000 else 5, "value": round(health)}
            row["healthDisplay"] = "normal"
        row["combatStats"] = {"health": None if health is None else round(health), "stunThreshold": None if stun.get("max") is None else round(stun["max"]), "stunCooldownSeconds": None if stun.get("cooldown") is None else round(stun["cooldown"])}
        weaknesses = normalized_bonuses(extracted.get("weaknesses"))
        row["elementalWeaknesses"] = [item for item in weaknesses if item["type"] in ELEMENTAL]
        row["damageWeaknesses"] = [item for item in weaknesses if item["type"] not in ELEMENTAL]
        row["resistancesV2"] = normalized_bonuses(extracted.get("resistances"))
        row["immunities"] = sorted({str(value).lower() for source_row in extracted.get("immunities") or [] for value in (source_row.get("damageTypes", []) if isinstance(source_row, dict) else [source_row])})
        row["attacks"] = normalized_attacks(
            extracted.get("attacks"), legacy.get("attacks") or row.get("attacks"),
        )
        loot, advanced = normalized_loot(row["technicalId"], loot_domain)
        if loot:
            row["loot"], row["advancedLootTable"] = loot, advanced
        row["sourceStatus"] = "extractor_merged"

    next_order = max(int(row.get("order") or 0) for row in app_creatures["creatures"]) + 1
    for technical_id, public_id in RELEASE_0_6_IDS.items():
        if any(row.get("publicId") == public_id for row in app_creatures["creatures"]):
            continue
        detail = release_detail(technical_id, source[technical_id], "en", next_order)
        app_creatures["creatures"].append({"publicId": public_id, "technicalId": technical_id, "sourceStatus": "implemented_unconfirmed", **{key: value for key, value in detail.items() if key not in {"id", "name", "game", "tier", "danger", "order", "defaultGold", "favoriteKey", "goldLinkId", "cardNormal", "cardGold", "photo", "listIconAsset", "mapMarkerAsset", "customAsset", "isBoss", "health", "entityType"}}})
        next_order += 1

    buggy_by_id = {row["identity"]["characterRow"]: row for row in bestiary["buggies"]["buggies"]}
    buggy_order = max(
        int(row.get("order") or 0)
        for row in app_creatures["creatures"]
        if row.get("publicId") != "g2_buggy_potato_beetle"
    ) + 1
    for technical_id, public_id in BUGGY_IDS.items():
        profile = compact_buggy(buggy_by_id[technical_id])
        matches = [row for row in app_creatures["creatures"] if row.get("publicId") == public_id]
        if matches:
            matches[0]["buggyProfile"] = profile
            matches[0]["availabilityStatus"] = "source_backed"
            if public_id == "g2_buggy_potato_beetle":
                matches[0]["order"] = buggy_order
                matches[0]["danger"] = "unknown"
            continue
        base = copy.deepcopy(next(row for row in app_creatures["creatures"] if row.get("publicId") == "g2_buggy_toe_biter"))
        base.update({"publicId": public_id, "technicalId": technical_id, "sourceStatus": "extractor_merged", "availabilityStatus": "source_backed", "buggyProfile": profile, "order": buggy_order, "danger": "unknown"})
        app_creatures["creatures"].append(base)

    for language in LANGUAGES:
        directory = DATA / "creatures" / language / "details"
        index_path = DATA / "creatures" / language / "index_g2.json"
        index = read_json(index_path)
        details = {path.stem: read_json(path) for path in directory.glob("g2_*.json")}
        for snapshot in app_creatures["creatures"]:
            public_id = snapshot["publicId"]
            extracted = source.get(snapshot.get("technicalId"))
            if public_id in RELEASE_0_6_IDS.values():
                technical_id = snapshot["technicalId"]
                detail = release_detail(technical_id, extracted, language, snapshot.get("order") or 0)
            elif public_id == "g2_buggy_potato_beetle":
                base = copy.deepcopy(details["g2_buggy_toe_biter"])
                detail = base
                detail.update({"id": public_id, "speciesKey": "buggy_potato_beetle", "technicalId": "PotatoBug_Buggy", "bestiaryId": None, "name": POTATO_BUGGY_NAME, "danger": "unknown", "order": snapshot.get("order") or buggy_order, "favoriteKey": public_id, "goldLinkId": None, "cardNormal": "", "cardGold": "", "hasCreatureCard": False, "hasGoldCreatureCard": False, "hasSelectableCardVariants": False, "defaultCardVariant": None, "photo": "assets/global/Aphidex_Proximamente.webp", "health": None, "healthDisplay": "hidden", "attacks": [], "loot": [], "advancedLootTable": [], "locations": [], "availabilityStatus": "source_backed", "buggyProfile": snapshot["buggyProfile"], "sourceProvenance": {"extractorTechnicalId": "PotatoBug_Buggy", "source": "Release 0.6 BuggyBuffing/Hatchery data"}})
            else:
                detail = details.get(public_id)
                if detail is None:
                    continue
                if extracted and public_id not in BUGGY_IDS.values():
                    detail.update({key: snapshot[key] for key in ("health", "healthDisplay", "combatStats", "elementalWeaknesses", "damageWeaknesses", "resistancesV2", "immunities", "attacks", "loot", "advancedLootTable") if key in snapshot})
                    detail["attacks"] = localized_attacks(
                        detail.get("attacks", []), language,
                    )
                    detail["sourceStatus"] = "extractor_merged"
                elif public_id in BUGGY_IDS.values():
                    detail.update({key: snapshot[key] for key in ("health", "healthDisplay", "combatStats", "attacks", "loot", "advancedLootTable", "elementalWeaknesses", "damageWeaknesses", "resistancesV2", "immunities") if key in snapshot})
                if snapshot.get("buggyProfile"):
                    detail["buggyProfile"] = snapshot["buggyProfile"]
                    detail["availabilityStatus"] = snapshot["availabilityStatus"]
            write_json(directory / f"{public_id}.json", detail)
        index = [summary_index(read_json(directory / f"{path.stem}.json")) for path in sorted(directory.glob("g2_*.json"), key=lambda item: (read_json(item).get("order") or 0, item.stem))]
        write_json(index_path, index)

    write_json(DATA / "g2" / "creatures.json", app_creatures)
    diff["applied"] = True
    diff["extractorManifest"] = str(extractor / "final" / "aphidex_extractor_manifest_v1.json")
    diff["sourceWarnings"] = qa.get("sourceWarnings", [])
    write_json(ROOT / "outputs" / "release_0_6_diff.json", diff)
    print(json.dumps(diff, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extractor-root", type=Path, default=DEFAULT_EXTRACTOR)
    parser.add_argument("--apply", action="store_true", help="write normalized Aphidex assets")
    apply(parser.parse_args())


if __name__ == "__main__":
    main()
