local promise = promise
local Await = Citizen.Await
local resourceName = GetCurrentResourceName()
local GetResourceState = GetResourceState

local options = {
	return_callback_errors = false
}

for i = 1, GetNumResourceMetadata(resourceName, 'mysql_option') do
	local option = GetResourceMetadata(resourceName, 'mysql_option', i - 1)
	options[option] = true
end

local function await(fn, query, parameters)
	local p = promise.new()

	fn(nil, query, parameters, function(result, error)
		if error then
			return p:reject(error)
		end

		p:resolve(result)
	end, resourceName, true)

	return Await(p)
end

local type = type
local queryStore = {}

local function safeArgs(query, parameters, cb, transaction)
	local queryType = type(query)

	if queryType == 'number' then
		query = queryStore[query]
		assert(query, "First argument received invalid query store reference")
	elseif transaction then
		if queryType ~= 'table' then
			error(("First argument expected table, received '%s'"):format(query))
		end
	elseif queryType ~= 'string' then
		error(("First argument expected string, received '%s'"):format(query))
	end

	if parameters then
		local paramType = type(parameters)

		if paramType ~= 'table' and paramType ~= 'function' then
			error(("Second argument expected table or function, received '%s'"):format(parameters))
		end

		if paramType == 'function' or parameters.__cfx_functionReference then
			cb = parameters
			parameters = nil
		end
	end

	if cb and parameters then
		local cbType = type(cb)

		if cbType ~= 'function' and (cbType == 'table' and not cb.__cfx_functionReference) then
			error(("Third argument expected function, received '%s'"):format(cb))
		end
	end

	return query, parameters, cb
end

local oxmysql = exports.oxmysql

local mysql_method_mt = {
	__call = function(self, query, parameters, cb)
		query, parameters, cb = safeArgs(query, parameters, cb, self.method == 'transaction')
		return oxmysql[self.method](nil, query, parameters, cb, resourceName, options.return_callback_errors)
	end
}

local MySQL = setmetatable(MySQL or {}, {
	__index = function(_, index)
		return function(...)
			return oxmysql[index](nil, ...)
		end
	end
})

for _, method in pairs({
	'scalar', 'single', 'query', 'insert', 'update', 'prepare', 'transaction', 'rawExecute',
}) do
	MySQL[method] = setmetatable({
		method = method,
		await = function(query, parameters)
			query, parameters = safeArgs(query, parameters, nil, method == 'transaction')
			return await(oxmysql[method], query, parameters)
		end
	}, mysql_method_mt)
end

local alias = {
	fetchAll = 'query',
	fetchScalar = 'scalar',
	fetchSingle = 'single',
	insert = 'insert',
	execute = 'update',
	transaction = 'transaction',
	prepare = 'prepare'
}

local alias_mt = {
	__index = function(self, key)
		if alias[key] then
			local method = MySQL[alias[key]]
			MySQL.Async[key] = method
			MySQL.Sync[key] = method.await
			alias[key] = nil
			return self[key]
		end
	end
}

local function addStore(query, cb)
	assert(type(query) == 'string', 'The SQL Query must be a string')

	local storeN = #queryStore + 1
	queryStore[storeN] = query

	return cb and cb(storeN) or storeN
end

MySQL.Sync = setmetatable({ store = addStore }, alias_mt)
MySQL.Async = setmetatable({ store = addStore }, alias_mt)

local function onReady(cb)
	while GetResourceState('oxmysql') ~= 'started' do
		Wait(50)
	end

	oxmysql.awaitConnection()

	return cb and cb() or true
end

MySQL.ready = setmetatable({
	await = onReady
}, {
	__call = function(_, cb)
		Citizen.CreateThreadNow(function() onReady(cb) end)
	end,
})

