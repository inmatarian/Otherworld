----------------------------------------

function classcall(class, ...)
  local inst = {}
  setmetatable(inst, inst)
  inst.__index = class
  if inst.init then inst:init(...) end
  return inst
end

function class( superclass )
  local t = {}
  t.__index = superclass
  t.__call = classcall
  return setmetatable(t, t)
end

strict_mt = {}
strict_mt.__newindex = function( t, k, v ) error("attempt to update a read-only table", 2) end
strict_mt.__index = function( t, k ) error("attempt to read key "..k, 2) end

function strict( table )
  return setmetatable( table, strict_mt )
end

----------------------------------------

function randomPull( ... )
  local pull = math.random(0, 10000) / 10000
  for n = 1, select('#', ...) do
    local e = select(n, ...)
    if pull < e then return n end
    pull = pull - e
  end
  return nil
end

----------------------------------------

keypress = setmetatable( {}, { __index = function() return 0 end } )

WHITE = strict { 255, 255, 255, 255 }
GRAY = strict { 144, 144, 144, 255 }

----------------------------------------

StateMachine = {
  stack = {}
}

function StateMachine.push( state )
  print( "State Machine Push", state )
  table.insert( StateMachine.stack, state )
end

function StateMachine.pop()
  print( "State Machine", state )
  table.remove( StateMachine.stack )
end

