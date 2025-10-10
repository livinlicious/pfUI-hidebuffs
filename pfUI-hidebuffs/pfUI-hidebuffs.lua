pfUI:RegisterModule("hidebuffs", "vanilla:tbc", function ()
  -- Configuration defaults
  pfUI:UpdateConfig("hidebuffs", nil, "enabled", "1")
  pfUI:UpdateConfig("hidebuffs", nil, "hiddenBuffs", "")

  local hiddenBuffNames = {}
  local visibleBuffIndices = {}
  local visibleBuffCount = 0
  local lastConfigString = ""  -- Track config changes

  -- Cache for GetPlayerBuff hook (rebuilt on PLAYER_AURAS_CHANGED)
  local buffMappingCache = {}
  local buffMappingCacheValid = false

  -- Tooltip for getting buff names
  local tooltip = CreateFrame("GameTooltip", "pfUIHideBuffsTooltip", nil, "GameTooltipTemplate")

  -- Parse hidden buffs from config (only when config changes)
  local function ParseHiddenBuffs()
    local buffList = C.hidebuffs.hiddenBuffs or ""

    -- Only re-parse if config changed
    if buffList == lastConfigString then
      return
    end

    lastConfigString = buffList
    hiddenBuffNames = {}

    -- Handle empty or whitespace-only strings
    if buffList == "" or string.gsub(buffList, "%s", "") == "" then
      return
    end

    -- Split by # and process each buff name
    for buff in string.gfind(buffList, "[^#]+") do
      local trimmed = string.gsub(buff, "^%s*(.-)%s*$", "%1")
      if trimmed ~= "" then
        hiddenBuffNames[trimmed] = true
      end
    end
  end

  -- Get buff name from buff ID (simple, no cache - buffs change too often)
  local function GetBuffName(buffId)
    if not buffId or buffId < 0 then return nil end

    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetPlayerBuff(buffId)
    local name = pfUIHideBuffsTooltipTextLeft1:GetText()
    tooltip:Hide()

    return name
  end

  -- Build list of visible buff indices (skipping hidden ones)
  local function BuildVisibleBuffs()
    if C.hidebuffs.enabled ~= "1" then
      visibleBuffIndices = {}
      visibleBuffCount = 0
      return
    end

    ParseHiddenBuffs()
    visibleBuffIndices = {}
    visibleBuffCount = 0

    -- Start at 1 - weapon buffs are NOT in GetPlayerBuff, they're separate
    local actualBuffId = 1

    while actualBuffId <= 32 do
      local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + actualBuffId, "HELPFUL")
      if bid < 0 then break end

      local buffName = GetBuffName(bid)
      if not (buffName and hiddenBuffNames[buffName]) then
        table.insert(visibleBuffIndices, actualBuffId)
        visibleBuffCount = visibleBuffCount + 1
      end
      actualBuffId = actualBuffId + 1
    end
  end

  -- Function to apply buff filtering
  local function ApplyBuffFiltering()
    if not pfUI.buff or not pfUI.buff.buffs or not pfUI.buff.buffs.buttons then return end

    -- Only filter if our addon is enabled AND pfUI buffs are enabled
    if C.hidebuffs.enabled == "1" and C.buffs.buffs == "1" then
      BuildVisibleBuffs()

      -- Apply filtering to helpful buffs
      if visibleBuffCount > 0 then
        for i=1,32 do
          local buff = pfUI.buff.buffs.buttons[i]
          if buff and buff.btype == "HELPFUL" and not buff.weapon then
            if i > visibleBuffCount then
              buff:Hide()
            else
              local actualId = visibleBuffIndices[i]
              if actualId then
                local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + actualId, "HELPFUL")
                if bid >= 0 and GetPlayerBuffTexture(bid) then
                  buff.bid = bid
                  buff.texture:SetTexture(GetPlayerBuffTexture(bid))
                  local br, bg, bb, ba = GetStringColor(pfUI_config.appearance.border.color)
                  buff.backdrop:SetBackdropBorderColor(br,bg,bb,ba)
                  buff:Show()
                else
                  buff:Hide()
                end
              else
                buff:Hide()
              end
            end
          end
        end
      end
    end
  end

  -- Hook into pfUI.buff after it's created
  local hookFrame = CreateFrame("Frame")
  hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  hookFrame:SetScript("OnEvent", function()
    if not pfUI.buff then return end

    -- Store original OnEvent
    local originalOnEvent = pfUI.buff:GetScript("OnEvent")

    -- Replace OnEvent to inject our filtering
    pfUI.buff:SetScript("OnEvent", function()
      -- Invalidate unitframe buff mapping cache (buffs changed)
      buffMappingCacheValid = false

      -- Get weapon count first
      if C.buffs.weapons == "1" then
        local mh, mhtime, mhcharge, oh, ohtime, ohcharge = GetWeaponEnchantInfo()
        pfUI.buff.wepbuffs.count = (mh and 1 or 0) + (oh and 1 or 0)
      else
        pfUI.buff.wepbuffs.count = 0
      end

      -- Build visible buffs if enabled
      if C.hidebuffs.enabled == "1" then
        BuildVisibleBuffs()
      end

      -- Call original to refresh all buttons
      if originalOnEvent then
        originalOnEvent()
      end

      -- Apply our filtering
      ApplyBuffFiltering()
    end)

    -- Trigger initial update
    pfUI.buff:GetScript("OnEvent")()

    -- Hook GetPlayerBuff API to transparently skip hidden buffs
    -- This makes unitframes work automatically without any special handling
    local originalGetPlayerBuff = GetPlayerBuff

    -- Function to rebuild the buff mapping cache
    local function RebuildBuffMappingCache()
      buffMappingCache = {}
      ParseHiddenBuffs()

      -- Build mapping: displayIndex -> buffId
      -- Start at 1 - weapon buffs are NOT in GetPlayerBuff, they're separate
      local visibleCount = 0
      local actualBuffId = 1

      while actualBuffId <= 32 do
        local bid = originalGetPlayerBuff(PLAYER_BUFF_START_ID + actualBuffId, "HELPFUL")
        if bid < 0 then break end

        local buffName = GetBuffName(bid)
        if not (buffName and hiddenBuffNames[buffName]) then
          visibleCount = visibleCount + 1
          buffMappingCache[visibleCount] = bid
        end
        actualBuffId = actualBuffId + 1
      end

      buffMappingCacheValid = true
    end

    GetPlayerBuff = function(buffSlot, buffFilter)
      -- Only intercept HELPFUL buff queries when enabled
      if C.hidebuffs.enabled ~= "1" or buffFilter ~= "HELPFUL" then
        return originalGetPlayerBuff(buffSlot, buffFilter)
      end

      -- Calculate what display index is being requested (1-based)
      local requestedIndex = buffSlot - PLAYER_BUFF_START_ID
      if requestedIndex < 1 then
        return originalGetPlayerBuff(buffSlot, buffFilter)
      end

      -- Rebuild cache if invalid
      if not buffMappingCacheValid then
        RebuildBuffMappingCache()
      end

      -- Return cached mapping
      return buffMappingCache[requestedIndex] or -1
    end

    this:UnregisterAllEvents()
  end)

  -- Create GUI configuration
  if pfUI.gui.CreateGUIEntry then
    pfUI.gui.CreateGUIEntry(T["Thirdparty"], T["Hide Buffs"], function()
      pfUI.gui.CreateConfig(nil, T["Enable Hide Buffs"], C.hidebuffs, "enabled", "checkbox")
      pfUI.gui.CreateConfig(nil, T["Hidden Buff Names"], C.hidebuffs, "hiddenBuffs", "list")
    end)
  else
    pfUI.gui.tabs.thirdparty.tabs.hidebuffs = pfUI.gui.tabs.thirdparty.tabs:CreateTabChild("Hide Buffs", true)
    pfUI.gui.tabs.thirdparty.tabs.hidebuffs:SetScript("OnShow", function()
      if not this.setup then
        local CreateConfig = pfUI.gui.CreateConfig
        this.setup = true
        CreateConfig(this, T["Enable Hide Buffs"], C.hidebuffs, "enabled", "checkbox")
        CreateConfig(this, T["Hidden Buff Names"], C.hidebuffs, "hiddenBuffs", "list")
      end
    end)
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Hide Buffs|r loaded successfully")
end)
