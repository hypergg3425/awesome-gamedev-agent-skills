# AI balance report

All numbers come from `tests/sim.tscn` (every country AI-driven, difficulty normal) and the `ai`, `ai_personalities`, `victory` test suites. **No human play-testing was done**; "balance" here means stability and absence of degenerate outcomes in simulation, not fun or fairness.

## Personalities (9)
aggressive, defensive, expansionist, diplomatic, economic, opportunistic, isolationist, **naval_trade**, **coalition_builder**. Default assignment when a scenario does not name one comes from the government type (merchant republics now map to `naval_trade`; natives are always `isolationist`).
Measured differences (t_ai_personalities, forced on every AI country, early_modern, 2 seeds × 40 turns): naval_trade ends with more ports + trade centres than aggressive and at least as many ships; coalition_builder ends with more alliances than isolationist. Each of the nine runs 24 turns with a valid state.

## Soak runs after this iteration (seed 8, 150 turns, 7 runs in parallel on 4 cores)
| Scenario | Alive at end | Wars started | Battles | Countries with gold < 0 | Countries in debt > 2000 | NaN/inf | State validation |
|---|---|---:|---:|---:|---:|---:|---|
| medieval_europe | 58/59 | 24 | 41 | 1 | 1 | 0 | no problems |
| hundred_years_war | 55/58 | 27 | 16 | 0 | 2 | 0 | no problems |
| fall_of_constantinople | 57/58 | 28 | 13 | 0 | 4 | 0 | no problems |
| early_modern | 65/73 | 39 | 62 | 0 | 1 | 0 | no problems |
| age_of_revolutions | 50/59 | 31 | 46 | 0 | 1 | 0 | no problems |
| industrial_era | 64/70 | 30 | 23 | 3 | 1 | 0 | no problems |
| world_conquest | 51/53 | 26 | 9 | 0 | 1 | 0 | no problems |
No run ended in an early victory (earlier iteration: AI technological/economic wins around turn 25; fixed by the minimum victory turn, hold counter and tech lead rule).

## Known weaknesses
* 1–4 countries per run still end in debt above 2000 gold: the AI avoids persistent bankruptcy only partly.
* Medieval scenarios see few battles (13–41 in 150 turns) and few border changes (6–16): the AI is cautious there; with two thirds of the map being passive generic native states there is little to conquer.
* Naval AI only builds/uses fleets in a simple way because naval combat itself is simplified.
* Difficulty knobs (`DIFF`): skip chance, army-size appetite ("force" 0.7–1.25), planning, war prudence, coalition use, construction appetite; `expert` reads enemy army sizes. No income/manpower/combat bonuses exist (checked by `test_difficulty_changes_decision_quality_not_resources`).
* AI decision explanations for the player are limited to diplomatic acceptance reasons; there is no general "why did the AI do this" log (not implemented).
