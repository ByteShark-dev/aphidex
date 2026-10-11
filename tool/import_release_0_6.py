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
    "modules/phase1/output_aphidex_extractor_v1_release_0_6_completion"
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

# Grounded 2 has no Russian resources for these rows.  These are Aphidex
# translations of the extractor's official runtime English, never guesses at
# gameplay values.  Keep the map here so a regeneration is deterministic.
RU_TEXT = {
    "Centipede": ("Скритч", "Этому многоножку поклоняются термиты из поленницы и редкие сотрудники Ominent. Ты всё ещё не понимаешь почему."),
    "SpiderDivingBellOGRE": ("Водолазный паук O.G.R.R.", "С этим водолазным пауком явно происходит что-то серьёзно неладное. Он устойчив к вкусу своей мутации."),
    "TermiteKing": ("Король термитов", "Самый опасный термит в гнезде: король предан защите и размножению королевы. После смерти из него могут выпасть панцирь короля термитов, челюсти термита и часть термита."),
    "TermiteKingOGRE": ("Король термитов O.G.R.R.", "Король термитов, которого абсолютная власть абсолютно развратила. Он устойчив к вкусу своей мутации."),
    "TermiteNymph": ("Личинка термита", "Маленький термит-малыш. Он ещё не решил, станет ли рабочим или солдатом."),
    "TermiteQueen": ("Королева термитов", "Королева гнезда оставляет сражения подданным, пока сама производит бесконечный запас наследников."),
    "TermiteSoldier": ("Термит-солдат", "Крупный солдат, грызущий древесину и готовый на всё, чтобы не пустить чужаков в гнездо термитов, вплоть до взрыва липкой жижей. После смерти может оставить часть термита и челюсти термита."),
    "TermiteSoldierORC": ("Термит-солдат O.R.C.", "Термит-солдат с двойной верностью. После смерти вместе с частями существа может оставить приёмник O.R.C."),
    "TermiteWorker": ("Термит-рабочий", "Крепкие общественные насекомые, поедающие древесину и строящие гнёзда в поленницах и упавших брёвнах. После смерти оставляют часть термита."),
    "TermiteWorkerORC": ("Термит-рабочий O.R.C.", "Термит-солдат с двойной верностью. После смерти вместе с частями существа может оставить приёмник O.R.C."),
}

# Aphidex editorial Spanish terminology.  Runtime text remains the source for
# descriptions; these two names are intentionally normalized for consistency
# with the app's existing creature naming style.
APHIDEX_ES_NAME_OVERRIDES = {
    "TermiteNymph": "Larva de termita",
    "SpiderDivingBellOGRE": "Araña campana buceadora I.R.G.O.",
}

