#!/usr/bin/env python3
"""Build Nketa content JSON files from ChatGPT shares and curated sources."""

from __future__ import annotations

import codecs
import json
import re
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "data"
CACHE_DIR = ROOT / "scripts" / ".chatgpt_cache"

CHATGPT_URLS = {
    "proverbs": "https://chatgpt.com/share/6aa0071f-5d24-83ea-aabb-b36b0953bcac",
    "cosmology": "https://chatgpt.com/share/6aa0074f-1938-83e9-9019-da7666f98b59",
    "folktales": "https://chatgpt.com/share/6aa010c1-1bcc-83ea-9ca8-58fd14e7b89c",
}

# Unicode Nsibidi block (U+1ECA0–U+1ECFF) for generated name compositions
NSIBIDI_CHARS = [chr(0x1ECA0 + i) for i in range(40)]

SYLLABLE_MAP = {
    "chi": NSIBIDI_CHARS[0],
    "ne": NSIBIDI_CHARS[1],
    "du": NSIBIDI_CHARS[2],
    "go": NSIBIDI_CHARS[3],
    "zi": NSIBIDI_CHARS[4],
    "am": NSIBIDI_CHARS[5],
    "aka": NSIBIDI_CHARS[6],
    "obi": NSIBIDI_CHARS[7],
    "na": NSIBIDI_CHARS[8],
    "em": NSIBIDI_CHARS[9],
    "eka": NSIBIDI_CHARS[10],
    "ife": NSIBIDI_CHARS[11],
    "oma": NSIBIDI_CHARS[12],
    "nna": NSIBIDI_CHARS[13],
    "nne": NSIBIDI_CHARS[14],
    "kene": NSIBIDI_CHARS[15],
    "chuk": NSIBIDI_CHARS[16],
    "wu": NSIBIDI_CHARS[17],
    "ada": NSIBIDI_CHARS[18],
    "uche": NSIBIDI_CHARS[19],
    "ebere": NSIBIDI_CHARS[20],
    "ike": NSIBIDI_CHARS[21],
    "ngozi": NSIBIDI_CHARS[22],
    "chidi": NSIBIDI_CHARS[23],
    "nnamdi": NSIBIDI_CHARS[24],
    "to": NSIBIDI_CHARS[25],
    "chioma": NSIBIDI_CHARS[26],
    "som": NSIBIDI_CHARS[27],
    "tochukwu": NSIBIDI_CHARS[28],
    "ebele": NSIBIDI_CHARS[29],
    "onye": NSIBIDI_CHARS[30],
    "nwa": NSIBIDI_CHARS[31],
    "buchi": NSIBIDI_CHARS[32],
    "dike": NSIBIDI_CHARS[33],
    "kamsi": NSIBIDI_CHARS[34],
    "jide": NSIBIDI_CHARS[35],
    "ofor": NSIBIDI_CHARS[36],
    "chima": NSIBIDI_CHARS[37],
    "ng": NSIBIDI_CHARS[38],
    "we": NSIBIDI_CHARS[39],
}

