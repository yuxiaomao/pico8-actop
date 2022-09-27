pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- actop

-- sfx:
--   0: attack
--   1: player hit by enemy
--   2: pickup item
--   3: attack ranged

-- global variables
g_frames=0
g_player={}
g_player_bullets={}
g_enemies={}
g_killcnt=0
g_items={}
g_itemtypes={}

-- global constants
k_atk=5
k_atkr=4

function _init()
  _initmenu()
  _update=_updatemenu
  _draw=_drawmenu
end

function _startlevel()
  _initlevel()
  _update=_updatelevel
  _draw=_drawlevel
end

function _initlevel()
  g_frames=0
  item_manager.init()
  enemy_manager.init()
  player.init(g_player)
  bullet_manager.init()
end

function _updatelevel()
  g_frames=(g_frames+1)%30
  item_manager.update()
  enemy_manager.update()
  player.update(g_player)
  bullet_manager.update()
end

function _drawlevel()
  cls()
  item_manager.draw()
  enemy_manager.draw()
  player.draw(g_player)
  bullet_manager.draw()
  -- draw ui
  for i=1,g_player.hpmax do
    if (g_player.hp >= i) then
      spr(11,i*8-6,0)
    else
      spr(10,i*8-6,0)
    end
  end
  for i=1,g_player.mpmax do
    if (g_player.mp >= i) then
      pset(i*2,8,12)
    else
      pset(i*2,8,5)
    end
  end
  local killpos=print(g_killcnt,0,-20)
  print("\f7score: "..g_killcnt,100-killpos,0)
end
-->8
-- player