EDITORIAL_ES = {
    "Centipede": {"behavior": "Cuelga de los muros de la arena y se descuelga para arrollar al jugador. Al bajar su vida alterna excavaciones, emboscadas y refuerzos.", "interactionWithPlayer": "Funciona como un miniboss: sus pisotones y recorridos con muchas zonas de daño hacen que bloquear toda la secuencia sea poco fiable.", "interactionWithCreatures": "Las termitas lo veneran y le ofrecen larvas. Cuando consume una larva puede curarse; es una relación de explotación ritual, no una alianza equilibrada.", "strategy": "Elimina las larvas en cuanto caigan para cortar su curación. Las armas a distancia permiten castigar sus desplazamientos; a melee, busca el aturdimiento y golpea el vientre expuesto.", "temperament": "aggressive", "collectionGroup": "boss", "environments": ["Termitero — arena profunda (invocación)"]},
    "TermiteKing": {"behavior": "Permanece en su cámara y responde al intruso con una rotación de mordidas, golpes y tierra a distancia. Al morir libera una explosión.", "interactionWithPlayer": "Ataca de inmediato y combina mordidas, empujones y proyectiles de tierra.", "interactionWithCreatures": "Aunque está apartado de la reina, conserva autoridad sobre el termitero y combate rodeado de sus súbditos.", "strategy": "Limpia primero a las termitas cercanas; después aprende el ritmo de su cadena de ataques y aléjate al caer para evitar el sacrificio explosivo.", "temperament": "aggressive", "collectionGroup": "termite", "environments": ["Termitero — sala del rey (sin spawn confirmado)"]},
    "TermiteKingOGRE": {"behavior": "La versión I.R.G.O. sustituye al rey normal en la versión actual del contenido; mantiene su patrón, pero su infusión lo vuelve mucho más exigente.", "interactionWithPlayer": "Presiona con el mismo repertorio del rey mientras sus resistencias reducen las opciones cómodas de daño.", "interactionWithCreatures": "Dirige a las termitas bajo control I.R.G.O., separado de la colonia normal.", "strategy": "Trátalo como al rey, pero no intercambies golpes: despeja los acompañantes, respeta sus ventanas y evita el sacrificio final.", "temperament": "aggressive", "collectionGroup": "ogrr"},
    "TermiteNymph": {"behavior": "Permanece en el suelo girando y brillando en pequeños grupos; no tiene ataques enlazados demostrables.", "interactionWithPlayer": "No huye ni contraataca: es una presa fácil y una fuente de recursos.", "interactionWithCreatures": "Las larvas aparecen junto a termitas y sirven de alimento a Ciempiés; encontrarlas suele delatar actividad del termitero.", "strategy": "Un golpe cargado basta. Contra grupos, el disparo ácido de la Buggie hormiga soldado negra ayuda a despejar sin acercarte a todas.", "temperament": "passive", "collectionGroup": "termite", "environments": ["Termitero", "Pozo de sacrificios"]},
    "TermiteQueen": {"behavior": "Gobierna desde el fondo del termitero mientras las larvas y las termitas sostienen su colonia. No combate; espera propuestas de intercambio.", "interactionWithPlayer": "Su interacción es por ofrendas. Hay dos rutas de alimento; el extractor confirma una recompensa de interacción, no botín de muerte.", "interactionWithCreatures": "Es el centro de la colonia: recibe la protección de sus súbditos y mantiene el ciclo de larvas, aun separada del rey.", "temperament": "passive", "collectionGroup": "termite", "environments": ["Termitero — fondo (ubicación editorial pendiente de confirmar)"]},
    "TermiteSoldier": {"behavior": "Permanece dentro del termitero, defendiendo a la colonia. Al caer puede explotar.", "interactionWithPlayer": "Ataca en cuanto detecta al jugador y usa mordidas, cadenas cortas y sacrificio explosivo.", "interactionWithCreatures": "Suele ir detrás de obreras y otras termitas, dejando que el grupo abra el combate.", "strategy": "Priorízala antes que a las obreras cuando el grupo se cierre y aléjate en cuanto caiga para no recibir la explosión.", "temperament": "aggressive", "collectionGroup": "termite", "environments": ["Termitero"]},
    "TermiteSoldierORC": {"behavior": "Controlada por C.R.O., combate para el ejército de la Enmascarada y deja atrás la defensa de su colonia.", "interactionWithPlayer": "En encuentros de la Enmascarada puede ser una molestia secundaria; evita quedarte a su alcance si hay una amenaza mayor.", "interactionWithCreatures": "Actúa junto a fuerzas C.R.O. en vez de respaldar al termitero.", "strategy": "No la ignores si prepara el sacrificio, pero prioriza la amenaza principal y elimina al soldado cuando tengas una ventana segura.", "temperament": "aggressive", "collectionGroup": "orc"},
    "TermiteWorker": {"behavior": "A diferencia de G1, se mantiene dentro del nido para proteger a su colonia y a sus reyes.", "interactionWithPlayer": "Lanza tierra y muerde al jugador al detectarlo.", "interactionWithCreatures": "Forma grupos densos con otras termitas y con frecuencia comparte espacio con Ciempiés.", "strategy": "Usa daño de área para controlar los grupos antes de que sus mordidas y proyectiles te encierren.", "temperament": "aggressive", "collectionGroup": "termite", "environments": ["Termitero"]},
    "TermiteWorkerORC": {"behavior": "Una obrera desviada de la colonia para servir a C.R.O.; conserva el patrón de grupo de la obrera normal.", "interactionWithPlayer": "Ataca en grupo con mordidas, embestidas y tierra a distancia.", "interactionWithCreatures": "Acompaña a las fuerzas C.R.O. y no a la colonia del termitero.", "strategy": "El daño de área sigue siendo la respuesta más eficiente; no dejes que varios proyectiles de tierra te recorten el espacio.", "temperament": "aggressive", "collectionGroup": "orc"},
}

