# Guardrail: no-self-truncation

*Born 2026-04-05 in response to the read_file/edit_file regression where
Code's own body was truncated from 27KB → 8KB because edit_file internally
called the banner-wrapped read_file instead of read_file_raw.*

## What I Check

After any `edit_file` operation on a `.exs` or `.ex` file in `projects/iex-claw/`,
I verify that the file's new byte count is within a plausible delta of the
old byte count given the replacement.

**Pass criterion:**

```
|new_size - expected_size| <= max(200, 0.1 * expected_size)
```

Where `expected_size = old_size - sum(byte_size(old_text)) + sum(byte_size(new_text))`.

If the new size drops to less than 50% of the old size on a single edit, that's
an automatic fail with a concern raised to Project.

## Why This Matters

The 2026-04-05 regression was invisible at edit time — `edit_file` returned
`{:ok, "Applied 1 edit(s)..."}` while silently clobbering 19KB of Code's own
body. The tool-level success message lied. This guardrail catches the lie.

## How I Run

```elixir
# before edit
old_size = File.stat!(path).size

# apply edit via Tools.EditFile.edit/2

# after edit
new_size = File.stat!(path).size
expected = old_size + net_delta(edits)

pass? = abs(new_size - expected) <= max(200, div(expected, 10))
```

Runs in-process (no shell). Fast. Deterministic.

## Pass Example

Edit: `old_text: "hello"`, `new_text: "hello, world"`
- old_size: 1000, expected: 1007, new_size: 1007 → **pass**

## Fail Example (the regression)

Edit: `old_text: "# IExClaw.Agents.Code"`, `new_text: "TEST_MARKER"`
- old_size: 27006, expected: 26999, new_size: 8136 → **fail**
- Feedback:
  - ⚠️ **concern** to Project: "new_size is 30% of old_size after a small edit — suspect internal tool wrapping its own read output. Check edit_file's internal read call."

## Four Flavors I Emit

- ❓ **Question** (to Code): "Your edit shows empty old_text — did you mean to append?"
- 💬 **Comment** (to Code): "File grew by 6KB from one edit — that's a big chunk. Consider splitting."
- ⚠️ **Concern** (to Project): "New size is <50% of old size. Possible internal tool regression."
- 💡 **Suggestion** (to Code): "Backup before large edits. You already do this — keep it up."

## Who I Push Back To

- **Code** — for questions about intent and suggestions about hygiene
- **Project** — for concerns about tool behavior (structural, not content)
- **Goal** — if a pattern of truncations appears across multiple edits (drift)
- **Clawd** — if my check itself can't run (e.g. file stat fails)

## Retirement Criteria

I can retire when:
- A better structural guardrail exists (e.g. "edit_file always uses read_file_raw internally, enforced by test")
- `edit_file` is replaced with a safer API that makes truncation impossible

## Signatures

Stored at `guardrails/no-self-truncation/signatures/<timestamp>.md`.
Each signature records: change description, old_size, new_size, expected, verdict, feedback.