COMMON_IGBO_NAMES = [
    ("Chinedu", "God leads"),
    ("Chidi", "God exists"),
    ("Chiamaka", "God is beautiful"),
    ("Chinonso", "God is near"),
    ("Chukwudi", "God exists"),
    ("Chukwuma", "God knows"),
    ("Chibueze", "God is king"),
    ("Chigozie", "God has blessed"),
    ("Chisom", "God follows me"),
    ("Chinwe", "God owns"),
    ("Chinweike", "God owns strength"),
    ("Chizoba", "God saves"),
    ("Chizitere", "God sent"),
    ("Ngozi", "Blessing"),
    ("Amaka", "Beauty"),
    ("Amarachi", "God's grace"),
    ("Adanna", "Father's daughter"),
    ("Adaku", "Daughter of wealth"),
    ("Ifeoma", "Good thing"),
    ("Ifunanya", "Love"),
    ("Obinna", "Father's heart"),
    ("Obiora", "Heart of the people"),
    ("Obioma", "Good heart"),
    ("Obiageli", "The time has come to enjoy wealth"),
    ("Ogechi", "God's time"),
    ("Uchenna", "God's thought"),
    ("Uchechi", "God's will"),
    ("Ugochukwu", "Eagle of God"),
    ("Ugonna", "Eagle of the father"),
    ("Ebuka", "God is great"),
    ("Ebere", "Mercy"),
    ("Echezona", "Do not forget"),
    ("Emeka", "God has done great"),
    ("Ikenna", "Father's power"),
    ("Ikechukwu", "God's power"),
    ("Kelechi", "Thank God"),
    ("Kosisochukwu", "As it pleases God"),
    ("Nnamdi", "My father lives"),
    ("Nnenna", "Father's mother"),
    ("Nkiruka", "The best is still to come"),
    ("Nkechi", "God's gift"),
    ("Somtochukwu", "Join me in praising God"),
    ("Tochukwu", "Praise God"),
    ("Jideofor", "Hold firm"),
    ("Jidenna", "Hold the father"),
    ("Osinachi", "From God"),
    ("Onyinyechi", "God's gift"),
    ("Onyeka", "Who is greater than God"),
    ("Oluchi", "God's work"),
    ("Oluoma", "Good work"),
    ("Chioma", "Good God"),
    ("Chinecherem", "God thinks of me"),
    ("Chineze", "God saves"),
    ("Chidimma", "God is good"),
    ("Chidiebere", "God is merciful"),
    ("Chidozie", "God has repaired"),
    ("Chigoziem", "God has blessed me"),
    ("Chika", "God is supreme"),
    ("Chikamso", "It is only God I follow"),
    ("Chikodi", "It is in God's hand"),
    ("Chinaza", "God answers"),
    ("Chisara", "God answers prayer"),
    ("Chizaram", "God answered me"),
    ("Ekwi", "Speak"),
    ("Ekwueme", "One who does as he says"),
    ("Ezinne", "Good mother"),
    ("Ifeyinwa", "Nothing compares to a child"),
    ("Ijeoma", "Good journey"),
    ("Ikemefuna", "Let my strength not be in vain"),
    ("Lotanna", "Remember the father"),
    ("Mmesoma", "Good deed"),
    ("Ngozika", "Blessing is the greatest"),
    ("Nkeiruka", "Future is greater"),
    ("Nneka", "Mother is supreme"),
    ("Obi", "Heart"),
    ("Ogechukwu", "God's time"),
    ("Okwudili", "Strong pillar"),
    ("Olaedo", "Gold/wealth"),
    ("Olisa", "God"),
    ("Onyekachi", "Who is greater than God"),
    ("Onyekwere", "Who believes in God"),
    ("Onyinye", "Gift"),
    ("Ozioma", "Good news"),
    ("Oziomachukwu", "Good news from God"),
    ("Ugochi", "Eagle of God"),
    ("Ugomma", "Beautiful eagle"),
    ("Uzoamaka", "Good road"),
    ("Zinachidi", "Show that God exists"),
    ("Adaeze", "Princess"),
    ("Adimchi", "My direction"),
    ("Akunna", "Father's wealth"),
    ("Amarachukwu", "God's grace"),
    ("Anulika", "God's joy"),
    ("Buchi", "Belonging to God"),
    ("Chidubem", "God is my guide"),
    ("Chigozirim", "God bless my journey"),
    ("Chimamanda", "My God will not fail"),
    ("Chimaraoke", "God knows why"),
    ("Chinagorom", "God will avenge me"),
    ("Chinedum", "God leads me"),
    ("Chinwendu", "God owns life"),
    ("Chizurum", "God rebuilds me"),
    ("Ebelechukwu", "God's mercy"),
    ("Ekene", "Praise"),
    ("Ekenechukwu", "Praise God"),
    ("Enyinnaya", "Father's friend"),
    ("Ezinwa", "Good child"),
    ("Ifeanyi", "Nothing is impossible"),
    ("Ifechukwu", "God's light"),
    ("Ihuoma", "Good face"),
    ("Kamso", "I only follow"),
    ("Kamsiyochukwu", "As I asked God"),
    ("Kenechukwu", "Thanks be to God"),
    ("Munachim", "I am with God"),
    ("Ndidiamaka", "Patience is good"),
    ("Ngoziem", "My blessing"),
    ("Nkiruka", "What is ahead is greater"),
    ("Obumneme", "The heart knows me"),
    ("Ogechioma", "God's good time"),
    ("Ogechukwu", "God's appointed time"),
    ("Okorie", "Born on market day"),
    ("Oluchioma", "Good God's work"),
    ("Onyebuchi", "Who is God"),
    ("Onyinyechukwu", "God's gift"),
    ("Uchechioma", "Good God's will"),
    ("Uchenna", "God's mind"),
    ("Udochukwu", "God's peace"),
    ("Ugonne", "Mother's eagle"),
    ("Uzoma", "Good path"),
    ("Zikora", "Show the world"),
]

