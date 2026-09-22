local juedou = fk.CreateSkill {
  name = "syqc__juedou",
}

-- 点燃标记（与重奏共用）
local IGNITE_MARK = "@@syqc__chongzou_ignite"
-- 标记：达米安身上记录目标 id（待办：回合结束时给目标额外回合）
local MARK_TARGET_ID = "syqc__juedou_target_id"
-- 标记：目标身上（标记自己是"角斗的额外回合"）
local MARK_EXTRA = "syqc__juedou_extra"

-- 辅助函数：点燃某角色的所有手牌
local function igniteAllCards(room, player)
  for _, id in ipairs(player:getCardIds("h")) do
    room:setCardMark(Fk:getCardById(id), IGNITE_MARK, 1)
  end
end

-- ============ 阶段 1：技能发动 ============
juedou:addEffect("active", {
  anim_type = "big",
  prompt = "#syqc__juedou",
  min_card_num = 0,
  max_card_num = 0,
  target_num = 0,
  can_use = function(self, player)
    return player:usedSkillTimes(juedou.name, Player.HistoryGame) < 1
      and player.hp < player.maxHp
  end,
  on_use = function(self, room, effect)
    local player = effect.from

    -- 步骤 1：动画 + 语音（1 或 2）
    player:broadcastSkillInvoke(juedou.name, math.random(1, 2))

    -- 步骤 2：选择一名其他角色
    local targets = room:askToChoosePlayers(player, {
      min_num = 1, max_num = 1,
      targets = room:getOtherPlayers(player),
      skill_name = juedou.name,
      prompt = "#syqc__juedou-choose",
      cancelable = false,
    })
    if #targets == 0 then return end
    local target = targets[1]

    -- 步骤 3：记录目标
    room:setPlayerMark(player, MARK_TARGET_ID, target.id)

    -- 步骤 4：播放 BGM（第 3 条语音）—— 只在达米安这里播
    player:broadcastSkillInvoke(juedou.name, 3)

    -- 步骤 5：点燃达米安所有手牌
    igniteAllCards(room, player)
  end,
})

-- ============ 达米安回合结束 → 给目标额外回合 ============
juedou:addEffect(fk.TurnEnd, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    return player:getMark(MARK_TARGET_ID) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targetId = player:getMark(MARK_TARGET_ID)

    room:setPlayerMark(player, MARK_TARGET_ID, 0)

    local targetPlayer = room:getPlayerById(targetId)
    if targetPlayer and not targetPlayer.dead then
      room:setPlayerMark(targetPlayer, MARK_EXTRA, 1)
      targetPlayer:gainAnExtraTurn(true, juedou.name, nil, { from = player })
    end
  end,
})

-- ============ 目标额外回合开始 → 点燃手牌 ============
juedou:addEffect(fk.TurnStart, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return player:getMark(MARK_EXTRA) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    --
    igniteAllCards(room, player)
  end,
})

-- ============ 目标额外回合结束 → 清除标记 ============
juedou:addEffect(fk.TurnEnd, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return player:getMark(MARK_EXTRA) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    room:setPlayerMark(player, MARK_EXTRA, 0)
  end,
})

return juedou