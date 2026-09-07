# Gloam economy balance

The figures below are projections from `scripts/economy_balance.gd`. They assume
all planned pickups are collected, every daytime enemy is defeated, the Mine's
35% Iron bonus is averaged, four starting Workers remain assigned, and no Farm
income is included unless noted. Enemy rewards are variable in a real run.

| Day | Wood | Stone | Iron | Essence | Food from Farms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 11 | 8 | 4.05 | 8 | 0 |
| 2 | 16 | 11 | 5.40 | 9 | +3 per active Farm |
| 3 | 17 | 12 | 5.75 | 10 | +3 per active Farm |
| 1–3 cumulative | 44 | 31 | 15.20 | 27 | +6 per active level-1 Farm |

Predictable Day 1 pickups alone are 8 Wood, 5 Stone, 3 Iron, and 6 Essence.
That supports either an immediate fortification package (Archer Tower + Ballista
+ Barricade: 8 Wood, 2 Stone, 2 Iron) or an infrastructure opening (Barracks +
Farm + Barricade: 7 Wood, 4 Stone), but not both. A level-1 Farm produces six
food before the end of the run if built before Day 2, covering six additional
rescues at one Food each. A House adds three capacity immediately, allowing the
player to turn that food into population rather than leaving it idle.

| Purchase | Cost | Useful timing | Opportunity cost |
| --- | --- | --- | --- |
| Archer Tower | 4 Wood | Day 1–2 | Competes with House/Blacksmith Wood |
| Ballista | 2 Wood + 1 Stone + 2 Iron | Day 1–2 | Consumes Mine materials needed by Blacksmith |
| Barricade | 2 Wood + 1 Stone | Day 1 | Low-cost first-night time buffer |
| House | 3 Wood | Day 1–2 | Delays a combat structure; pays back through rescued population |
| Farm | 2 Wood + 1 Stone | Day 1–2 | Pays back only through future dawns/rescues |
| Barracks | 3 Wood + 2 Stone | Day 1 | Enables Guards/Archers, but competes with Farm/defenses |
| Blacksmith | 3 Wood + 1 Stone + 2 Iron | Day 2–3 | Immediate +1 damage, but competes with Ballista and Barracks upgrades |
| Shrine: heal / blessing / ward | 1 / 2 / 3 Essence | Situational each day | Spends the same Essence needed for later choices |

Balance audit: no opening purchase is dominant. Immediate fortification protects
the first night but gives up population and future food; Barracks/Farm/House
growth gives more options but leaves less immediate structure coverage. The main
trap is spending Mine Iron on both Ballistas and Blacksmith upgrades before
choosing which defense plan the night needs. Level-3 Blacksmith and defense
upgrades are intentionally late-run luxuries: they are useful before Night 3,
but their escalating costs prevent them from crowding out the first-night plan.

Upgrade costs escalate by next level. Blacksmith upgrades cost 2 Wood + 1 Stone
+ 2 Iron, then 3 Wood + 2 Stone + 3 Iron; non-gate defenses cost 2/1/1 and
then 3/2/2 (Wood/Stone/Iron). Repairs stay cheaper than replacement, so losing
a structure hurts the current plan without making the run unrecoverable.
