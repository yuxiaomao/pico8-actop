pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- actop

-- sfx:
--   0: attack
--   1: player hit by enemy
--   2: pickup item

-- global variables
g_frames=0
g_player={}
g_enemies={}
g_killcnt=0
g_items={}
g_itemtypes={}

-- global constants
k_atk=5

function _init()
  g_frames=0
  item_manager.init()
  enemy_manager.init()
  player.init(g_player)
end

function _update()
  g_frames=(g_frames+1)%30
  item_manager.update()
  enemy_manager.update()
  player.update(g_player)
end

function _draw()
  cls()
  item_manager.draw()
  enemy_manager.draw()
  player.draw(g_player)
  -- draw ui
  for i=1,g_player.hpmax do
    if (g_player.hp >= i) then
      spr(11,i*8,0)
    else
      spr(10,i*8,0)
    end
  end
  local killpos=print(g_killcnt,0,-20)
  print("score: "..g_killcnt,100-killpos,0)
end
-->8
-- player

player={
  init=function(this)
    this.hpmax=3 -- const
    this.hp=3
    this.x=64
    this.y=64
    this.dx=0
    this.dy=0
    this.face=3
    this.frame=0
    this.hitbox={x=1,y=1,w=6,h=6} -- const
    this.invulnframe=0
    -- melee attack
    this.atk={}
    this.atk.x=0
    this.atk.y=0
    this.atk.face=0
    this.atk.frame=0
    this.atk.cooldown=0
    this.atk.hitbox={x=0,y=0,w=8,h=8} -- const
    this.atk.pow=1
  end,
  update=function(this)
    if (this.invulnframe > 0) this.invulnframe-=1
    if (this.atk.cooldown > 0) this.atk.cooldown-=1
    -- input
    this.dx=0
    this.dy=0
    if (btn(0)) then
      this.face=0
      this.dx=-1
    end
    if (btn(1)) then
      this.face=1
      this.dx=1
    end
    if (btn(2)) then
      this.face=2
      this.dy=-1
    end
    if (btn(3)) then
      this.face=3
      this.dy=1
    end
    -- move
    this.x+=this.dx
    this.y+=this.dy
    item_manager.consumeall(this)
    -- attack
    if (btn(k_atk) and (this.atk.cooldown == 0)) then
      sfx(0)
      this.atk.frame=3
      this.atk.cooldown=10
      this.atk.face=this.face
      local atkpos=face2pos(this.atk.face)
      this.atk.x=this.x+atkpos.x*8
      this.atk.y=this.y+atkpos.y*8
    end
    if (this.atk.frame > 0) then
      enemy_manager.hitall(this.atk)
    end
  end,
  draw=function(this)
    -- draw player body
    if (this.invulnframe > 0) pal(8,9)
    if ((this.dx == 0) and (this.dy == 0)) then -- stop
      spr(1,this.x,this.y)
    else -- move
      spr(2+this.frame,this.x,this.y)
      if ((g_frames%5) == 0) this.frame=(this.frame+1)%2
    end
    pal()
    -- draw player eye
    spr(this.face+12,this.x,this.y)
    -- draw atk
    if (this.atk.frame > 0) then
      local atkpos=face2pos(this.atk.face)
      spr(this.atk.face*3+this.atk.frame+15,
          this.x+atkpos.x*8,
          this.y+atkpos.y*8)
      this.atk.frame-=1
    end
  end,
  hit=function(this,other)
    if (this.invulnframe == 0) then
      if (collidebox(this,other)) then
        sfx(1)
        this.hp-=other.pow
        this.invulnframe=30
        if (this.hp <= 0) player.kill(this)
      end
    end
  end,
  kill=function(this)
    -- todo player dead
  end,
}

-->8
-- enemy

enemy={
  init=function(this,x,y)
    this.hp=1
    this.x=x
    this.y=y
    this.dx=0
    this.dy=0
    this.flipx=false
    this.frame=0
    this.hitbox={x=0,y=3,w=8,h=5} -- const
    this.invulnframe=0
    this.pow=1
  end,
  update=function(this)
    if (this.invulnframe > 0) this.invulnframe-=1
    -- update speed and face
    if ((g_frames%30) == 0) then
      this.dx=cmp(g_player.x,this.x)*0.1
      this.dy=cmp(g_player.y,this.y)*0.1
      this.flipx=(this.dx > 0)
    end
    -- move
    this.x+=this.dx
    this.y+=this.dy
    -- attack
    player.hit(g_player,this)
  end,
  draw=function(this)
    spr(this.frame+32,this.x,this.y,1,1,this.flipx,false)
    if ((g_frames%5) == 0) this.frame=(this.frame+1)%2
  end,
  hit=function(this,other)
    if (this.invulnframe == 0) then
      if (collidebox(this,other)) then
        this.hp-=other.pow
        this.invulnframe=3
        if (this.hp <= 0) enemy_manager.kill(this)
      end
    end
  end,
}

