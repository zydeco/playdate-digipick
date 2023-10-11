import "CoreLibs/graphics"
import "CoreLibs/animator"

local gfx <const> = playdate.graphics

local RING_CENTER <const> = {x=120, y=120}
local RING_WIDTHS <const> = {-1, 10, 8, 6, 5}
local RING_RADIUS <const> = {114, 95, 82, 71, 62}
local CHUNK_SIZE <const> = {-1, 0.4, 0.45, 0.5, 0.5}
local PIN_SIZE <const> = {{-10, 5}, {-7, 5}, {-6, 4}, {-5, 4}}
local SEGMENT_SIZE <const> = 11.25
local SEGMENT_HALFSIZE <const> = SEGMENT_SIZE / 2
local PIN_WIDTH <const> = 6
local SMOL_PIN_WIDTH <const> = 3

local rotateAnimator = gfx.animator.new(0, 0, 0)
local ringAnimator = gfx.animator.new(0, 0, 0)
local needToDraw = true
local ringsImage = nil
local clearAllPicks = false

function startLevelGfx(game)
  rotateAnimator = gfx.animator.new(0, 0, game.currentOffset * SEGMENT_SIZE)
  ringAnimator = gfx.animator.new(0, RING_RADIUS[game.ring], RING_RADIUS[game.ring])
  ringsImage = nil
  needToDraw = true
  clearAllPicks = true
end

function animateRingChange(from, to)
  ringAnimator = gfx.animator.new(100, RING_RADIUS[from], RING_RADIUS[to])
  needToDraw = true
end

function animateRotation(dstPos)
  local dstAngle = dstPos * SEGMENT_SIZE
  local currentAngle = rotateAnimator:currentValue()
  if currentAngle < 0 then
    currentAngle = currentAngle + 360
  end
  if currentAngle < 90 and dstAngle > 270 then
    dstAngle = dstAngle - 360
  elseif currentAngle > 270 and dstAngle < 90 then
    currentAngle = currentAngle - 360
  end
  rotateAnimator = gfx.animator.new(40, currentAngle, dstAngle)
  needToDraw = true
end

local function drawSegment(ring, segment)
  gfx.setLineWidth(RING_WIDTHS[ring])
  local startAngle = -SEGMENT_HALFSIZE + (segment * SEGMENT_SIZE) + CHUNK_SIZE[ring]
  local endAngle = SEGMENT_HALFSIZE + (segment * SEGMENT_SIZE) - CHUNK_SIZE[ring]
  gfx.drawArc(RING_CENTER.x, RING_CENTER.y, RING_RADIUS[ring], startAngle, endAngle)
end

local function drawPin(ring, angle)
  local my = RING_CENTER.y - RING_RADIUS[ring]
  local pinSize = PIN_SIZE[ring]
  local ln = playdate.geometry.lineSegment.new(RING_CENTER.x, my - pinSize[1], RING_CENTER.x, my - pinSize[2])
  local transform = playdate.geometry.affineTransform.new()
  transform:rotate(angle, RING_CENTER.x, RING_CENTER.y)
  transform:transformLineSegment(ln)
  gfx.drawLine(ln)
end

local function drawPick(pick, ring, crank)
  -- pins
  if ring <= 4 and pick ~= nil then
    gfx.setLineWidth(PIN_WIDTH)
    for _, value in ipairs(pick) do
      drawPin(ring, (value * SEGMENT_SIZE) + crank)
    end
  end
  -- outer ring
  gfx.setColor(gfx.kColorWhite)
  gfx.setLineWidth(1.5)
  gfx.drawCircleAtPoint(RING_CENTER.x, RING_CENTER.y, 1+ringAnimator:currentValue())
  gfx.setColor(gfx.kColorBlack)
  gfx.setPattern({0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa})
  gfx.drawCircleAtPoint(RING_CENTER.x, RING_CENTER.y, ringAnimator:currentValue())
end

local KEY_MENU <const> = {
  cols = 3,
  x = 245, y = 20,
  dx = 50, dy = 50
}

local function drawSmolPick(pick, index, selected, currentOffset)
  local col = (index - 1) % 3
  local row = (index - 1) // 3
  local x = KEY_MENU.x + (col * KEY_MENU.dx) + 1
  local y = KEY_MENU.y + (row * KEY_MENU.dy) + 1
  if pick ~= nil then
    local cx = x + 24
    local cy = y + 24
    local offset = 0
    if selected then
      gfx.setColor(gfx.kColorWhite)
      gfx.fillRect(x, y, 50, 50)
      gfx.setColor(gfx.kColorBlack)
      gfx.fillCircleInRect(x+14, y+14, 20, 20)
      offset = currentOffset
    end
    gfx.setLineWidth(1)
    gfx.drawCircleInRect(x+4, y+4, 40, 40)
    for _, bit in ipairs(pick) do
      local ln = playdate.geometry.lineSegment.new(cx, cy - 14, cx, cy - 24)
      local transform = playdate.geometry.affineTransform.new()
      transform:rotate((bit + offset) * SEGMENT_SIZE, cx, cy)
      transform:transformLineSegment(ln)
      gfx.setLineWidth(SMOL_PIN_WIDTH)
      gfx.drawLine(ln)
    end
  end
end

local function drawPickMenu(game)
  if clearAllPicks then
    -- draw all picks
    clearAllPicks = false
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(KEY_MENU.x, KEY_MENU.y, 150, 200)
    gfx.setColor(gfx.kColorBlack)
    for i=1,12 do
      drawSmolPick(game.picks[i], i, i == game.pick, game.currentOffset)
    end
  else
    -- clear and draw selected
    drawSmolPick(game.picks[game.pick], game.pick, true, game.currentOffset)
  end
end

local function drawRing(index, value)
  for bit=0,31 do
    if 1 << bit & value ~= 0 then
      drawSegment(index, bit)
    end
  end
end

local function drawRingsImage(rings, currentRing)
  local img = gfx.image.new(240, 240, gfx.kColorWhite)
  gfx.pushContext(img)
  gfx.setColor(gfx.kColorBlack)
  -- inner rings
  for r=currentRing+1,#rings+1 do
    gfx.setDitherPattern((r - currentRing - 1) * 0.25)
    drawRing(r, rings[r-1])
  end
  gfx.popContext()
  return img
end

function gfxNeedUpdate(redrawRings, redrawPicks)
  needToDraw = true
  if redrawRings then
    ringsImage = nil
  end
  if redrawPicks then
    clearAllPicks = true
  end
end

function gfxUpdate(game)
  if not needToDraw then
    return
  end

  -- draw rings
  if ringsImage == nil then
    ringsImage = drawRingsImage(game.rings, game.ring)
  end
  ringsImage:draw(0, 0)
  gfx.setColor(gfx.kColorBlack)

  local ringAnimatorEnded = ringAnimator:ended()
  if ringAnimatorEnded then
    -- curent pick
    drawPick(game.picks[game.pick], game.ring, rotateAnimator:currentValue())
    if rotateAnimator:ended() then
      needToDraw = false
    end
  else
    -- animating ring
    gfx.setLineWidth(1)
    gfx.drawCircleAtPoint(RING_CENTER.x, RING_CENTER.y, ringAnimator:currentValue())
  end

  drawPickMenu(game)
end