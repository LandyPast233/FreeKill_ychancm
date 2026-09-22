local yincha = fk.CreateSkill {
  name = "syqc__yincha",
  tags = { Skill.Compulsory },
}

yincha:addEffect(fk.EnterDying, {
  anim_type = "defensive",
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player
      and player:hasSkill(yincha.name)
      and player:usedSkillTimes(yincha.name, Player.HistoryTurn) < 1
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judge = {
      who = player,
      reason = yincha.name,
      pattern = ".",
    }
    room:judge(judge)
    if not judge.card then return end
    if judge.card.color == Card.Black then
      if not player.dead then
        room:recover {
          who = player,
          num = 1,
          recoverBy = player,
          skillName = yincha.name,
        }
      end
    end
  end,
})

return yincha