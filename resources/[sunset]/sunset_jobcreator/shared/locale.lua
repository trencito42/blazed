SunsetJobCreator = SunsetJobCreator or {}

SunsetJobCreator.Locale = {
    creator_title = 'Job Creator',
    shift_default = 'Work Shift',
    press_key = 'Press {key}',
    no_session = 'No active work session.',
    wrong_job = 'You are not employed for this job.',
    already_working = 'Already on a work shift.',
    job_not_found = 'Job definition not found.',
    job_disabled = 'This job is not available.',
    not_admin = 'Admin level 3+ required.',
    saved = 'Job saved.',
    published = 'Job published.',
    placement_hint = 'Walk to position — ENTER confirm · BACKSPACE cancel · SCROLL rotate',
    placement_saved = 'Location saved.',
    interact_far = 'Get closer to the marker.',
    shift_complete = 'Shift complete.',
    shift_failed = 'Shift failed.',
    shift_cancelled = 'Shift cancelled.',
}

function SunsetJobCreator.L(key)
    return SunsetJobCreator.Locale[key] or key
end
