require("fmath")

local level_min = -100fx
local level_max = 100fx
local arena_size = 150fx
local arena_rotation = 0fx
local phase = 1
local time_elapsed = 0fx
local fps = 60fx
local dt = 1fx / fps

-- Entity pools for memory efficiency
local enemy_pool = {}
local collector_pool = {}
local multiplier_particles = {}

-- Score tracking
local score_multiplier = 1fx
local base_score = 0fx

-- Phase timings (in frames)
local phase_durations = {
  [1] = 2700,   -- 45 seconds at 60 FPS
  [2] = 4500,   -- 75 seconds
  [3] = 3600,   -- 60 seconds
}

function pewpew.on_init()
  pewpew.set_level_size(level_min, level_max, level_min, level_max)
  
  -- Initialize entity pools
  for i = 1, 100 do
    table.insert(enemy_pool, {
      active = false,
      entity_id = nil,
      x = 0fx,
      y = 0fx,
      vx = 0fx,
      vy = 0fx,
      lifetime = 0fx,
      is_multiplier = false,
    })
  end
  
  for i = 1, 30 do
    table.insert(collector_pool, {
      active = false,
      entity_id = nil,
      x = 0fx,
      y = 0fx,
      vx = 0fx,
      vy = 0fx,
    })
  end
end

function pewpew.on_frame_pre_player_orientation(entities)
  time_elapsed = time_elapsed + 1
  arena_rotation = arena_rotation + (0x10000 / 3600)  -- Full rotation every 60 seconds in Phase 1
  
  -- Determine current phase
  local elapsed_sum = 0
  phase = 1
  for p = 1, 3 do
    elapsed_sum = elapsed_sum + phase_durations[p]
    if time_elapsed >= elapsed_sum then
      phase = p + 1
    else
      break
    end
  end
  
  -- Handle phase logic
  if phase == 1 then
    update_phase_1(entities)
  elseif phase == 2 then
    update_phase_2(entities)
  elseif phase == 3 then
    update_phase_3(entities)
  elseif phase == 4 then
    update_phase_4(entities)
  end
  
  -- Update all entities
  update_entities(entities)
end

function update_phase_1(entities)
  local phase_start = 0
  local phase_time = time_elapsed - phase_start
  
  -- Spawn enemies in mirrored pairs every 30 frames
  if phase_time % 30 == 0 and phase_time > 0 then
    local angle = phase_time * (0x10000 / 600)  -- Rotating angle
    local dist = 50fx
    
    -- Mirrored pair 1
    spawn_enemy(math.cos(angle) * dist, math.sin(angle) * dist, false)
    spawn_enemy(-math.cos(angle) * dist, -math.sin(angle) * dist, false)
    
    -- Mirrored pair 2 (perpendicular)
    local angle2 = angle + 0x4000
    spawn_enemy(math.cos(angle2) * dist, math.sin(angle2) * dist, false)
    spawn_enemy(-math.cos(angle2) * dist, -math.sin(angle2) * dist, false)
  end
  
  -- Increase arena rotation speed
  arena_rotation = arena_rotation + (0x10000 / 3600)
end

function update_phase_2(entities)
  local phase_start = phase_durations[1]
  local phase_time = time_elapsed - phase_start
  
  -- Exponential wave spawning - increases over time
  local spawn_rate = 20 - math.floor(phase_time / 300)  -- Decreases interval
  spawn_rate = math.max(spawn_rate, 5)
  
  if phase_time % spawn_rate == 0 and phase_time > 0 then
    -- Regular enemy
    local angle = (phase_time / 10) * (0x10000 / 360)
    spawn_enemy(
      math.cos(angle) * 60fx,
      math.sin(angle) * 60fx,
      false
    )
    
    -- Multiplier enemy (every 3rd spawn)
    if phase_time % (spawn_rate * 3) == 0 then
      local angle2 = angle + 0x8000
      spawn_enemy(
        math.cos(angle2) * 50fx,
        math.sin(angle2) * 50fx,
        true  -- is_multiplier
      )
    end
  end
end

function update_phase_3(entities)
  local phase_start = phase_durations[1] + phase_durations[2]
  local phase_time = time_elapsed - phase_start
  
  -- Spawn mothership at start of phase
  if phase_time == 0 then
    spawn_mothership(0fx, 0fx)
  end
  
  -- Continuous wave spawning from center
  if phase_time % 15 == 0 and phase_time > 0 then
    local angle = (phase_time / 5) * (0x10000 / 360)
    for i = 0, 7 do
      local a = angle + (i * 0x2000)
      spawn_enemy(
        math.cos(a) * 30fx,
        math.sin(a) * 30fx,
        false
      )
    end
  end
