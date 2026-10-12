"""Synchronize the current Augusta weapon/effect domains into Aphidex.

The importer intentionally consumes the extractor outside of the Flutter
workspace.  It changes only source-backed weapon and shield fields, keeps
public item IDs stable, and writes a compact generated Dart part for the
equipment-effect codex.  Run it again after a new extractor export instead of
editing the generated data by hand.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data" / "g2" / "equipment.json"
GENERATED_DART = ROOT / "lib" / "data" / "generated_equipment_effect_catalog.dart"
REPORT = ROOT / "outputs" / "weapon_properties_import_report.json"
DEFAULT_SOURCE = Path(
    "/mnt/F/ByteShark-Dev/Aphidex_extractor_v1/aphidex_extractor_v1/"
    "output_aphidex_extractor_v1_augusta_weapon_properties"
)
DEFAULT_FMODEL = Path(
    "/mnt/F/Software_Instaladores/F-model/Output/Exports/Augusta/Content"
)

# These are Aphidex editorial labels for the one technical row that is absent
# from the pre-existing catalogue. They never add combat values or recipes.
NEW_ITEM_COPY = {
    "PaintGun": {
        "en": "Paint Gun",
        "es": "Pistola de pintura",
        "ru": "Краскопульт",
    },
}

TECHNICAL_EFFECT_ALIASES = {
    "Chill": "chill",
    "Corrosion": "tang_buildup",
    "Sizzle": "sizzle",
    "Venom": "venom",
}

WEAPON_TYPE_TAGS = (
    ("Stats.Attacks.Paintball", "paint_launcher"),
    ("Stats.Attacks.Staff", "staff"),
    ("Stats.Attacks.Sword.Katana", "katana"),
    ("Stats.Attacks.Sword.Greatsword", "greatsword"),
    ("Stats.Attacks.Sickle", "sickle"),
    ("Stats.Attacks.Dagger", "dagger"),
    ("Stats.Attacks.Unarmed", "fists"),
    ("Stats.Attacks.Spear", "spear"),
    ("Stats.Attacks.Club", "club"),
    ("Stats.Attacks.Sword", "sword"),
    ("Stats.Attacks.Bow", "bow"),
)

ES_WORDS = {
    "Apply": "Aplicar", "Attack": "ataque", "Block": "bloqueo",
    "Chance": "probabilidad", "Charge": "carga", "Charged": "cargado",
    "Chill": "congelamiento", "Corrosion": "corrosión", "Critical": "crítico",
    "Crouch": "agachado", "Damage": "daño", "Disable": "desactivar",
    "Dodge": "esquiva", "Durability": "durabilidad", "Effect": "efecto",
    "Equipment": "equipo", "Fall": "caída", "Food": "comida",
    "Free": "gratis", "Frozen": "congelado", "Gas": "gas", "Gravity": "gravedad",
    "Health": "vida", "Healing": "curación", "Hit": "golpe", "Immunity": "inmunidad",
    "Jump": "salto", "Kill": "eliminación", "Life": "vida", "Loot": "botín",
    "Luck": "suerte", "Max": "máximo", "Mount": "montura", "Move": "movimiento",
    "None": "sin efecto", "On": "al", "Perfect": "perfecto", "Percentage": "porcentaje",
    "Poison": "veneno", "Rate": "ritmo", "Received": "recibida", "Reduction": "reducción",
    "Regen": "regeneración", "Self": "propio", "Set": "establecer", "Shatter": "fractura",
    "Sizzle": "calor", "Speed": "velocidad", "Sprint": "carrera", "Stamina": "aguante",
    "Status": "estado", "Steal": "robo", "Stun": "aturdimiento", "Summon": "invocación",
    "Swimming": "nado", "Swim": "nado", "Team": "equipo", "Threat": "amenaza",
    "Time": "tiempo", "Trigger": "activador", "Extra": "adicional", "Venom": "veneno",
    "Water": "agua", "Weakpoint": "punto débil", "Multiplier": "multiplicador",
}
RU_WORDS = {
    "Apply": "Применение", "Attack": "атаки", "Block": "блокирования",
    "Chance": "вероятность", "Charge": "заряда", "Charged": "заряженный",
    "Chill": "холод", "Corrosion": "коррозия", "Critical": "критический",
    "Crouch": "приседание", "Damage": "урон", "Disable": "отключение",
    "Dodge": "уклонение", "Durability": "прочность", "Effect": "эффект",
    "Equipment": "снаряжение", "Fall": "падение", "Food": "еда", "Free": "бесплатный",
    "Frozen": "заморозка", "Gas": "газ", "Gravity": "гравитация", "Health": "здоровье",
    "Healing": "лечение", "Hit": "попадание", "Immunity": "иммунитет", "Jump": "прыжок",
    "Kill": "устранение", "Life": "жизнь", "Loot": "добыча", "Luck": "удача",
    "Max": "максимум", "Mount": "езда", "Move": "движение", "None": "без эффекта",
    "On": "при", "Perfect": "идеальный", "Percentage": "процент", "Poison": "яд",
    "Rate": "скорость", "Received": "получаемое", "Reduction": "снижение",
    "Regen": "восстановление", "Self": "себя", "Set": "установка", "Shatter": "разрушение",
    "Sizzle": "перегрев", "Speed": "скорость", "Sprint": "бег", "Stamina": "выносливость",
    "Status": "статус", "Steal": "кража", "Stun": "оглушение", "Summon": "призыв",
    "Swimming": "плавание", "Swim": "плавание", "Team": "команда", "Threat": "угроза",
    "Time": "время", "Trigger": "активатор", "Extra": "дополнительный", "Venom": "яд",
    "Water": "вода", "Weakpoint": "слабое место", "Multiplier": "множитель",
}


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def snake(value: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", value).lower()


def words(value: str) -> list[str]:
    return re.findall(r"[A-Z]+(?=[A-Z][a-z]|$)|[A-Z]?[a-z]+|\d+", value)


def translated_label(effect_type: str, language: str) -> str:
    parts = words(effect_type)
    if language == "en":
        return " ".join(parts)
    lookup = ES_WORDS if language == "es" else RU_WORDS
    return " ".join(lookup.get(part, part) for part in parts).capitalize()


def category_for(effect_type: str) -> str:
    if effect_type.startswith(("Apply", "Trigger", "Summon")) or effect_type in {
        "TeamChange", "SetGravityScale",
    }:
        return "trigger"
    if effect_type in {
        "AttackDamage", "CriticalDamage", "FrozenShatterDamage", "Stun", "WeakpointDamage",
    }:
        return "damage"
    if effect_type in {"Chill", "Corrosion", "Sizzle", "Venom", "None"}:
        return "status"
    return "attribute"


def copy_for(effect_type: str) -> tuple[str, str, str, str, str, str]:
    label_en = translated_label(effect_type, "en")
    label_es = translated_label(effect_type, "es")
    label_ru = translated_label(effect_type, "ru")
    category = category_for(effect_type)
    if effect_type == "None":
        return (
            label_en, label_es, label_ru,
            "Technical marker used to identify an equipment effect; it does not describe a gameplay modifier on its own.",
            "Marcador técnico usado para identificar un efecto de equipo; no describe por sí solo un modificador de juego.",
            "Технический маркер для идентификации эффекта снаряжения; сам по себе он не описывает игровой модификатор.",
        )
    if category == "trigger":
        return (
            label_en, label_es, label_ru,
            "A verified trigger that applies or starts a linked effect when its source condition is met.",
            "Activador verificado que aplica o inicia un efecto vinculado cuando se cumple la condición de su fuente.",
            "Подтверждённый активатор, который применяет или запускает связанный эффект при выполнении условия источника.",
        )
    if category == "damage":
        return (
            label_en, label_es, label_ru,
            "A verified combat modifier. Its exact value and activation are shown on the equipment effect that provides it.",
            "Modificador de combate verificado. Su valor y activación exactos se muestran en el efecto del equipo que lo proporciona.",
            "Подтверждённый боевой модификатор. Его точное значение и активация показаны у эффекта снаряжения, который его даёт.",
        )
    if category == "status":
        return (
            label_en, label_es, label_ru,
            "A verified status effect represented by the current equipment data.",
            "Efecto de estado verificado y representado por los datos actuales de equipo.",
            "Подтверждённый статусный эффект из текущих данных снаряжения.",
        )
    return (
        label_en, label_es, label_ru,
        "A verified equipment modifier. Its exact value and activation are shown on the equipment effect that provides it.",
        "Modificador de equipo verificado. Su valor y activación exactos se muestran en el efecto del equipo que lo proporciona.",
        "Подтверждённый модификатор снаряжения. Его точное значение и активация показаны у эффекта снаряжения, который его даёт.",
    )


def public_effect_id(effect_type: str) -> str:
    return TECHNICAL_EFFECT_ALIASES.get(effect_type, snake(effect_type))


def source_effects(effect: dict, origin: str, out: list[dict], seen: set[tuple]) -> None:
    if not isinstance(effect, dict) or not effect.get("resolved"):
        return
    effect_type = effect.get("type")
    if not effect_type:
        return
    relation = {
        "effectId": public_effect_id(effect_type),
        "origin": origin,
        "sourceRow": effect.get("row"),
        "activation": effect.get("activation"),
        "value": effect.get("value"),
        "duration": effect.get("duration"),
    }
    key = (relation["effectId"], relation["origin"], relation["sourceRow"])
    if key not in seen:
        out.append(relation)
        seen.add(key)
    nested = effect.get("extraDataResolved")
    if isinstance(nested, dict):
        source_effects(nested, origin, out, seen)


def profile_relations(profile: dict) -> list[dict]:
    relations: list[dict] = []
    seen: set[tuple] = set()
    for field, origin in (
        ("alwaysEquippedEffects", "equipped"),
        ("technicalMarkers", "equipped"),
        ("attackAppliedEffects", "attack"),
        ("enhancementUnlockedEffects", "upgrade"),
    ):
        for row in profile.get(field, []):
            source_effects(row.get("effect", row), origin, relations, seen)
    return relations


def detail_from_damage(node: dict | None) -> tuple[str | None, str | None, list[dict]]:
    if not isinstance(node, dict):
        return None, None, []
    detail = node.get("damageTypeDetail") or {}
    status = [
        {"id": item.get("type") or item.get("row") or "", "row": item.get("row"), "source": {"table": item.get("table")}}
        for item in node.get("statusEffectRefs", [])
        if isinstance(item, dict) and (item.get("type") or item.get("row"))
    ]
    return detail.get("physical"), detail.get("element"), status


def compact_attack(attack: dict) -> dict:
    base = attack.get("base") or {}
    charged = attack.get("charged") or {}
    perfect = attack.get("perfectCharged") or {}
    physical, element, status = detail_from_damage(base)
    return {
        "sourceRow": (attack.get("source") or {}).get("row"),
        "sourceTable": (attack.get("source") or {}).get("table"),
        "damage": base.get("damage"),
        "chargedDamage": charged.get("damage"),
        "perfectChargedDamage": perfect.get("damage"),
        "stun": base.get("hitStun"),
        "poiseDamage": base.get("poiseDamage"),
        "pushback": base.get("pushback"),
        "stamina": attack.get("staminaCost"),
        "chargedStamina": attack.get("chargedStaminaCost"),
        "range": attack.get("range"),
        "chargedRange": attack.get("chargedRange"),
        "chargeTime": attack.get("chargeTime"),
        "perfectChargedWindow": attack.get("perfectChargedWindow"),
        "physical": physical,
        "element": element,
        "statusEffects": status,
    }


def attack_tags(source_weapon: dict) -> set[str]:
    return {
        tag
        for attack in source_weapon.get("combat", {}).get("attacks", [])
        for tag in (attack.get("rawDefinition") or {}).get("Tags", [])
    }


def weapon_subtype(source_weapon: dict) -> str:
    tags = attack_tags(source_weapon)
    for prefix, subtype in WEAPON_TYPE_TAGS:
        if any(tag.startswith(prefix) for tag in tags):
            return subtype
    return "special"


def upgrade_effect_relations(source_weapon: dict) -> list[dict]:
    out = []
    for route in source_weapon.get("enhancement", {}).get("summary", {}).get("availableFlavors", []):
        element = (route.get("damageType") or {}).get("element")
        if element:
            out.append({
                "effectId": element,
                "origin": "upgrade",
                "sourceRow": route.get("tag"),
                "activation": "upgrade_route",
            })
    return out


def attack_damage_relations(source_weapon: dict) -> list[dict]:
    """Expose resolved physical and elemental components in the codex.

    Damage components are part of the attack definition, not equipped status
    effects, so they need their own source-backed relations.
    """
    out = []
    for attack in source_weapon.get("combat", {}).get("attacks", []):
        source = attack.get("source") or {}
        source_row = source.get("row")
        for state in ("base", "charged", "perfectCharged"):
            detail = (attack.get(state) or {}).get("damageTypeDetail") or {}
            for effect_id in (detail.get("physical"), detail.get("element")):
                if effect_id:
                    out.append({
                        "effectId": effect_id,
                        "origin": "attack",
                        "sourceRow": source_row,
                        "activation": f"{state}_damage",
                    })
    return out


def synthesize_item(source: dict, domain: str, existing: dict | None, profile: dict | None) -> dict:
    technical_id = source["technicalId"]
    if existing is None:
        existing = {
            "id": technical_id,
            "technicalId": technical_id,
            "domain": domain,
            "name": NEW_ITEM_COPY.get(technical_id, {"en": technical_id, "es": technical_id, "ru": technical_id}),
            "translationStatus": {"en": "technical_source", "es": "aphidex_translation", "ru": "aphidex_translation"},
            "acquisition": {"status": "unresolved_acquisition", "methods": [], "recipes": [], "lootSourceReferences": []},
            "locations": [], "environmentHazards": [], "repair": [],
        }
    item = dict(existing)
    combat = source.get("combat", {})
    raw = source.get("rawSelectedItemData", {})
    item.update({
        "technicalId": technical_id,
        "domain": domain,
        "tier": source.get("tier"),
        "slot": source.get("slot"),
        "twoHanded": source.get("twoHanded"),
        "canBlock": combat.get("canBlock"),
        "durability": combat.get("durability"),
        "normalizedType": domain,
        "normalizedSubtype": "shield" if domain == "shield" else weapon_subtype(source),
        "classificationSource": "extractor_attack_tags",
        "classificationFallbackUsed": domain == "weapon" and weapon_subtype(source) == "special",
        "kind": domain,
        "effects": [ref.get("source", {}).get("row") for ref in source.get("effects", {}).get("equippedStatusEffects", []) if ref.get("source", {}).get("row")],
        "attacks": [compact_attack(attack) for attack in combat.get("attacks", [])],
        "upgradeRoutes": [route.get("tag") for route in source.get("enhancement", {}).get("routes", []) if route.get("tag")],
        "repair": [{"itemId": item_id, "count": 1} for item_id in source.get("repairRecipe", [])],
        "combat": {
            "critChance": combat.get("critChance"),
            "blockDamageMultiplier": combat.get("blockDamageMultiplier"),
            "blockStaminaCost": combat.get("blockStaminaCost"),
            "blockStaminaRegenMultiplier": combat.get("blockStaminaRegenMultiplier"),
            "ammoAttackSlots": source.get("properties", {}).get("ammoAttackSlots"),
        },
    })
    relations = (
        profile_relations(profile or {})
        + attack_damage_relations(source)
        + upgrade_effect_relations(source)
    )
    deduped = {}
    for relation in relations:
        key = (relation["effectId"], relation["origin"], relation.get("sourceRow"))
        deduped[key] = relation
    item["effectRelations"] = list(deduped.values())
    return item


def write_generated_catalog(effect_types: set[str]) -> None:
    entries = []
    aliases = {effect_type: public_effect_id(effect_type) for effect_type in sorted(effect_types)}
    for effect_type in sorted(effect_types):
        effect_id = aliases[effect_type]
        if effect_id in TECHNICAL_EFFECT_ALIASES.values():
            continue
        en, es, ru, desc_en, desc_es, desc_ru = copy_for(effect_type)
        entries.append(
            "  EffectCatalogEntry(\n"
            f"    id: {effect_id!r},\n"
            f"    category: EffectCategory.{category_for(effect_type)},\n"
            f"    name: LocalizedText(en: {en!r}, es: {es!r}, ru: {ru!r}),\n"
            "    description: LocalizedText(\n"
            f"      en: {desc_en!r},\n      es: {desc_es!r},\n      ru: {desc_ru!r},\n"
            "    ),\n  ),"
        )
    aliases_dart = "\n".join(
        f"  {technical!r}: {public!r}," for technical, public in aliases.items()
    )
    GENERATED_DART.write_text(
        "// GENERATED CODE - DO NOT EDIT. Run tool/import_weapon_properties.py.\n"
        "part of 'effect_catalog.dart';\n\n"
        "const extractorTechnicalEffectIdAliases = <String, String>{\n"
        f"{aliases_dart}\n}};\n\n"
        "final generatedEquipmentEffectCatalogEntries = <EffectCatalogEntry>[\n"
        + "\n".join(entries)
        + "\n];\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--fmodel", type=Path, default=DEFAULT_FMODEL)
    args = parser.parse_args()
    equipment_root = args.source / "phase2" / "equipment"
    weapons_doc = read_json(equipment_root / "weapon" / "grounded2_weapon_domain_v2.json")
    effects_doc = read_json(equipment_root / "effects" / "grounded2_equipment_effect_resolver_v1.json")
    effects_qa = read_json(equipment_root / "effects" / "grounded2_equipment_effect_qa_v1.json")
    if not weapons_doc.get("qualityGate", {}).get("pass") or not effects_qa.get("pass"):
        raise SystemExit("Extractor quality gates did not pass; no Aphidex data was written.")
    if len(weapons_doc.get("weapons", [])) != 58 or len(weapons_doc.get("shields", [])) != 9:
        raise SystemExit("Unexpected weapon/shield roster; expected 58 weapons and 9 shields.")

    catalog = read_json(DATA)
    by_id = {item["id"]: item for item in catalog["items"]}
    profiles = {profile["technicalId"]: profile for profile in effects_doc["equipmentProfiles"]}
    changed, added = [], []
    for domain, rows in (("weapon", weapons_doc["weapons"]), ("shield", weapons_doc["shields"])):
        for source in rows:
            item_id = source["technicalId"]
            before = by_id.get(item_id)
            by_id[item_id] = synthesize_item(source, domain, before, profiles.get(item_id))
            (added if before is None else changed).append(item_id)
    catalog["items"] = [by_id[item["id"]] for item in catalog["items"] if item["id"] in by_id]
    for item_id in added:
        catalog["items"].append(by_id[item_id])
    write_json(DATA, catalog)

    source_icon = args.fmodel / "Blueprints/Items/Icons/ICO_PaintGun.png"
    target_icon = ROOT / "assets/g2/equipment/icons/ICO_PaintGun.png"
    if source_icon.exists():
        target_icon.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_icon, target_icon)
        by_id["PaintGun"]["icon"] = "assets/g2/equipment/icons/ICO_PaintGun.png"
        by_id["PaintGun"]["iconProvenance"] = "texture_export"
        write_json(DATA, catalog)

    effect_types = {effect["type"] for effect in read_json(equipment_root / "effects" / "grounded2_equipment_effect_catalog_v1.json")["effects"] if effect.get("type")}
    if len(effect_types) != 72:
        raise SystemExit(f"Unexpected effect type count: {len(effect_types)} (expected 72).")
    write_generated_catalog(effect_types)
    report = {
        "source": str(args.source),
        "qualityGate": {"weapons": True, "effects": True},
        "weapons": len(weapons_doc["weapons"]),
        "shields": len(weapons_doc["shields"]),
        "effectTypes": len(effect_types),
        "updatedIds": changed,
        "addedIds": added,
        "subtypes": dict(Counter(item["normalizedSubtype"] for item in catalog["items"] if item.get("domain") == "weapon")),
    }
    write_json(REPORT, report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
