pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- orbital mechanics game
-- navigate space using gravity

-- player ship
ship={
 x=64,
 y=30,
 vx=0, -- velocity x
 vy=0, -- velocity y
 angle=0,
 thrust=0.08,
 fuel=100,
 max_fuel=100
}

-- planets (x, y, mass, radius, color)
planets={}

-- goal
goal={x=64,y=100,r=8,active=true}

-- stars background
stars={}

-- particles for thrust
particles={}

-- game state
score=0
level=1
gameover=false
won=false
trail={}
trail_max=30

-- demo mode
demo_mode=false
last_input_time=0
demo_timeout=300 -- 10 seconds at 30fps

function _init()
 init_level()
 init_stars()
 last_input_time=0
 demo_mode=false
end

function init_stars()
 stars={}
 for i=1,50 do
  add(stars,{
   x=rnd(128),
   y=rnd(128),
   brightness=rnd(1)
  })
 end
end

function init_level()
 trail={}
 ship.x=64
 ship.y=20
 ship.vx=0
 ship.vy=0
 ship.angle=0
 ship.fuel=100
 gameover=false
 won=false

 planets={}

 if level==1 then
  -- simple: one planet in center
  add(planets,{
   x=64,y=64,
   mass=400,r=8,
   col=12
  })
  goal.x=64
  goal.y=100

 elseif level==2 then
  -- two planets
  add(planets,{
   x=40,y=60,
   mass=300,r=7,
   col=12
  })
  add(planets,{
   x=88,y=68,
   mass=300,r=7,
   col=11
  })
  goal.x=64
  goal.y=110

 elseif level==3 then
  -- three planets in triangle
  add(planets,{
   x=64,y=50,
   mass=250,r=6,
   col=12
  })
  add(planets,{
   x=40,y=80,
   mass=250,r=6,
   col=11
  })
  add(planets,{
   x=88,y=80,
   mass=250,r=6,
   col=8
  })
  goal.x=64
  goal.y=110

 else
  -- random level
  local num_planets=3+flr(level/3)
  num_planets=min(num_planets,5)

  for i=1,num_planets do
   add(planets,{
    x=20+rnd(88),
    y=40+rnd(60),
    mass=180+rnd(150),
    r=5+rnd(3),
    col=8+flr(rnd(8))
   })
  end
  goal.x=64
  goal.y=110
 end
end

