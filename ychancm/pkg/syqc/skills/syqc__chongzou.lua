local chongzou = fk.CreateSkill {
  name = "syqc__chongzou",
  tags = { Skill.Compulsory },
}

-- 点燃标记：双 @ 开头会显示在牌面上
local IGNITE_MARK = "@@syqc__chongzou_ignite"

-- 判断一张牌是否被点燃
local function isIgnited(cardId)
  return Fk:getCardById(cardId):getMark(IGNITE_MARK) > 0
end

-- 让一名玩家点燃一张手牌（强制，无手牌则跳过）
local function igniteCard(room, player)
  if player.dead or player:isKongcheng() then return end
  local cardId = room:askToChooseCard(player, {
    target = player,
    flag = "h",
    skill_name = chongzou.name,
    prompt = "#syqc__chongzou-ignite",
  })
  if cardId then
    room:setCardMark(Fk:getCardById(cardId), IGNITE_MARK, 1)
  end
end

-- 处理一次"重奏"触发
-- player: 达米安（技能拥有者）
-- other:  对方（可能是 nil，如无来源伤害）
local function triggerChongzou(room, player, other)
  -- 收集参与玩家（去重，排除死亡）
  local participants = {}
  local seen = {}
  local function add(p)
    if p and not p.dead and not seen[p.id] then
      seen[p.id] = true
      table.insert(participants, p)
    end
  end
  add(player)  -- 达米安一定在前
  add(other)   -- 对方在后

  -- 各摸一张牌
  for _, p in ipairs(participants) do
    p:drawCards(1, chongzou.name)
  end

  -- 达米安先选，另一方后选
  for _, p in ipairs(participants) do
    igniteCard(room, p)
  end
end

-- ============ 受到伤害后（达米安是受害者，来源是对方） ============
chongzou:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(chongzou.name)
  end,
  on_use = function(self, event, target, player, data)
    triggerChongzou(player.room, player, data.from)
  end,
})

-- ============ 造成伤害后（达米安是来源，受害者是对方） ============
chongzou:addEffect(fk.Damaged, {
  can_trigger = function(self, event, target, player, data)
    return data.from == player and player:hasSkill(chongzou.name)
  end,
  on_use = function(self, event, target, player, data)
    triggerChongzou(player.room, player, target)
  end,
})

-- ============ 点燃牌无视距离和次数（参考成略的 targetmod） ============
chongzou:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card)
    return card and card:getMark(IGNITE_MARK) > 0
  end,
  bypass_distances = function(self, player, skill, card)
    return card and card:getMark(IGNITE_MARK) > 0
  end,
})

-- ============ 回合结束时弃置所有点燃牌（进弃牌堆 + 清标记） ============
chongzou:addEffect(fk.TurnEnd, {
  can_refresh = function(self, event, target, player, data)
    return true
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local toDiscard = {}
    for _, p in ipairs(room.players) do
      -- "he" = 手牌 + 装备区（不含判定区）
      for _, cardId in ipairs(p:getCardIds("he")) do
        local card = Fk:getCardById(cardId)
        if card:getMark(IGNITE_MARK) > 0 then
          -- ✅ 关键：收集前先清除点燃标记
          room:setCardMark(card, IGNITE_MARK, 0)
          table.insert(toDiscard, cardId)
        end
      end
    end
    if #toDiscard > 0 then
      -- ✅ 目标区域用 Card.DiscardPile（真正的弃牌堆）
      room:moveCardTo(toDiscard, Card.DiscardPile, nil, fk.ReasonDiscard, chongzou.name)
    end
  end,
})

return chongzou