COSMOLOGY_ENTRIES = [
    {
        "section": "Supreme Being",
        "name": "Chukwu",
        "description": "Chukwu is the supreme being, the creator of the universe, and the source of all life and power. All other deities (Alusi) derive their authority from Chukwu.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Cosmic Realms",
        "name": "Uwa",
        "description": "The Igbo universe is divided into the physical world (Uwa mmadu), the spirit world (Uwa mmuo), and the world of the ancestors (Ala mmuo). These realms are interconnected, and life is seen as a cycle between them.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Earth Deity",
        "name": "Ala",
        "description": "Ala is the earth goddess, guardian of morality, fertility, and the ancestors. She is one of the most important deities in Igbo cosmology and is closely tied to the land and community.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Solar Deity",
        "name": "Anyanwu",
        "description": "Anyanwu is the sun god, representing light, warmth, and divine vision. Anyanwu watches over the living world and is often associated with clarity and truth.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Personal Deity",
        "name": "Chi",
        "description": "Chi is the personal spiritual guardian assigned to each person at birth. It guides destiny and is invoked in proverbs such as 'Onye kwe, chi ya ekwe.'",
        "image": None,
        "audio": None,
    },
    {
        "section": "Deities",
        "name": "Amadioha",
        "description": "Amadioha is the god of thunder and justice, often associated with oaths, truth, and retribution against wrongdoing.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Deities",
        "name": "Ikenga",
        "description": "Ikenga is the horned deity of achievement, strength, and personal success. It is widely represented in Igbo art and ritual.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Water Spirits",
        "name": "Mami Wata",
        "description": "Mami Wata is a water spirit associated with beauty, wealth, and the mysteries of rivers and streams in Igbo folklore.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Ancestral World",
        "name": "Ndị Ichie",
        "description": "Ndị Ichie are the venerated ancestors who remain spiritually present in the community and are honored through libations, festivals, and masquerades.",
        "image": None,
        "audio": None,
    },
    {
        "section": "Masquerade",
        "name": "Mmuo",
        "description": "Mmuo represent spirits of the ancestors during festivals. Masquerades embody spiritual presence and community order in Igbo tradition.",
        "image": None,
        "audio": None,
    },
]