function _update()
 -- check for user input
 local has_input=btn(0) or btn(1) or btn(4)

 if has_input then
  if demo_mode then
   -- exit demo mode, reset game
   demo_mode=false
   level=1
   score=0
   init_level()
  end
  last_input_time=0
 else
  last_input_time+=1
  -- enter demo mode after timeout
  if last_input_time>=demo_timeout and not demo_mode then
   demo_mode=true
   level=1
   score=0
   init_level()
  end
 end

 if won then
  if btnp(4) or (demo_mode and t()%2<1) then
   level+=1
   init_level()
  end
  return
 end

 if gameover then
  if btnp(4) or (demo_mode and t()%2<1) then
   if not demo_mode then
    level=1
    score=0
   end
   init_level()
  end
  return
 end

 -- demo ai decisions
 local demo_thrust=false
 local demo_turn=0

 if demo_mode then
  -- improved ai: consider velocity and position
  local goal_dx=goal.x-ship.x
  local goal_dy=goal.y-ship.y
  local dist_to_goal=sqrt(goal_dx*goal_dx+goal_dy*goal_dy)

  -- calculate current speed for safety checks
  local speed=sqrt(ship.vx*ship.vx+ship.vy*ship.vy)

  -- check for danger (collision threats)
  local danger_x=0
  local danger_y=0
  local in_danger=false

  -- predict future position (more frames for high speed)
  local prediction_frames=max(10,speed*8)
  local future_x=ship.x+ship.vx*prediction_frames
  local future_y=ship.y+ship.vy*prediction_frames

  -- check planet collisions
  for p in all(planets) do
   local dx=p.x-ship.x
   local dy=p.y-ship.y
   local dist=sqrt(dx*dx+dy*dy)
   local future_dx=p.x-future_x
   local future_dy=p.y-future_y
   local future_dist=sqrt(future_dx*future_dx+future_dy*future_dy)

   -- dynamic danger threshold based on speed
   local danger_threshold=p.r+15+speed*3

   -- check if velocity is pointing toward planet
   local vel_toward_planet=0
   if speed>0.1 then
    local vel_angle=atan2(ship.vx,ship.vy)
    local planet_angle=atan2(dx,dy)
    local angle_diff=abs(vel_angle-planet_angle)
    if angle_diff>0.5 then angle_diff=1-angle_diff end
    -- if heading toward planet (angle diff < 0.25 = 90 degrees)
    if angle_diff<0.25 then
     vel_toward_planet=1-angle_diff*4
    end
   end

   -- danger if: too close, heading toward, or future collision
   if dist<danger_threshold or future_dist<p.r+8 or
      (vel_toward_planet>0.3 and dist<p.r+25) then
    in_danger=true
    -- create repulsion vector away from planet
    -- stronger repulsion when very close or moving fast
    local repulsion_strength=1
    if dist<p.r+12 then repulsion_strength=3 end
    if vel_toward_planet>0.5 then repulsion_strength*=2 end
    danger_x-=(dx/dist)*repulsion_strength
    danger_y-=(dy/dist)*repulsion_strength
   end
  end

  -- check map edges
  local edge_margin=10
  if ship.x<edge_margin or future_x<5 then
   in_danger=true
   danger_x+=1
  end
  if ship.x>128-edge_margin or future_x>123 then
   in_danger=true
   danger_x-=1
  end
  if ship.y<edge_margin or future_y<5 then
   in_danger=true
   danger_y+=1
  end
  if ship.y>128-edge_margin or future_y>123 then
   in_danger=true
   danger_y-=1
  end

  -- velocity limits based on situation
  local max_speed=2.5
  if dist_to_goal<30 then
   max_speed=1.5 -- slower near goal
  end

  -- calculate desired velocity (velocity needed to reach goal)
  local desired_vx=goal_dx*0.08
  local desired_vy=goal_dy*0.08

  -- if in danger, prioritize escape over goal
  if in_danger then
   desired_vx=danger_x*3
   desired_vy=danger_y*3
   max_speed=1.8 -- limit speed when escaping
  else
   -- limit desired velocity to max_speed
   local desired_speed=sqrt(desired_vx*desired_vx+desired_vy*desired_vy)
   if desired_speed>max_speed then
    desired_vx=(desired_vx/desired_speed)*max_speed
    desired_vy=(desired_vy/desired_speed)*max_speed
   end
  end

  -- calculate velocity error
  local vel_error_x=desired_vx-ship.vx
  local vel_error_y=desired_vy-ship.vy

  -- calculate gravity influence
  local total_gx=0
  local total_gy=0
  for p in all(planets) do
   local dx=p.x-ship.x
   local dy=p.y-ship.y
   local dist_sq=dx*dx+dy*dy
   local dist=sqrt(dist_sq)
   if dist>0.1 then
    local force=p.mass/dist_sq
    total_gx+=(dx/dist)*force*0.008
    total_gy+=(dy/dist)*force*0.008
   end
  end

  -- compensate for gravity
  vel_error_x-=total_gx*3
  vel_error_y-=total_gy*3

  -- calculate the angle we should thrust
  local thrust_angle=atan2(vel_error_x,vel_error_y)
  local angle_diff=thrust_angle-ship.angle

  -- normalize angle difference
  while angle_diff>0.5 do angle_diff-=1 end
  while angle_diff<-0.5 do angle_diff+=1 end

  -- turn toward thrust direction
  if angle_diff<-0.02 then
   demo_turn=-1
  elseif angle_diff>0.02 then
   demo_turn=1
  end

  -- thrust conditions:
  -- 1. must be aimed in the right direction
  -- 2. must have fuel
  -- 3. must need velocity correction (not moving perfectly)
  -- 4. apply velocity limiting
  local vel_error_mag=sqrt(vel_error_x*vel_error_x+vel_error_y*vel_error_y)
  local should_thrust=false

  -- check if we're moving too fast
  local too_fast=speed>max_speed

  if ship.fuel>5 and abs(angle_diff)<0.15 then
   if in_danger then
    -- in danger: always thrust to escape if aimed right way
    should_thrust=true
   elseif too_fast then
    -- moving too fast: only thrust if it will slow us down
    -- check if thrust direction opposes velocity
    local vel_angle=atan2(ship.vx,ship.vy)
    local thrust_vel_diff=abs(ship.angle-vel_angle)
    if thrust_vel_diff>0.5 then thrust_vel_diff=1-thrust_vel_diff end
    -- if thrust is opposite to velocity (>90 degrees)
    if thrust_vel_diff>0.25 then
     should_thrust=true
    end
   elseif dist_to_goal>goal.r*2 then
    -- far from goal: thrust if we need velocity correction
    if vel_error_mag>0.2 then
     should_thrust=true
    end
   else
    -- close to goal: only thrust if moving too fast
    if speed>1.2 then
     should_thrust=true
    end
   end
  end

  demo_thrust=should_thrust
 end

 -- apply thrust
 local do_thrust=(demo_mode and demo_thrust) or (not demo_mode and btn(4))
 if do_thrust and ship.fuel>0 then
  -- ai uses reduced thrust for better control
  local thrust_power=demo_mode and ship.thrust*0.5 or ship.thrust
  ship.vx+=cos(ship.angle)*thrust_power
  ship.vy+=sin(ship.angle)*thrust_power
  ship.fuel-=0.5

  -- spawn thrust particle
  add(particles,{
   x=ship.x-cos(ship.angle)*4,
   y=ship.y-sin(ship.angle)*4,
   vx=-cos(ship.angle)*0.5+rnd(0.2)-0.1,
   vy=-sin(ship.angle)*0.5+rnd(0.2)-0.1,
   life=15
  })
 end

 -- rotate ship
 if demo_mode then
  ship.angle+=demo_turn*0.05
 else
  if btn(0) then ship.angle-=0.05 end
  if btn(1) then ship.angle+=0.05 end
 end

 -- apply gravity from each planet
 for p in all(planets) do
  local dx=p.x-ship.x
  local dy=p.y-ship.y
  local dist_sq=dx*dx+dy*dy
  local dist=sqrt(dist_sq)

  -- prevent division by zero
  if dist>0.1 then
   -- f = g*m1*m2/r^2
   -- acceleration = force/mass = g*m/r^2
   local force=p.mass/dist_sq

   -- normalize and apply
   local ax=(dx/dist)*force*0.008
   local ay=(dy/dist)*force*0.008

   ship.vx+=ax
   ship.vy+=ay
  end

  -- check collision with planet
  if dist<p.r+2 then
   gameover=true
   return
  end
 end

 -- update ship position
 ship.x+=ship.vx
 ship.y+=ship.vy

 -- add to trail
 add(trail,{
  x=ship.x,
  y=ship.y
 })
 while #trail>trail_max do
  deli(trail,1)
 end

 -- update particles
 for pt in all(particles) do
  pt.x+=pt.vx
  pt.y+=pt.vy
  pt.life-=1
  if pt.life<=0 then
   del(particles,pt)
  end
 end

 -- check bounds
 if ship.x<0 or ship.x>128 or
    ship.y<0 or ship.y>128 then
  gameover=true
  return
 end

 -- check goal
 local gdx=goal.x-ship.x
 local gdy=goal.y-ship.y
 local gdist=sqrt(gdx*gdx+gdy*gdy)

 if gdist<goal.r then
  won=true
  score+=100
  score+=flr(ship.fuel)
 end
