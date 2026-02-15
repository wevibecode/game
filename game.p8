pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- frog-tastic
-- a frogger-style game

-- player
p={x=64,y=120,w=6,h=6,has_gun=true}

-- player trail
trail={}
trail_max=8 -- number of trail particles

-- gun and bullets
bullets={}
bullet_speed=3
shoot_cooldown=0
shoot_delay=15 -- frames between shots

-- game state
lives=3
score=0
high_score=0
level=1
max_level=5
best_level=1 -- best level reached
gameover=false
won=false
levelcomplete=false
transition_timer=0
transition_delay=2*30 -- 2 sec
finalwin=false
death_pause=false
death_timer=0
death_delay=10 -- ~0.33 sec

-- death screen
death_screen=false
death_cause="" -- "car", "lava", "hawk"
death_screen_timer=0
death_screen_duration=2*30 -- 2 seconds

-- demo mode
demo_mode=false
idle_time=0
idle_timeout=10*30 -- 10 sec
gameover_time=0
gameover_cooldown=120*30 -- 2 min
demo_dir=0 -- ai direction

-- auto restart
restart_timer=0
restart_delay=3*30 -- 3 sec

-- lanes (y, speed, type)
-- type: 0=safe, 1=car, 2=log
-- base speeds (scaled by level)
base_lanes={
 {y=112,spd=0,t=0},  -- start
 {y=104,spd=0.3,t=1},
 {y=96,spd=-0.4,t=1},
 {y=88,spd=0.35,t=1},
 {y=80,spd=-0.5,t=1},
 {y=72,spd=0,t=0},   -- middle
 {y=64,spd=0.4,t=2},
 {y=56,spd=-0.5,t=2},
 {y=48,spd=0.6,t=2},
 {y=40,spd=-0.4,t=2},
 {y=32,spd=0,t=0},   -- goal
}
lanes={}

-- obstacles per lane
obstacles={}

-- mushroom collectibles
mushrooms={}
max_mushrooms=3
slow_timer=0
slow_duration=4*30 -- 4 seconds
slow_factor=0.3 -- obstacles move at 30% speed

-- heart powerup
hearts={}
max_hearts=1
heart_spawn_timer=0
heart_spawn_delay=15*30 -- 15 seconds between spawn attempts
heart_spawn_chance=0.3 -- 30% chance to spawn

-- hawks (rare flying enemies)
hawks={}
hawk_spawn_timer=0
hawk_spawn_delay=45 -- ~1.5 seconds between spawns
hawk_spawn_chance=0.85 -- 85% chance when timer expires

-- car spawning system
car_spawn_timer=0
car_spawn_delay=60 -- ~2 seconds between spawn checks
min_cars_per_lane=2 -- minimum cars to maintain per lane

-- combo meter
combo=0

-- countdown timer
timer=0 -- frames remaining
timer_max=30*30 -- 30 seconds per level
time_bonus_awarded=false

-- fps counter
fps=0
fps_counter=0
fps_timer=0

function _init()
 init_level()
 init_trail()
 spawn_mushrooms()
 bullets={}
 shoot_cooldown=0
 hawks={}
 hawk_spawn_timer=0
 car_spawn_timer=0
 hearts={}
 heart_spawn_timer=0
end

function init_trail()
 trail={}
end

function init_level()
 -- scale difficulty by level
 -- start easier (0.5x speed) and increase gradually
 local difficulty=0.5+(level-1)*0.08
 lanes={}
 for i=1,#base_lanes do
  local bl=base_lanes[i]
  add(lanes,{
   y=bl.y,
   spd=bl.spd*difficulty,
   t=bl.t
  })
 end
 init_obstacles()
 -- reset timer for new level
 timer=timer_max
 time_bonus_awarded=false
end

function init_obstacles()
 obstacles={}
 -- add more obstacles gradually
 local car_count=min(2+flr(level/3),4)
 local log_count=max(4-flr(level/5),2)

 for i=1,#lanes do
  obstacles[i]={}
  local lane=lanes[i]
  if lane.t==1 then
   -- cars with ai behavior
   for j=1,car_count do
    local is_hunter=rnd()<0.3 -- 30% chance of hunter car
    add(obstacles[i],{
     x=(j-1)*(128/car_count)+rnd(10),
     y=lane.y-3,
     w=12,
     h=6,
     col=is_hunter and 8 or 6, -- red=hunter, silver=normal
     spd_var=0.5+rnd(1), -- speed variance 0.5-1.5x
     hunt=is_hunter, -- hunting behavior
     hunt_cd=0, -- hunting cooldown
     wobble=rnd(), -- wobble phase for unpredictability
     hp=3, -- hit points (cars take 3 hits to destroy)
     max_hp=3 -- maximum hp for visual feedback
    })
   end
  elseif lane.t==2 then
   -- logs with gaps and contraction
   for j=1,log_count do
    local base_w=20+rnd(10) -- variable log size
    add(obstacles[i],{
     x=(j-1)*64+rnd(30),
     y=lane.y-3,
     w=base_w,
     h=6,
     base_w=base_w,
     contract=rnd()<0.4, -- 40% chance of contracting log
     contract_phase=rnd()*3.14
    })
   end
  end
 end
