# Gloam ten-night economy balance

Gloam is balanced as one ten-day, ten-night run. Night 10 still contains the
only final boss. The figures below come from `scripts/economy_balance.gd` and
are gross income before building, repairs, rescues, or shrine spending.

## Projection assumptions

- The baseline collects every spawned pickup and defeats every daytime enemy.
- Mine enemies always give Stone; their 25% Iron bonus is represented as an
  average. Actual runs will receive integer, variable Iron rewards.
- Four starting Workers stay assigned for the whole projection. Their dawn
  income begins on Day 2: 4 Wood, 1 Stone, and no Iron.
- The Food column assumes one level-1 Farm was built on Day 1. It produces 2
  Food at each dawn from Day 2 onward. Food is not included in the other totals.
- Daytime enemy rewards are optional. Nights award no construction resources.
- Day length is 165 seconds. Players can end a day early from the village.

| Day | Pickups (W/S/I/E) | Day enemies (Forest/Mine/Ruins) | Wood | Stone | Iron (avg.) | Essence | Farm Food |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 8 / 5 / 3 / 6 | 3 / 3 / 2 | 11 | 8 | 3.75 | 8 | 0 |
| 2 | 6 / 4 / 2 / 3 | 4 / 4 / 3 | 14 | 9 | 3.00 | 6 | 2 |
| 3 | 6 / 4 / 2 / 3 | 4 / 4 / 3 | 14 | 9 | 3.00 | 6 | 2 |
| 4 | 5 / 3 / 2 / 2 | 5 / 5 / 4 | 14 | 9 | 3.25 | 6 | 2 |
| 5 | 5 / 3 / 2 / 2 | 5 / 5 / 4 | 14 | 9 | 3.25 | 6 | 2 |
| 6 | 4 / 3 / 1 / 2 | 4 / 4 / 3 | 12 | 8 | 2.00 | 5 | 2 |
| 7 | 4 / 2 / 1 / 1 | 4 / 4 / 3 | 12 | 7 | 2.00 | 4 | 2 |
| 8 | 3 / 2 / 1 / 1 | 4 / 4 / 3 | 11 | 7 | 2.00 | 4 | 2 |
| 9 | 3 / 2 / 1 / 1 | 4 / 4 / 3 | 11 | 7 | 2.00 | 4 | 2 |
| 10 | 3 / 2 / 1 / 1 | 4 / 4 / 3 | 11 | 7 | 2.00 | 4 | 2 |
| **Days 1–10** | **47 / 30 / 16 / 22** | **41 / 41 / 31** | **124** | **80** | **26.25** | **53** | **18** |

The taper is deliberate: Day 1 retains the full authored resource plan, Days
4–5 carry the largest optional daytime fights, and Days 7–10 contain fewer
pickups instead of repeating a full-map harvest. A run that collects and defeats
roughly 70% of both sources, while receiving all Worker income, projects to
about 98 Wood, 59 Stone, 18.38 Iron, and 37 Essence. That is enough to keep
building and repairing, but focused Iron upgrades still require deliberate Mine
trips or a Worker-heavy population plan.

## Openings and competing strategies

Predictable Day 1 pickups alone remain 8 Wood, 5 Stone, 3 Iron, and 6 Essence.
They support several openings without relying on enemy drops:

- Immediate fortification: Archer Tower + Ballista + Barricade costs 8 Wood,
  2 Stone, and 2 Iron.
- Barracks economy: Barracks + Farm + Barricade costs 7 Wood and 4 Stone.
- Population growth: House + Farm + Barricade costs 7 Wood and 2 Stone.

No pair of complete opening packages fits the pickup budget. Fortification is
safer immediately; Barracks converts rescued population into soldiers; House
and Farm increase long-run role choices but spend slots and materials before
adding combat power.

Worker output has diminishing returns. Four Workers yield 4 Wood/1 Stone/0
Iron each dawn; six yield 5/2/1; ten yield the cap of 6/3/1. Assigning two early
rescues as Workers raises the ten-day projection to 133 Wood, 89 Stone, and 35.25 Iron,
but those villagers are not Guards or Archers during the harder nights. Farm
levels produce 2/3/4 Food, while House levels add 3/5/7 capacity. Farms enable
rescues; Houses create room; Barracks determines whether population becomes
combat power. None is useful in isolation.

Two representative max-level plans show the intended resource tension:

| Plan | Included investments | Wood | Stone | Iron |
| --- | --- | ---: | ---: | ---: |
| Combat specialist | Lv.3 Blacksmith, two Lv.3 Archer Towers, one Lv.3 Ballista | 45 | 22 | 24 |
| Population specialist | Lv.3 House, Farm, and Barracks | 32 | 20 | 8 |
| Both plans | All of the above | 77 | 42 | 32 |

The fixed-four-Worker projection can afford either specialist plan but not both
because it averages only 26.25 Iron before repairs. Six early Workers can cross
the combined Iron threshold, trading away two immediate soldiers. Even the
baseline cannot fill all seven defense slots with max-level Barricades. This
keeps focused builds viable without making total completion routine.

## Costs and upgrade value

Base building costs are unchanged so Day 1 remains flexible. Upgrade costs rise
more sharply across the longer run:

| Upgrade | Level 2 (W/S/I) | Level 3 (W/S/I) | Role |
| --- | --- | --- | --- |
| Defense | 3 / 2 / 1 | 5 / 3 / 3 | Broad lane strength; expensive to repeat across seven slots |
| Gate | 3 / 4 / 2 | 5 / 6 / 4 | Durable fallback when a damage build lacks coverage |
| House or Farm | 3 / 2 / 0 | 5 / 3 / 1 | Converts late capacity/Food into population options |
| Barracks | 3 / 3 / 2 | 5 / 4 / 4 | Improves every soldier, favoring population builds |
| Blacksmith | 3 / 2 / 3 | 5 / 3 / 5 | Improves hero and soldiers, favoring concentrated damage |

Repairs remain cheaper than replacement, so recovery is practical but consumes
part of the projected surplus. Shrine costs are now 2 Essence for healing, 4
for a blessing, and 5 for a ward. Day 1's expected 8 Essence cannot buy both a
blessing and a ward, and the ten-day total cannot fund a ward every night plus
unlimited progression. Essence therefore remains a tactical budget.

## Progression targets

| Timing | Healthy target, not a requirement |
| --- | --- |
| Day 1 | Commit to immediate defenses, Barracks access, or House/Farm growth; cover at least one lane |
| Days 2–3 | Reach 2–3 defenses and one enabling village building; decide whether early rescues become Workers or soldiers |
| Days 4–5 | Establish the run's main identity; begin level-2 upgrades and maintain a repair reserve |
| Days 6–7 | Complete one level-3 keystone (Blacksmith, Barracks, Gate, or core defense) rather than upgrading everything evenly |
| Days 8–9 | Hold 5–7 mixed defenses or an equivalent soldier-heavy plan; prepare both lanes and reserve resources for damage repair |
| Day 10 | Repair and finish the most valuable upgrade; gathering is optional preparation, not a mandatory full-map sweep |

## Expected run duration

Ten full days total 27 minutes 30 seconds. The deterministic wave scripts add
9 minutes 58 seconds of minimum spawn pacing across Nights 1–10. Nights are
kill-gated, so combat cleanup, the final boss, village management, and travel
after dusk add variable time. A successful run is expected to take roughly
42–50 minutes; experienced players who skip completed days can finish faster.