end

function _draw()
 cls(0)

 -- draw stars
 for s in all(stars) do
  local col=s.brightness>0.5 and 7 or 6
  pset(s.x,s.y,col)
 end

 -- draw trail
 for i=1,#trail do
  local fade=i/#trail
  local col=1
  if fade>0.7 then col=5 end
  if fade>0.85 then col=6 end
  pset(trail[i].x,trail[i].y,col)
 end

 -- draw planets
 for p in all(planets) do
  -- planet body (solid color)
  circfill(p.x,p.y,p.r,p.col)

  -- green outline
  circ(p.x,p.y,p.r,11)
 end

 -- draw thrust particles
 for pt in all(particles) do
  local fade=pt.life/15
  local col=10
  if fade<0.7 then col=9 end
  if fade<0.4 then col=8 end
  pset(pt.x,pt.y,col)
 end

 -- draw goal
 if not won then
  circ(goal.x,goal.y,goal.r,11)
  circ(goal.x,goal.y,goal.r-2,3)
  print("goal",goal.x-8,goal.y-2,7)
 end

 -- draw ship
 local sx=ship.x
 local sy=ship.y

 -- ship body (triangle pointing in direction)
 local nose_x=sx+cos(ship.angle)*4
 local nose_y=sy+sin(ship.angle)*4
 local left_x=sx+cos(ship.angle+0.6)*3
 local left_y=sy+sin(ship.angle+0.6)*3
 local right_x=sx+cos(ship.angle-0.6)*3
 local right_y=sy+sin(ship.angle-0.6)*3

 -- draw triangle
 line(nose_x,nose_y,left_x,left_y,7)
 line(nose_x,nose_y,right_x,right_y,7)
 line(left_x,left_y,right_x,right_y,8)

 -- thrust visual
 if btn(4) and ship.fuel>0 then
  local thrust_x=sx-cos(ship.angle)*5
  local thrust_y=sy-sin(ship.angle)*5
  local flicker=rnd(1)
  local flame_col=flicker>0.5 and 10 or 9
  line(sx,sy,thrust_x,thrust_y,flame_col)
 end

 -- ui
 print("level:"..level,2,2,7)
 print("score:"..score,2,8,7)

 -- fuel bar
 local fuel_pct=ship.fuel/ship.max_fuel
 print("fuel",90,2,7)
 rect(90,8,126,12,6)
 rectfill(91,9,90+flr(fuel_pct*35),11,11)

 -- velocity indicator
 local vel=sqrt(ship.vx*ship.vx+ship.vy*ship.vy)
 print("vel:"..flr(vel*10)/10,2,14,6)

 -- controls hint
 if demo_mode then
  print("demo mode - press any key",4,120,10)
 else
  print("⬅➡:rotate z:thrust",6,120,5)
 end

 if won then
  rectfill(20,50,108,78,0)
  rect(20,50,108,78,11)
  print("level complete!",28,56,11)
  print("score:"..score,42,64,7)
  print("press z",44,70,6)
 end

 if gameover then
  rectfill(20,50,108,78,0)
  rect(20,50,108,78,8)
  print("crashed!",42,56,8)
  print("score:"..score,42,64,7)
  print("press z",44,70,6)
 end
end

__sfx__
000100001c5501c5501855015550125500f5500c55009550065500355001550005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