EDITORIAL_ES_EXPANSIONS = {
    "Centipede": {"behavior": " No pelea como un enemigo común: domina el espacio vertical de la arena y sus recorridos obligan a leer el suelo y los muros a la vez.", "interactionWithPlayer": " Su peligro real es encadenar varios impactos pequeños mientras se mueve sobre ti, no sólo un golpe aislado.", "interactionWithCreatures": " La mecánica de larvas cambia la prioridad del combate: ignorarlas puede prolongar una pelea ya muy resistente.", "strategy": " Conserva resistencia para sus cambios de posición; perseguirlo durante una excavación suele dejarte expuesto."},
    "TermiteKing": {"behavior": " La sensación es la de un guardián de cámara, no la de una criatura errante: protege su zona hasta que el intruso cae o se retira.", "interactionWithPlayer": " Sus golpes a distancia complican curarse o recuperar resistencia fuera de su alcance inmediato.", "strategy": " No lo encierres contra una pared: deja una ruta de salida para su cadena y para la explosión de muerte."},
    "TermiteKingOGRE": {"behavior": " La infusión no cambia su identidad de rey, pero transforma un duelo ordenado en una prueba de disciplina y selección de daño.", "strategy": " Lleva una alternativa de daño antes de entrar; insistir contra resistencias sólo alarga el combate y aumenta los errores."},
    "TermiteNymph": {"behavior": " Su inmovilidad no significa que sea irrelevante: su valor está en los recursos y en el vínculo con los eventos del termitero.", "strategy": " Si hay combate alrededor, elimina primero las larvas que Ciempiés pueda alcanzar; después recoge con calma."},
    "TermiteQueen": {"behavior": " La ficha la trata como autoridad social de la colonia, no como objetivo de combate.", "interactionWithPlayer": " La decisión importante es qué ofrenda entregar; Aphidex no presenta esa recompensa como botín ni como una muerte posible."},
    "TermiteSoldier": {"behavior": " Su papel es comprar tiempo para el resto del grupo: llega tarde a la línea frontal, pero castiga al jugador que se queda rodeado.", "strategy": " Tras derribarla, no corras hacia el botín de inmediato: confirma primero que el radio del sacrificio terminó."},
    "TermiteSoldierORC": {"behavior": " La estética C.R.O. deja claro que ya no combate por protección territorial, sino como parte de una fuerza hostil organizada.", "strategy": " Si comparte encuentro con una criatura élite, gana espacio primero y vuelve por el soldado cuando no pueda forzarte una explosión."},
    "TermiteWorker": {"behavior": " Por sí sola es manejable; el riesgo aparece cuando varias obreras mezclan mordidas y tierra en un pasillo estrecho.", "strategy": " No te quedes retrocediendo en línea recta: abre el grupo con daño de área y desplázate por sus flancos."},
    "TermiteWorkerORC": {"behavior": " Conserva su función de masa y control de espacio, ahora al servicio de C.R.O.", "strategy": " Separa al grupo antes de comprometerte con enemigos de mayor rango; sus ataques sencillos se vuelven peligrosos por acumulación."},
}

RELEASE_DANGER = {
    "Centipede": "imposible",  # one level below King Dozer
    "SpiderDivingBellOGRE": "muy_alta",
    "TermiteKing": "muy_alta",
    "TermiteKingOGRE": "imposible",
    "TermiteNymph": "baja",
    "TermiteQueen": "baja",  # non-combat interaction
    "TermiteSoldier": "alta",
    "TermiteSoldierORC": "muy_alta",
    "TermiteWorker": "intermedia",
    "TermiteWorkerORC": "alta",
}
BUGGY_PUBLIC_IDS = frozenset(BUGGY_IDS.values())


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if not path.exists() or path.read_text(encoding="utf-8") != content:
        path.write_text(content, encoding="utf-8")


