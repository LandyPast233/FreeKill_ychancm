local cuojian = fk.CreateSkill {
  name = "syqc__cuojian",
}

cuojian:addEffect("viewas", {
  pattern = ".",
  prompt = "#syqc__cuojian",

  interaction = function(self, player)
    local all_names = {}
    for _, name in ipairs(Fk:getAllCardNames("b")) do
      table.insert(all_names, name)
    end
    for _, name in ipairs(Fk:getAllCardNames("t")) do
      table.insert(all_names, name)
    end
    local names = {}
    for _, name in ipairs(all_names) do
      if player:getMark("syqc__cuojian_used_" .. name) == 0 then
        table.insert(names, name)
      end
    end
    if #names == 0 then return end
    return UI.CardNameBox {choices = names, all_choices = all_names}
  end,

  card_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    local targetName = self.interaction and self.interaction.data
    if not targetName then return false end

    local card = Fk:getCardById(to_select)
    if card.type ~= Card.TypeBasic and card.type ~= Card.TypeTrick then return false end
    if card.type == Card.TypeTrick and card.sub_type == Card.SubtypeDelayedTrick then return false end

    local isTargetBasic = table.contains(Fk:getAllCardNames("b"), targetName)
    local isTargetTrick = table.contains(Fk:getAllCardNames("t"), targetName)

    if card.type == Card.TypeBasic and isTargetBasic then return false end
    if card.type == Card.TypeTrick and isTargetTrick then return false end

    return true
  end,

  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|.|hand",
  },

  view_as = function(self, player, cards)
    if #cards ~= 1 or not self.interaction.data then return end
    local targetName = self.interaction.data
    local c = Fk:cloneCard(targetName)
    if not c then return end
    c:addSubcards(cards)
    c.skillName = cuojian.name
    return c
  end,

  before_use = function(self, player, use)
    player.room:setPlayerMark(player, "syqc__cuojian_used_" .. use.card.name, 1)
  end,

  enabled_at_play = function(self, player)
    return player.phase == Player.Play
  end,

  -- 核心修改：只允许"使用"类响应，"打出"类响应禁止
  enabled_at_response = function(self, player, response)
    if player.phase ~= Player.Play then return false end
    if response then return false end
    return true
  end,
})

cuojian:addEffect("prohibit", {
  is_prohibited = function(self, from, to, card)
    if not from:hasSkill(cuojian.name) then return false end
    if from.phase ~= Player.Play then return false end
    if card.skillName == cuojian.name then return false end
    if card.type == Card.TypeBasic then return true end
    if card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick then
      return true
    end
    return false
  end,
})

cuojian:addEffect(fk.TurnEnd, {
  can_refresh = function(self, event, target, player, data)
    return target == player
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, name in ipairs(Fk:getAllCardNames("t")) do
      room:setPlayerMark(player, "syqc__cuojian_used_" .. name, 0)
    end
    for _, name in ipairs(Fk:getAllCardNames("b")) do
      room:setPlayerMark(player, "syqc__cuojian_used_" .. name, 0)
    end
  end,
})

return cuojian