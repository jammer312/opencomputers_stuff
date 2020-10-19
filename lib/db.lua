local serialization = require"serialization"

local db = {}
local PREFIX = "/database/"
local POSTFIX = ".db"

local cached_databases = {}

--stores all databases entirely in memory, might be way too crude for big dbs

function db.load(dbname, verbose)
  verbose = verbose or 0
  if not dbname or type(dbname) ~= "string" or string.find(dbname, "[\\.'\"]") then
    print("Db.load: invalid dbname!")
    return
  end
  if verbose > 0 then
    print("Using database", dbname)
  end
  if not cached_databases[dbname] then
    local _, _, dbpath = string.find(dbname, "^(.*)/")
    dbpath = dbpath or ""
    os.execute("mkdir \"" .. PREFIX .. dbpath .. "\" 2>/dev/null") --2>/dev/null to supress "directory already exists"
    local dbfile, reason = io.open(PREFIX .. dbname .. POSTFIX, "r")
    if not dbfile then
      if reason ~= "file not found" then error(reason) end
      if verbose > 0 then print("Creating database file...") end
      dbfile, reason = io.open(PREFIX .. dbname .. POSTFIX, "w")
      if not dbfile then error(reason) end
      dbfile:close()
      dbfile, reason = io.open(PREFIX .. dbname ..POSTFIX, "r")
      if not dbfile then error(reason) end
    end
    if verbose > 0 then
      print("Loading database from file...")
    end
    local loaded = {}
    for L in dbfile:lines() do
      local _, _, key, val = L:find("^(.-) = (.+)$")
      if not key then print("Malformed db entry:", L) end
      val = serialization.unserialize(val)
      loaded[key] = val
      if verbose > 1 then print(key .. ":", val) end
    end
    dbfile:close()
    cached_databases[dbname] = loaded
    dbfile, reason = io.open(PREFIX .. dbname .. POSTFIX, "a")
    if not dbfile then error("Failed to open " .. dbname .. " database for appending: " .. reason) end
    local function update_db(tbl, entry, value)
      rawset(tbl, entry, value)
      value = serialization.serialize(value)
      dbfile:write(entry .. " = " .. value .. "\n")
      dbfile:flush()
      if verbose > 0 then print(dbname .. ": new entry: " .. entry .. " = " .. value) end
    end
    setmetatable(cached_databases[dbname], {__newindex = update_db})
  end
  return cached_databases[dbname]
end

return db