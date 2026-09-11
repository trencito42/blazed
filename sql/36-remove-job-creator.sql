-- Job Creator was retired in favour of the audited, hand-authored civilian jobs.
-- Keep this migration for existing installations; clean installations never
-- create these obsolete tables because migration 28 was removed.
DROP TABLE IF EXISTS `jc_job_logs`;
DROP TABLE IF EXISTS `jc_jobs`;