TIMELINE_ENTRIES = [
    {
        "era": "Ancient Origins",
        "title": "Kingdom of Nri Established",
        "period": "1043 CE",
        "icon": "👑",
        "description": "The Kingdom of Nri is formally established with Eze Nri Ifikuanim as the first priest-king, becoming a major religious and political institution in Igboland.",
        "story": "Nri emissaries spread ritual order across Igbo communities through purification ceremonies and spiritual law.",
    },
    {
        "era": "Ancient Origins",
        "title": "Igbo Ukwu Bronze Civilization",
        "period": "9th–10th century",
        "icon": "🏺",
        "description": "Advanced bronze casting flourishes at Igbo Ukwu, producing sophisticated artifacts that reveal early Igbo technological achievement.",
        "story": "Archaeological discoveries show long-distance trade and complex artistry in pre-colonial southeastern Nigeria.",
    },
    {
        "era": "Pre-Colonial Era",
        "title": "Height of Nri Influence",
        "period": "12th–15th century",
        "icon": "🌍",
        "description": "Nri influence extends across much of Igboland through ritual authority rather than military conquest.",
        "story": "Traveling mburiichi helped install rulers and spread taboos that shaped Igbo social order.",
    },
    {
        "era": "Pre-Colonial Era",
        "title": "Aro Confederacy Rises",
        "period": "17th–19th century",
        "icon": "⚖️",
        "description": "The Aro Confederacy grows in economic and spiritual influence, especially through long-distance trade networks.",
        "story": "Regional power shifts as new commercial centers challenge older ritual hegemonies.",
    },
    {
        "era": "Colonial Period",
        "title": "British Colonial Rule Begins",
        "period": "1900s",
        "icon": "🏛️",
        "description": "British administration expands across southeastern Nigeria, introducing indirect rule and warrant chiefs.",
        "story": "Colonial policies reshape governance and taxation in Igbo communities.",
    },
    {
        "era": "Colonial Period",
        "title": "Aba Women's War (Ogu Umunwanyi)",
        "period": "1929",
        "icon": "✊",
        "description": "Thousands of Igbo women protest colonial taxation and warrant chiefs in one of West Africa's largest anti-colonial uprisings.",
        "story": "The movement forced colonial authorities to revise policies and curb warrant chief power.",
    },
    {
        "era": "Colonial Period",
        "title": "Igbo Landing",
        "period": "1803",
        "icon": "🌊",
        "description": "Enslaved Igbo people revolt at Dunbar Creek in Georgia, choosing death over bondage in a powerful symbol of resistance.",
        "story": "The event remains a touchstone of Igbo diaspora memory and courage.",
    },
    {
        "era": "Independence Era",
        "title": "Nigerian Independence",
        "period": "1960",
        "icon": "🇳🇬",
        "description": "Nigeria gains independence, with Igbo leaders playing major roles in politics, education, and commerce.",
        "story": "Post-independence hopes are followed by rising ethnic and political tensions.",
    },
    {
        "era": "Independence Era",
        "title": "Anti-Igbo Violence in the North",
        "period": "1966",
        "icon": "⚠️",
        "description": "Pogroms across northern Nigeria kill thousands of Igbo people and displace many more toward the Eastern Region.",
        "story": "Mass return migration reshapes Igbo society and sets the stage for secession debates.",
    },
    {
        "era": "Biafra Period",
        "title": "Republic of Biafra Declared",
        "period": "1967",
        "icon": "🕊️",
        "description": "The Republic of Biafra is declared under Colonel Chukwuemeka Odumegwu Ojukwu amid national crisis.",
        "story": "Secession follows months of failed peace talks and regional insecurity.",
    },
    {
        "era": "Biafra Period",
        "title": "Nigerian Civil War",
        "period": "1967–1970",
        "icon": "🕯️",
        "description": "The Biafran War devastates Igboland, with widespread loss of life from conflict, famine, and displacement.",
        "story": "The war ends in January 1970 with reintegration under the 'no victor, no vanquished' policy.",
    },
    {
        "era": "Post-War Revival",
        "title": "Igbo Economic Rebuilding",
        "period": "1970s–1980s",
        "icon": "📈",
        "description": "Igbo communities rebuild through trade, education, and enterprise despite post-war devastation.",
        "story": "The period is often described as the Igbo spirit of resilience and self-reliance.",
    },
    {
        "era": "Post-War Revival",
        "title": "Nri Cultural Revival",
        "period": "1974",
        "icon": "🔄",
        "description": "The Kingdom of Nri undergoes formal socio-cultural revival, reconnecting modern communities with ancient traditions.",
        "story": "Revival efforts preserve ritual heritage and historical identity.",
    },
    {
        "era": "Modern Era",
        "title": "Ekumeku Resistance Remembered",
        "period": "1883–1914",
        "icon": "🛡️",
        "description": "The Ekumeku movement represents sustained Igbo resistance to British encroachment in the Niger area.",
        "story": "Oral and written histories preserve Ekumeku as a symbol of anti-colonial struggle.",
    },
    {
        "era": "Modern Era",
        "title": "Global Igbo Diaspora Growth",
        "period": "1990s–present",
        "icon": "🌐",
        "description": "Igbo communities expand globally, maintaining language, festivals, and identity abroad.",
        "story": "Organizations and digital platforms help diaspora Igbo reconnect with homeland culture.",
    },
    {
        "era": "Modern Era",
        "title": "New Yam Festival (Iri Ji)",
        "period": "Annual",
        "icon": "🍠",
        "description": "Iri Ji remains a major cultural festival celebrating harvest, community, and gratitude across Igboland.",
        "story": "The festival ties agricultural cycles to spiritual thanksgiving and social reunion.",
    },
    {
        "era": "Modern Era",
        "title": "Ofala Festival Revival",
        "period": "20th–21st century",
        "icon": "🎭",
        "description": "Ofala festivals in towns such as Onitsha celebrate royal tradition, culture, and community pride.",
        "story": "Ofala draws visitors and strengthens cultural continuity in urban Igbo kingdoms.",
    },
    {
        "era": "Modern Era",
        "title": "Ikeji Festival of Arondizuogu",
        "period": "Annual",
        "icon": "🥁",
        "description": "The Ikeji festival is a major cultural gathering known for masquerades, trade, and reunion of Arondizuogu communities.",
        "story": "The festival combines spiritual symbolism with economic and social exchange.",
    },
]