function StateMachine.isEmpty()
  return ( #StateMachine.stack == 0 )
end

function StateMachine.draw()
  local n = #StateMachine.stack
  if n > 0 then
    StateMachine.stack[n]:draw()
  end
end

function StateMachine.update( dt )
  local n = #StateMachine.stack
  if n > 0 then
    StateMachine.stack[n]:update(dt)
  end
end

----------------------------------------

Sound = {
  bank = {};
  effectFiles = {};
  effectData = {};
}

function Sound.init()
  for name, file in pairs(Sound.effectFiles) do
    Sound.effectData[name] = love.sound.newSoundData(file)
  end
end

function Sound.playsound(name)
  local sound = love.audio.newSource(Sound.effectData[name])
  Sound.bank[sound] = sound
  love.audio.play(sound)
end

function Sound.playmod( file )
  Sound.stopmod()
  Sound.bgm = love.audio.newSource(file, "stream")
  Sound.bgm:setLooping( true )
  Sound.bgm:setVolume(0.8)
  love.audio.play(Sound.bgm)
  Sound.bgmfile = file
end

function Sound.stopmod()
  if not Sound.bgm then return end
  love.audio.stop(Sound.bgm)
  Sound.bgm = nil
  Sound.bgmfile = nil
end

function Sound.update()
  local remove = {}
  for _, src in pairs(Sound.bank) do
    if src:isStopped() then table.insert(remove, src) end
  end
  for _, src in ipairs(remove) do
    Sound.bank[src] = nil
  end
end

----------------------------------------

Graphics = {
  gameWidth = 320,
  gameHeight = 240,
  tileBounds = strict {
  },
  quads = {},
  fontset = [==[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~]==],
}
Graphics.xScale = math.floor(love.graphics.getWidth() / Graphics.gameWidth)
Graphics.yScale = math.floor(love.graphics.getHeight() / Graphics.gameHeight)

function Graphics.init()
  love.graphics.setColorMode("modulate")
  love.graphics.setBlendMode("alpha")
  Graphics.loadFont("cgafont.png")
  Graphics.loadTileset("tileset.png")
end

function Graphics.loadTileset(name)
  Graphics.tilesetImage = love.graphics.newImage(name)
  Graphics.tilesetImage:setFilter("nearest", "nearest")
  local sw, sh = Graphics.tilesetImage:getWidth(), Graphics.tilesetImage:getHeight()
  local i = 0
  for y = 0, sh-1, 16 do
    for x = 0, sw-1, 16 do
      Graphics.quads[i] = love.graphics.newQuad(x, y, 16, 16, sw, sh)
      i = i + 1
    end
  end
end

function Graphics.loadFont(name)
  local fontimage = love.graphics.newImage(name)
  fontimage:setFilter("nearest", "nearest")
  Graphics.font = love.graphics.newImageFont(fontimage, Graphics.fontset)
  Graphics.font:setLineHeight( fontimage:getHeight() )
  love.graphics.setFont(Graphics.font)
end

function Graphics.drawPixel( x, y, r, g, b )
  love.graphics.setColor( r, g, b )
  love.graphics.rectangle( "fill", x, y, 1, 1 )
end

function Graphics.drawTile( x, y, tile )
  local xs, ys = Graphics.xScale, Graphics.yScale
  love.graphics.drawq( Graphics.tilesetImage, Graphics.quads[tile],
    math.floor(x*ys)/ys, math.floor(y*ys)/ys )
end

function Graphics.setColorDepth( depth )
  local x = 31 + (255-31) * depth
  love.graphics.setColor( x, x, x )
end

function Graphics.saveScreenshot()
  local screen = love.graphics.newScreenshot()
  local filedata = love.image.newEncodedImageData(screen, "bmp")
  love.filesystem.write( "screenshot.bmp", filedata)
end

function Graphics.changeScale( size )
  Graphics.xScale, Graphics.yScale = size, size
  love.graphics.setMode( Graphics.gameWidth*size, Graphics.gameHeight*size, false )
end

function Graphics.text( x, y, color, str )
  if x == "center" then x = 80-(str:len()*4) end
  love.graphics.setColor(color)
  for c in str:gmatch('.') do
    love.graphics.print(c, x, y)
    x = x + Graphics.font:getWidth(c)
  end
end

----------------------------------------

Animator = class()

function Animator:init( frames )
  self.frames = frames or {}
  self.index = 1
  self.clock = 0
end

function Animator:add( name, length )
  table.insert(self.frames, {name=name, length=length})
end

function Animator:update(dt)
  self.clock = self.clock + dt
  while self.clock >= self.frames[self.index].length do
    self.clock = self.clock - self.frames[self.index].length
    self.index = self.index + 1
    if self.index > #self.frames then
      self.index = 1
    end
  end
end

function Animator:current()
  return self.frames[self.index].name
end

----------------------------------------

function generateAutomataMap( w, h, iter, wall, floor )
  w = w or 20
  h = h or 15
  iter = iter or 4
  wall = wall or 3
  floor = floor or 0
  local lastMap = {}

  for y = 1, h do
    lastMap[y] = {}
    for x = 1, w do
      if x == 1 or y == 1 or x == w or y == h or math.random(0, 1) == 1 then
        lastMap[y][x] = wall
      else
        lastMap[y][x] = floor
      end
    end
  end

  for i = 1, iter do
    local newMap = {}
    for y = 1, h do
      newMap[y] = {}
      for x = 1, w do
        if x == 1 or y == 1 or x == w or y == h then
          newMap[y][x] = wall
        else
          local neighbors = 0
          for ny = y-1, y+1 do
            for nx = x-1, x+1 do
              neighbors = neighbors + ( lastMap[ny][nx] ~= wall and 0 or 1 )
            end
          end
          newMap[y][x] = (neighbors>=5) and wall or floor
        end
      end
    end
    lastMap = newMap
  end
  return lastMap
end

----------------------------------------

PlainMap = class()

function PlainMap:init( x, y, width, height )
  self.x = x
  self.y = y
  self.width = width
  self.height = height
  self.data = {}
end

function PlainMap:set( x, y, v )
  if x < self.x or y < self.y or x >= self.x+self.width or y >= self.y+self.height then return end
  if not self.data[y] then self.data[y] = {} end
  self.data[y][x] = v
end

function PlainMap:get( x, y )
  if x < self.x or y < self.y or x >= self.x+self.width or y >= self.y+self.height then return end
  if not self.data[y] then return end
  return self.data[y][x]
end

----------------------------------------

NoiseMap = class( PlainMap )

function NoiseMap:init( x, y, w, h, c1, c2, c3, c4 )
  PlainMap.init(self, x, y, w, h)
  self.data = {}
  self:divide( x, y, self.width+1, self.height+1, c1, c2, c3, c4 )
end

function NoiseMap:displace( v )
  local max = v / (self.width + self.height) * 3
  return (math.random() - 0.5) * max
end

function NoiseMap:divide( x, y, w, h, c1, c2, c3, c4 )
  if w > 2 or h > 2 then
    local nW = w/2
    local nH = h/2
    local mid = ( c1 + c2 + c3 + c4 ) / 4 + self:displace(nW, nH)
    if mid < 0 then mid = 0 elseif mid > 1 then mid = 1 end

    local edge1 = (c1 + c2) / 2
    local edge2 = (c2 + c3) / 2
    local edge3 = (c3 + c4) / 2
    local edge4 = (c4 + c1) / 2

    self:divide(x, y, nW, nH, c1, edge1, mid, edge4);
    self:divide(x + nW, y, nW, nH, edge1, c2, edge2, mid);
    self:divide(x + nW, y + nH, nW, nH, mid, edge2, c3, edge3);
    self:divide(x, y + nH, nW, nH, edge4, mid, edge3, c4);
  else
    local c = (c1+c2+c3+c4)/4
    self:set( math.floor(x), math.floor(y), c )
  end
end

----------------------------------------

WorldChunk = class()

-- In the algo, the corners are clockwise.
-- In the ctor, the corners are TL TR BL BR for ease of use.
function WorldChunk:init( x, y, w, h, tl, tr, bl, br )
  self.x = x
  self.y = y
  self.w = w
  self.h = h
  self.tl = tl
  self.tr = tr
  self.bl = bl
  self.br = br
  self.heightMap = PlainMap( x, y, w, h )
  self.floor = PlainMap( x, y, w, h )
end

function WorldChunk:generate()
  local noiseMap = NoiseMap(self.x, self.y, self.w, self.h, self.tl, self.tr, self.br, self.bl)
  local heightMap = self.heightMap
  local floorMap = self.floor
  for y = self.y, self.y+self.h-1 do
    for x = self.x, self.x+self.w-1 do
      local v = noiseMap:get(x, y)
      local cell
      if v < 0.25 then cell = 4
      elseif v < 0.35 then cell = 6
      elseif v < 0.65 then cell = 5
      else cell = 7 end
      floorMap:set( x, y, cell )
      heightMap:set( x, y, v )
    end
  end
end

function WorldChunk:containsPoint( px, py )
  return ( px >= self.x and px < self.x + self.w ) and
         ( py >= self.y and py < self.y + self.h )
end

function intersect( ax, ay, aw, ah, bx, by, bw, bh )
  local min, max = math.min, math.max
  local ax2, ay2 = ax + aw, ay + ah
  local bx2, by2 = bx + bw, by + bh
  local tx1 = max(ax, bx);
  local tx2 = min(ax2, bx2);
  local ty1 = max(ay, by);
  local ty2 = min(ay2, by2);
  local tw = tx2 - tx1
  local th = ty2 - ty1
  if tw < 0 or th < 0 then return end
  return tx1, ty1, tw, th
end

function WorldChunk:draw( px, py )
  local vx, vy, vw, vh = intersect( self.x, self.y, self.w, self.h, px-10, py-7, 21, 15 )
  if not vx then return end
  for y = vy, vy+vh-1 do
    for x = vx, vx+vw-1 do
      local floor = self.floor:get( x, y )
      if floor then
        local tx, ty = (x-px)*16+152, (y-py)*16+112
        Graphics.drawTile( tx, ty, floor )
        visi = visi + 1
      end
    end
  end
end

----------------------------------------

WorldMap = class()
WorldMap.CHUNK_SIZE = 64

function WorldMap:init()
  self.chunks = PlainMap( -128, -128, 256, 256 )
end

function WorldMap:draw( px, py )
  local wx, wy = math.floor(px/self.CHUNK_SIZE), math.floor(py/self.CHUNK_SIZE)
  for y = wy - 1, wy + 1 do
    for x = wx - 1, wx + 1 do
      chunk = self.chunks:get( x, y )
      if chunk then chunk:draw( px, py ) end
    end
  end
end

function WorldMap:generate( px, py )
  local SIZE = self.CHUNK_SIZE
  local wx, wy = math.floor(px/SIZE), math.floor(py/SIZE)
  for y = wy - 1, wy + 1 do
    for x = wx - 1, wx + 1 do
      chunk = self.chunks:get( x, y )
      if not chunk then
        local tl, tr, bl, br
        local north = self.chunks:get( x, y-1 )
        if north then tl = north.bl; tr = north.br end
        local south = self.chunks:get( x, y+1 )
        if south then bl = south.tl; br = south.tr end
        local west = self.chunks:get( x-1, y )
        if west then tl = west.tr; bl = west.br end
        local east = self.chunks:get( x+1, y )
        if east then tr = east.tl; br = east.bl end

        if not tl then tl = math.random() end
        if not tr then tr = math.random() end
        if not bl then bl = math.random() end
        if not br then br = math.random() end

        print( "Generating chunk at", x, y, px, py, tl, tr, bl, br )
        local newChunk = WorldChunk( x*SIZE, y*SIZE, SIZE, SIZE, tl, tr, bl, br )
        newChunk:generate()
        self.chunks:set( x, y, newChunk )
      end
    end
  end
end

----------------------------------------

TestState = class()

function TestState:init()
  self.x = 0
  self.y = 0
  self.world = WorldMap()
  self.world:generate( self.x, self.y )
end

function TestState:draw()
  love.graphics.setColor( WHITE )
  visi = 0
  self.world:draw( self.x, self.y )
  Graphics.drawTile( 152, 112, 128 )
  Graphics.text( 0, 0, WHITE, string.format("%i,%i -- %i", self.x, self.y, visi) )
end

function TestState:update(dt)
  if keypress["escape"]==1 then StateMachine.pop() end
  local x, y = 0, 0
  local u, l, r, d = keypress["up"], keypress["left"], keypress["right"], keypress["down"]
  if u == 1 or u >= 1.333 then y = y - 1 end
  if d == 1 or d >= 1.333 then y = y + 1 end
  if l == 1 or l >= 1.333 then x = x - 1 end
  if r == 1 or r >= 1.333 then x = x + 1 end
  self:move( x, y )
end

function TestState:move( dx, dy )
  if dx == 0 and dy == 0 then return end

  local newx, newy = self.x + dx, self.y + dy
  self.x, self.y = newx, newy

  self.world:generate( newx, newy )
end

----------------------------------------

function love.load()
  math.randomseed( os.time() )
  Graphics.init()
  Sound.init()
  StateMachine.push( TestState() )
end

function love.update(dt)
  if dt > 0.1 then dt = 0.1 end
  if keypress["f2"] == 1 then Graphics.saveScreenshot() end
  if keypress["f10"] == 1 then love.event.push('q') end

  local scale
  for i = 1, 5 do
    if keypress[ "" .. i ] == 1 then scale = i end
  end
  if scale then Graphics.changeScale(scale) end

  StateMachine.update(dt)
  Sound.update()
  if StateMachine.isEmpty() then love.event.push('q') end
  for i, v in pairs(keypress) do
    keypress[i] = v + dt
  end
end

function love.draw()
  love.graphics.scale( Graphics.xScale, Graphics.yScale )
  love.graphics.setColor( 255, 255, 255 )
  StateMachine.draw(dt)
end

function love.keypressed(key, unicode)
  keypress[key] = 1
end

function love.keyreleased(key, unicode)
  keypress[key] = nil
end

--[==[
function love.focus(focused)
  if not focused then
    local n = #stateStack
    if (n > 0) and (stateStack[n].pause) then
      stateStack[n]:pause()
    end
  end
end
]==]

