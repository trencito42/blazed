local JobCache = {}
local Published = {}

function JCStorage_EnsureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS jc_jobs (
            id VARCHAR(48) NOT NULL PRIMARY KEY,
            label VARCHAR(96) NOT NULL,
            description TEXT,
            category VARCHAR(48) NOT NULL DEFAULT 'civilian',
            icon VARCHAR(64) NOT NULL DEFAULT 'briefcase',
            status ENUM('draft', 'published', 'disabled') NOT NULL DEFAULT 'draft',
            definition JSON NOT NULL,
            version INT NOT NULL DEFAULT 1,
            created_by VARCHAR(64) DEFAULT NULL,
            updated_by VARCHAR(64) DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_jc_jobs_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS jc_job_logs (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            job_id VARCHAR(48) NOT NULL,
            character_id INT UNSIGNED DEFAULT NULL,
            action VARCHAR(48) NOT NULL,
            detail VARCHAR(255) DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_jc_logs_job (job_id),
            INDEX idx_jc_logs_char (character_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

local function decode(row)
    if not row then return nil end
    local def = row.definition
    if type(def) == 'string' then
        def = json.decode(def)
    end
    return {
        id = row.id,
        label = row.label,
        description = row.description,
        category = row.category,
        icon = row.icon,
        status = row.status,
        version = row.version,
        definition = def,
        updatedAt = row.updated_at,
    }
end

function JCStorage_Log(jobId, characterId, action, detail)
    MySQL.insert.await(
        'INSERT INTO jc_job_logs (job_id, character_id, action, detail) VALUES (?, ?, ?, ?)',
        { jobId, characterId, action, detail }
    )
end

function JCStorage_LoadAll()
    JobCache = {}
    Published = {}
    local rows = MySQL.query.await('SELECT * FROM jc_jobs') or {}
    for _, row in ipairs(rows) do
        local job = decode(row)
        if job then
            JobCache[job.id] = job
            if job.status == 'published' then
                Published[job.id] = job
            end
        end
    end
    return JobCache
end

function JCStorage_Get(jobId)
    return JobCache[jobId]
end

function JCStorage_GetPublished()
    return Published
end

function JCStorage_List()
    local list = {}
    for _, job in pairs(JobCache) do
        list[#list + 1] = {
            id = job.id,
            label = job.label,
            description = job.description,
            category = job.category,
            icon = job.icon,
            status = job.status,
            version = job.version,
            stageCount = #(job.definition and job.definition.stages or {}),
            updatedAt = job.updatedAt,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

function JCStorage_Save(jobId, meta, definition, actor)
    local ok, errors = SunsetJobCreator.ValidateDefinition(definition)
    if not ok then return nil, table.concat(errors, ' ') end

    local encoded = json.encode(definition)
    local existing = JobCache[jobId]
    if existing then
        MySQL.update.await([[
            UPDATE jc_jobs SET label = ?, description = ?, category = ?, icon = ?, status = ?, definition = ?,
                version = version + 1, updated_by = ? WHERE id = ?
        ]], {
            meta.label, meta.description, meta.category, meta.icon, meta.status or existing.status,
            encoded, actor, jobId,
        })
    else
        MySQL.insert.await([[
            INSERT INTO jc_jobs (id, label, description, category, icon, status, definition, created_by, updated_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            jobId, meta.label, meta.description, meta.category, meta.icon,
            meta.status or 'draft', encoded, actor, actor,
        })
    end
    JCStorage_LoadAll()
    JCStorage_Log(jobId, nil, existing and 'updated' or 'created', actor)
    return JCStorage_Get(jobId)
end

function JCStorage_SetStatus(jobId, status, actor)
    if not JobCache[jobId] then return nil, 'Job not found.' end
    if status == 'published' then
        local ok, errors = SunsetJobCreator.ValidateDefinition(JobCache[jobId].definition)
        if not ok then return nil, table.concat(errors, ' ') end
    end
    MySQL.update.await('UPDATE jc_jobs SET status = ?, updated_by = ? WHERE id = ?', { status, actor, jobId })
    JCStorage_LoadAll()
    JCStorage_Log(jobId, nil, 'status_' .. status, actor)
    return JCStorage_Get(jobId)
end

function JCStorage_Delete(jobId, actor)
    if not JobCache[jobId] then return false end
    MySQL.update.await('DELETE FROM jc_jobs WHERE id = ?', { jobId })
    JCStorage_LoadAll()
    JCStorage_Log(jobId, nil, 'deleted', actor)
    return true
end

function JCStorage_Export(jobId)
    local job = JobCache[jobId]
    if not job then return nil end
    return {
        id = job.id,
        label = job.label,
        description = job.description,
        category = job.category,
        icon = job.icon,
        definition = job.definition,
        exportVersion = 1,
    }
end

function JCStorage_Import(payload, actor, forceId)
    if type(payload) ~= 'table' or type(payload.definition) ~= 'table' then
        return nil, 'Invalid import payload.'
    end
    local jobId = forceId or SunsetJobCreator.NormalizeId(payload.id)
    if not jobId then return nil, 'Invalid job id.' end
    return JCStorage_Save(jobId, {
        label = payload.label or jobId,
        description = payload.description or '',
        category = payload.category or 'civilian',
        icon = payload.icon or 'briefcase',
        status = 'draft',
    }, payload.definition, actor)
end

function JCStorage_RegisterCivilianJobs()
    local migrated = SunsetJobCreator.LegacyMigrations or {}

    for jobId, job in pairs(Published) do
        local def = job.definition or {}
        Sunset.CivilianJobs[jobId] = {
            label = job.label,
            type = 'civilian',
            description = job.description or '',
            grades = { [0] = { label = 'Worker', salary = tonumber(def.salary) or 140, perms = {} } },
            creator = true,
        }
        Sunset.JobsConfig = Sunset.JobsConfig or {}
        Sunset.JobsConfig[jobId] = {
            label = job.label,
            help = job.description or 'Use /work to start your shift.',
            timeoutSec = tonumber(def.timeoutSec) or 1800,
            creator = true,
        }
    end

    for legacy, creatorId in pairs(migrated) do
        local creator = Published[creatorId]
        if creator then
            local def = creator.definition or {}
            local label = (creator.label or legacy):gsub(' %(Creator%)', ''):gsub(' %(creator%)', '')
            Sunset.CivilianJobs[legacy] = {
                label = label,
                type = 'civilian',
                description = creator.description or '',
                grades = { [0] = { label = 'Worker', salary = tonumber(def.salary) or 140, perms = {} } },
                creatorJob = creatorId,
            }
            Sunset.JobsConfig = Sunset.JobsConfig or {}
            Sunset.JobsConfig[legacy] = {
                label = label,
                help = creator.description or 'Use /work to start your shift.',
                timeoutSec = tonumber(def.timeoutSec) or 1800,
                creator = true,
                creatorJob = creatorId,
            }
        end
    end
end