def fix_text(value: str) -> str:
    if not isinstance(value, str):
        return value
    text = value
    # Strip ChatGPT citation artifacts.
    text = re.sub(r"[\uE000-\uF8FF]", "", text)
    text = re.sub(r"turn\d+search\d+", "", text)
    text = re.sub(r"cite", "", text)

    for _ in range(3):
        if "Ã" in text or "â" in text or "á»" in text:
            try:
                candidate = text.encode("latin1", errors="ignore").decode("utf-8", errors="ignore")
                if candidate:
                    text = candidate
            except UnicodeError:
                break
        else:
            break

    replacements = {
        "\u2011": "-",
        "\u2013": "-",
        "\u2014": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "â\u0080\u0091": "-",
        "â\u0080\u0093": "-",
        "â\u0080\u0094": "-",
        "â\u0080\u0099": "'",
        "á»": "ọ",
        "áº": "ụ",
        "á": "à",
        "Ä": "ị",
        "á»‹": "ị",
        "á»": "ọ",
        "á»¥": "ụ",
        "á»‹a": "ịa",
    }
    for bad, good in replacements.items():
        text = text.replace(bad, good)
    return re.sub(r"\s+", " ", text).strip()


def unescape_layers(raw: str) -> str:
    text = raw.strip()
    for _ in range(8):
        if "\\" not in text:
            break
        try:
            text = codecs.decode(text, "unicode_escape")
        except UnicodeError:
            break
    return text


def fetch_cached(name: str, url: str) -> str:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = CACHE_DIR / f"{name}.html"
    if not cache_path.exists():
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            cache_path.write_bytes(resp.read())
    return cache_path.read_text(encoding="utf-8", errors="ignore")


def parse_json_block(block: str):
    text = unescape_layers(block)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"(\[[\s\S]+\]|\{[\s\S]+\})", text)
        if not match:
            raise
        cleaned = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", " ", match.group(1))
        return json.loads(cleaned)


def extract_json_blocks(page_text: str) -> list:
    return re.findall(r"```json\s*(.*?)```", page_text, flags=re.DOTALL)


