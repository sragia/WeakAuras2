if not WeakAuras.IsCorrectVersion() then return end

local SharedMedia = LibStub("LibSharedMedia-3.0")
local L = WeakAuras.L

local screenWidth, screenHeight = math.ceil(GetScreenWidth() / 20) * 20, math.ceil(GetScreenHeight() / 20) * 20

local self_point_types = {
  BOTTOMLEFT = L["Bottom Left"],
  BOTTOM = L["Bottom"],
  BOTTOMRIGHT = L["Bottom Right"],
  RIGHT = L["Right"],
  TOPRIGHT = L["Top Right"],
  TOP = L["Top"],
  TOPLEFT = L["Top Left"],
  LEFT = L["Left"],
  CENTER = L["Center"],
  AUTO = L["Automatic"]
}

local function createOptions(parentData, data, index, subIndex)
  -- The toggles for font flags is intentionally not keyed on the id
  -- So that all auras share the state of that toggle
  local hiddenFontExtra = function()
    return WeakAuras.IsCollapsed("subtext", "subtext", "fontflags" .. index, true)
  end

  local indentWidth = 0.15

  local options = {
    __title = L["Text %s"]:format(subIndex),
    __order = 1,
    __up = function()
      if (WeakAuras.ApplyToDataOrChildData(parentData, WeakAuras.MoveSubRegionUp, index, "subtext")) then
        WeakAuras.ClearAndUpdateOptions(parentData.id)
      end
    end,
    __down = function()
      if (WeakAuras.ApplyToDataOrChildData(parentData, WeakAuras.MoveSubRegionDown, index, "subtext")) then
        WeakAuras.ClearAndUpdateOptions(parentData.id)
      end
    end,
    __duplicate = function()
      if (WeakAuras.ApplyToDataOrChildData(parentData, WeakAuras.DuplicateSubRegion, index, "subtext")) then
        WeakAuras.ClearAndUpdateOptions(parentData.id)
      end
    end,
    __delete = function()
      if (WeakAuras.ApplyToDataOrChildData(parentData, WeakAuras.DeleteSubRegion, index, "subtext")) then
        WeakAuras.ClearAndUpdateOptions(parentData.id)
      end
    end,
    text_visible = {
      type = "toggle",
      width = WeakAuras.halfWidth,
      order = 9,
      name = L["Show Text"],
    },
    text_color = {
      type = "color",
      width = WeakAuras.halfWidth,
      name = L["Color"],
      hasAlpha = true,
      order = 10,
    },
    text_text = {
      type = "input",
      width = WeakAuras.normalWidth,
      desc = function()
        return L["Dynamic text tooltip"] .. WeakAuras.GetAdditionalProperties(parentData)
      end,
      name = L["Display Text"],
      order = 11,
      set = function(info, v)
        data.text_text = WeakAuras.ReplaceLocalizedRaidMarkers(v)
        WeakAuras.Add(parentData)
        WeakAuras.ClearAndUpdateOptions(parentData.id)
      end
    },
    text_font = {
      type = "select",
      width = WeakAuras.normalWidth,
      dialogControl = "LSM30_Font",
      name = L["Font"],
      order = 13,
      values = AceGUIWidgetLSMlists.font,
    },
    text_fontSize = {
      type = "range",
      width = WeakAuras.normalWidth,
      name = L["Size"],
      order = 14,
      min = 6,
      softMax = 72,
      step = 1,
    },
    text_fontFlagsDescription = {
      type = "execute",
      control = "WeakAurasExpandSmall",
      name = function()
        local textFlags = WeakAuras.font_flags[data.text_fontType]
        local color = format("%02x%02x%02x%02x",
                             data.text_shadowColor[4] * 255, data.text_shadowColor[1] * 255,
                             data.text_shadowColor[2] * 255, data.text_shadowColor[3]*255)

        local textJustify = ""
        if data.text_justify == "CENTER" then
          -- CENTER is default
        elseif data.text_justify == "LEFT" then
          textJustify = " " .. L["and aligned left"]
        elseif data.text_justify == "RIGHT" then
          textJustify = " " ..  L["and aligned right"]
        end

        local textRotate = ""
        if data.rotateText == "LEFT" then
          textRotate = " " .. L["and rotated left"]
        elseif data.rotateText == "RIGHT" then
          textRotate = " " .. L["and rotated right"]
        end

        local textWidth = ""
        if data.text_automaticWidth == "Fixed" then
          local wordWarp = ""
          if data.text_wordWrap == "WordWrap" then
            wordWarp = L["wrapping"]
          else
            wordWarp = L["eliding"]
          end
          textWidth = " "..L["and with width |cFFFF0000%s|r and %s"]:format(data.text_fixedWidth, wordWarp)
        end

        local secondline = L["|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s%s"]:format(textFlags, color, data.text_shadowXOffset, data.text_shadowYOffset, textRotate, textJustify, textWidth)

        return secondline
      end,
      width = WeakAuras.doubleWidth,
      order = 44,
      func = function(info, button)
        local collapsed = WeakAuras.IsCollapsed("subtext", "subtext", "fontflags" .. index, true)
        WeakAuras.SetCollapsed("subtext", "subtext", "fontflags" .. index, not collapsed)
      end,
      image = function()
        local collapsed = WeakAuras.IsCollapsed("subtext", "subtext", "fontflags" .. index, true)
        return collapsed and "collapsed" or "expanded"
      end,
      imageWidth = 15,
      imageHeight = 15,
      arg = {
        expanderName = "subtext" .. index .. "#" .. subIndex
      }
    },

    text_font_space = {
      type = "description",
      name = "",
      order = 45,
      hidden = hiddenFontExtra,
      width = indentWidth
    },

    text_fontType = {
      type = "select",
      width = WeakAuras.normalWidth - indentWidth,
      name = L["Outline"],
      order = 46,
      values = WeakAuras.font_flags,
      hidden = hiddenFontExtra
    },
    text_shadowColor = {
      type = "color",
      hasAlpha = true,
      width = WeakAuras.normalWidth,
      name = L["Shadow Color"],
      order = 47,
      hidden = hiddenFontExtra
    },

    text_font_space3 = {
      type = "description",
      name = "",
      order = 47.5,
      hidden = hiddenFontExtra,
      width = indentWidth
    },
    text_shadowXOffset = {
      type = "range",
      width = WeakAuras.normalWidth - indentWidth,
      name = L["Shadow X Offset"],
      softMin = -15,
      softMax = 15,
      bigStep = 1,
      order = 48,
      hidden = hiddenFontExtra
    },
    text_shadowYOffset = {
      type = "range",
      width = WeakAuras.normalWidth,
      name = L["Shadow Y Offset"],
      softMin = -15,
      softMax = 15,
      bigStep = 1,
      order = 49,
      hidden = hiddenFontExtra
    },

    text_font_space4 = {
      type = "description",
      name = "",
      order = 49.5,
      hidden = hiddenFontExtra,
      width = indentWidth
    },
    rotateText = {
      type = "select",
      width = WeakAuras.normalWidth - indentWidth,
      name = L["Rotate Text"],
      values = WeakAuras.text_rotate_types,
      order = 50,
      hidden = hiddenFontExtra
    },
    text_justify = {
      type = "select",
      width = WeakAuras.normalWidth,
      name = L["Alignment"],
      values = WeakAuras.justify_types,
      order = 50.5,
      hidden = hiddenFontExtra
    },
    text_font_space5 = {
      type = "description",
      name = "",
      order = 51,
      hidden = hiddenFontExtra,
      width = indentWidth
    },
    text_automaticWidth = {
      type = "select",
      width = WeakAuras.normalWidth - indentWidth,
      name = L["Width"],
      order = 51.5,
      values = WeakAuras.text_automatic_width,
      hidden = hiddenFontExtra
    },
    text_font_space6 = {
      type = "description",
      name = "",
      order = 52,
      hidden = hiddenFontExtra,
      width = WeakAuras.normalWidth
    },
    text_font_space7 = {
      type = "description",
      name = "",
      order = 52.5,
      width = indentWidth,
      hidden = function() return hiddenFontExtra() or data.text_automaticWidth ~= "Fixed" end
    },
    text_fixedWidth = {
      name = L["Width"],
      width = WeakAuras.normalWidth - indentWidth,
      order = 53,
      type = "range",
      min = 1,
      softMax = 200,
      bigStep = 1,
      hidden = function() return hiddenFontExtra() or data.text_automaticWidth ~= "Fixed" end
    },
    text_wordWrap = {
      type = "select",
      width = WeakAuras.normalWidth,
      name = L["Overflow"],
      order = 54,
      values = WeakAuras.text_word_wrap,
      hidden = function() return hiddenFontExtra() or data.text_automaticWidth ~= "Fixed" end
    },

    text_anchor = {
      type = "description",
      name = "",
      order = 55,
      hidden = hiddenFontExtra,
      control = "WeakAurasExpandAnchor",
      arg = {
        expanderName = "subtext" .. index .. "#" .. subIndex
      }
    }
  }

  -- Note: Anchor Options need to be generalized once there are multiple sub regions
  -- While every sub region will have anchor options, the initial
  -- design I had for anchor options proved to be not general enough for
  -- what SubText needed. So, I removed it, and postponed making it work for unknown future
  -- sub regions
  local anchors
  if parentData.controlledChildren then
    anchors = {}
    for index, childId in ipairs(parentData.controlledChildren) do
      local childData = WeakAuras.GetData(childId)
      Mixin(anchors, WeakAuras.GetAnchorsForData(childData, "point"))
    end
  else
     anchors = WeakAuras.GetAnchorsForData(parentData, "point")
  end
  -- Anchor Options
  options.text_anchorsDescription = {
    type = "execute",
    control = "WeakAurasExpandSmall",
    name = function()
      local selfPoint = data.text_selfPoint ~= "AUTO" and self_point_types[data.text_selfPoint]
      local anchorPoint = anchors[data.text_anchorPoint or "CENTER"] or anchors["CENTER"]

      local xOffset = data.text_anchorXOffset or 0
      local yOffset = data.text_anchorYOffset or 0

      if (type(anchorPoint) == "table") then
        anchorPoint = anchorPoint[1] .. "/" .. anchorPoint[2]
      end

      if selfPoint then
        if xOffset == 0 and yOffset == 0 then
          return L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r"]:format(selfPoint, anchorPoint)
        else
          return L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"]:format(selfPoint, anchorPoint, xOffset, yOffset)
        end
      else
        if xOffset == 0 and yOffset == 0 then
          return L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r"]:format(anchorPoint)
        else
          return L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"]:format(anchorPoint, xOffset, yOffset)
        end
      end
    end,
    width = WeakAuras.doubleWidth,
    order = 60,
    image = function()
      local collapsed = WeakAuras.IsCollapsed("subregion", "text_anchors", tostring(index), true)
      return collapsed and "collapsed" or "expanded"
    end,
    imageWidth = 15,
    imageHeight = 15,
    func = function(info, button)
      local collapsed = WeakAuras.IsCollapsed("subregion", "text_anchors", tostring(index), true)
      WeakAuras.SetCollapsed("subregion", "text_anchors", tostring(index), not collapsed)
    end,
    arg = {
      expanderName = "subtext_anchor" .. index .. "#" .. subIndex
    }
  }


  local hiddenFunction = function()
    return WeakAuras.IsCollapsed("subregion", "text_anchors", tostring(index), true)
  end

  options.text_anchor_space = {
    type = "description",
    name = "",
    order = 60.15,
    hidden = hiddenFunction,
    width = indentWidth
  }

  options.text_selfPoint = {
    type = "select",
    width = WeakAuras.normalWidth - indentWidth,
    name = L["Anchor"],
    order = 60.2,
    values = self_point_types,
    hidden = hiddenFunction
  }

  options.text_anchorPoint = {
    type = "select",
    width = WeakAuras.normalWidth,
    name = function()
      return L["To Frame's"]
    end,
    order = 60.3,
    values = anchors,
    hidden = hiddenFunction,
    control = "WeakAurasTwoColumnDropdown"
  }

  options.text_anchor_space2 = {
    type = "description",
    name = "",
    order = 60.35,
    hidden = hiddenFunction,
    width = indentWidth
  }

  options.text_anchorXOffset = {
    type = "range",
    width = WeakAuras.normalWidth - indentWidth,
    name = L["X Offset"],
    order = 60.4,
    softMin = (-1 * screenWidth),
    softMax = screenWidth,
    bigStep = 10,
    hidden = hiddenFunction
  }

  options.text_anchorYOffset = {
    type = "range",
    width = WeakAuras.normalWidth,
    name = L["Y Offset"],
    order = 60.5,
    softMin = (-1 * screenHeight),
    softMax = screenHeight,
    bigStep = 10,
    hidden = hiddenFunction
  }

  options.text_anchor_anchor = {
    type = "description",
    name = "",
    order = 61,
    hidden = hiddenFontExtra,
    control = "WeakAurasExpandAnchor",
    arg = {
      expanderName = "subtext_anchor" .. index .. "#" .. subIndex
    }
  }

  local function hideCustomTextOption()
    if not parentData.subRegions then
      return true
    end

    for index, subRegion in ipairs(parentData.subRegions) do
      if subRegion.type == "subtext" and WeakAuras.ContainsCustomPlaceHolder(subRegion.text_text) then
        return false
      end
    end
    return true
  end

  local commonTextOptions = {
    __title = L["Common Text"],
    __hidden = function() return hideCustomTextOption() end,
    text_customTextUpdate = {
      type = "select",
      width = WeakAuras.doubleWidth,
      hidden = hideCustomTextOption,
      name = L["Update Custom Text On..."],
      values = WeakAuras.text_check_types,
      order = 3,
      get = function() return parentData.customTextUpdate or "event" end,
      set = function(info, v)
        parentData.customTextUpdate = v
        WeakAuras.Add(parentData)
        WeakAuras.ClearAndUpdateOptions(parentData.id)
      end
    },
  }

  WeakAuras.commonOptions.AddCodeOption(commonTextOptions, parentData, L["Custom Function"], "customText", "https://github.com/WeakAuras/WeakAuras2/wiki/Custom-Code-Blocks#custom-text",
                          4,  hideCustomTextOption, {"customText"}, false)

  -- Add Text Format Options
  local hidden = function()
    return WeakAuras.IsCollapsed("format_option", "text", "text_text", true)
  end

  local setHidden = function(hidden)
    WeakAuras.SetCollapsed("format_option", "text", "text_text", hidden)
  end

  local order = 12
  local function addOption(key, option)
    option.order = order
    order = order + 0.01
    if option.reloadOptions then
      option.reloadOptions = nil
      option.set = function(info, v)
        data["text_text_format_" .. key] = v
        WeakAuras.Add(parentData)
        WeakAuras.ClearAndUpdateOptions(parentData.id, true)
      end
    end
    options["text_text_format_" .. key] = option
  end

  if parentData.controlledChildren then
    for _, childId in pairs(parentData.controlledChildren) do
      local parentChildData = WeakAuras.GetData(childId)

      if parentChildData.subRegions then
        local childData = parentChildData.subRegions[index]
        if childData then
          local get = function(key)
            return childData["text_text_format_" .. key]
          end
          local input = childData["text_text"]
          WeakAuras.AddTextFormatOption(input, true, get, addOption, hidden, setHidden)
        end
      end
    end
  else
    local get = function(key)
      return data["text_text_format_" .. key]
    end
    local input = data["text_text"]
    WeakAuras.AddTextFormatOption(input, true, get, addOption, hidden, setHidden)
  end

  addOption("footer", {
    type = "description",
    name = "",
    width = WeakAuras.doubleWidth,
    hidden = hidden
  })

  return options, commonTextOptions
