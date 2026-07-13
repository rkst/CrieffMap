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

-- Verbose diagnostics, toggled by `/cmap debug` and persisted in the char DB so
-- it survives a `/reload` (the login race we most want to observe only happens
-- at load). When on, the apply path narrates which frame it picked, which branch
-- it took, and reads the anchor back a frame later to catch another addon
-- snapping the minimap away after we move it.
function CrieffMap.IsDebug()
    return CrieffMap.db and CrieffMap.db.debug
end

function CrieffMap.Debug(msg)
    if CrieffMap.IsDebug() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff5dade2CrieffMap|r |cff999999dbg|r " .. tostring(msg))
    end
end

-- Human-readable frame identity / anchor, for the diagnostics above.
local function FrameLabel(f)
    if not f then return "nil" end
    return f:GetName() or tostring(f)
end

local function PointLabel(f)
    if not f then return "nil frame" end
    local point, relativeTo, relPoint, x, y = f:GetPoint()
    if not point then return "no anchor" end
    return string.format("%s -> %s.%s (%.0f, %.0f)",
        point, FrameLabel(relativeTo), relPoint or "?", x or 0, y or 0)
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
        CrieffMap.Debug("captured original on " .. FrameLabel(target) .. ": " .. PointLabel(target))
    else
        CrieffMap.Debug("capture skipped: " .. FrameLabel(target) .. " has no anchor yet")
    end
end

-- Restore the minimap to the anchor we captured at login.
function CrieffMap.RestoreOriginal()
    local o = CrieffMap.original
    -- o[1] (point) may be missing if GetPoint() returned nothing at capture.
    if not o or not o[1] then
        CrieffMap.Debug("RestoreOriginal: nothing captured, no-op")
        return
    end
    local target = CrieffMap.GetTarget()
    target:ClearAllPoints()
    target:SetPoint(o[1], o[2] or UIParent, o[3], o[4], o[5])
    CrieffMap.Debug("RestoreOriginal on " .. FrameLabel(target) .. " -> " .. PointLabel(target))
end

-- Move the minimap to the saved preset. No-op if nothing has been set yet.
function CrieffMap.MoveToPreset()
    local p = CrieffMap.db and CrieffMap.db.preset
    if not p then
        CrieffMap.Debug("MoveToPreset: no preset set, no-op")
        return
    end
    local target = CrieffMap.GetTarget()
    target:ClearAllPoints()
    target:SetPoint(p.point, p.relativeTo or UIParent, p.relPoint, p.x, p.y)
    CrieffMap.Debug("MoveToPreset on " .. FrameLabel(target) .. " -> " .. PointLabel(target))
end

-- Decide where the minimap belongs for the current zone and put it there.
function CrieffMap.ApplyPosition()
    CrieffMap.CaptureOriginal()
    local inInstance = IsInInstance()
    CrieffMap.Debug(string.format("ApplyPosition: inInstance=%s target=%s",
        tostring(inInstance), FrameLabel(CrieffMap.GetTarget())))
    if inInstance then
        CrieffMap.RestoreOriginal()
    else
        CrieffMap.MoveToPreset()
    end
    -- Read the anchor back next frame: if it differs from what we just set, some
    -- other addon (or a deferred Blizzard/EllesmereUI reapply) is overriding us.
    if CrieffMap.IsDebug() then
        C_Timer.After(0, function()
            CrieffMap.Debug("settled: " .. PointLabel(CrieffMap.GetTarget()))
        end)
    end
end

CrieffMap:RegisterEvent("ADDON_LOADED", function(loaded)
    if loaded ~= addonName then return end
    CrieffMapCharDB = CrieffMapCharDB or {}
    CrieffMap.db = CrieffMapCharDB
end)

-- Re-assert our position by polling across the transition settle window, not with
-- a single next-frame apply.
--
-- Why: both Blizzard's load sequence and minimap-replacement addons re-anchor the
-- minimap on their own deferred timers at a moment we can't predict. EllesmereUI
-- in particular positions the minimap on its *first activation*, and that
-- activation re-runs on every /reload (its `active` guard lives in a Lua table
-- that resets with the UI), firing a deferred SetPoint back to its configured
-- spot. A busy zone pushes that re-anchor out further: in a capital city
-- (Silvermoon) it lands over a second after the event -- past any fixed deadline
-- we'd hardcode. Debug proved this: five taps out to 1.0s each set *and* read back
-- BOTTOM, then the map still ended at CENTER because the clobber came later.
--
-- We can't win a race against a timer we don't own, and we can't stop early on
-- "looks stable" either -- the position looks settled right up until that single
-- late clobber fires. But the clobber is one-shot per transition (a manual
-- `/cmap apply` holds indefinitely), so we simply outlast it: re-apply densely for
-- a few seconds and correct any drift within one tick. ApplyPosition is idempotent
-- -- CaptureOriginal is guarded to run once, MoveToPreset/RestoreOriginal just
-- re-set the same anchor, and IsInInstance() is read fresh each tick -- so the
-- repeated taps are harmless and a late tick still resolves the current zone.
-- WATCH_TICKS * WATCH_INTERVAL must exceed the slowest transition's re-anchor;
-- if a revert is ever seen later than that window, raise WATCH_TICKS.
local WATCH_INTERVAL = 0.2   -- seconds between re-asserts
local WATCH_TICKS    = 25    -- ~5s of polling after each transition