def extract_proverbs(page_text: str) -> list[dict]:
    proverbs: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for block in extract_json_blocks(page_text):
        try:
            data = parse_json_block(block)
        except json.JSONDecodeError:
            continue
        items = data if isinstance(data, list) else [data]
        for item in items:
            if not isinstance(item, dict):
                continue
            igbo = fix_text(item.get("igbo", ""))
            english = fix_text(item.get("english", ""))
            if not igbo or not english:
                continue
            key = (igbo, english)
            if key in seen:
                continue
            seen.add(key)
            proverbs.append({"igbo": igbo, "english": english})
    return proverbs


def normalize_story(item: dict) -> dict | None:
    title = fix_text(item.get("title", ""))
    text = fix_text(item.get("text", ""))
    if not title or not text:
        return None
    story = {
        "title": title,
        "author": fix_text(item.get("author", "Igbo Oral Tradition")),
        "text": text,
        "category": fix_text(item.get("category", "Folktale")),
    }
    for key in ("cover_image", "audio", "excerpt", "source"):
        if item.get(key):
            story[key] = fix_text(item[key])
    return story


def extract_stories(page_text: str) -> list[dict]:
    best: dict[str, dict] = {}
    for block in extract_json_blocks(page_text):
        try:
            data = parse_json_block(block)
        except json.JSONDecodeError:
            continue
        items = data if isinstance(data, list) else [data]
        for item in items:
            if not isinstance(item, dict):
                continue
            story = normalize_story(item)
            if not story:
                continue
            title = story["title"]
            existing = best.get(title)
            if existing is None or len(story["text"]) > len(existing["text"]):
                best[title] = story
    return sorted(best.values(), key=lambda s: s["title"])


def compose_nsibidi(name: str) -> str:
    lower = name.lower()
    keys = sorted(SYLLABLE_MAP.keys(), key=len, reverse=True)
    i = 0
    parts: list[str] = []
    while i < len(lower):
        matched = False
        for key in keys:
            if lower.startswith(key, i):
                parts.append(SYLLABLE_MAP[key])
                i += len(key)
                matched = True
                break
        if not matched:
            parts.append(NSIBIDI_CHARS[i % len(NSIBIDI_CHARS)])
            i += 1
    return "".join(parts)


def build_dictionary() -> list[dict]:
    entries: list[dict] = []
    for idx, (name, meaning) in enumerate(COMMON_IGBO_NAMES, start=1):
        nsibidi = compose_nsibidi(name)
        entries.append(
            {
                "id": str(idx),
                "word": name,
                "igboWord": name,
                "nsibidi": nsibidi,
                "definitions": [
                    {
                        "wordClass": "NNP",
                        "definitions": [meaning],
                        "nsibidi": nsibidi,
                    }
                ],
                "tags": ["generated-v1", "name"],
            }
        )
    return entries


def write_json(filename: str, data) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / filename
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {path} ({len(data) if isinstance(data, list) else 'object'})")


def main() -> int:
    print("Fetching ChatGPT share pages...")
    proverbs_page = fetch_cached("proverbs", CHATGPT_URLS["proverbs"])
    folktales_page = fetch_cached("folktales", CHATGPT_URLS["folktales"])

    proverbs = extract_proverbs(proverbs_page)
    stories = extract_stories(folktales_page)

    events_src = ROOT / "assets" / "data" / "igbo_events.json"
    events = json.loads(events_src.read_text(encoding="utf-8"))

    write_json("events.json", events)
    write_json("igbo_events.json", events)
    write_json("proverbs.json", proverbs)
    write_json("stories.json", stories)
    write_json("igbo_cosmology.json", COSMOLOGY_ENTRIES)
    write_json("timeline.json", TIMELINE_ENTRIES)
    write_json("dictionary.json", build_dictionary())

    print("\nSummary:")
    print(f"  events: {len(events)}")
    print(f"  proverbs: {len(proverbs)}")
    print(f"  stories: {len(stories)}")
    print(f"  cosmology: {len(COSMOLOGY_ENTRIES)}")
    print(f"  timeline: {len(TIMELINE_ENTRIES)}")
    print(f"  dictionary: {len(build_dictionary())}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
