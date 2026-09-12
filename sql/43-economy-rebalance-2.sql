-- 43: Economy rebalance pass 2 (docs/product/RPG_PROGRESSION.md §4, audit economy review)
-- Crime paid 20-50x legal hourly income; this shrinks passive/illegal faucets
-- while code-side changes raised legal salaries and halved fence/carjack payouts.
-- IDEMPOTENT: UPDATEs use GREATEST floors and only shrink values above targets.

-- Turf passive income: 1500 -> 900 per payday per turf (clan endgame should be
-- prestige + moderate income, not a faucet that dwarfs salaries).
UPDATE `turfs` SET `payout` = 900 WHERE `payout` > 900;

-- Respect payout stays (progression currency, not money).
