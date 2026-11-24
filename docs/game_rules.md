# Life Kingdom - Game Rules (v0.1, draft for review)

All numbers live in one config file (`lib/core/game/game_config.dart`) so they can be tuned without touching logic.
Pacing assumption used below: an active player earns about **130 XP/day** (4-5 habits plus quests).

## 1. Currencies
| Currency | Source | Use |
|---|---|---|
| XP | habits, quests, streak bonus | levels and ranks only (never spent) |
| Gold | habits, quests, level-ups, chests | buildings, shop, streak freeze |
| Gems | quests, streak milestones, rank-ups, chests (never from plain habits) | legendary items, skipping builder time |

## 2. Habit rewards (per completion)
| Difficulty | XP | Gold |
|---|---|---|
| Easy | 10 | 5 |
| Medium | 20 | 10 |
| Hard | 35 | 18 |
| Epic | 60 | 30 |

- **Once-per-day rule:** a habit pays out once per calendar day (device local time). A completion is stored as `(habitId, dateKey)` with a unique key, so a double tap or re-open cannot pay twice.
- **Undo:** unchecking on the same day reverses that habit's XP/gold. Reverse can never push XP below the start of the current level (no level loss).
- **Not-due days:** a habit not scheduled today cannot be completed for rewards.
- **Anti-abuse:** max 20 active habits; rewards use the difficulty chosen at creation; changing difficulty applies from the next day.

## 3. Streak
- A day counts if **at least one scheduled habit** is completed.
- **Streak multiplier** on habit XP: +5% per full 7 days, capped at +25% (reached at 35 days).
- **Streak Freeze:** protects one missed day. Costs 150 gold, max 2 held. Used automatically.
- Longest streak and the full calendar history are always kept; a broken streak resets only the current counter.

| Milestone | Gold | Gems | Extra |
|---|---|---|---|
| 7 days | 50 | 2 | |
| 14 days | 100 | 3 | |
| 30 days | 300 | 10 | title "Steadfast" |
| 60 days | 600 | 20 | Rare chest |
| 100 days | 1000 | 50 | Legendary chest, title "Unbreakable" |

Milestones pay once per streak run record (reaching 30 again after a break does not repay it).

## 4. Levels and XP curve
XP needed to go from level n to n+1: `cost(n) = round5(20 * n^1.2)`, levels 1 to 100.

| Level | Cumulative XP | Approx. time at 130 XP/day |
|---|---|---|
| 2 | 20 | instant (onboarding hook) |
| 5 | 245 | 2 days |
| 10 | 1,285 | 10 days |
| 20 | 6,255 | 1.6 months |
| 35 | 21,955 | 5.6 months |
| 55 | 60,065 | 15 months |
| 80 | 137,835 | 35 months |
| 100 | 225,835 | 57 months (~4.7 years) |

Level-up reward: `10 * level` gold; every 5th level also 5 gems. A level-up animation and notification fire on each.

## 5. Ranks
| Rank | Levels | Reward on reaching | Typical time |
|---|---|---|---|
| E | 1-9 | start | day 1 |
| D | 10-19 | 25 gems, Wooden chest | ~10 days |
| C | 20-34 | 25 gems, Silver chest, title | ~1.6 months |
| B | 35-54 | 40 gems, Silver chest | ~5.6 months |
| A | 55-79 | 60 gems, Golden chest | ~15 months |
| S | 80-99 | 100 gems, Golden chest | ~35 months |
| National Level | 100 | 200 gems, Legendary chest, unique title | ~57 months |

A rank can never be skipped or bought; it derives only from level.

## 6. Quests
| Type | Resets | Example | Reward |
|---|---|---|---|
| Daily (3 per day) | local midnight | complete 3 habits; finish a Hard habit; log before noon | 40 XP, 30 gold each |
| Daily bonus | - | all 3 dailies done | Wooden chest |
| Weekly (2 per week) | Monday 00:00 | 5 active days; 20 habit completions | 200 XP, 150 gold, 5 gems |
| Special | never (one-time) | 30-day challenge; 100 completions of one habit | 1000 XP, 600 gold, 25 gems, Epic chest |

Quest progress is derived from completion records, so it stays correct after undo.

## 7. Buildings and the Builder
- Upgrade cost: `cost(L) = round10(100 * 1.6^(L-1))` gold for the building's next level L.
- Max level of any building is capped by **Keep level**; Keep level is gated by player level (Keep L = player level 5L).
- **Builder time:** each upgrade needs 1-5 *work days*. A work day only advances on a day with at least one completed habit, so the Builder "hammers" only when the player does real work. Gems can skip remaining days (1 gem per day).
- Builder's Hut level sets parallel upgrades (1 at L1, 2 at L5, 3 at L10).
- Building effects (first pass): Keep unlocks tiers; Treasury raises gold bonus (+2% per level); Laboratory unlocks magic items; Army Camp raises the number of active companions; Clan Castle slot for a hero; Shop unlocks stock tiers; Magic Items unlocks consumables.

## 8. Shop and characters
| Rarity | Gold price | Gem price |
|---|---|---|
| Common | 200 | - |
| Rare | 600 | - |
| Epic | 1,500 | 30 |
| Legendary | - | 150 |

- Items: character skins, weapons/accessories, titles, backgrounds/colors, and **custom rewards** the user defines (a real-life treat with their own gold price).
- A purchase is atomic: balance check, deduct, grant, inventory write in one transaction. Insufficient funds shows the missing amount.

## 9. Chests
| Chest | Gold | Gems | Character/item chance |
|---|---|---|---|
| Wooden | 50-100 | 0-1 | 5% Common |
| Silver | 150-300 | 1-3 | 10% Rare, 25% Common |
| Golden | 400-800 | 3-8 | 15% Epic, 30% Rare |
| Legendary | 1000-2000 | 10-25 | 25% Legendary, 40% Epic |

Duplicate characters convert to gold at 50% of the shop price.

## 10. Data model (local storage)
- `PlayerProfile`: name, totalXp, gold, gems, createdAt, settings, equippedCharacterId.
- `Habit`: id, title, description, difficulty, schedule (daily | weekdays[] | custom), reminderTime, archived.
- `Completion`: id, habitId, dateKey (`YYYY-MM-DD`), xpAwarded, goldAwarded; unique(habitId, dateKey).
- `StreakState`: current, longest, freezesHeld, lastCountedDateKey, milestonesClaimed[].
- `QuestInstance`: id, templateId, type, periodKey, progress, claimed.
- `BuildingState`: buildingId, level, upgrade{targetLevel, workDaysLeft}.
- `InventoryItem`: itemId, owned, equipped.
- `Achievement`: id, unlockedAt.
- Level, rank and quest progress are **derived** from totalXp and completions, never stored separately.
- Backup: JSON export of all tables with a `schemaVersion`; restore validates the version then replaces data.

## 11. Open decisions for you
1. Is the early pace (rank D in ~10 days) right, or should the first ranks be slower?
2. Builder work days: keep "advances only on active days", or use a plain timer?
3. Should a missed day with no freeze reset the streak fully, or halve it?
4. Day boundary: midnight, or a user-chosen hour (for night owls)?