local watchTicker
local function StartWatch()
    -- A fresh transition restarts the poll so tickers don't stack across zones.
    if watchTicker then watchTicker:Cancel() end
    CrieffMap.ApplyPosition()   -- immediate assert (also captures original once)
    watchTicker = C_Timer.NewTicker(WATCH_INTERVAL, CrieffMap.ApplyPosition, WATCH_TICKS)
end

-- Primary trigger: fires on login, on every instance transition, and on /reload.
CrieffMap:RegisterEvent("PLAYER_ENTERING_WORLD", StartWatch)

-- Catches outdoor world transitions that don't reload the world.
CrieffMap:RegisterEvent("ZONE_CHANGED_NEW_AREA", StartWatch)

-- One-shot snapshot of everything that decides where the minimap lands. This is
-- the first thing to check when it "stopped moving": it tells you whether an
-- addon reparented the minimap (so GetTarget picks the right frame), whether the
-- game thinks we're in an instance, and what we captured/saved.
function CrieffMap.PrintStatus()
    local _, instanceType = IsInInstance()
    local mmParent = Minimap and Minimap:GetParent()
    local target = CrieffMap.GetTarget()
    local euiLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
        and C_AddOns.IsAddOnLoaded("EllesmereUIMinimap")
    local o = CrieffMap.original

    CrieffMap:Print("status:")
    CrieffMap:Print("  EllesmereUIMinimap loaded: " .. tostring(euiLoaded))
    CrieffMap:Print("  Minimap parent: " .. FrameLabel(mmParent)
        .. (mmParent == MinimapCluster and " (cluster)" or " (detached)"))
    CrieffMap:Print("  GetTarget -> " .. FrameLabel(target))
    CrieffMap:Print(string.format("  IsInInstance: %s (%s)",
        tostring(IsInInstance()), instanceType or "none"))
    CrieffMap:Print(string.format("  MinimapCluster: shown=%s alpha=%.2f",
        tostring(MinimapCluster and MinimapCluster:IsShown()),
        MinimapCluster and MinimapCluster:GetAlpha() or -1))
    CrieffMap:Print("  target anchor: " .. PointLabel(target))
    CrieffMap:Print("  captured original: " .. (o and o[1] and
        string.format("%s (%s, %.0f, %.0f)", o[1], o[3] or "?", o[4] or 0, o[5] or 0) or "none"))
    CrieffMap:Print("  saved preset: " .. (CrieffMap.db and CrieffMap.db.preset and
        string.format("%s (%s, %.0f, %.0f)", CrieffMap.db.preset.point,
            CrieffMap.db.preset.relPoint or "?", CrieffMap.db.preset.x or 0,
            CrieffMap.db.preset.y or 0) or "none"))
    CrieffMap:Print("  debug logging: " .. (CrieffMap.IsDebug() and "on" or "off"))
end

local function HandleSlash(arg)
    arg = arg and strtrim(arg):lower() or ""
    if arg == "drag" then
        CrieffMap.Mover:Start()
    elseif arg == "reset" then
        CrieffMap.db.preset = nil
        CrieffMap.ApplyPosition()
        CrieffMap:Print("preset cleared.")
    elseif arg == "status" then
        CrieffMap.PrintStatus()
    elseif arg == "debug" then
        CrieffMap.db.debug = not CrieffMap.db.debug
        CrieffMap:Print("debug logging " .. (CrieffMap.db.debug and "on" or "off")
            .. " (persists across /reload).")
    elseif arg == "apply" then
        CrieffMap:Print("re-applying position for the current zone.")
        CrieffMap.ApplyPosition()
    else
        CrieffMap:Print("|cffffff00/cmap drag|r set the outdoor spot, |cffffff00/cmap reset|r clear it, |cffffff00/cmap status|r diagnostics, |cffffff00/cmap debug|r toggle verbose logging, |cffffff00/cmap apply|r re-run positioning.")
    end
end

SLASH_CRIEFFMAP1 = "/cmap"
SLASH_CRIEFFMAP2 = "/crieffmap"
SlashCmdList["CRIEFFMAP"] = HandleSlash
