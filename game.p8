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
  -- simple ai: aim toward goal
  local goal_dx=goal.x-ship.x
  local goal_dy=goal.y-ship.y
  local angle_to_goal=atan2(goal_dx,goal_dy)
  local angle_diff=angle_to_goal-ship.angle

  -- normalize angle difference
  while angle_diff>0.5 do angle_diff-=1 end
  while angle_diff<-0.5 do angle_diff+=1 end

  -- turn toward goal
  if angle_diff<-0.02 then
   demo_turn=-1
  elseif angle_diff>0.02 then
   demo_turn=1
  end

  -- thrust if fuel available and somewhat aimed
  if ship.fuel>20 and abs(angle_diff)<0.2 then
   demo_thrust=true
  end
 end

 -- apply thrust
 local do_thrust=(demo_mode and demo_thrust) or (not demo_mode and btn(4))
 if do_thrust and ship.fuel>0 then
  ship.vx+=cos(ship.angle)*ship.thrust
  ship.vy+=sin(ship.angle)*ship.thrust
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
  -- planet body
  circfill(p.x,p.y,p.r,p.col)

  -- surface details (craters/terrain)
  for i=1,3 do
   local cx=p.x+(rnd(p.r*1.4)-p.r*0.7)
   local cy=p.y+(rnd(p.r*1.4)-p.r*0.7)
   local dx=cx-p.x
   local dy=cy-p.y
   -- only draw if within planet
   if dx*dx+dy*dy<p.r*p.r then
    circfill(cx,cy,1+rnd(1.5),p.col-1)
   end
  end

  -- atmospheric highlight (crescent)
  local hl_size=p.r*0.6
  circfill(p.x-p.r*0.3,p.y-p.r*0.3,hl_size,7)
  circfill(p.x-p.r*0.3+1,p.y-p.r*0.3+1,hl_size*0.7,p.col+1)

  -- terminator shadow (darker edge)
  circ(p.x+p.r*0.3,p.y+p.r*0.3,p.r*0.8,p.col-2)

  -- draw gravity field (subtle)
  circ(p.x,p.y,p.r+3,p.col-1)
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