player={
  init=function(this)
    this.hpmax=3 -- const
    this.hp=3
    this.mpmax=20-- const
    this.mp=20
    this.x=64
    this.y=64
    this.dx=0
    this.dy=0
    this.face=3
    this.frame=0
    this.hitbox={x=1,y=1,w=6,h=6} -- const
    this.invulnframe=0
    this.cooldown=0 -- action cooldown
    -- melee attack
    this.atk={}
    this.atk.x=0
    this.atk.y=0
    this.atk.face=0
    this.atk.frame=0
    this.atk.hitbox={x=0,y=0,w=8,h=8} -- const
    this.atk.pow=1
    -- ranged attack manage by bullet_manager
  end,
  update=function(this)
    if (this.invulnframe > 0) this.invulnframe-=1
    if (this.cooldown > 0) this.cooldown-=1
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
    forceinsidescreen(this)
    item_manager.consumeall(this)
    -- melee attack
    if (btn(k_atk) and (this.cooldown == 0)) then
      sfx(0)
      this.atk.frame=3
      this.cooldown=10
      this.atk.face=this.face
      local atkpos=face2pos(this.atk.face)
      this.atk.x=this.x+atkpos.x*8
      this.atk.y=this.y+atkpos.y*8
    end
    if (this.atk.frame > 0) then
      enemy_manager.hitall(this.atk)
    end
    -- ranged attack (use mana)
    if (btn(k_atkr) and (this.cooldown == 0)
        and (this.mp > 0)) then
      sfx(3)
      this.mp-=1
      this.cooldown=10
      local atkpos=face2pos(this.face)
      bullet_manager.fire(this.x+atkpos.x*8+4,
                          this.y+atkpos.y*8+4,
                          this.face)
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

bullet={
  init=function(this,x,y,face)
    this.x=x
    this.y=y
    this.speed=3
    this.size=1
    local bulletpos=face2pos(face)
    this.dx=bulletpos.x*this.speed
    this.dy=bulletpos.y*this.speed
    this.hitbox={x=-1,y=-1,w=this.size+2,h=this.size+2}
    this.pow=1
  end,
  update=function(this)
    -- move
    this.x+=this.dx
    this.y+=this.dy
    -- attack
    enemy_manager.hitall(this)
  end,
  draw=function(this)
    rectfill(this.x,this.y,
             this.x+this.size,this.y+this.size,
             12)
  end,
  dead=function(this)
    return isoutofscreen(this)
  end,
}

-- manage function
-- manipulate global var g_player_bullets
bullet_manager={
  init=function()
    g_player_bullets={}
  end,
  update=function()
    foreach(g_player_bullets,bullet.update)
    -- dead objs detection after update
    for obj in all(g_player_bullets) do
      if bullet.dead(obj) then
        bullet_manager.remove(obj)
      end
    end
  end,
  draw=function()
    foreach(g_player_bullets,bullet.draw)
  end,
  fire=function(x,y,face)
    local obj={}
    bullet.init(obj,x,y,face)
    add(g_player_bullets,obj)
  end,
  remove=function(obj)
    del(g_player_bullets,obj)
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
    this.speed=0.1
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
      this.dx=cmp(g_player.x,this.x)*this.speed
      this.dy=cmp(g_player.y,this.y)*this.speed
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
      enemy_manager.spawnrnd()
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
  spawnrnd=function()
    local spawnpos=rndspawnpos()
    enemy_manager.spawn(spawnpos.x,spawnpos.y)
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
      sfx(2)
      other.hp+=1
      item_manager.remove(this)
    end
  end,
}

item_mp={
  init=function(this,x,y)
    this.type=item_mp
    this.x=x
    this.y=y
    this.hitbox={x=1,y=1,w=6,h=6}
  end,
  update=function(this)
  end,
  draw=function(this)
    spr(49,this.x,this.y)
  end,
  consume=function(this,other)
    if (collidebox(this,other)) then
      sfx(2)
      other.mp=other.mpmax
      item_manager.remove(this)
    end
  end,
}

-- manage function
-- manipulate global var g_items, g_itemtypes
item_manager={
  init=function()
    g_items={}
    g_itemtypes={item_hp, item_mp}
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

isoutofscreen=function(this)
  return ((this.x < -8) or
          (this.x > 128) or
          (this.y < -8) or
          (this.y > 128))
end

forceinsidescreen=function(this)
  if (this.x < 0) this.x=0
  if (this.x > 120) this.x=120
  if (this.y < 0) this.y=0
  if (this.y > 120) this.y=120
end

-->8
-- menu

function _initmenu()
end

function _updatemenu()
  if (btnp(5)) then
    _startlevel()
  end
end

function _drawmenu()
  cls()
  local titlex=32
  local titley=24
  -- draw title
  sspr(96,32,32,16,titlex,titley,64,32)
  sspr(112,48,16,8,titlex+48,titley+32)
  -- draw menu item
  print("press ❎ to start",titlex-2,titley+64)
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
00000000000000000006000000076000000000000000000000000000000000000000000000055000000500000005500000000000000000000000000000000000
00000000000000000007600000760000000000000000000000000000000000000000000000056700000550000006500000000000000000000000000000000000
00000000000000000000760007600000000000000000000000000000000060000000000000000670000670000067000000000000000000000000000000000000
00000055006666550000076556000000057770005500000060000000000760000000007600000067000670000670000000000000000000000000000000000000
00000065000777500000005555000000556666005670000076000000000760000000076000000006000670006700000000000000000000000000000000000000
00000670000000000000000000000000000000000067000007600000000760000000760000000000000600000000000000000000000000000000000000000000
00006700000000000000000000000000000000000006700000765000000550000005600000000000000000000000000000000000000000000000000000000000
00067000000000000000000000000000000000000000600000055000000050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
333b0000333b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3323b0003323b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333300333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333300033333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333330003333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000088000000cc000000076000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088880000cccc00000767000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007688800076ccc00057670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777680007776c000005700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777000077770000060500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00770000007700000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008888880000000050000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008188180000000555000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008188180888805555508888808888800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008888880800000767008000808000800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008888880800000767008000808000800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800800800000767008000808000800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800800888800767008888808888800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000767000000008000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000767000000008000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000008000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090909990
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090909990
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000099099909090
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000909090
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000099909090
__sfx__
000600002435027250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000003a6703f6703c6500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a0000350503c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000023550285502c5503155035550395500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