-- oxmysql's transaction export passes a single callable query function to Lua.
-- The framework historically used the same typed helpers exposed by MySQL
-- (query.await, single.await, update.await and insert.await) inside transaction
-- callbacks.  Adapt the raw transaction result here so every resource uses the
-- transaction connection while retaining the normal oxmysql return contracts.
--
-- [CRITICAL FIX] The JS side (startTransaction -> runQuery -> conn.query)
-- returns a PROMISE resolving to the mysql2 tuple `[rows, fields]`. The
-- previous adapter neither awaited the promise nor unwrapped the tuple, so
-- every transactional UPDATE returned nil -> `tonumber(nil) ~= 1` -> rollback.
-- That broke refueling ("Payment failed"), dealership purchases, crafting,
-- fisherman sells, tuning saves and trades. Always Citizen.Await + unwrap.
local CitizenAwait = Citizen.Await

local function runRaw(rawQuery, sql, values)
	local result = rawQuery(sql, values)
	-- If the bridge handed back an un-awaited promise (older/newer runtimes),
	-- resolve it. A real Cfx promise is identifiable by __cfx_promise or a
	-- callable .next; a plain result table (OkPacket / row array) is not.
	if type(result) == 'table' and result.__cfx_promise ~= nil then
		result = CitizenAwait(result)
	elseif type(result) == 'table' and type(result.next) == 'function' and result.affectedRows == nil and result[1] == nil then
		result = CitizenAwait(result)
	end
	return result
end

local function unwrap(raw)
	-- JS resolves [rows, fields]; rows is the OkPacket (UPDATE/INSERT) or the
	-- row array (SELECT). When await returns the marshaled tuple, payload = [1].
	if type(raw) == 'table' and raw[1] ~= nil and raw.affectedRows == nil and raw.insertId == nil then
		return raw[1]
	end
	return raw
end

local function transactionResult(kind, raw)
	local result = unwrap(raw)

	if kind == 'single' then
		if type(result) ~= 'table' then return nil end
		return result[1]
	end

	if kind == 'scalar' then
		if type(result) ~= 'table' then return nil end
		local row = result[1]
		if type(row) ~= 'table' then return nil end
		local _, value = next(row)
		return value
	end

	if kind == 'update' then
		return type(result) == 'table' and tonumber(result.affectedRows) or nil
	end

	if kind == 'insert' then
		return type(result) == 'table' and tonumber(result.insertId) or nil
	end

	return result
end

local function inferTransactionKind(sql)
	local verb = type(sql) == 'string' and sql:match('^%s*(%a+)')
	verb = verb and verb:upper() or ''
	if verb == 'INSERT' or verb == 'REPLACE' then return 'insert' end
	if verb == 'UPDATE' or verb == 'DELETE' then return 'update' end
	return 'query'
end

local function transactionAdapter(rawQuery)
	local adapter = {}

	adapter.await = function(sql, values)
		return transactionResult(inferTransactionKind(sql), runRaw(rawQuery, sql, values))
	end
	adapter.query = { await = function(sql, values)
		return transactionResult('query', runRaw(rawQuery, sql, values))
	end }
	adapter.single = { await = function(sql, values)
		return transactionResult('single', runRaw(rawQuery, sql, values))
	end }
	adapter.scalar = { await = function(sql, values)
		return transactionResult('scalar', runRaw(rawQuery, sql, values))
	end }
	adapter.update = { await = function(sql, values)
		return transactionResult('update', runRaw(rawQuery, sql, values))
	end }
	adapter.insert = { await = function(sql, values)
		return transactionResult('insert', runRaw(rawQuery, sql, values))
	end }

	return setmetatable(adapter, {
		__call = function(_, sql, values)
			return rawQuery(sql, values)
		end,
	})
end

function MySQL.startTransaction(cb)
	assert(type(cb) == 'function', 'MySQL.startTransaction expects a callback')
	return oxmysql:startTransaction(function(rawQuery)
		return cb(transactionAdapter(rawQuery))
	end, resourceName)
end

_ENV.MySQL = MySQL
