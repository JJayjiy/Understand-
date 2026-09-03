def align_phones(expected, recognized):
    """Align two lists of phones using edit distance."""

    rows = len(expected) + 1
    cols = len(recognized) + 1

    costs = [[0] * cols for _ in range(rows)]
    back = [[None] * cols for _ in range(rows)]

    for i in range(1, rows):
        costs[i][0] = i
        back[i][0] = "deletion"

    for j in range(1, cols):
        costs[0][j] = j
        back[0][j] = "insertion"

    for i in range(1, rows):
        for j in range(1, cols):
            same = expected[i - 1] == recognized[j - 1]

            choices = {
                "match" if same else "substitution":
                    costs[i - 1][j - 1] + (0 if same else 1),
                "deletion": costs[i - 1][j] + 1,
                "insertion": costs[i][j - 1] + 1,
            }

            operation = min(choices, key=choices.get)
            costs[i][j] = choices[operation]
            back[i][j] = operation

    alignment = []
    i = len(expected)
    j = len(recognized)

    while i > 0 or j > 0:
        operation = back[i][j]

        if operation in ("match", "substitution"):
            alignment.append({
                "expected": expected[i - 1],
                "recognized": recognized[j - 1],
                "operation": operation,
            })
            i -= 1
            j -= 1

        elif operation == "deletion":
            alignment.append({
                "expected": expected[i - 1],
                "recognized": "∅",
                "operation": "deletion",
            })
            i -= 1

        else:
            alignment.append({
                "expected": "∅",
                "recognized": recognized[j - 1],
                "operation": "insertion",
            })
            j -= 1

    return list(reversed(alignment))


def calculate_per(alignment):
    """PER = substitutions + deletions + insertions / reference phones."""

    errors = sum(
        row["operation"] != "match"
        for row in alignment
    )

    reference_phones = sum(
        row["expected"] != "∅"
        for row in alignment
    )

    if reference_phones == 0:
        return None

    return errors / reference_phones