end

local function createDefaultsOptions()
  local options = {
    __title = L["Sub Text"],
    __order = 2,
    subtext_font = {
      type = "select",
      width = WeakAuras.normalWidth,
      dialogControl = "LSM30_Font",
      get = function()
        return WeakAuras.GetDefault('subtext', 'font', true)
      end,
      set = function(_, value)
        WeakAuras.SetDefault('subtext', 'font', value)
      end,
      name = L["Font"],
      order = 1,
      values = AceGUIWidgetLSMlists.font,
    },
    subtext_fontSize = {
      type = "range",
      width = WeakAuras.normalWidth,
      name = L["Size"],
      get = function()
        return WeakAuras.GetDefault('subtext', 'fontSize', true)
      end,
      set = function(_, value)
        WeakAuras.SetDefault('subtext', 'fontSize', value)
      end,
      order = 2,
      min = 6,
      softMax = 72,
      step = 1,
    },
    subtext_fontType = {
      type = "select",
      width = WeakAuras.normalWidth,
      name = L["Outline"],
      get = function()
        return WeakAuras.GetDefault('subtext', 'fontType', true)
      end,
      set = function(_, value)
        -- Need to figure out this
        WeakAuras.SetDefault('subtext', 'fontType', value)
        WeakAuras.SetDefault('subtext', 'outline', value)
      end,
      order = 3,
      values = WeakAuras.font_flags,
    }
  }
  return options
end

WeakAuras.RegisterDefaultsOptions('subtext', createDefaultsOptions)
WeakAuras.RegisterSubRegionOptions("subtext", createOptions, L["Shows one or more lines of text, which can include dynamic information such as progress or stacks"])
