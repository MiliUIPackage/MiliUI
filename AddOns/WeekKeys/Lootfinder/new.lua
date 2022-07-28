LF = {}
LF.__index = LF
LF.tables = {}

function LF:New(tbl,db)
    tbl = tbl or {}
    tbl.db = db
    tbl.results = {}
    tbl.selectedstats = {}
    tbl.raids = {
        false,
        false,
        false,
        false,
        false,
    }

    tbl.instances = {
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    }

    return setmetatable(tbl, self)
end
