-- CrieffMap — auto-reposition the minimap by zone type.
-- Outdoors: move the minimap to a saved preset point.
-- In any instance (dungeon/raid/delve/scenario/arena/bg): restore the original anchor.
--
-- "The minimap" means whatever frame currently governs the visible map. Normally
-- that is MinimapCluster (the Edit Mode frame). But UI-replacement addons such as
-- EllesmereUI detach the Minimap frame from the cluster, parent it to UIParent and
-- hide the cluster -- after that, moving the cluster does nothing. GetTarget()
-- resolves the correct frame at use time so we move what the player actually sees.

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

-- The frame whose anchor controls the visible minimap. See the header note:
-- when an addon detaches Minimap from MinimapCluster (parenting it elsewhere and
-- hiding the cluster), we must move the Minimap frame itself; otherwise the
-- cluster is the right handle. Resolved at use time so it tracks the live layout.
function CrieffMap.GetTarget()
    if Minimap and Minimap:GetParent() and Minimap:GetParent() ~= MinimapCluster then
        return Minimap
    end
    return MinimapCluster
end

-- Captured once, after the layout settles at login, before we ever move the
-- target. Holds { point, relativeTo, relPoint, x, y } exactly as GetPoint() returns.
CrieffMap.original = nil

-- Capture the live anchor before anything moves it. Guarded so it only runs
-- once we actually get a point back; a managed frame can return nil early, and
-- capturing {} then would later blow up RestoreOriginal.
function CrieffMap.CaptureOriginal()
    if CrieffMap.original then return end
    local target = CrieffMap.GetTarget()
    if target:GetPoint() then
        CrieffMap.original = { target:GetPoint() }
    end
end

-- Restore the minimap to the anchor we captured at login.
function CrieffMap.RestoreOriginal()
    local o = CrieffMap.original
    -- o[1] (point) may be missing if GetPoint() returned nothing at capture.
    if not o or not o[1] then return end
    local target = CrieffMap.GetTarget()
    target:ClearAllPoints()
    target:SetPoint(o[1], o[2] or UIParent, o[3], o[4], o[5])
end

-- Move the minimap to the saved preset. No-op if nothing has been set yet.
function CrieffMap.MoveToPreset()
    local p = CrieffMap.db and CrieffMap.db.preset
    if not p then return end
    local target = CrieffMap.GetTarget()
    target:ClearAllPoints()
    target:SetPoint(p.point, p.relativeTo or UIParent, p.relPoint, p.x, p.y)
end

-- Decide where the minimap belongs for the current zone and put it there.
function CrieffMap.ApplyPosition()
    CrieffMap.CaptureOriginal()
    if IsInInstance() then
        CrieffMap.RestoreOriginal()
    else
        CrieffMap.MoveToPreset()
    end
end

CrieffMap:RegisterEvent("ADDON_LOADED", function(loaded)
    if loaded ~= addonName then return end
    CrieffMapCharDB = CrieffMapCharDB or {}
    CrieffMap.db = CrieffMapCharDB
end)

-- Primary trigger: fires on login and on every instance transition.
-- Defer the apply (and the capture, which ApplyPosition does first) to the next
-- frame: both Blizzard's Edit Mode and minimap-replacement addons like EllesmereUI
-- reapply their layout on PLAYER_ENTERING_WORLD, some via their own C_Timer.After(0).
-- Running on the next frame lands us after they settle, so we capture the real
-- layout, GetTarget picks the right frame, and our SetPoint wins.
CrieffMap:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0, CrieffMap.ApplyPosition)
end)

-- Catches outdoor world transitions that don't reload the world.
CrieffMap:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    CrieffMap.ApplyPosition()
end)

local function HandleSlash(arg)
    arg = arg and strtrim(arg):lower() or ""
    if arg == "drag" then
        CrieffMap.Mover:Start()
    elseif arg == "reset" then
        CrieffMap.db.preset = nil
        CrieffMap.ApplyPosition()
        CrieffMap:Print("preset cleared.")
    else
        CrieffMap:Print("|cffffff00/cmap drag|r to set the outdoor spot (drag the minimap, then click Save), |cffffff00/cmap reset|r to clear it.")
    end
end

SLASH_CRIEFFMAP1 = "/cmap"
SLASH_CRIEFFMAP2 = "/crieffmap"
SlashCmdList["CRIEFFMAP"] = HandleSlash
