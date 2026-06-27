-- CrieffMap.Mover — drag-to-set helper for the outdoor preset position.
-- `/cmap drag` toggles a mode where you drag the minimap to where you want it
-- outdoors; on drop, the cluster's anchor is saved to CrieffMapCharDB.preset.

local Mover = {}
CrieffMap.Mover = Mover

Mover.active = false

-- Lazily-created on-screen instruction label shown while drag mode is active.
local function GetOverlay()
    if Mover.overlay then return Mover.overlay end

    local f = CreateFrame("Frame", "CrieffMapMoverOverlay", UIParent, "BackdropTemplate")
    f:SetSize(360, 48)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.8)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText("Drag the minimap to the desired outdoor spot.\nType |cffffff00/cmap drag|r again to save.")
    text:SetJustifyH("CENTER")

    Mover.overlay = f
    return f
end

local function StartDragMode()
    MinimapCluster:SetMovable(true)
    MinimapCluster:EnableMouse(true)
    MinimapCluster:RegisterForDrag("LeftButton")
    MinimapCluster:SetScript("OnDragStart", function(self) self:StartMoving() end)
    MinimapCluster:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relPoint, x, y = self:GetPoint()
        -- relativeTo is a frame reference; store its name so it survives a
        -- /reload (StartMoving normally anchors to UIParent, but don't assume).
        local relativeToName = relativeTo and relativeTo:GetName() or nil
        CrieffMapCharDB.preset = {
            point = point,
            relativeTo = relativeToName,
            relPoint = relPoint,
            x = x,
            y = y,
        }
    end)
    GetOverlay():Show()
end

local function StopDragMode()
    MinimapCluster:SetScript("OnDragStart", nil)
    MinimapCluster:SetScript("OnDragStop", nil)
    MinimapCluster:RegisterForDrag()
    MinimapCluster:EnableMouse(false)
    if Mover.overlay then Mover.overlay:Hide() end
    -- Re-assert the correct position for the current zone (preset outdoors).
    CrieffMap.ApplyPosition()
end

function Mover:Toggle()
    if self.active then
        self.active = false
        StopDragMode()
        CrieffMap:Print("outdoor spot saved.")
    else
        self.active = true
        StartDragMode()
        CrieffMap:Print("drag the minimap, then |cffffff00/cmap drag|r to save.")
    end
end
