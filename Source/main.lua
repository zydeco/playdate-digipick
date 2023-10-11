import "CoreLibs/timer"
import "CoreLibs/ui"

import "game"
import "gfx"

local SEGMENT_SIZE <const> = 11.25

local DIFFICULTY_LEVELS = {"novice", "advanced", "expert", "master"}

local game = {
  pick = 1, -- selected pick
  ring = 1, -- currently operating ring
  currentOffset = 0, -- [0, 31]
  picks = {}, -- list of pins
  rings = {} -- 32-bit integers
}
local undoStack = {}
local settings = {
  level = 3 -- difficulty [0,3]
}

local sounds = {}

local function nextRing()
  if game.ring < 5 then
    animateRingChange(game.ring, game.ring + 1)
    game.ring = game.ring + 1
  end
end

local function startLevel(picks, rings)
  game.pick = 1
  game.ring = 1
  game.picks = picks
  game.currentOffset = math.floor(playdate.getCrankPosition() / SEGMENT_SIZE)
  game.picks[game.pick] = offsetPick(game.picks[game.pick], -game.currentOffset)
  game.rings = rings
  undoStack = {}
end

local function choosePick(newPick)
  if newPick == nil then
    newPick = game.pick
    while #game.picks[newPick] == 0 do
      newPick = (newPick % #game.picks) + 1
    end
  end
  game.picks[game.pick] = offsetPick(game.picks[game.pick], game.currentOffset)
  game.picks[newPick] = offsetPick(game.picks[newPick], -game.currentOffset)
  game.pick = newPick
  gfxNeedUpdate(false, true)
  sounds.change:play()
end

local function LevelIsComplete()
  return game.rings[#game.rings] == 0xffffffff
end

local function doSlot(pick)
  sounds.slot:play()
  gfxNeedUpdate(true)
  table.insert(undoStack, {
    selectedRing=game.ring,
    selectedPick=game.pick,
    pick=offsetPick(game.picks[game.pick], game.currentOffset),
    ring=game.rings[game.ring]
  })
  game.rings[game.ring] = game.rings[game.ring] | bitsToValue(pick)
  game.picks[game.pick] = {}
  if game.rings[game.ring] == 0xffffffff then
    nextRing()
  end
  if LevelIsComplete() then
    game.pick = 0
    sounds.unlock:play()
    gfxNeedUpdate(true, true)
  else
    choosePick()
  end
end

local function CanUndo()
  return #undoStack > 0 and not LevelIsComplete()
end

local function undo()
  sounds.unslot:play()
  local state = table.remove(undoStack)
  if game.ring ~= state.selectedRing then
    animateRingChange(game.ring, state.selectedRing)
    game.ring = state.selectedRing
  end
  game.rings[state.selectedRing] = state.ring
  if state.selectedPick ~= game.pick then
    game.picks[game.pick] = offsetPick(game.picks[game.pick], game.currentOffset)
  end
  game.picks[state.selectedPick] = offsetPick(state.pick, -game.currentOffset)
  game.pick = state.selectedPick
  gfxNeedUpdate(true, true)
end

local function changePick(change)
  if LevelIsComplete() then
    return
  end
  local newPick = game.pick + change
  if newPick >= 1 and newPick <= #game.picks then
    choosePick(newPick)
  end
end

local function isPickSelected()
  local pick = game.picks[game.pick] or {}
  return #pick ~= 0
end

local function StartNewGame()
  local picks, rings = createLevel(settings.level)
  startLevel(picks, rings)
  startLevelGfx(game)
  sounds.start:play()
end

function playdate.cranked(_, _)
  local crank = playdate.getCrankPosition()
  local dstPos = math.floor(crank / SEGMENT_SIZE)
  if dstPos ~= game.currentOffset and isPickSelected() then
    game.currentOffset = dstPos
    animateRotation(dstPos)
    sounds.click:play()
  end
end

function playdate.AButtonDown()
  if LevelIsComplete() then
    StartNewGame()
    return
  end
  local pick = offsetPick(game.picks[game.pick], game.currentOffset)
  if fitTest(game.rings[game.ring], pick) then
    doSlot(pick)
  end
end

function playdate.BButtonDown()
  if CanUndo() then
    undo()
  end
end

function playdate.leftButtonDown()
  changePick(-1)
end

function playdate.rightButtonDown()
  changePick(1)
end

function playdate.upButtonDown()
  changePick(-3)
end

function playdate.downButtonDown()
  changePick(3)
end

local crankWasDocked = playdate.isCrankDocked()

function playdate.update()
  playdate.timer.updateTimers()
  playdate.graphics.sprite.update()
  if crankWasDocked then
    if playdate.isCrankDocked() then
      playdate.ui.crankIndicator:update()
    else
      crankWasDocked = false
      gfxNeedUpdate(true, true)
      playdate.graphics.clear()
    end
  end
  gfxUpdate(game)
end

local function InitSettings()
  local readSettings = playdate.datastore.read("settings")
  if readSettings == nil then
    settings.level = 0
  else
    settings = readSettings
  end
end

local function SaveSettings()
  playdate.datastore.write(settings, "settings")
end

local function InitMenus()
  local menu = playdate.getSystemMenu()
  menu:addMenuItem("new game", function()
    StartNewGame()
  end)
  menu:addOptionsMenuItem("level", DIFFICULTY_LEVELS, DIFFICULTY_LEVELS[settings.level+1], function(chosen)
    local oldLevel = settings.level
    for i = 1, #DIFFICULTY_LEVELS do
      if chosen == DIFFICULTY_LEVELS[i] then
        local newLevel = i - 1
        if oldLevel ~= newLevel then
          settings.level = newLevel
          SaveSettings()
          StartNewGame()
          return
        end
      end
    end
  end)
end

local function LoadState()
  local state = playdate.datastore.read("game")
  if state == nil then
    return false
  end
  game = state.game
  undoStack = state.undoStack
end

local function SaveState()
  if LevelIsComplete() then
    playdate.datastore.delete("game")
    return
  end

  playdate.datastore.write({
    game=game,
    undoStack=undoStack
  }, "game")
end

playdate.gameWillTerminate = SaveState
playdate.deviceWillSleep = SaveState

local function InitSounds()
  sounds.start = playdate.sound.sampleplayer.new("snd/start")
  sounds.click = playdate.sound.sampleplayer.new("snd/click")
  sounds.change = playdate.sound.sampleplayer.new("snd/change")
  sounds.slot = playdate.sound.sampleplayer.new("snd/slot")
  sounds.unslot = playdate.sound.sampleplayer.new("snd/unslot")
  sounds.unlock = playdate.sound.sampleplayer.new("snd/unlock")
end

local function InitGame()
  -- initialize stuff
  InitSettings()
  InitMenus()
  InitSounds()

  -- show crank indicator if it's docked
  if crankWasDocked then
    playdate.ui.crankIndicator:start()
  end

  -- load or start the game
  if not LoadState() then
    StartNewGame()
  end
end

InitGame()
