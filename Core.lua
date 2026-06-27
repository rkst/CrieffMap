-- CrieffMap — auto-reposition the minimap by zone type.
-- Outdoors: move MinimapCluster to a saved preset point.
-- In any instance (dungeon/raid/delve/scenario/arena/bg): restore the original anchor.

local addonName, ns = ...

CrieffMap = CrieffMap or {}
CrieffMap.name = addonName
CrieffMap.version = "0.1.0"
CrieffMap.events = {}

local frame = CreateFrame("Frame", "CrieffMapEventFrame")
CrieffMap.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = CrieffMap.events[event]
    if handler then
        handler(...)
    end
end)

function CrieffMap:RegisterEvent(event, handler)
    self.events[event] = handler
    frame:RegisterEvent(event)
end

function CrieffMap:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff5dade2CrieffMap|r: " .. tostring(msg))
end

-- Captured once, on the first PLAYER_ENTERING_WORLD, before we ever move the
-- cluster. Holds { point, relativeTo, relPoint, x, y } exactly as GetPoint() returns.
CrieffMap.original = nil

-- Restore MinimapCluster to the anchor we captured at login.
function CrieffMap.RestoreOriginal()
    local o = CrieffMap.original
    -- o[1] (point) may be missing if GetPoint() returned nothing at capture.
    if not o or not o[1] then return end
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint(o[1], o[2] or UIParent, o[3], o[4], o[5])
end

-- Move MinimapCluster to the saved preset. No-op if nothing has been set yet.
function CrieffMap.MoveToPreset()
    local p = CrieffMap.db and CrieffMap.db.preset
    if not p then return end
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint(p.point, p.relativeTo or UIParent, p.relPoint, p.x, p.y)
end

-- Decide where the minimap belongs for the current zone and put it there.
function CrieffMap.ApplyPosition()
    if IsInInstance() then
        CrieffMap.RestoreOriginal()
    else
        CrieffMap.MoveToPreset()
    end
end

-- Capture the live anchor before anything moves it. Guarded so it only runs
-- once we actually get a point back; a managed MinimapCluster can return nil
-- early, and capturing {} then would later blow up RestoreOriginal.
local function CaptureOriginal()
    if CrieffMap.original then return end
    if MinimapCluster:GetPoint() then
        CrieffMap.original = { MinimapCluster:GetPoint() }
    end
end

CrieffMap:RegisterEvent("ADDON_LOADED", function(loaded)
    if loaded ~= addonName then return end
    CrieffMapCharDB = CrieffMapCharDB or {}
    CrieffMap.db = CrieffMapCharDB
end)

-- Primary trigger: fires on login and on every instance transition.
-- Defer the apply to the next frame: Blizzard's Edit Mode also handles
-- PLAYER_ENTERING_WORLD and reapplies its layout, and if its handler runs
-- after ours it overwrites our SetPoint. Running on the next frame lands us last.
CrieffMap:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    CaptureOriginal()
    C_Timer.After(0, CrieffMap.ApplyPosition)
end)

-- Catches outdoor world transitions that don't reload the world.
CrieffMap:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    CrieffMap.ApplyPosition()
end)

local function HandleSlash(arg)
    arg = arg and strtrim(arg):lower() or ""
    if arg == "drag" then
        CrieffMap.Mover:Toggle()
    elseif arg == "reset" then
        CrieffMap.db.preset = nil
        CrieffMap.ApplyPosition()
        CrieffMap:Print("preset cleared.")
    else
        CrieffMap:Print("|cffffff00/cmap drag|r to set the outdoor spot (drag the minimap, then /cmap drag again), |cffffff00/cmap reset|r to clear it.")
    end
end

SLASH_CRIEFFMAP1 = "/cmap"
SLASH_CRIEFFMAP2 = "/crieffmap"
SlashCmdList["CRIEFFMAP"] = HandleSlash