end

function update_phase_4(entities)
  local phase_start = phase_durations[1] + phase_durations[2] + phase_durations[3]
  local phase_time = time_elapsed - phase_start
  
  -- Extreme spawning with split arenas
  local spawn_rate = 8
  
  if phase_time % spawn_rate == 0 and phase_time > 0 then
    -- Arena 1 (top-left quadrant)
    spawn_enemy(-50fx + fmath.random() * 40fx, 30fx + fmath.random() * 30fx, false)
    
    -- Arena 2 (top-right quadrant)
    spawn_enemy(30fx + fmath.random() * 40fx, 30fx + fmath.random() * 30fx, false)
    
    -- Arena 3 (bottom-left quadrant)
    spawn_enemy(-50fx + fmath.random() * 40fx, -50fx + fmath.random() * 30fx, false)
    
    -- Arena 4 (bottom-right quadrant)
    spawn_enemy(30fx + fmath.random() * 40fx, -50fx + fmath.random() * 30fx, false)
    
    -- Occasional multiplier
    if phase_time % 40 == 0 then
      local qx = fmath.random() * 2 - 1
      local qy = fmath.random() * 2 - 1
      spawn_enemy(qx * 40fx, qy * 40fx, true)
    end
  end
end

function spawn_enemy(x, y, is_multiplier)
  -- Find available slot in pool
  for i = 1, #enemy_pool do
    if not enemy_pool[i].active then
      local angle = fmath.atan2(y, x)
      local speed = 20fx
      
      if is_multiplier then
        speed = 15fx
      end
      
      enemy_pool[i].active = true
      enemy_pool[i].x = x
      enemy_pool[i].y = y
      enemy_pool[i].vx = math.cos(angle) * speed
      enemy_pool[i].vy = math.sin(angle) * speed
      enemy_pool[i].lifetime = 0fx
      enemy_pool[i].is_multiplier = is_multiplier
      
      -- Create actual entity
      local entity_id = pewpew.new_customizable_entity(x, y)
      local color = is_multiplier and 0xff00ff or 0x00ffff  -- Magenta for multiplier, cyan for regular
      pewpew.customizable_entity_set_color(entity_id, color)
      
      enemy_pool[i].entity_id = entity_id
      break
    end
  end
end

function spawn_mothership(x, y)
  -- Create mothership as large entity
  local mothership_id = pewpew.new_customizable_entity(x, y)
  pewpew.customizable_entity_set_color(mothership_id, 0xff6600)  -- Orange
  -- Set mothership mesh if available (would use mesh exporter)
end

function update_entities(entities)
  -- Update enemy pool
  for i = 1, #enemy_pool do
    if enemy_pool[i].active then
      local enemy = enemy_pool[i]
      enemy.lifetime = enemy.lifetime + dt
      
      -- Update position
      enemy.x = enemy.x + enemy.vx * dt
      enemy.y = enemy.y + enemy.vy * dt
      
      -- Update entity position
      if enemy.entity_id then
        pewpew.customizable_entity_set_position(
          enemy.entity_id,
          enemy.x,
          enemy.y
        )
      end
      
      -- Remove if out of bounds
      if enemy.x < level_min or enemy.x > level_max or
         enemy.y < level_min or enemy.y > level_max or
         enemy.lifetime > 600fx then
        if enemy.entity_id then
          pewpew.delete_entity(enemy.entity_id)
        end
        enemy.active = false
      end
    end
  end
end

function pewpew.on_frame_post_player_collision(entities, collisions, projectiles)
  -- Handle projectile-enemy collisions
  for _, collision in ipairs(collisions) do
    if collision.projectile_owner == pewpew.player_id then
      for i = 1, #enemy_pool do
        if enemy_pool[i].active and enemy_pool[i].entity_id == collision.entity_id then
          if enemy_pool[i].is_multiplier then
            score_multiplier = score_multiplier * 1.5fx
          end
          
          base_score = base_score + (100fx * score_multiplier)
          
          if enemy_pool[i].entity_id then
            pewpew.delete_entity(enemy_pool[i].entity_id)
          end
          enemy_pool[i].active = false
          break
        end
      end
    end
  end
end

function pewpew.on_frame_post_player_projectile_collision(entities, collisions, projectiles)
  -- Additional collision handling if needed
end

-- Helper function to get random value (fixed point)
function fmath.random()
  return math.random() * 65536fx / 65536fx
end
