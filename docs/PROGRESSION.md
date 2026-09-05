# Character progression

SunsetMP uses classic SA:MP RPG progression. Every hourly payday awards one Respect Point (RP), independently of civilian job skill XP. The character remains at the current level until the player uses `/buylevel` or the button in `M -> Statistics`.

The RP requirement is `current level * 4`; the money cost is `current level * $2,500`. Both values are server-authoritative and shown before purchase. Job-specific experience and levels remain stored separately in `job_progress` and are not spent on character levels.

Migration `14-respect-progression.sql` converts historical account playtime to one RP per completed hour exactly once, so existing players retain the progression earned before this system was introduced.
