pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- orbital mechanics game
-- navigate space using gravity

-- player ship
ship={
 x=64,
 y=30,
 vx=1.2, -- velocity x
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

function _init()
 init_level()
 init_stars()
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
 ship.vx=1.2
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
  local num_planets=3+flr(level/2)
  num_planets=min(num_planets,6)

  for i=1,num_planets do
   add(planets,{
    x=20+rnd(88),
    y=40+rnd(60),
    mass=200+rnd(200),
    r=5+rnd(4),
    col=8+flr(rnd(8))
   })
  end
  goal.x=64
  goal.y=110
 end
end

function _update()
 if won then
  if btnp(4) then
   level+=1
   init_level()
  end
  return
 end

 if gameover then
  if btnp(4) then
   level=1
   score=0
   init_level()
  end
  return
 end

 -- apply thrust
 if btn(4) and ship.fuel>0 then
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
 if btn(0) then ship.angle-=0.05 end
 if btn(1) then ship.angle+=0.05 end

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
   local ax=(dx/dist)*force*0.01
   local ay=(dy/dist)*force*0.01

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
  -- highlight
  circfill(p.x-1,p.y-1,p.r/2,7)
  -- shadow
  circfill(p.x+1,p.y+1,p.r/3,0)

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
 print("⬅➡:rotate z:thrust",6,120,5)

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
