local zhenyin = fk.CreateSkill {
  name = "syqc__zhenyin",
}

-- 隐藏标记（去掉 @@ 前缀，不再显示在牌面上）
local PEACH_MARK = "syqc__zhenyin_peach"
-- 玩家标记：记录"这个玩家身上有震音给的防具"
local ARMOR_TARGET_MARK = "syqc__zhenyin_armor_target"
-- 模式标记（0=未锁定，1=①，2=②）
local MODE_MARK = "syqc__zhenyin_mode"

-- 从牌堆检索一张随机防具牌
local function findRandomArmor(room)
  local cards = room:getCardsFromPileByRule(".|.|.|.|.|armor", 1, "allPiles")
  if #cards == 0 then
    cards = room:getCardsFromPileByRule(".|.|.|.|.|equip", 1, "allPiles")
  end
  if #cards == 0 then return nil end
  return Fk:getCardById(room:tableRandomPick(cards))
end

-- ============ 主体：只有达米安自己的准备阶段才触发 ============
zhenyin:addEffect(fk.EventPhaseStart, {
  anim_type = "special",
  can_trigger = function(self, event, target, player, data)
    return target == player
      and player.room:getCurrent() == player
      and player:hasSkill(zhenyin.name)
      and player.phase == Player.Start
      and player:usedSkillTimes(zhenyin.name, Player.HistoryTurn) < 1
      and player:usedSkillTimes(zhenyin.name, Player.HistoryGame) < 2
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, { skill_name = zhenyin.name })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local lockedMode = player:getMark(MODE_MARK)

    local choice
    if lockedMode == 1 then
      choice = 1
    elseif lockedMode == 2 then
      choice = 2
    else
      local choices = { "syqc__zhenyin_mode1", "syqc__zhenyin_mode2" }
      local picked = room:askToChoice(player, {
        choices = choices,
        skill_name = zhenyin.name,
        all_choices = choices,
      })
      if picked == choices[1] then
        choice = 1
        room:setPlayerMark(player, MODE_MARK, 1)
      else
        choice = 2
        room:setPlayerMark(player, MODE_MARK, 2)
      end
    end

    if choice == 1 then
      -- ===== ①：亮出牌堆顶三张，选一张"视为桃" =====
      local cards = room:getNCards(3)
      if #cards == 0 then return end

      room:showCards(cards)

      local choices = {}
      for i, id in ipairs(cards) do
        local card = Fk:getCardById(id)
        table.insert(choices, tostring(i) .. "：" .. card:toLogString())
      end

      local picked = room:askToChoice(player, {
        choices = choices,
        skill_name = zhenyin.name,
      })

      if picked then
        local index = tonumber(string.sub(picked, 1, 1))
        if index and cards[index] then
          local chosenCard = Fk:getCardById(cards[index])
          -- ✅ 打上隐藏标记（filter 会自动显示"视为桃"）
          room:setCardMark(chosenCard, PEACH_MARK, 1)
        end
      end

      for i = #cards, 1, -1 do
        room:moveCardTo(cards[i], Card.DrawPile, nil, fk.ReasonJustMove, zhenyin.name)
      end

    elseif choice == 2 then
      -- ===== ②：令一名角色装备随机防具牌 =====
      local targets = room:askToChoosePlayers(player, {
        min_num = 1, max_num = 1,
        targets = room.alive_players,
        skill_name = zhenyin.name,
        cancelable = false,
      })
      if #targets == 0 then return end
      local tgt = targets[1]

      local armorCard = findRandomArmor(room)
      if not armorCard then
        room:doNotify(player, "牌堆中无防具牌")
        return
      end

      room:setPlayerMark(tgt, ARMOR_TARGET_MARK, 1)

      room:useCard {
        from = tgt,
        tos = { tgt },
        card = armorCard,
      }
    end
  end,
})

-- ============ ①：带"视为桃"标记的牌，任何玩家使用时都视为桃 ============
zhenyin:addEffect("filter", {
  mute = true,
  card_filter = function(self, card, player, isJudgeEvent)
    return card:getMark(PEACH_MARK) > 0
  end,
  view_as = function(self, player, card)
    return Fk:cloneCard("peach", card.suit, card.number)
  end,
})

-- ============ ①：带标记的牌进入弃牌堆时，清除"视为桃"标记（静默） ============
zhenyin:addEffect(fk.AfterCardsMove, {
  mute = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(zhenyin.name)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          local card = Fk:getCardById(info.cardId)
          if card:getMark(PEACH_MARK) > 0 then
            room:setCardMark(card, PEACH_MARK, 0)
          end
        end
      end
    end
  end,
})

-- ============ ②：带防具标记的角色"下一个回合开始"时，弃置防具（静默） ============
zhenyin:addEffect(fk.TurnStart, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    -- ⚠️ 这里不检查 player:hasSkill，因为震音拥有者可能已经死亡但防具仍在
    if target:getMark(ARMOR_TARGET_MARK) == 0 then return false end
    for _, id in ipairs(target:getCardIds("e")) do
      if Fk:getCardById(id).sub_type == Card.SubtypeArmor then
        return true
      end
    end
    return false
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local toDiscard = {}
    for _, id in ipairs(target:getCardIds("e")) do
      local card = Fk:getCardById(id)
      if card.sub_type == Card.SubtypeArmor then
        table.insert(toDiscard, id)
      end
    end
    if #toDiscard > 0 then
      -- ✅ 不传 zhenyin.name，避免被引擎算作技能发动
      room:moveCardTo(toDiscard, Card.DiscardPile, nil, fk.ReasonDiscard)
    end
    room:setPlayerMark(target, ARMOR_TARGET_MARK, 0)
  end,
})

return zhenyin