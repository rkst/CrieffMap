-- CrieffMap.Mover — drag-to-set helper for the outdoor preset position.
-- `/cmap drag` enters a mode where you drag the minimap to where you want it
-- outdoors. A small overlay panel offers Save (commit the spot) and Cancel
-- (revert to the previous spot). The saved anchor goes to CrieffMapCharDB.preset.
--
-- We drag whatever frame currently controls the minimap (CrieffMap.GetTarget),
-- so this works whether the map lives in MinimapCluster or has been detached to
-- UIParent by an addon like EllesmereUI.

local Mover = {}
CrieffMap.Mover = Mover

Mover.active = false

-- Lazily-created instruction panel with Save / Cancel buttons, shown while
-- drag mode is active.
local function GetOverlay()
    if Mover.overlay then return Mover.overlay end

    local f = CreateFrame("Frame", "CrieffMapMoverOverlay", UIParent, "BackdropTemplate")
    f:SetSize(360, 96)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", f, "TOP", 0, -14)
    text:SetWidth(336)
    text:SetText("Drag the minimap to your preferred outdoor spot, then click |cffffff00Save|r.")
    text:SetJustifyH("CENTER")

    local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    save:SetSize(120, 24)
    save:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 12)
    save:SetText("Save")
    save:SetScript("OnClick", function() Mover:Save() end)

    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetSize(120, 24)
    cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 12)
    cancel:SetText("Cancel")
    cancel:SetScript("OnClick", function() Mover:Cancel() end)

    Mover.overlay = f
    return f
end

-- Leave drag mode: detach the drag scripts, restore the frame's prior mouse
-- state and hide the overlay. Does not itself decide the final position.
local function StopDragMode()
    local target = Mover.target
    if target then
        target:SetScript("OnDragStart", nil)
        target:SetScript("OnDragStop", nil)
        target:RegisterForDrag()
        -- Restore mouse interactivity to whatever it was (EllesmereUI, for one,
        -- keeps MinimapCluster mouse disabled; don't leave it enabled).
        if Mover.prevMouse ~= nil then target:EnableMouse(Mover.prevMouse) end
    end
    if Mover.overlay then Mover.overlay:Hide() end
    Mover.active = false
    Mover.target = nil
    Mover.prevMouse = nil
    Mover.prevPreset = nil
end

-- Enter drag mode. Remembers the current preset (for Cancel) and makes the live
-- minimap frame draggable.
function Mover:Start()
    if self.active then return end

    local target = CrieffMap.GetTarget()
    self.active = true
    self.target = target
    self.prevPreset = CrieffMapCharDB.preset
    self.prevMouse = target:IsMouseEnabled()

    target:SetMovable(true)
    target:EnableMouse(true)
    target:RegisterForDrag("LeftButton")
    target:SetScript("OnDragStart", function(self) self:StartMoving() end)
    target:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    GetOverlay():Show()
    CrieffMap:Print("drag the minimap, then click |cffffff00Save|r (or Cancel).")
end

-- Commit the current position as the outdoor preset.
function Mover:Save()
    if not self.active then return end
    local target = self.target or CrieffMap.GetTarget()
    local point, relativeTo, relPoint, x, y = target:GetPoint()
    -- Store relativeTo by name so it survives a /reload (StartMoving normally
    -- anchors to UIParent, but don't assume).
    local relativeToName = relativeTo and relativeTo:GetName() or nil
    CrieffMapCharDB.preset = {
        point = point,
        relativeTo = relativeToName,
        relPoint = relPoint,
        x = x,
        y = y,
    }
    StopDragMode()
    -- Re-assert the correct position for the current zone (preset outdoors).
    CrieffMap.ApplyPosition()
    CrieffMap:Print("outdoor spot saved.")
end

-- Discard the drag: restore the previous preset and snap the minimap back.
function Mover:Cancel()
    if not self.active then return end
    CrieffMapCharDB.preset = self.prevPreset
    StopDragMode()
    CrieffMap.ApplyPosition()
    CrieffMap:Print("drag cancelled.")
end
