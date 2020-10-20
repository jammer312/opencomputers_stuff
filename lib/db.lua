local serialization = require"serialization"

local db = {}
local PREFIX = "/database/"
local POSTFIX = ".db"
local BACKUP_POSTFIX = ".db_bac"
local FAILED_POSTFIX = ".db_corrupted"

local cached_databases = {}

--[[
  stores all databases entirely in memory, might be way too crude for big dbs

  doesn't automatically update existing entries when they're modified;
  need to call it (as function) to regenerate db file (and it's kinda expensive)

  TODO: make improved db manager that can quickly partially modify files instead of fully regenerating them
]]--
function db.load(dbname, verbose)
  verbose = verbose or 0
  if not dbname or type(dbname) ~= "string" or string.find(dbname, "[\\.'\"]") then
    print("db.load: invalid dbname!")
    return
  end
  if verbose > 0 then
    print("Using database", dbname)
  end
  if not cached_databases[dbname] then
    local _, _, dbpath = string.find(dbname, "^(.*)/")
    dbpath = dbpath or ""
    os.execute("mkdir \"" .. PREFIX .. dbpath .. "\" 2>/dev/null") --2>/dev/null to supress "directory already exists"


    --[[
      tries to open backup instead of actual db
      such backup should exist if and only if dbfile regeneration failed for whatever reason (power failure etc)
      so if it exists it loads backup db file instead of actual db file (which is most probably corrupted)
    ]]--

    local dbfile, reason = io.open(PREFIX .. dbname .. BACKUP_POSTFIX, "r")
    if dbfile then
      dbfile:close()
      print("Backup db file found, ignoring non-backup one (if present) due to possible corruption:", dbname)
      -- also replace old corrupted db file with new one (if any) for potential manual inspection
      os.remove(PREFIX .. dbname .. FAILED_POSTFIX) --not sure if it's needed there, but I guess it won't harm
      os.rename(PREFIX .. dbname .. POSTFIX, PREFIX .. dbname .. FAILED_POSTFIX)
      os.rename(PREFIX .. dbname .. BACKUP_POSTFIX, PREFIX .. dbname .. POSTFIX)
    else
      if reason ~= "file not found" then error(reason) end
    end

    dbfile, reason = io.open(PREFIX .. dbname .. POSTFIX, "r")
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
      if not key then
        if verbose > 0 then print("Ignoring malformed db entry:", L) end
      else
        val = serialization.unserialize(val)
        loaded[key] = val
        if verbose > 1 then print(key .. ":", val) end
      end
    end

    dbfile:close()
    cached_databases[dbname] = loaded
    dbfile, reason = io.open(PREFIX .. dbname .. POSTFIX, "a")
    if not dbfile then error("Failed to open " .. dbname .. " database for appending: " .. reason) end

    local function update_db_new_index(tbl, entry, value)
      rawset(tbl, entry, value)
      value = serialization.serialize(value)
      dbfile:write(entry .. " = " .. value .. "\n")
      dbfile:flush()
      if verbose > 0 then print(dbname .. ": new entry: " .. entry .. " = " .. value) end
    end

    local function regenerate_db_file(tbl)
      dbfile:close()
      os.rename(PREFIX .. dbname .. POSTFIX, PREFIX .. dbname .. BACKUP_POSTFIX) --keep it as backup in case bad things happen
      dbfile, reason = io.open(PREFIX .. dbname .. POSTFIX, "a")
      if not dbfile then error("Failed to open " .. dbname .. " database for appending: " .. reason) end

      for k, v in pairs(tbl) do
        v = serialization.serialize(v)
        dbfile:write(k .. " = " .. v .. "\n")
      end
      dbfile:flush()
      os.remove(PREFIX .. dbname .. BACKUP_POSTFIX) --remove backup because regeneration finished correctly
    end

    setmetatable(cached_databases[dbname], {__newindex = update_db_new_index, __call = regenerate_db_file})
  end
  return cached_databases[dbname]
end

return db