-- manage function
-- manipulate global var g_enemies, g_killcnt
enemy_manager={
  init=function()
    g_killcnt=0
    g_enemies={}
  end,
  update=function()
    foreach(g_enemies,enemy.update)
    -- spawn if not enough enemy
    if (enemy_manager.count() < 2) then
      local spawnpos=rndspawnpos()
      enemy_manager.spawn(spawnpos.x,spawnpos.y)
    end
  end,
  draw=function()
    foreach(g_enemies,enemy.draw)
  end,
  spawn=function(x,y)
    local obj={}
    enemy.init(obj,x,y)
    add(g_enemies,obj)
  end,
  count=function()
    return #g_enemies
  end,
  hitall=function(other)
    for e in all(g_enemies) do
      enemy.hit(e,other)
    end
  end,
  kill=function(obj)
    g_killcnt+=1
    if ((g_killcnt % 5) == 0) item_manager.spawnrnd()
    del(g_enemies,obj)
  end,
}

-->8
-- item

item_hp={
  init=function(this,x,y)
    this.type=item_hp
    this.x=x
    this.y=y
    this.hitbox={x=1,y=1,w=6,h=6}
  end,
  update=function(this)
  end,
  draw=function(this)
    spr(48,this.x,this.y)
  end,
  consume=function(this,other)
    if (collidebox(this,other)) then
      if (other.hp < other.hpmax) then
        sfx(2)
        other.hp+=1
        item_manager.remove(this)
      end
    end
  end,
}

-- manage function
-- manipulate global var g_items, g_itemtypes
item_manager={
  init=function()
    g_items={}
    g_itemtypes={item_hp}
    item_manager.spawn(item_hp,50,50)
  end,
  update=function()
    for i in all(g_items) do
      i.type.update(i)
    end
  end,
  draw=function()
    for i in all(g_items) do
      i.type.draw(i)
    end
  end,
  spawn=function(type,x,y)
    local obj={}
    type.init(obj,x,y)
    add(g_items,obj)
  end,
  spawnrnd=function()
    local type=rnd(g_itemtypes)
    local pos=rndspawnpos()
    item_manager.spawn(type,pos.x,pos.y)
  end,
  count=function()
    return #g_items
  end,
  consumeall=function(other)
    for i in all(g_items) do
      (i.type).consume(i,other)
    end
  end,
  remove=function(obj)
    del(g_items,obj)
  end,
}

-->8
-- util

-- helper function

face2pos=function(face)
  local x=0
  local y=0
  if (face == 0) x=-1
  if (face == 1) x=1
  if (face == 2) y=-1
  if (face == 3) y=1
  return {x=x,y=y}
end

cmp=function(x1,x2)
  local res=0
  if (x1 < x2) res=-1
  if (x1 > x2) res=1
  return res
end

collidebox=function(obj1,obj2)
  if ((obj1.x+obj1.hitbox.x < obj2.x+obj2.hitbox.x+obj2.hitbox.w) and
      (obj1.x+obj1.hitbox.x+obj1.hitbox.w > obj2.x+obj2.hitbox.x) and
      (obj1.y+obj1.hitbox.y < obj2.y+obj2.hitbox.y+obj2.hitbox.h) and
      (obj1.y+obj1.hitbox.y+obj1.hitbox.h > obj2.y+obj2.hitbox.y)) then
    return true
  else
    return false
  end
end

-- random spawn location away from player
rndspawnpos=function()
  -- spawn only away from player
  local x=0
  local y=0
  repeat
    x=flr(rnd(120))
    y=flr(rnd(120))
  until ((abs(x-g_player.x)>20)
         or (abs(y-g_player.y)>20))
  return {x=x,y=y}
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088888800888888008888880000000000000000000000000000000000000000000000000055055000880880000000000000000000000000000000000
00000000088888800888888008888880000000000000000000000000000000000000000000000000500500508888878000000000000000000010010000000000
00000000088888800888888008888880000000000000000000000000000000000000000000000000500000508888888000101000000101000010010000100100
00000000088888800888888008888880000000000000000000000000000000000000000000000000050005000888880000101000000101000000000000100100
00000000088888800888888008888880000000000000000000000000000000000000000000000000005050000088800000000000000000000000000000000000
00000000008008000080080000800800000000000000000000000000000000000000000000000000000500000008000000000000000000000000000000000000
00000000008008000080000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006000000076000000000000000000000000000000000000000000000055000000500000005500000600000000006000067760000000000
00000000000000000007600000760000000000000000000000000000000000000000000000056700000550000006500006000000000000600600006000000000
00000000000000000000760007600000000000000000000000000000000060000000000000000670000670000067000060000000000000066000000600000000
00000055006666550000076556000000057770005500000060000000000760000000007600000067000670000670000070000000000000070000000000000000
00000065000777500000005555000000556666005670000076000000000760000000076000000006000670006700000070000000000000070000000000000000
00000670000000000000000000000000000000000067000007600000000760000000760000000000000600000000000060000000000000060000000060000006
00006700000000000000000000000000000000000006700000765000000550000005600000000000000000000000000006000000000000600000000006000060
00067000000000000000000000000000000000000000600000055000000050000005500000000000000000000000000000600000000006000000000000677600
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
333b0000333b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3323b0003323b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333300333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333300033333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333330003333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008800000007600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088880000076700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00768880005767000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07776800000570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777000006050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00770000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000600002435027250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000003a6703f6703c6500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a0000350503c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