def clean_description(value):
    """Strip UE rich-text tags while retaining their human-readable content."""
    import re
    return re.sub(r"</?[^>]+>", "", value or "").replace("<--->", "").strip()


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
        base_id = str(row.get("id") or row.get("ability") or "")
        if not base_id:
            continue
        # Boss phases and DefaultAttackComboData can reference the same ability
        # more than once.  Keep every proven source row, giving only duplicates
        # a stable UI identifier rather than silently dropping them.
        technical_id = base_id
        duplicate = 2
        while technical_id in seen:
            technical_id = f"{base_id}#{duplicate}"
            duplicate += 1
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
        previous = existing_by_id.get(technical_id) or existing_by_id.get(base_id)
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


def normalized_complete_loot(loot_field: dict):
    """Turn finalized Release 0.6 loot rolls into Aphidex's visible tables."""
    rows = [row for row in (loot_field.get("rolls") or [])
            if row.get("parseStatus") == "resolved" and row.get("rollKind") == "item" and row.get("itemRow")]
    grouped = defaultdict(list)
    for row in rows:
        grouped[row["itemRow"]].append(row)
    loot, advanced = [], []
    for item_id, item_rows in sorted(grouped.items()):
        chances = [float(row.get("baseDropChance", row.get("dropChance", 0)) or 0) for row in item_rows]
        counts = [int(row.get("count") or 0) for row in item_rows]
        loot.append({"section": "rare" if max(chances) <= .05 else "loot", "item": technical_label(item_id),
                     "minCount": sum(count for count, chance in zip(counts, chances) if chance >= 1), "maxCount": sum(counts)})
        for row, chance in zip(item_rows, chances):
            note = "conditional" if (row.get("presentation") or {}).get("sourceConditional") else None
            advanced.append({"item": technical_label(item_id), "countLabel": str(row.get("count") or 0),
                             "chancePct": round(chance * 100), "rollCount": 1, "notes": note})
    return loot, advanced


def localized_release_text(technical_id: str, source: dict, language: str):
    localization = source.get("localization") or {}
    if language == "ru":
        return RU_TEXT[technical_id]
    locale = "es-MX" if language == "es" else "en"
    name = (localization.get("displayName") or {}).get(locale)
    description = (localization.get("description") or {}).get(locale)
    if not name or not description:
        raise ValueError(f"Missing runtime {locale} localization for {technical_id}")
    if language == "es":
        name = APHIDEX_ES_NAME_OVERRIDES.get(technical_id, name)
    return clean_description(name), clean_description(description)