end

function spawn_mushrooms()
 -- spawn multiple mushrooms on random safe lanes
 mushrooms={}
 local safe_lanes={}
 for i=1,#lanes do
  if lanes[i].t==0 then
   add(safe_lanes,i)
  end
 end

 if #safe_lanes>0 then
  for i=1,max_mushrooms do
   local lane_idx=safe_lanes[flr(rnd(#safe_lanes))+1]
   add(mushrooms,{
    x=flr(rnd(110))+10,
    y=lanes[lane_idx].y-2,
    w=6,
    h=6,
    active=true
   })
  end
 end
end

function spawn_heart()
 -- spawn heart on a random safe lane
 -- only spawn if we don't already have max hearts
 if #hearts>=max_hearts then return end

 local safe_lanes={}
 for i=1,#lanes do
  if lanes[i].t==0 then
   add(safe_lanes,i)
  end
 end

 if #safe_lanes>0 then
  local lane_idx=safe_lanes[flr(rnd(#safe_lanes))+1]
  add(hearts,{
   x=flr(rnd(110))+10,
   y=lanes[lane_idx].y-2,
   w=6,
   h=6,
   active=true
  })
 end
end

function _update()
 -- update fps counter
 fps_counter+=1
 fps_timer+=1
 if fps_timer>=30 then
  fps=flr((fps_counter/fps_timer)*30)
  fps_counter=0
  fps_timer=0
 end

 -- handle death screen
 if death_screen then
  death_screen_timer+=1
  if death_screen_timer>=death_screen_duration then
   death_screen=false
   death_screen_timer=0
   death_cause=""
  end
  return
 end

 -- handle death pause
 if death_pause then
  death_timer+=1
  if death_timer>=death_delay then
   death_pause=false
   death_timer=0
  end
  return
 end

 -- handle level transition
 if levelcomplete then
  transition_timer+=1
  if transition_timer>=transition_delay then
   advance_level()
  end
  return
 end

 -- handle game over
 if gameover then
  restart_timer+=1
  -- in demo mode, restart immediately
  if demo_mode then
   reset_game()
   demo_mode=true
   return
  end
  if btnp(4) or restart_timer>=restart_delay then
   reset_game()
  end
  return
 end

 -- handle final win
 if finalwin then
  restart_timer+=1
  if demo_mode then
   reset_game()
   demo_mode=true
   return
  end
  if btnp(4) or restart_timer>=restart_delay then
   reset_game()
  end
  return
 end

 -- check for player input
 local has_input=btnp(0) or btnp(1) or btnp(2) or btnp(3)

 if has_input then
  -- exit demo mode
  if demo_mode then
   reset_game()
   demo_mode=false
  end
  idle_time=0
 else
  -- track idle time
  idle_time+=1

  -- check demo activation
  local can_demo=true
  if gameover_time>0 then
   if time()-gameover_time<gameover_cooldown/30 then
    can_demo=false
   end
  end

  if idle_time>=idle_timeout and can_demo then
   demo_mode=true
  end
 end

 -- move player
 if not demo_mode then
  if btnp(0) then p.x-=8 end
  if btnp(1) then p.x+=8 end
  if btnp(2) then p.y-=8 end
  if btnp(3) then p.y+=8 end

  -- shoot with button 4 (x button)
  if p.has_gun and btnp(4) and shoot_cooldown<=0 then
   shoot_bullet()
   shoot_cooldown=shoot_delay
  end
 else
  -- demo ai movement
  update_demo_ai()
 end

 -- clamp player
 p.x=mid(2,p.x,122)
 p.y=mid(32,p.y,120)

 -- update trail
 update_trail()

 -- snap to lane row
 local ly=flr((120-p.y)/8)+1
 if ly>=1 and ly<=#lanes then
  p.y=lanes[ly].y+1
 end

 -- update countdown timer
 if timer>0 then
  timer-=1
 end

 -- update slow effect timer
 if slow_timer>0 then
  slow_timer-=1
 end

 -- update shoot cooldown
 if shoot_cooldown>0 then
  shoot_cooldown-=1
 end

 -- update hawk spawning
 hawk_spawn_timer+=1
 if hawk_spawn_timer>=hawk_spawn_delay then
  hawk_spawn_timer=0
  if rnd()<hawk_spawn_chance then
   spawn_hawk()
  end
 end

 -- update heart spawning
 heart_spawn_timer+=1
 if heart_spawn_timer>=heart_spawn_delay then
  heart_spawn_timer=0
  if rnd()<heart_spawn_chance then
   spawn_heart()
  end
 end

 -- update car spawning (dynamic spawn when low)
 car_spawn_timer+=1
 if car_spawn_timer>=car_spawn_delay then
  car_spawn_timer=0
  spawn_cars_if_needed()
 end

 -- update hawks
 for h in all(hawks) do
  h.x+=h.spd
  h.wing_phase+=0.15

  -- remove hawks that go off screen
  if h.spd>0 and h.x>136 then
   del(hawks,h)
  elseif h.spd<0 and h.x<-16 then
   del(hawks,h)
  end
 end

 -- update bullets
 for b in all(bullets) do
  b.x+=b.vx
  b.y+=b.vy
  -- remove bullets that go off screen
  if b.y<0 or b.y>128 or b.x<0 or b.x>128 then
   del(bullets,b)
  end
 end

 -- move obstacles (with slow effect if active)
 local speed_mult=1
 if slow_timer>0 then
  speed_mult=slow_factor
 end

 for i=1,#lanes do
  local lane=lanes[i]
  if lane.spd!=0 then
   for obs in all(obstacles[i]) do
    -- car ai: hunting and wobbling
    if lane.t==1 then
     local base_spd=lane.spd*obs.spd_var*speed_mult

     -- hunter cars track player
     if obs.hunt and obs.hunt_cd<=0 then
      local dx=p.x-obs.x
      local same_row=(abs(p.y-obs.y)<12)

      if same_row and abs(dx)<48 then
       -- accelerate toward player
       if (dx>0 and base_spd>0) or (dx<0 and base_spd<0) then
        base_spd=base_spd*1.8
       end
       obs.hunt_cd=15 -- cooldown
      end
     else
      obs.hunt_cd=max(0,obs.hunt_cd-1)
     end

     -- wobble movement for unpredictability
     obs.wobble+=0.05
     local wobble_offset=sin(obs.wobble)*0.3

     obs.x+=base_spd+wobble_offset

    -- log ai: contracting platforms
    elseif lane.t==2 then
     obs.x+=lane.spd*speed_mult

     -- contract and expand
     if obs.contract then
      obs.contract_phase+=0.03
      local contract_amt=sin(obs.contract_phase)*8
      obs.w=max(12,obs.base_w+contract_amt)
     end
    else
     -- normal movement
     obs.x+=lane.spd*speed_mult
    end

    -- wrap around
    if obs.x>128 then obs.x=-obs.w end
    if obs.x<-obs.w then obs.x=128 end
   end
  end
 end

 -- check collisions
 check_collisions()

 -- check mushroom collection
 for m in all(mushrooms) do
  if m.active and collide(p,m) then
   -- increment combo
   combo+=1
   -- calculate combo multiplier (1x, 2x, 3x, etc.)
   local multiplier=combo
   local points=100*multiplier
   score+=points
   -- update high score immediately
   if score>high_score then
    high_score=score
   end
   m.active=false
   slow_timer=slow_duration
   sfx(3) -- collect sound
  end
 end

 -- check heart collection
 for h in all(hearts) do
  if h.active and collide(p,h) then
   -- restore one life (but don't exceed 3)
   if lives<3 then
    lives+=1
    sfx(2) -- positive sound
   end
   h.active=false
   del(hearts,h)
  end
 end

 -- check bullet collisions with cars
 for b in all(bullets) do
  local ly=flr((120-b.y)/8)+1
  if ly>=1 and ly<=#lanes and lanes[ly].t==1 then
   for obs in all(obstacles[ly]) do
    if collide(b,obs) then
     -- damage the car
     obs.hp-=1
     del(bullets,b)

     -- destroy car if hp reaches 0
     if obs.hp<=0 then
      del(obstacles[ly],obs)
      score+=50
      -- update high score
      if score>high_score then
       high_score=score
      end
      sfx(3) -- destruction sound
     else
      -- flash white when damaged but not destroyed
      obs.col=7
      sfx(3) -- hit sound
     end
     break
    end
   end
  end
 end

 -- check bullet collisions with hawks
 for b in all(bullets) do
  for h in all(hawks) do
   if collide(b,h) then
    -- destroy the hawk and bullet
    del(hawks,h)
    del(bullets,b)
    score+=100 -- hawks are worth more
    -- update high score
    if score>high_score then
     high_score=score
    end
    sfx(3)
    break
   end
  end
 end

 -- check hawk collisions with player
 for h in all(hawks) do
  if collide(p,h) then
   die("hawk")
   break
  end
 end

 -- check win
 if p.y<=32 then
  win_level()
 end
end

function check_collisions()
 local ly=flr((120-p.y)/8)+1
 if ly<1 or ly>#lanes then return end

 local lane=lanes[ly]

 if lane.t==0 then
  -- safe lane (grass) - no collision check needed
  return
 elseif lane.t==1 then
  -- car lane - check hit
  for obs in all(obstacles[ly]) do
   if collide(p,obs) then
    die("car")
    return
   end
  end
 elseif lane.t==2 then
  -- lava lane - check on platform
  local on_log=false
  for obs in all(obstacles[ly]) do
   if collide(p,obs) then
    on_log=true
    p.x+=lane.spd
    break
   end
  end
  if not on_log then
   die("lava")
   return
  end
 end
end

function collide(a,b)
 return a.x<b.x+b.w and
        a.x+a.w>b.x and
        a.y<b.y+b.h and
        a.y+a.h>b.y
end

function shoot_bullet()
 -- create bullets in 4 cardinal directions only
 local center_x=p.x+p.w/2-1
 local center_y=p.y+p.h/2-2

 -- 4 cardinal directions: up, down, left, right
 local directions={
  {vx=0,vy=-1},   -- up
  {vx=0,vy=1},    -- down
  {vx=-1,vy=0},   -- left
  {vx=1,vy=0}     -- right
 }

 -- create a bullet for each direction
 for dir in all(directions) do
  add(bullets,{
   x=center_x,
   y=center_y,
   w=2,
   h=2,
   vx=dir.vx*bullet_speed,
   vy=dir.vy*bullet_speed
  })
 end

 -- play quick beep sound effect
 sfx(3)
end

function spawn_hawk()
 -- spawn hawk from left or right side
 local from_left=rnd()<0.5
 local start_x=from_left and -12 or 136
 local spd=from_left and 1.5 or -1.5

 -- spawn at a random y position in playable area
 local spawn_y=40+flr(rnd(70))

 add(hawks,{
  x=start_x,
  y=spawn_y,
  w=10,
  h=6,
  spd=spd,
  wing_phase=0
 })
end

function spawn_cars_if_needed()
 -- check each car lane and spawn if below minimum
 for i=1,#lanes do
  local lane=lanes[i]
  if lane.t==1 then
   local car_count=#obstacles[i]

   -- spawn rate increases as car count decreases
   if car_count<min_cars_per_lane then
    -- higher chance when fewer cars (100% when 0, 50% when 1)
    local spawn_chance=1-(car_count/min_cars_per_lane)*0.5

    if rnd()<spawn_chance then
     -- spawn from appropriate side based on lane direction
     local from_left=lane.spd>0
     local start_x=from_left and -14 or 136
     local is_hunter=rnd()<0.3 -- 30% chance of hunter car

     add(obstacles[i],{
      x=start_x,
      y=lane.y-3,
      w=12,
      h=6,
      col=is_hunter and 8 or 6,
      spd_var=0.5+rnd(1),
      hunt=is_hunter,
      hunt_cd=0,
      wobble=rnd(),
      hp=3,
      max_hp=3
     })
    end
   end
  end
 end
end

function die(cause)
 -- show death screen
 death_screen=true
 death_screen_timer=0
 death_cause=cause or "unknown"

 -- play death melody (4 descending notes)
 sfx(0)

 -- reset combo on hit
 combo=0

 lives-=1
 if lives<=0 then
  gameover=true
  -- update high score
  if score>high_score then
   high_score=score
  end
  -- update best level
  if level>best_level then
   best_level=level
  end
  if not demo_mode then
   gameover_time=time()
  end
 else
  p.x=64
  p.y=120
 end
end

function win_level()
 score+=100*level

 -- award time bonus if timer hasn't expired
 if timer>0 and not time_bonus_awarded then
  local time_bonus=flr((timer/30)*50) -- up to 50 points per second remaining
  score+=time_bonus
  time_bonus_awarded=true
 end

 -- update high score immediately
 if score>high_score then
  high_score=score
 end
 -- play goal reached sound
 sfx(2)

 -- check if final level
 if level>=max_level then
  finalwin=true
 else
  levelcomplete=true
 end
end

function advance_level()
 level+=1
 levelcomplete=false
 transition_timer=0
 p.x=64
 p.y=120
 init_level()
 spawn_mushrooms()
end

function reset_game()
 p.x=64
 p.y=120
 p.has_gun=true
 lives=3
 score=0
 level=1
 combo=0
 slow_timer=0
 timer=timer_max
 time_bonus_awarded=false
 gameover=false
 levelcomplete=false
 finalwin=false
 idle_time=0
 demo_mode=false
 restart_timer=0
 transition_timer=0
 death_pause=false
 death_timer=0
 death_screen=false
 death_screen_timer=0
 death_cause=""
 bullets={}
 shoot_cooldown=0
 hawks={}
 hawk_spawn_timer=0
 car_spawn_timer=0
 hearts={}
 heart_spawn_timer=0
 init_level()
 init_trail()
 spawn_mushrooms()
 -- play start jingle
 sfx(1)
end

function update_trail()
 -- add current position to trail
 add(trail,{
  x=p.x+p.w/2,
  y=p.y+p.h/2,
  age=0
 })

 -- age existing trail particles
 for t in all(trail) do
  t.age+=1
 end

 -- remove old particles
 while #trail>trail_max do
  deli(trail,1)
 end
end

function update_demo_ai()
 -- improved ai: smarter pathing and timing
 local ly=flr((120-p.y)/8)+1
 local lane=lanes[ly]

 -- demo ai gun usage - shoot at nearby threats
 if p.has_gun and shoot_cooldown<=0 then
  local should_shoot=false

  -- check for hawks in range
  for h in all(hawks) do
   local dist_x=abs(h.x-p.x)
   local dist_y=abs(h.y-p.y)
   if dist_x<40 and h.y<p.y and dist_y<50 then
    should_shoot=true
    break
   end
  end

  -- check for cars ahead in next few lanes
  if not should_shoot then
   for check_ly=ly+1,min(ly+3,#lanes) do
    if lanes[check_ly].t==1 then
     for obs in all(obstacles[check_ly]) do
      local dist_x=abs(obs.x-p.x)
      if dist_x<25 then
       should_shoot=true
       break
      end
     end
    end
    if should_shoot then break end
   end
  end

  -- shoot more frequently in demo mode
  if should_shoot or (idle_time%40==0 and rnd()<0.4) then
   shoot_bullet()
   shoot_cooldown=shoot_delay
  end
 end

 -- collect mushrooms if nearby
 for m in all(mushrooms) do
  if m.active then
   local dist=abs(m.x-p.x)+abs(m.y-p.y)
   if dist<24 and ly<=3 then
    -- move toward mushroom
    if abs(m.x-p.x)>4 then
     if m.x>p.x then p.x+=8 end
     if m.x<p.x then p.x-=8 end
    end
    -- return to avoid other logic
    p.x=mid(2,p.x,122)
    return
   end
  end
 end

 -- try to move up with better timing
 -- use a frame counter instead of time() for more consistent movement
 if true then
  local safe=true
  local next_ly=ly+1

  if next_ly<=#lanes then
   local next_lane=lanes[next_ly]

   if next_lane.t==1 then
    -- improved car avoidance with prediction
    safe=check_car_lane_safe(next_ly,p.x,next_lane.spd)
   elseif next_lane.t==2 then
    -- improved log timing
    safe=check_log_lane_safe(next_ly,p.x)
   end
  end

  -- move every 20 frames when safe
  if safe and p.y>32 and (idle_time%20==0) then
   p.y-=8
  elseif not safe or p.y<=32 then
   -- try lateral movement to find safe path
   local left_safe=false
   local right_safe=false

   if next_ly<=#lanes then
    local next_lane=lanes[next_ly]
    if next_lane.t==1 then
     left_safe=check_car_lane_safe(next_ly,p.x-8,next_lane.spd)
     right_safe=check_car_lane_safe(next_ly,p.x+8,next_lane.spd)
    elseif next_lane.t==2 then
     left_safe=check_log_lane_safe(next_ly,p.x-8)
     right_safe=check_log_lane_safe(next_ly,p.x+8)
    end
   end

   -- move to safer position every 10 frames
   if (idle_time%10==0) then
    if left_safe and p.x>10 then
     p.x-=8
    elseif right_safe and p.x<118 then
     p.x+=8
    end
   end
  end
 end

 -- move with log intelligently
 if lane.t==2 then
  local on_log=false
  for obs in all(obstacles[ly]) do
   if collide(p,obs) then
    on_log=true
    p.x+=lane.spd
    -- move toward center of log for safety
    local log_center=obs.x+obs.w/2
    if abs(p.x-log_center)>4 then
     if p.x<log_center and p.x<118 then p.x+=0.5 end
     if p.x>log_center and p.x>10 then p.x-=0.5 end
    end
    break
   end
  end
 end

 -- stay on screen
 p.x=mid(2,p.x,122)
 p.y=mid(32,p.y,120)

 -- snap to lane row
 local demo_ly=flr((120-p.y)/8)+1
 if demo_ly>=1 and demo_ly<=#lanes then
  p.y=lanes[demo_ly].y+1
 end
end

function check_car_lane_safe(lane_idx,check_x,spd)
 -- predict car positions 15 frames ahead
 local prediction=15
 for obs in all(obstacles[lane_idx]) do
  -- calculate future position
  local future_x=obs.x
  local check_spd=obs.spd_var or 1

  -- account for hunter behavior
  if obs.hunt and obs.hunt_cd<=0 then
   check_spd*=1.8
  end

  future_x+=lanes[lane_idx].spd*check_spd*prediction

  -- check collision zone (wider for safety)
  if abs(future_x-check_x)<20 then
   return false
  end

  -- also check current position
  if abs(obs.x-check_x)<18 then
   return false
  end
 end
 return true
end

function check_log_lane_safe(lane_idx,check_x)
 -- find closest log and check if we can land on it
 local best_log=nil
 local best_dist=999

 for obs in all(obstacles[lane_idx]) do
  local dist=abs(obs.x+obs.w/2-check_x)
  if dist<best_dist then
   best_dist=dist
   best_log=obs
  end
 end

 if best_log then
  -- check if we'll land on the log
  local log_left=best_log.x
  local log_right=best_log.x+best_log.w

  -- account for contracting logs
  if best_log.contract then
   local contract_amt=sin(best_log.contract_phase)*8
   local future_w=max(12,best_log.base_w+contract_amt)
   log_right=best_log.x+future_w
  end

  -- need to be comfortably on the log
  return check_x>=log_left+2 and check_x<=log_right-8
 end

 return false
end

function _draw()
 cls(0)

 -- draw lanes
 for i=1,#lanes do
  local lane=lanes[i]
  local col=5 -- gray
  if lane.t==0 then col=3 end -- green
  if lane.t==2 then
   -- lava effect with flickering
   local flicker=flr(time()*8)%2
   col=flicker==0 and 9 or 8 -- orange/red flicker
  end
  rectfill(0,lane.y-4,127,lane.y+4,col)

  -- add lava bubbles/spots
  if lane.t==2 then
   local bubble_phase=time()*2
   for j=0,15 do
    local bx=(j*8+flr(sin(bubble_phase+j)*3))%128
    local by=lane.y+sin(bubble_phase*1.5+j)*2
    local bubble_col=10 -- yellow highlights
    pset(bx,by,bubble_col)
   end
  end
 end

 -- draw obstacles
 for i=1,#lanes do
  local lane=lanes[i]
  for obs in all(obstacles[i]) do
   local col=8
   if lane.t==1 then col=obs.col or 8 end -- car (red or silver)
   if lane.t==2 then col=0 end -- black rock platforms in lava
   rectfill(obs.x,obs.y,
            obs.x+obs.w,obs.y+obs.h,col)

   -- fire effects for cars
   if lane.t==1 then
    -- pulsing glow outline
    local glow_phase=time()*4
    local glow_intensity=sin(glow_phase)*0.5+0.5
    if glow_intensity>0.6 then
     rect(obs.x-1,obs.y-1,obs.x+obs.w+1,obs.y+obs.h+1,9) -- orange glow
    end

    -- flame particles above cars
    for j=0,2 do
     local fx=obs.x+2+j*4+sin(time()*3+j)*2
     local fy=obs.y-2-rnd(3)
     local flame_phase=(time()*5+j)%1

     -- rising flames with color transition
     if flame_phase<0.3 then
      pset(fx,fy,10) -- yellow core
     elseif flame_phase<0.6 then
      pset(fx,fy,9) -- orange
     else
      pset(fx,fy,8) -- red
     end

     -- additional flame particle
     if rnd()<0.5 then
      pset(fx+1,fy-1,10)
     end
    end

    -- glowing ember particles
    local ember_x=obs.x+rnd(obs.w)
    local ember_y=obs.y-1-rnd(2)
    if rnd()<0.3 then
     pset(ember_x,ember_y,10) -- yellow ember
    end
   end

   -- add glow effect to lava platforms
   if lane.t==2 then
    rect(obs.x,obs.y,obs.x+obs.w,obs.y+obs.h,2) -- dark red outline
   end
  end
 end

 -- draw mushrooms
 for m in all(mushrooms) do
  if m.active then
   -- mushroom cap (red with white spots)
   rectfill(m.x,m.y,
            m.x+m.w,m.y+4,8)
   -- white spots
   pset(m.x+1,m.y+1,7)
   pset(m.x+4,m.y+2,7)
   -- mushroom stem
   rectfill(m.x+2,m.y+4,
            m.x+4,m.y+m.h,6)
  end
 end

 -- draw hearts
 for h in all(hearts) do
  if h.active then
   -- heart shape with pulsing effect
   local pulse=sin(time()*4)*0.5+0.5
   local heart_col=pulse>0.5 and 8 or 14 -- red/pink pulse
   -- heart body (simple pixel heart)
   rectfill(h.x+1,h.y,h.x+2,h.y+1,heart_col)
   rectfill(h.x+3,h.y,h.x+4,h.y+1,heart_col)
   rectfill(h.x,h.y+1,h.x+5,h.y+4,heart_col)
   pset(h.x+1,h.y+4,heart_col)
   pset(h.x+2,h.y+5,heart_col)
   pset(h.x+3,h.y+4,heart_col)
   -- highlight
   pset(h.x+1,h.y,7)
   pset(h.x+3,h.y,7)
  end
 end

 -- draw trail (only when slow effect is active)
 if slow_timer>0 then
  for t in all(trail) do
   local fade=1-(t.age/trail_max)
   local size=flr(4*fade)
   if size>0 then
    -- use colors that fade: 14->10->9->4
    local col=14
    if fade<0.7 then col=10 end
    if fade<0.5 then col=9 end
    if fade<0.3 then col=4 end
    circfill(t.x,t.y,size,col)
   end
  end
 end

 -- draw bullets
 for b in all(bullets) do
  -- bullet body (yellow energy shot)
  rectfill(b.x,b.y,b.x+b.w,b.y+b.h,10)
  -- bullet glow
  pset(b.x+1,b.y-1,7)
 end

 -- draw hawks
 for h in all(hawks) do
  -- body (brown/gray)
  rectfill(h.x+2,h.y+2,h.x+8,h.y+4,4)
  -- head (darker)
  rectfill(h.x+7,h.y+1,h.x+10,h.y+3,5)
  -- beak (yellow)
  pset(h.x+10,h.y+2,10)
  -- eye
  pset(h.x+8,h.y+1,7)

  -- wings (animated)
  local wing_offset=flr(sin(h.wing_phase)*2)
  -- left wing
  line(h.x+3,h.y+2,h.x,h.y+wing_offset,6)
  line(h.x+3,h.y+3,h.x+1,h.y+1+wing_offset,6)
  -- right wing
  line(h.x+6,h.y+2,h.x+9,h.y+wing_offset,6)
  line(h.x+6,h.y+3,h.x+8,h.y+1+wing_offset,6)

  -- shadow for depth
  pset(h.x+4,h.y+5,1)
  pset(h.x+5,h.y+5,1)
 end

 -- draw player (frog)
 -- purple pants section (upper part)
 rectfill(p.x,p.y,p.x+p.w,p.y+2,2)
 -- main body of the frog (green)
 rectfill(p.x,p.y+2,p.x+p.w,p.y+p.h,3)
 -- darker belly at bottom
 rectfill(p.x,p.y+p.h-1,p.x+p.w,p.y+p.h,4)
 -- rounded front
 pset(p.x,p.y,0) -- cut corner for rounded look
 pset(p.x,p.y+1,2) -- purple pants accent
 -- back detail
 line(p.x+p.w-1,p.y,p.x+p.w-1,p.y+2,13) -- bright purple accent
 -- frog eyes (white with black pupils)
 pset(p.x+1,p.y+3,7) -- left eye white
 pset(p.x+1,p.y+3,0) -- left eye pupil
 pset(p.x+4,p.y+3,7) -- right eye white
 pset(p.x+4,p.y+3,0) -- right eye pupil

 -- draw gun if equipped
 if p.has_gun then
  -- gun barrel (silver)
  line(p.x+p.w,p.y+3,p.x+p.w+2,p.y+2,6)
  -- gun body (dark gray)
  pset(p.x+p.w,p.y+3,5)
  -- muzzle flash when shooting
  if shoot_cooldown>shoot_delay-3 then
   pset(p.x+p.w+3,p.y+2,10) -- yellow flash
   pset(p.x+p.w+2,p.y+1,7) -- white flash
  end
 end

 -- draw ui (organized header)
 -- top bar background for contrast
 rectfill(0,0,127,8,1)

 -- countdown timer (top left)
 local time_sec=flr(timer/30)
 local time_col=7
 if timer<=5*30 then time_col=8 end -- red when low
 if timer<=0 then time_col=2 end -- dark red when expired
 print("time:"..time_sec,2,2,time_col)

 -- title centered at top
 print("frog-tastic",34,2,7)

 -- high score (top right corner)
 print("hi:"..high_score,94,2,10)

 -- lives counter with frog icons (top right)
 for i=1,lives do
  local frog_x=127-(i*8)
  local frog_y=10
  -- mini frog icon
  rectfill(frog_x,frog_y,frog_x+6,frog_y+6,3) -- green body
  pset(frog_x+1,frog_y+2,7) -- left eye
  pset(frog_x+4,frog_y+2,7) -- right eye
 end

 -- second row: lives, score, level, best level
 -- lives (left)
 print("♥"..lives,2,10,8)

 -- score (left-center)
 print("sc:"..score,28,10,7)

 -- level (right-center)
 print("lv:"..level,76,10,11)

 -- best level (right)
 print("best:"..best_level,94,10,10)

 -- combo meter (third row, centered)
 if combo>0 then
  local combo_text="combo x"..combo
  local combo_x=64-(#combo_text*2)
  print(combo_text,combo_x,18,9)
 end

 -- slow effect indicator
 if slow_timer>0 then
  print("slow!",2,18,8)
 end

 -- demo mode indicator
 if demo_mode then
  print("demo",2,122,10)
 end

 -- fps counter (bottom right)
 print("fps:"..fps,96,122,11)

 -- draw goal zone
 print("goal",54,34,7)

 if gameover then
  rectfill(24,50,104,78,0)
  rect(24,50,104,78,7)
  print("game over!",38,56,8)
  print("final score:"..score,30,64,7)
  print("best level:"..best_level,32,70,10)
  print("press z",42,76,6)
 end

 if levelcomplete then
  rectfill(24,50,104,78,0)
  rect(24,50,104,78,7)
  print("level "..level-1 .." complete!",28,56,11)
  print("score:"..score,40,64,7)
  print("next level...",32,70,10)
 end

 if finalwin then
  rectfill(24,50,104,78,0)
  rect(24,50,104,78,7)
  print("you win!",42,56,11)
  print("all levels done!",26,62,10)
  print("score:"..score,40,68,7)
  print("press z",42,74,6)
 end

 -- death screen with dramatic visuals
 if death_screen then
  -- full screen dark overlay
  rectfill(0,0,127,127,0)

  -- pulsing red effect
  local pulse=sin(time()*8)*0.5+0.5
  local pulse_col=pulse>0.5 and 8 or 2

  if death_cause=="car" then
   -- roadkill theme: tire tracks and impact
   -- title with flashing red
   local flash=flr(time()*16)%2==0
   local title_col=flash and 8 or 7
   print("roadkill!",42,30,title_col)

   -- tire tracks across screen
   for i=0,127,4 do
    rectfill(i,50,i+2,52,5) -- top track
    rectfill(i,76,i+2,78,5) -- bottom track
   end

   -- skid marks (diagonal lines)
   for i=0,5 do
    line(10+i*2,45-i*3,50+i*2,55-i*3,0)
    line(77+i*2,73+i*3,117+i*2,83+i*3,0)
   end

   -- impact starburst
   local cx,cy=64,64
   for i=0,7 do
    local angle=i/8
    local len=12+sin(time()*4+i)*4
    local ex=cx+cos(angle)*len
    local ey=cy+sin(angle)*len
    line(cx,cy,ex,ey,pulse_col)
    -- outer burst
    local len2=16+sin(time()*6+i)*6
    local ex2=cx+cos(angle)*len2
    local ey2=cy+sin(angle)*len2
    line(ex,ey,ex2,ey2,9) -- orange
   end

   -- splat effect (dark spots)
   for i=0,8 do
    local sx=cx+cos(i)*8+rnd(4)-2
    local sy=cy+sin(i)*8+rnd(4)-2
    circfill(sx,sy,2+rnd(2),2)
   end

   -- crushed frog silhouette
   rectfill(60,60,68,66,4)
   pset(61,61,3) -- green bit
   pset(66,62,3) -- green bit

   -- warning stripes
   for i=0,15 do
    if i%2==0 then
     rectfill(i*8,0,i*8+8,6,8)
     rectfill(i*8,121,i*8+8,127,8)
    else
     rectfill(i*8,0,i*8+8,6,10)
     rectfill(i*8,121,i*8+8,127,10)
    end
   end

  elseif death_cause=="lava" then
   -- lava theme
   local flash=flr(time()*16)%2==0
   local title_col=flash and 8 or 9
   print("burned!",44,30,title_col)

   -- lava waves/surface
   for i=0,127,8 do
    local wave_y=64+sin(time()*3+i/16)*4
    rectfill(i,wave_y,i+8,127,8) -- red lava
    rectfill(i,wave_y+2,i+8,127,9) -- orange lava
   end

   -- rising embers and fire particles
   for i=0,15 do
    local ex=10+i*7+sin(time()*2+i)*6
    local ey=100-((time()*25+i*6)%90)
    -- ember glow
    circfill(ex,ey,2+sin(time()*4+i),9) -- orange
    circfill(ex,ey,1,10) -- yellow core
    -- additional fire particles
    pset(ex+rnd(3)-1,ey-3,10) -- yellow sparks
   end

   -- heat shimmer effect (wavy lines)
   for i=0,10 do
    local sy=50+i*3
    local sx=30+sin(time()*5+i)*20
    line(sx,sy,sx+60,sy,2) -- dark red shimmer
   end

  elseif death_cause=="hawk" then
   -- hawk attack theme
   print("snatched!",38,56,14)
   -- claw marks
   for i=0,3 do
    line(40+i*3,40,50+i*3,70,8)
    line(78+i*3,40,88+i*3,70,8)
   end
   -- falling feathers
   for i=0,6 do
    local fx=30+i*15+sin(time()*3+i)*8
    local fy=30+((time()*15+i*10)%60)
    line(fx,fy,fx+2,fy+4,6)
   end
  end

  -- death message at bottom
  print("hit by "..death_cause.."!",32,100,7)
  print("lives left: "..lives,36,110,8)
 end
end

__sfx__
000100001c5501c5501855015550125500f5500c55009550065500355001550005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100000c5500f55012550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000c5500f550125501855020550245502755029550005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
00010000185501a5501c5501e550205502255024550265500050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050
