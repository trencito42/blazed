# LSSI licenses and instructor QA

## Player licenses

- Driving is a self-service theory and practical exam at Driving School.
- Pilot, boat and firearm exams require an on-duty LSSI instructor to authorize and supervise them.
- Every license expires after 150 completed paydays.
- The server validates the assigned test vehicle, driver seat, checkpoint order, positions, range targets and finish state.
- During pilot and boat practicals, the on-duty instructor must supervise from the assigned vehicle. During the firearm practical, the instructor must remain at the range until completion.

## Instructor workflow

1. Go on duty at LSSI HQ.
2. Meet the candidate at the relevant facility.
3. Use `/issuelicense [id] [pilot|boat|weapon]`.
4. During the practical, use `/lssimark [id] [0.5|1] [reason]` for an observed mistake.
5. Use `/lssiunmark [id]` to correct the most recent mark while the exam is active.

The practical fails at 3.0 candidate mistakes. The automatic validation and the instructor marks are stored together in the exam report.

## Management QA (rank 5+)

- `/lssireviews [pending|all]` lists completed reports.
- `/lssireport [report id]` displays the full report and recorded evidence.
- `/lssireview [report id] [mistakes] [approved|improve] [notes]` reviews the instructor. Instructor mistakes must be between 0 and 20 in 0.5 steps.
- `/lssiperformance [server id?]` displays reviewed tests, pending tests, verdicts, average mistakes and progress toward the next rank.

An instructor cannot review their own report. Unless they are the faction leader, reviewers cannot evaluate an instructor at their own or a higher rank. Reviews are immutable so a second reviewer cannot silently overwrite them.

## Rank-up requirements

LSSI promotions through faction commands and the faction roster are blocked until these QA thresholds are met:

| Target rank | Reviewed exams | Maximum average instructor mistakes |
| --- | ---: | ---: |
| 2 | 5 | 1.50 |
| 3 | 10 | 1.00 |
| 4 | 18 | 0.75 |
| 5 | 25 | 0.50 |
| 6 | 35 | 0.50 |
| 7 | 50 | 0.25 |

The thresholds live in `sunset_licenses/shared/config.lua`. Direct administrative faction assignment remains an explicit staff override.

## Database

Migration `sql/25-lssi-exam-reviews.sql` creates the persistent report, evidence, candidate marks and instructor review storage. Supervised tests refuse to start when their audit record cannot be created, preventing untracked licenses.