def polish_es_attack(attack: dict):
    ident = attack.get("technicalId", "").split("#")[0]
    names = {"CentipedeEatTermite": "Devorar larva", "CentipedeUnburrowWall_CA": "Salida desde el muro", "CentipedeCombo3": "Combo de tres golpes", "CentipedeCombo3Phase2": "Combo de tres golpes — fase 2", "CentipedeCombo5Phase2": "Combo de cinco golpes — fase 2", "CentipedeCombo5Phase3": "Combo de cinco golpes — fase 3", "CentipedeBodyslam": "Golpe corporal", "CentipedeTakePath_CA": "Recorrido por la arena", "CentipedeBurrowWall_CA": "Excavación en muro", "CentipedeGoToFarPoint_CA": "Reposicionamiento lejano", "CentipedeEmerge_CA": "Salida subterránea", "CentipedeBurrowGround_CA": "Excavación", "CentipedeEmergeMelee_CA": "Salida de emboscada", "SpiderDivingBellBite_Augusta": "Mordida", "SpiderDivingBellLunge_Augusta": "Embestida", "SpiderDivingBell_WaterDodge_Augusta": "Esquiva acuática", "TermiteKingBiteLeft": "Mordida", "TermiteKingMultiStrike": "Cadena de mandíbulas", "TermiteKingMultiStrike_5": "Cadena larga de mandíbulas", "TermiteKingPowerAttack": "Golpe potente", "TermiteKingRange": "Lanzamiento de tierra", "TermiteKingSacrifice": "Sacrificio explosivo", "TermiteSoldierBiteLeft": "Mordida", "TermiteSoldierBiteRight": "Mordida", "TermiteSoldierMultiStrike": "Cadena de mandíbulas", "TermiteSoldierPowerAttack": "Golpe potente", "TermiteSoldierShout": "Grito de combate", "TermiteSoldierSacrifice": "Sacrificio explosivo", "TermiteWorkerBiteLeft": "Mordida", "TermiteWorkerBiteRight": "Mordida", "TermiteWorkerLunge": "Embestida", "TermiteWorkerRange": "Lanzamiento de tierra", "BlockOffensive": "Bloqueo ofensivo"}
    attack["name"] = names.get(ident, attack.get("name"))
    if ident == "CentipedeEatTermite": attack.update({"tell": "Caen larvas del techo y Ciempiés corre hacia ellas, ignorando momentáneamente al jugador.", "howToAvoid": "Elimina las larvas antes de que las alcance; el área es más segura que perseguirlo a melee.", "notes": "Puede curarse al devorarlas. Es una prioridad de control de objetivos, no un ataque directo."})
    elif "Sacrifice" in ident: attack.update({"tell": "La termita queda expuesta al final de su vida y su cuerpo anuncia la detonación.", "howToAvoid": "Aléjate en cuanto caiga y espera a que termine el radio antes de volver.", "notes": "Explosión de área: el peligro es castigarla demasiado cerca al rematarla."})
    elif "Range" in ident: attack.update({"tell": "Se orienta a distancia y prepara tierra para lanzarla hacia tu posición.", "howToAvoid": "Muévete lateralmente y evita curarte quieto; retroceder recto suele conservar su línea de tiro.", "notes": "Presión a distancia para obligarte a entrar en su grupo."})
    elif "Lunge" in ident or "Power" in ident or "Bodyslam" in ident: attack.update({"tell": "Se afirma un instante antes de comprometerse en un golpe frontal.", "howToAvoid": "Esquiva hacia un lado con decisión; retroceder en línea recta deja poco margen.", "notes": "Ataque de compromiso que abre una ventana si falla."})
    elif attack.get("damage", 0) > 0: attack.update({"tell": "Entra en alcance con las mandíbulas preparadas y orienta el cuerpo hacia el objetivo.", "howToAvoid": "Bloquea si tienes resistencia o desplázate fuera de su frente antes de la conexión.", "notes": "Ataque directo; se vuelve peligroso cuando otras termitas ocupan tus flancos."})
    else: attack.update({"tell": "Cambia de posición o prepara la continuación de su patrón.", "howToAvoid": "Mantén distancia, no gastes toda la resistencia y observa si enlaza con un ataque de daño.", "notes": "Movimiento o utilidad; el extractor no confirma daño directo en esta acción."})


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
        "game": "g2", "tier": int(source.get("tier") or 0), "danger": RELEASE_DANGER[technical_id], "isBoss": technical_id == "Centipede",
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


