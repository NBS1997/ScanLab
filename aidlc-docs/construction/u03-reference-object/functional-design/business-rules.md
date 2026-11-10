# Business Rules — U03 Reference Object

Inputs: `unit-of-work.md` (U03), `bolt-plan.md` (Bolt 2), `requirements.md` (FR-8.1–8.5), `decisions.md` (ADR-009, ADR-010), `stories.md` (US-12), `.claude/rules/aidlc-team.md`, `.claude/rules/aidlc-project.md`.

| ID | Rule | Requirement | Checked by |
|---|---|---|---|
| BR-1 | One script (`reference-object/reference_object.py`) is the only source for the STL, STEP, feature table and measurement sheet; all four are written in one run. | ADR-010 | workflow run |
| BR-2 | The object fits 340 × 320 × 340 mm; the footprint is kept near 160 × 110 mm. | FR-8.1 | `test_fits_printer_volume` |
| BR-3 | Each of the five feature kinds (lengths, steps, holes and bosses, angles, curves) appears at three or more sizes, the smallest 2 mm or under and the largest 100 mm or over; holes and bosses are capped at 30–40 mm (reason in the README). The largest length is at least 100 mm. | FR-8.2 | `test_every_kind_at_three_sizes_spanning_small_to_large` |
| BR-4 | The shape has no mirror symmetry (three planes) and no half-turn symmetry (three axes) about its box centre. | FR-8.3 | `test_shape_has_no_mirror_or_half_turn_symmetry`, `test_feature_layout_has_no_symmetry` |
| BR-5 | Every feature has a unique ID (kind letter + number), a design value and a plain-English caliper instruction, and is listed on the measurement sheet. | FR-8.4 | `test_ids_unique_and_prefixed`, `test_sheet_lists_every_feature` |
| BR-6 | Every feature region lies inside the overall box and contains a face matching the design value (separation, radius or angle within 0.01). | ADR-009 | `test_feature_geometry_matches_design` |
| BR-7 | Printable flat without supports: no downward face steeper than 45° except the underside on the bed; walls at least 1.2 mm. | FR-8.5 | `test_no_unsupported_overhang`, `test_minimum_wall` |
| BR-8 | The STL is closed (each edge shared by exactly two triangles, in opposite directions); the STEP reopens with the same volume. | FR-8.5 | `test_stl_is_watertight`, `test_step_reimports_with_same_volume` |
| BR-9 | The feature table is deterministic: identical on every run from the same script. Values rounded to 0.001. | ADR-010 | `test_feature_table_is_deterministic_and_matches_disk` |
| BR-10 | The owner's caliper value, not the design value, is the truth for every comparison. `version` increases whenever the geometry changes. | FR-8.4, FR-8.6 | measurement sheet text |
| BR-11 | Generated files are committed so the owner never runs the script. | ADR-010 | repository |
