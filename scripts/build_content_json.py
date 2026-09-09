#!/usr/bin/env python3
"""Build Nketa content JSON files from ChatGPT shares and curated sources."""

from __future__ import annotations

import codecs
import json
import re
import shutil
import sys
import unicodedata
import urllib.request
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "data"
CACHE_DIR = ROOT / "scripts" / ".chatgpt_cache"
IGBO_API_NSIBIDI_PATH = (
    Path(__file__).resolve().parents[2] / "igbo_api" / "src" / "dictionaries" / "nsibidi" / "nsibidi_dictionary.ts"
)

CHATGPT_URLS = {
    "proverbs": "https://chatgpt.com/share/6aa0071f-5d24-83ea-aabb-b36b0953bcac",
    "cosmology": "https://chatgpt.com/share/6aa0074f-1938-83e9-9019-da7666f98b59",
    "folktales": "https://chatgpt.com/share/6aa010c1-1bcc-83ea-9ca8-58fd14e7b89c",
}

# Igbo name morpheme hints mapped to tonal pronunciations in igbo_api nsibidi dictionary.
NAME_PRONUNCIATION_HINTS = {
    "chukwu": "chí:úkwú",
    "chukw": "chukwu",
    "chi": "chí",
    "chị": "chị̀",
    "ngozi": "ń:gọ́:zí",
    "gozi": "gọ́:zí",
    "gozie": "gọ́:zí",
    "di": "dị̀",
    "du": "dú",
    "edu": "è:dú",
    "nedu": "nè:dú",
    "ne": "nè",
    "ma": "m:á",
    "ka": "ká",
    "amaka": "á:mà:ká",
    "aka": "áká",
    "obi": "ó:bì",
    "nna": "nà",
    "nne": "nè",
    "nnamdi": "nà:m:dị̀",
    "ife": "ị́:fé",
    "oma": "ọ́:má",
    "ifeoma": "ị́:fé:ọ́:má",
    "uche": "úchè",
    "uchenna": "úchè:nà",
    "eme": "é:mé",
    "emeka": "é:mé:ká",
    "eka": "éká",
    "kele": "kè:lè",
    "kelechi": "kè:lè:chí",
    "som": "sọ̀:m",
    "to": "tọ̀",
    "chukwuma": "chí:úkwú:m:á",
    "bueze": "bụ́:é:zè",
    "chibueze": "chí:bụ́:é:zè",
    "chidi": "chí:dị̀",
    "chinedu": "chí:nè:dú",
    "chiamaka": "chí:á:mà:ká",
    "chisom": "chí:sọ̀:m",
    "chinonso": "chí:nọ̀:n:sọ̀",
    "chinwe": "chí:nwè",
    "chinweike": "chí:nwè:í:ké",
    "chizoba": "chí:zọ̀:bá",
    "chizitere": "chí:zị̀:téré",
    "adanna": "á:dá:nà",
    "adaku": "á:dá:kú",
    "amarachi": "á:má:rá:chí",
    "onyinye": "ó:nyé:nyé",
    "oluchi": "ó:lú:chí",
    "oluoma": "ó:lú:ọ́:má",
    "ebere": "é:bé:rè",
    "ebuka": "é:bú:ká",
    "ikenna": "í:ké:nà",
    "ikechukwu": "í:ké:chí:úkwú",
    "jide": "jí:dé",
    "ofor": "ó:fò:r",
    "kamsi": "ká:m:sí",
    "kosi": "kọ̀:sí",
    "nkiru": "ń:kí:rú",
    "nkechi": "ń:ké:chí",
    "osita": "ó:sị̀:tá",
    "osinachi": "ó:sị̀:ná:chí",
    "ugochukwu": "ú:gó:chí:úkwú",
    "ugonna": "ú:gó:nà",
    "tochukwu": "tọ̀:chí:úkwú",
    "somtochukwu": "sọ̀:m:tọ̀:chí:úkwú",
    "obinna": "ò:bì:nà",
    "obiora": "ò:bì:ó:rá",
    "obioma": "ò:bì:ọ́:má",
    "oge": "ó:gé",
    "ogechi": "ó:gé:chí",
    "chinecherem": "chí:né:ché:rè:m",
    "chineze": "chí:né:zè",
    "chidimma": "chí:dị̀:m:má",
    "chidiebere": "chí:dị̀:é:bé:rè",
    "chidozie": "chí:dọ̀:zí",
    "chigoziem": "chí:gọ́:zí:m",
    "chika": "chí:ká",
    "chikamso": "chí:ká:m:sọ̀",
    "chikodi": "chí:kó:dí",
    "chinaza": "chí:ná:zá",
    "chisara": "chí:sá:rá",
    "chizaram": "chí:zá:rá:m",
    "ekene": "é:ké:nè",
    "ekenechukwu": "é:ké:nè:chí:úkwú",
    "ezinne": "é:zì:nè",
    "ifeanyi": "ị́:fé:á:nyí",
    "ifechukwu": "ị́:fé:chí:úkwú",
    "ihuoma": "í:hú:ọ́:má",
    "kamso": "ká:m:sọ̀",
    "kamsiyochukwu": "ká:m:sí:yó:chí:úkwú",
    "kenechukwu": "ké:nè:chí:úkwú",
    "munachim": "mú:ná:chí:m",
    "ndidiamaka": "ń:dị̀:á:mà:ká",
    "ngoziem": "ń:gọ́:zí:m",
    "nkiruka": "ń:kí:rú:ká",
    "obumneme": "ò:bù:m:né:mé",
    "ogechioma": "ó:gé:chí:ọ́:má",
    "ogechukwu": "ó:gé:chí:úkwú",
    "okorie": "ó:kó:rí",
    "oluchioma": "ó:lú:chí:ọ́:má",
    "onyebuchi": "ó:nyé:bù:chí",
    "onyinyechukwu": "ó:nyé:nyé:chí:úkwú",
    "uchechioma": "ú:chè:chí:ọ́:má",
    "udochukwu": "ú:dò:chí:úkwú",
    "ugonne": "ú:gó:nè",
    "uzoma": "ú:zó:má",
    "zikora": "zí:kó:rá",
    "adaeze": "á:dá:é:zè",
    "adimchi": "á:dị̀:m:chí",
    "akunna": "á:kú:nà",
    "amarachukwu": "á:má:rá:chí:úkwú",
    "anulika": "á:nú:lí:ká",
    "buchi": "bù:chí",
    "chidubem": "chí:dù:bé:m",
    "chigozirim": "chí:gọ́:zí:rí:m",
    "chimamanda": "chí:má:má:ń:dá",
    "chimaraoke": "chí:má:rá:ó:ké",
    "chinagorom": "chí:ná:gó:ró:m",
    "chinedum": "chí:né:dù:m",
    "chinwendu": "chí:n:wé:ń:dù",
    "chizurum": "chí:zú:rú:m",
    "ebelechukwu": "é:bé:lè:chí:úkwú",
    "enyinnaya": "é:nyí:nà:yá",
    "ezinwa": "é:zì:ń:wá",
    "lotanna": "ló:tá:nà",
    "mmesoma": "m:mé:sọ̀:má",
    "ngozika": "ń:gọ́:zí:ká",
    "nkeiruka": "ń:ké:í:rú:ká",
    "nneka": "nè:ká",
    "onyeka": "ó:nyé:ká",
    "onyekachi": "ó:nyé:ká:chí",
    "obiageli": "ó:bì:lì",
    "ekwi": "kwú",
    "olisa": "chí:úkwú",
    "jideofor": "jí:dé:ó:fò",
    "onyekwere": "ó:nyé:kwé:rè",
    "ozioma": "ó:zí:ọ́:má",
    "oziomachukwu": "ó:zí:ọ́:má:chí:úkwú",
    "ugochi": "ú:gó:chí",
    "ugomma": "ú:gó:m:má",
    "uzoamaka": "ú:zó:á:mà:ká",
    "zinachidi": "zí:ná:chí:dị̀",
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


def normalize_pronunciation(value: str) -> str:
    text = unicodedata.normalize("NFD", value)
    text = "".join(char for char in text if unicodedata.category(char) != "Mn")
    return text.lower().replace(":", "")


def parse_igbo_api_nsibidi_dictionary(path: Path) -> list[dict]:
    if not path.exists():
        raise FileNotFoundError(f"Igbo API nsibidi dictionary not found: {path}")
    text = path.read_text(encoding="utf-8")
    entries: list[dict] = []
    pattern = re.compile(
        r"\{\s*sym: '((?:\\'|[^'])*)',\s*pro: ([^,]+),\s*form: '((?:\\'|[^'])*)',\s*defs: '((?:\\'|[^'])*)',?\s*\}"
    )
    for match in pattern.finditer(text):
        sym, pro, _form, defs = match.groups()
        if pro.strip() == "null":
            continue
        entries.append(
            {
                "sym": sym.replace("\\'", "'"),
                "pro": pro.strip("'"),
                "defs": defs.replace("\\'", "'"),
            }
        )
    return entries


@lru_cache(maxsize=1)
def load_nsibidi_lookup() -> tuple[dict[str, dict], dict[str, dict]]:
    entries = parse_igbo_api_nsibidi_dictionary(IGBO_API_NSIBIDI_PATH)
    by_pro: dict[str, dict] = {}
    by_norm: dict[str, dict] = {}
    for entry in entries:
        by_pro[entry["pro"].lower()] = entry
        norm_key = normalize_pronunciation(entry["pro"])
        if norm_key not in by_norm:
            by_norm[norm_key] = entry
    return by_pro, by_norm


def lookup_symbol(pro: str, by_pro: dict[str, dict], by_norm: dict[str, dict]) -> str | None:
    entry = by_pro.get(pro.lower()) or by_norm.get(normalize_pronunciation(pro))
    if entry:
        return entry["sym"]
    # Tone-insensitive fallback for single-token lookups.
    target = normalize_pronunciation(pro)
    for key, candidate in by_norm.items():
        if key == target:
            return candidate["sym"]
    return None


def symbols_from_pronunciation(pro: str, by_pro: dict[str, dict], by_norm: dict[str, dict]) -> str:
    if pro.lower() in by_pro:
        return by_pro[pro.lower()]["sym"]

    parts = pro.split(":")
    symbols: list[str] = []
    index = 0
    while index < len(parts):
        matched = False
        for end in range(len(parts), index, -1):
            chunk = ":".join(parts[index:end])
            symbol = lookup_symbol(chunk, by_pro, by_norm)
            if symbol:
                symbols.append(symbol)
                index = end
                matched = True
                break
        if not matched:
            symbols.append("?")
            index += 1
    return "".join(symbols)


def compose_nsibidi(name: str) -> tuple[str, str]:
    by_pro, by_norm = load_nsibidi_lookup()
    lower = name.lower()

    if lower in NAME_PRONUNCIATION_HINTS:
        pronunciation = NAME_PRONUNCIATION_HINTS[lower]
        return symbols_from_pronunciation(pronunciation, by_pro, by_norm), pronunciation

    norm_name = normalize_pronunciation(name)
    if norm_name in by_norm:
        entry = by_norm[norm_name]
        return entry["sym"], entry["pro"]

    parts: list[str] = []
    i = 0
    hint_keys = sorted(NAME_PRONUNCIATION_HINTS.keys(), key=len, reverse=True)
    while i < len(lower):
        matched = None
        for key in hint_keys:
            if lower.startswith(key, i):
                matched = NAME_PRONUNCIATION_HINTS[key]
                i += len(key)
                break
        if matched is None:
            matched = lower[i]
            i += 1
        parts.append(matched)

    pronunciation = ":".join(parts)
    return symbols_from_pronunciation(pronunciation, by_pro, by_norm), pronunciation


def build_dictionary() -> list[dict]:
    entries: list[dict] = []
    missing = 0
    for idx, (name, meaning) in enumerate(COMMON_IGBO_NAMES, start=1):
        nsibidi, pronunciation = compose_nsibidi(name)
        if "?" in nsibidi:
            missing += 1
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
                "tags": ["generated-v2-igbo-api", "name", f"pro:{pronunciation}"],
            }
        )
    if missing:
        print(f"  dictionary warning: {missing} names have unresolved nsibidi segments")
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