def completion_detail(technical_id: str, source: dict, completed: dict, language: str, order: int):
    """Build one Release 0.6 detail from its enriched, final record."""
    detail = release_detail(technical_id, source, language, order)
    fields = completed[technical_id]["fields"]
    name, description = localized_release_text(technical_id, source, language)
    detail["name"], detail["description"], detail["danger"] = name, description, RELEASE_DANGER[technical_id]
    stats = fields["hpStats"].get("value") or {}
    health = stats.get("health")
    detail["health"] = None if health is None else {
        "rating": 1 if health < 400 else 2 if health < 700 else 3 if health < 1100 else 4 if health < 2000 else 5,
        "value": round(health),
    }
    detail["combatStats"] = {
        "health": None if health is None else round(health),
        "stunThreshold": stats.get("stun", {}).get("max"),
        "stunCooldownSeconds": stats.get("stun", {}).get("cooldown"),
    }
    detail["attacks"] = normalized_attacks(fields["attacks"].get("items"))
    detail["weakPoints"] = [
        {"part": str(part).lower(), "susceptibleDamage": "unknown", "susceptibleDamageTypes": [],
         "weaponFamilies": [], "provenance": "extractor_region_only"}
        for part in fields["weakpoints"].get("value", [])
    ]
    detail["elementalWeaknesses"] = [item for item in normalized_bonuses(source.get("weaknesses")) if item["type"] in ELEMENTAL]
    detail["damageWeaknesses"] = [item for item in normalized_bonuses(source.get("weaknesses")) if item["type"] not in ELEMENTAL]
    detail["resistancesV2"] = normalized_bonuses(source.get("resistances"))
    detail["immunities"] = sorted({str(value).lower() for row in source.get("immunities") or [] for value in (row.get("damageTypes", []) if isinstance(row, dict) else [row])})
    loot, advanced = normalized_complete_loot(fields["loot"])
    detail["loot"], detail["advancedLootTable"] = loot, advanced
    normal = fields["normalCard"].get("value") or {}
    gold = fields["goldCard"].get("value") or {}
    normal_asset = f"assets/g2/creatures/cards/{normal.get('textureName')}.png" if normal.get("textureName") else ""
    gold_folder = "cards_golden" if "/Gold/" in str(gold.get("localImage") or "") else "cards"
    gold_asset = f"assets/g2/creatures/{gold_folder}/{gold.get('textureName')}.png" if gold.get("textureName") else ""
    detail.update({"cardNormal": normal_asset, "cardGold": gold_asset,
                   "hasCreatureCard": bool(normal_asset), "hasGoldCreatureCard": bool(gold_asset),
                   "hasSelectableCardVariants": bool(normal_asset and gold_asset),
                   "defaultCardVariant": "normal" if normal_asset else "gold" if gold_asset else None})
    detail["cardEvidence"] = {
        "normal": normal.get("textureName"), "gold": gold.get("textureName"),
        "goldChance": gold.get("chance"), "status": "source_texture_resolved_asset_not_distributed",
    }
    detail["sourceProvenance"] = {
        "extractorTechnicalId": technical_id,
        "extractorStatus": "resolved_release_0_6_completion",
        "localization": "resolved_runtime_en_es_MX",
        "locationStatus": fields["locationSpawn"].get("status"),
    }
    detail["dataRevision"] = "extractor_release_0_6_completion"
    if language == "es" and technical_id in EDITORIAL_ES:
        editorial = EDITORIAL_ES[technical_id]
        detail.update({key: value for key, value in editorial.items() if key != "environments"})
        for field, addition in EDITORIAL_ES_EXPANSIONS.get(technical_id, {}).items():
            detail[field] = f"{detail[field]}{addition}"
        if editorial.get("environments"):
            detail["environments"] = editorial["environments"]
        for attack in detail["attacks"]:
            polish_es_attack(attack)
    if technical_id == "TermiteQueen":
        interaction = fields["interaction"]
        detail["interactionInfo"] = {
            "type": interaction.get("evidence", {}).get("interactionType"),
            "offerings": [row.get("item", {}).get("itemRow") for row in interaction.get("offerings", [])],
            "rewards": interaction.get("triggerRewards", []),
            "deathLoot": "not_applicable",
        }
        traits = {
            "en": ["Conversation interaction", "Offerings: OfferingTermiteQueenCentipede; OfferingTermiteQueenPoisoned", "Interaction reward: 1 Termite Part"],
            "es": ["Interacción de conversación", "Ofrendas: OfferingTermiteQueenCentipede; OfferingTermiteQueenPoisoned", "Recompensa por interacción: 1 parte de termita"],
            "ru": ["Разговорное взаимодействие", "Подношения: OfferingTermiteQueenCentipede; OfferingTermiteQueenPoisoned", "Награда за взаимодействие: 1 часть термита"],
        }
        detail["specialTraits"] = traits[language]
    return detail


