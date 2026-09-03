import tempfile
import unittest
from pathlib import Path

from phonetics import align_phones, build_profile, calculate_per, save_review, validate_speaker_code


class PhoneticsTests(unittest.TestCase):
    def test_deletion_and_per(self):
        alignment = align_phones(["w", "ɔ", "t", "ɚ"], ["w", "ɔ", "ɚ"])
        self.assertEqual(alignment[2]["operation"], "deletion")
        self.assertAlmostEqual(calculate_per(alignment), 0.25)

    def test_reject_name_as_code(self):
        with self.assertRaises(ValueError):
            validate_speaker_code("Melodie")

    def test_three_reviewed_examples_suggest_rule(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "profiles.json"
            for number in range(3):
                save_review("S01", {
                    "clip_id": f"S01-C{number + 1:03d}", "per": 0.25,
                    "mismatches": [{"expected": "t", "recognized": "∅", "operation": "deletion", "review_decision": "speaker_pattern", "process": "final_consonant_deletion"}],
                }, path)
            profile = build_profile("S01", path)
            self.assertEqual(profile[0]["count"], 3)
            self.assertTrue(profile[0]["candidate_rule"])


if __name__ == "__main__":
    unittest.main()
