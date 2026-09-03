"""Offline phonetic-analysis helpers for Understand.

Automatic phone output is an estimate. Only human-reviewed mismatches are
allowed to become speaker-profile evidence.
"""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

PROFILE_PATH = Path("data/phonological_profiles.json")
EMPTY_PHONE = "∅"
SPEAKER_CODE_RE = re.compile(r"^S\d{2,4}$", re.IGNORECASE)

try:
    from gruut import sentences as gruut_sentences
except Exception:
    gruut_sentences = None

try:
    from allosaurus.app import read_recognizer
except Exception:
    read_recognizer = None

try:
    from panphon.distance import Distance
except Exception:
    Distance = None


def optional_dependency_status():
    return {
        "reference_ipa": gruut_sentences is not None,
        "phone_recognizer": read_recognizer is not None,
        "feature_distance": Distance is not None,
    }


def validate_speaker_code(speaker_code):
    code = speaker_code.strip().upper()
    if not SPEAKER_CODE_RE.fullmatch(code):
        raise ValueError("Use an anonymous code such as S01 (never a name).")
    return code


def generate_reference_ipa(confirmed_text):
    """Return (word-separated display IPA, flat reference-phone list)."""
    if gruut_sentences is None:
        raise RuntimeError(
            "Reference IPA needs the optional packages. Run: "
            "pip install -r requirements-phonetics.txt"
        )
    text = confirmed_text.strip()
    if not text:
        return "", []
    display_words, phones = [], []
    for sentence in gruut_sentences(text, lang="en-us"):
        for word in sentence:
            if word.phonemes:
                word_phones = [
                    phone.replace("ˈ", "").replace("ˌ", "")
                    for phone in word.phonemes
                ]
                display_words.append(" ".join(word_phones))
                phones.extend(word_phones)
    if not phones:
        raise ValueError("No reference phones could be generated from that text.")
    return " | ".join(display_words), phones


def load_phone_recognizer():
    if read_recognizer is None:
        raise RuntimeError(
            "Phone recognition needs Allosaurus. Run: "
            "pip install -r requirements-phonetics.txt"
        )
    return read_recognizer()


def recognize_phones(audio_path, recognizer, language="eng"):
    """Return Allosaurus's estimated phone list for a WAV file."""
    try:
        output = recognizer.recognize(str(audio_path), language)
    except TypeError:
        output = recognizer.recognize(str(audio_path))
    phones = output.split() if isinstance(output, str) else list(output or [])
    if not phones:
        raise ValueError("The recognizer returned no phones for this clip.")
    return phones


def align_phones(expected, recognized):
    """Align phone lists with matches, substitutions, deletions, insertions."""
    rows, cols = len(expected) + 1, len(recognized) + 1
    costs = [[0] * cols for _ in range(rows)]
    back = [[None] * cols for _ in range(rows)]
    for i in range(1, rows):
        costs[i][0], back[i][0] = i, "deletion"
    for j in range(1, cols):
        costs[0][j], back[0][j] = j, "insertion"
    for i in range(1, rows):
        for j in range(1, cols):
            same = expected[i - 1] == recognized[j - 1]
            choices = {
                "match" if same else "substitution": costs[i - 1][j - 1] + (0 if same else 1),
                "deletion": costs[i - 1][j] + 1,
                "insertion": costs[i][j - 1] + 1,
            }
            operation = min(choices, key=choices.get)
            costs[i][j], back[i][j] = choices[operation], operation
    alignment, i, j = [], len(expected), len(recognized)
    while i > 0 or j > 0:
        operation = back[i][j]
        if operation in ("match", "substitution"):
            alignment.append({"expected": expected[i - 1], "recognized": recognized[j - 1], "operation": operation})
            i, j = i - 1, j - 1
        elif operation == "deletion":
            alignment.append({"expected": expected[i - 1], "recognized": EMPTY_PHONE, "operation": operation})
            i -= 1
        else:
            alignment.append({"expected": EMPTY_PHONE, "recognized": recognized[j - 1], "operation": "insertion"})
            j -= 1
    return list(reversed(alignment))


def calculate_per(alignment):
    errors = sum(row["operation"] != "match" for row in alignment)
    reference_count = sum(row["expected"] != EMPTY_PHONE for row in alignment)
    return None if reference_count == 0 else errors / reference_count


def add_feature_distances(alignment):
    """Attach optional PanPhon distance to substitution rows."""
    distance = Distance() if Distance is not None else None
    result = []
    for row in alignment:
        item = dict(row)
        item["feature_distance"] = None
        if distance is not None and row["operation"] == "substitution":
            try:
                item["feature_distance"] = round(
                    distance.weighted_feature_edit_distance(row["expected"], row["recognized"]), 3
                )
            except (KeyError, ValueError):
                pass
        result.append(item)
    return result


def load_profiles(path=PROFILE_PATH):
    path = Path(path)
    if not path.exists():
        return {"speakers": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {"speakers": {}}
    if not isinstance(data, dict) or not isinstance(data.get("speakers"), dict):
        return {"speakers": {}}
    return data


def save_review(speaker_code, clip_analysis, path=PROFILE_PATH):
    code = validate_speaker_code(speaker_code)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = load_profiles(path)
    clips = data["speakers"].setdefault(code, {"clips": []}).setdefault("clips", [])
    clips[:] = [clip for clip in clips if clip.get("clip_id") != clip_analysis["clip_id"]]
    clips.append(clip_analysis)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def build_profile(speaker_code, path=PROFILE_PATH, threshold=3):
    """Count only mismatches marked by a reviewer as a speaker pattern."""
    code = validate_speaker_code(speaker_code)
    clips = load_profiles(path)["speakers"].get(code, {}).get("clips", [])
    counts = Counter()
    for clip in clips:
        for mismatch in clip.get("mismatches", []):
            if mismatch.get("review_decision") == "speaker_pattern":
                counts[(mismatch["expected"], mismatch["recognized"], mismatch["operation"])] += 1
    profile = []
    for (expected, recognized, operation), count in counts.most_common():
        if operation == "deletion":
            description = f"/{expected}/ → deleted"
        elif operation == "insertion":
            description = f"inserted /{recognized}/"
        else:
            description = f"/{expected}/ → /{recognized}/"
        profile.append({
            "expected": expected, "recognized": recognized, "operation": operation,
            "count": count, "candidate_rule": count >= threshold, "description": description,
        })
    return profile


def top_rule_descriptions(speaker_code, path=PROFILE_PATH, limit=5):
    return [
        f"{row['description']} ({row['count']} reviewed examples)"
        for row in build_profile(speaker_code, path)
        if row["candidate_rule"]
    ][:limit]