def apply_completion(args):
    """Import only enriched Release 0.6 records, preserving all other edits."""
    extractor = args.extractor_root.resolve()
    payload = read_json(extractor / "phase1" / "aphidex_grounded2_v5_1_1.json")
    source = {row["id"]: row for row in payload["creatures"]}
    completed = {row["id"]: row for row in read_json(extractor / "release_0_6" / "release_0_6_entities_complete.json")["entities"]}
    missing = sorted(set(RELEASE_0_6_IDS) - set(completed))
    if missing:
        raise ValueError(f"Completion export is missing Release 0.6 entities: {missing}")
    app = read_json(DATA / "g2" / "creatures.json")
    by_public = {row.get("publicId"): row for row in app["creatures"]}
    diff = {"schema": "aphidex-release-0-6-completion-diff-v1", "source": str(extractor), "entities": []}
    for technical_id, public_id in RELEASE_0_6_IDS.items():
        if public_id not in by_public:
            raise ValueError(f"First integration entry is missing: {public_id}")
        fields = completed[technical_id]["fields"]
        diff["entities"].append({"id": public_id, "technicalId": technical_id,
            "health": fields["hpStats"].get("value", {}).get("health"),
            "attackCount": fields["attacks"].get("count", 0),
            "lootResolved": fields["loot"].get("status") == "resolved_finalized_loot_domain",
            "normalCard": (fields["normalCard"].get("value") or {}).get("textureName"),
            "goldCard": (fields["goldCard"].get("value") or {}).get("textureName")})
    if not args.apply:
        print(json.dumps(diff, ensure_ascii=False, indent=2))
        return
    for language in LANGUAGES:
        directory = DATA / "creatures" / language / "details"
        for technical_id, public_id in RELEASE_0_6_IDS.items():
            prior = read_json(directory / f"{public_id}.json")
            detail = completion_detail(technical_id, source[technical_id], completed, language, prior.get("order") or 0)
            # Retain app-owned compatibility keys and artwork placeholders.
            for key in ("photo", "listIconAsset", "mapMarkerAsset", "customAsset", "favoriteKey", "goldLinkId"):
                detail[key] = prior.get(key, detail.get(key))
            write_json(directory / f"{public_id}.json", detail)
        index_path = DATA / "creatures" / language / "index_g2.json"
        index = read_json(index_path)
        updated = {row["id"]: row for row in index}
        for technical_id, public_id in RELEASE_0_6_IDS.items():
            updated[public_id] = summary_index(read_json(directory / f"{public_id}.json"))
        write_json(index_path, sorted(updated.values(), key=lambda row: (row.get("order") or 0, row["id"])))
        # Buggies are player companions, so Aphidex deliberately does not show
        # a combat difficulty for any of them.
        for public_id in BUGGY_PUBLIC_IDS:
            path = directory / f"{public_id}.json"
            if not path.exists():
                continue
            buggy = read_json(path)
            buggy["danger"] = "unknown"
            if language == "es" and public_id == "g2_buggy_potato_beetle":
                buggy["name"] = "Buggie Escarabajo de la papa"
                buggy.update({
                    "description": "Un Buggie pesado que recicla biomasa de enemigos derrotados para alimentar su cañón de residuos biológicos.",
                    "behavior": "Acompañante resistente, similar a Ladybuggy, diseñado para aprovechar restos de combate.",
                    "interactionWithPlayer": "Un aliado reciclador de biomasa; su cañón cobra valor cuando hay varios enemigos o combates prolongados.",
                    "interactionWithCreatures": "Como los demás Buggies, combate junto al jugador en vez de comportarse como un enemigo independiente.",
                    "strategy": "Resérvalo para enfrentamientos largos y defensas MIX.R, donde disponer de biomasa y tiempo permite aprovechar mejor su cañón.",
                    "collectionGroup": "buggy",
                })
            write_json(path, buggy)
        updated = {row["id"]: row for row in read_json(index_path)}
        for public_id in BUGGY_PUBLIC_IDS:
            path = directory / f"{public_id}.json"
            if path.exists():
                updated[public_id] = summary_index(read_json(path))
        write_json(index_path, sorted(updated.values(), key=lambda row: (row.get("order") or 0, row["id"])))
    for technical_id, public_id in RELEASE_0_6_IDS.items():
        detail = completion_detail(technical_id, source[technical_id], completed, "en", by_public[public_id].get("order") or 0)
        by_public[public_id].update({key: value for key, value in detail.items() if key not in {"id", "name", "description"}})
    for public_id in BUGGY_PUBLIC_IDS:
        if public_id in by_public:
            by_public[public_id]["danger"] = "unknown"
    write_json(DATA / "g2" / "creatures.json", app)
    diff["applied"] = True
    write_json(ROOT / "outputs" / "release_0_6_completion_diff.json", diff)
    print(json.dumps(diff, ensure_ascii=False, indent=2))


def apply(args):
    extractor = args.extractor_root.resolve()
    # Completion exports are intentionally self-contained and do not carry the
    # older manifest/phase2 tree.  Prefer this final, enriched import path.
    if (extractor / "release_0_6" / "release_0_6_entities_complete.json").exists():
        return apply_completion(args)
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
