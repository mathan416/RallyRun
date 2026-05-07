import "CoreLibs/graphics"
import "CoreLibs/timer"

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound

local defaultFont <const> = gfx.getSystemFont()
local arcadeFont = gfx.font.new("fonts/Supermini")

local SCREEN_W <const> = 400
local SCREEN_H <const> = 240
local CELL <const> = 16
local GRID_W <const> = 20
local GRID_H <const> = 15
local WORLD_W <const> = GRID_W * CELL
local HUD_X <const> = WORLD_W
local HUD_W <const> = SCREEN_W - WORLD_W
local LEVEL_INTRO_FRAMES <const> = 60
local CELEBRATE_NEW_HIGH_SCORE_ONLY <const> = false
local AUDIO_ENABLED <const> = true

local DIRS <const> = {
    up = { x = 0, y = -1 },
    down = { x = 0, y = 1 },
    left = { x = -1, y = 0 },
    right = { x = 1, y = 0 },
    none = { x = 0, y = 0 }
}

local OPPOSITE <const> = {
    up = "down",
    down = "up",
    left = "right",
    right = "left",
    none = "none"
}

local LEFT_TURN <const> = {
    up = "left",
    left = "down",
    down = "right",
    right = "up",
    none = "left"
}

local RIGHT_TURN <const> = {
    up = "right",
    right = "down",
    down = "left",
    left = "up",
    none = "right"
}

local FLAG_COUNT <const> = 10

local MAP <const> = {}

local SPAWN_TILES <const> = {
    { 1, 1 }, { 18, 13 }, { 18, 1 }, { 1, 13 }
}

local game = {}
local player = {}
local enemies = {}
local flags = {}
local smoke = {}
local particles = {}
local highScore = 0
local celebrationCar = {}
local titleCar = {
    x = SCREEN_W + 24,
    y = 32,
    dir = "left",
    speed = 1.8,
    smokeTimer = 0
}

local audio = {
    engine = nil,
    blip = nil,
    lead = nil,
    harmony = nil,
    bass = nil,
    noise = nil,
    enginePlaying = false,
    engineTicker = 0,
    sequence = nil,
    sequenceStep = 1,
    sequenceDelay = 0,
    musicStep = 1,
    musicDelay = 0,
    musicPlaying = false
}

local TITLE_MUSIC <const> = {
    { lead = 330, harmony = 247, bass = 82, delay = 5 },
    { lead = 392, harmony = 294, delay = 5 },
    { lead = 440, harmony = 330, bass = 98, delay = 5 },
    { lead = 392, harmony = 294, delay = 5 },
    { lead = 494, harmony = 392, bass = 110, delay = 5 },
    { lead = 440, harmony = 330, delay = 5 },
    { lead = 392, harmony = 330, bass = 98, delay = 5 },
    { lead = 330, delay = 8 },
    { lead = 294, harmony = 220, bass = 73, delay = 5 },
    { lead = 330, harmony = 247, delay = 5 },
    { lead = 392, harmony = 294, bass = 82, delay = 5 },
    { lead = 440, harmony = 330, delay = 5 },
    { lead = 392, harmony = 294, bass = 98, delay = 5 },
    { lead = 330, harmony = 247, delay = 5 },
    { lead = 247, harmony = 196, bass = 62, delay = 5 },
    { lead = 330, delay = 8 }
}

local function setupAudio()
    if not AUDIO_ENABLED or snd == nil then
        return
    end

    audio.engine = snd.synth.new(snd.kWaveSawtooth)
    audio.engine:setADSR(0.02, 0.08, 0.35, 0.08)
    audio.engine:setVolume(0.20)
    audio.engine:setLegato(true)

    audio.blip = snd.synth.new(snd.kWaveSquare)
    audio.blip:setADSR(0.005, 0.04, 0, 0.02)
    audio.blip:setVolume(0.88)

    audio.lead = snd.synth.new(snd.kWaveTriangle)
    audio.lead:setADSR(0.01, 0.05, 0.45, 0.12)
    audio.lead:setVolume(0.72)
    audio.lead:setLegato(true)

    audio.harmony = snd.synth.new(snd.kWaveTriangle)
    audio.harmony:setADSR(0.012, 0.05, 0.35, 0.12)
    audio.harmony:setVolume(0.32)
    audio.harmony:setLegato(true)

    audio.bass = snd.synth.new(snd.kWaveSquare)
    audio.bass:setADSR(0.005, 0.04, 0.28, 0.08)
    audio.bass:setVolume(0.32)
    audio.bass:setLegato(true)

    audio.noise = snd.synth.new(snd.kWaveNoise)
    audio.noise:setADSR(0.001, 0.08, 0, 0.06)
    audio.noise:setVolume(0.56)
end

local function stopEngineSound()
    if audio.enginePlaying and audio.engine ~= nil then
        audio.engine:noteOff()
        audio.enginePlaying = false
    end
end

local function playNote(synth, frequency, volume, length)
    if synth ~= nil then
        synth:playNote(frequency, volume, length)
    end
end

local function playAudioSequence(sequence)
    audio.sequence = sequence
    audio.sequenceStep = 1
    audio.sequenceDelay = 0
end

local function startTitleMusic()
    if audio.lead == nil then
        return
    end

    audio.musicPlaying = true
    audio.musicStep = 1
    audio.musicDelay = 0
end

local function stopTitleMusic()
    audio.musicPlaying = false
    audio.musicDelay = 0

    if audio.lead ~= nil then
        audio.lead:noteOff()
    end

    if audio.harmony ~= nil then
        audio.harmony:noteOff()
    end

    if audio.bass ~= nil then
        audio.bass:noteOff()
    end
end

local function playPickupSound()
    playNote(audio.blip, 880, 0.22, 0.06)
end

local function playSmokeSound()
    playNote(audio.noise, 140, 0.16, 0.18)
end

local function playStunSound()
    playNote(audio.lead, 140, 0.16, 0.12)
end

local function playCrashSound()
    stopEngineSound()
    playNote(audio.noise, 70, 0.42, 0.35)
    playNote(audio.lead, 96, 0.2, 0.18)
end

local function playStageStartSound()
    playAudioSequence({
        { synth = audio.lead, frequency = 330, volume = 0.16, length = 0.08, delay = 5 },
        { synth = audio.lead, frequency = 440, volume = 0.16, length = 0.08, delay = 5 },
        { synth = audio.lead, frequency = 660, volume = 0.18, length = 0.14, delay = 14 }
    })
end

local function playLevelClearSound()
    playAudioSequence({
        { synth = audio.lead, frequency = 523, volume = 0.16, length = 0.08, delay = 4 },
        { synth = audio.lead, frequency = 659, volume = 0.16, length = 0.08, delay = 4 },
        { synth = audio.lead, frequency = 784, volume = 0.18, length = 0.16, delay = 12 }
    })
end

local function playGameOverSound()
    stopEngineSound()
    playAudioSequence({
        { synth = audio.lead, frequency = 220, volume = 0.2, length = 0.12, delay = 8 },
        { synth = audio.lead, frequency = 165, volume = 0.18, length = 0.14, delay = 8 },
        { synth = audio.lead, frequency = 110, volume = 0.22, length = 0.28, delay = 18 }
    })
end

local function updateAudioSequence()
    if audio.sequence == nil then
        return
    end

    if audio.sequenceDelay > 0 then
        audio.sequenceDelay -= 1
        return
    end

    local note = audio.sequence[audio.sequenceStep]
    if note == nil then
        audio.sequence = nil
        return
    end

    playNote(note.synth, note.frequency, note.volume, note.length)
    audio.sequenceDelay = note.delay or 1
    audio.sequenceStep += 1
end

local function updateTitleMusic()
    if not audio.musicPlaying then
        return
    end

    if game.state ~= "title" then
        stopTitleMusic()
        return
    end

    if audio.musicDelay > 0 then
        audio.musicDelay -= 1
        return
    end

    local note = TITLE_MUSIC[audio.musicStep]
    if note == nil then
        audio.musicStep = 1
        note = TITLE_MUSIC[audio.musicStep]
    end

    local leadLength = (note.delay + 2) / 30
    local bassLength = math.max(0.12, note.delay / 30)

    playNote(audio.lead, note.lead, 0.12, leadLength)
    if note.harmony ~= nil then
        playNote(audio.harmony, note.harmony, 0.055, leadLength)
    elseif audio.harmony ~= nil then
        audio.harmony:noteOff()
    end

    if note.bass ~= nil then
        playNote(audio.bass, note.bass, 0.07, bassLength)
    end

    audio.musicDelay = note.delay
    audio.musicStep += 1
end

local function updateEngineSound()
    if game.state ~= "playing" or player.dir == "none" or player.speed <= 0 then
        stopEngineSound()
        return
    end

    audio.engineTicker += 1
    if audio.engineTicker % 6 ~= 0 then
        return
    end

    local speedRatio = player.speed / player.maxSpeed
    local frequency = 72 + speedRatio * 58
    local volume = 0.05 + speedRatio * 0.35
    audio.engine:setVolume(volume)
    audio.engine:playNote(frequency, volume, -1)
    audio.enginePlaying = true
end

local function updateAudio()
    if audio.engine == nil then
        return
    end

    updateAudioSequence()
    updateTitleMusic()
    updateEngineSound()
end

local function useArcadeFont()
    if arcadeFont ~= nil then
        gfx.setFont(arcadeFont)
    elseif defaultFont ~= nil then
        gfx.setFont(defaultFont)
    end
end

local function useDefaultFont()
    if defaultFont ~= nil then
        gfx.setFont(defaultFont)
    end
end

local function drawCenteredText(text, x, y)
    local width = gfx.getTextSize(text)
    gfx.drawText(text, x - width / 2, y)
end

local function drawWhiteCenteredText(text, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    drawCenteredText(text, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function loadHighScore()
    local data = pd.datastore.read("scores")
    if data ~= nil and type(data.highScore) == "number" then
        highScore = data.highScore
    end
end

local function saveHighScore()
    pd.datastore.write({ highScore = highScore }, "scores")
end

local function shouldShowCelebration()
    return game.state == "gameover" and (game.newHighScore or not CELEBRATE_NEW_HIGH_SCORE_ONLY)
end

local function tileToWorld(tx, ty)
    return tx * CELL + CELL / 2, ty * CELL + CELL / 2
end

local function worldToTile(x, y)
    return math.floor(x / CELL), math.floor(y / CELL)
end

local function makeBlankMaze()
    local maze = {}
    for y = 0, GRID_H - 1 do
        maze[y] = {}
        for x = 0, GRID_W - 1 do
            maze[y][x] = "#"
        end
    end
    return maze
end

local function setMazeTile(maze, tx, ty, value)
    if tx > 0 and tx < GRID_W - 1 and ty > 0 and ty < GRID_H - 1 then
        maze[ty][tx] = value
    end
end

local function mazeToRows(maze)
    for y = 0, GRID_H - 1 do
        local row = {}
        for x = 0, GRID_W - 1 do
            row[x + 1] = maze[y][x]
        end
        MAP[y + 1] = table.concat(row)
    end
end

local function isWall(tx, ty)
    if tx < 0 or tx >= GRID_W or ty < 0 or ty >= GRID_H then
        return true
    end

    return MAP[ty + 1]:sub(tx + 1, tx + 1) == "#"
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
end

local function softenMazeFringe(maze)
    local rightRoad = GRID_W - 2
    local bottomRoad = GRID_H - 2

    for ty = 1, GRID_H - 2 do
        if maze[ty][rightRoad - 1] == "." and math.random(1, 100) <= 65 then
            maze[ty][rightRoad] = "."
        end
    end

    for tx = 1, GRID_W - 2 do
        if maze[bottomRoad - 1][tx] == "." and math.random(1, 100) <= 45 then
            maze[bottomRoad][tx] = "."
        end
    end

    for ty = 2, GRID_H - 3 do
        if maze[ty - 1][rightRoad] == "." and maze[ty + 1][rightRoad] == "." then
            maze[ty][rightRoad] = "."
        end
    end

    for tx = 2, GRID_W - 3 do
        if maze[bottomRoad][tx - 1] == "." and maze[bottomRoad][tx + 1] == "." and math.random(1, 100) <= 70 then
            maze[bottomRoad][tx] = "."
        end
    end
end

local function generateMaze()
    local maze = makeBlankMaze()
    local visited = {}

    for y = 1, GRID_H - 2, 2 do
        visited[y] = {}
    end

    local function carve(tx, ty)
        visited[ty][tx] = true
        maze[ty][tx] = "."

        local directions = {
            { x = 2, y = 0 }, { x = -2, y = 0 },
            { x = 0, y = 2 }, { x = 0, y = -2 }
        }
        shuffle(directions)

        for _, dir in ipairs(directions) do
            local nx = tx + dir.x
            local ny = ty + dir.y
            if nx > 0 and nx < GRID_W - 1 and ny > 0 and ny < GRID_H - 1 and not visited[ny][nx] then
                maze[ty + dir.y // 2][tx + dir.x // 2] = "."
                carve(nx, ny)
            end
        end
    end

    carve(1, 1)

    for _ = 1, 18 do
        local tx = math.random(1, GRID_W - 2)
        local ty = math.random(1, GRID_H - 2)
        if maze[ty][tx] == "#" then
            local horizontal = maze[ty][tx - 1] == "." and maze[ty][tx + 1] == "."
            local vertical = maze[ty - 1][tx] == "." and maze[ty + 1][tx] == "."
            if horizontal or vertical then
                maze[ty][tx] = "."
            end
        end
    end

    softenMazeFringe(maze)

    setMazeTile(maze, 1, 1, ".")
    setMazeTile(maze, 2, 1, ".")
    setMazeTile(maze, 18, 1, ".")
    setMazeTile(maze, 17, 1, ".")
    setMazeTile(maze, 1, 13, ".")
    setMazeTile(maze, 2, 13, ".")
    setMazeTile(maze, 18, 13, ".")
    setMazeTile(maze, 17, 13, ".")

    mazeToRows(maze)
end

local function isCentered(entity)
    local tx, ty = worldToTile(entity.x, entity.y)
    local cx, cy = tileToWorld(tx, ty)
    return math.abs(entity.x - cx) < 0.5 and math.abs(entity.y - cy) < 0.5
end

local function snapToCenter(entity)
    local tx, ty = worldToTile(entity.x, entity.y)
    entity.x, entity.y = tileToWorld(tx, ty)
end

local function canMove(entity, dirName)
    local dir = DIRS[dirName]
    local tx, ty = worldToTile(entity.x, entity.y)
    return not isWall(tx + dir.x, ty + dir.y)
end

local function isDirection(dirName)
    return dirName ~= nil and dirName ~= "none"
end

local function setFlag(tx, ty)
    flags[#flags + 1] = {
        x = tx,
        y = ty,
        collected = false,
        pulse = math.random() * 6
    }
end

local function isSpawnTile(tx, ty)
    for _, spawn in ipairs(SPAWN_TILES) do
        if spawn[1] == tx and spawn[2] == ty then
            return true
        end
    end

    return false
end

local function randomizeFlags()
    local candidates = {}
    flags = {}

    for ty = 1, GRID_H - 2 do
        for tx = 1, GRID_W - 2 do
            if not isWall(tx, ty) and not isSpawnTile(tx, ty) then
                candidates[#candidates + 1] = { tx, ty }
            end
        end
    end

    shuffle(candidates)
    for index = 1, math.min(FLAG_COUNT, #candidates) do
        setFlag(candidates[index][1], candidates[index][2])
    end
end

local function resetGame(showTitle)
    stopEngineSound()

    game = {
        score = 0,
        fuel = 100,
        lives = 3,
        state = showTitle and "title" or "playing",
        message = showTitle and "RALLY RUN" or "STAGE 1",
        messageTimer = 0,
        level = 1,
        collected = 0,
        radarZoom = 1,
        frame = 0,
        gameOverTimer = 0,
        newHighScore = false
    }

    player = {
        x = 0,
        y = 0,
        dir = "none",
        queuedDir = "none",
        speed = 0,
        minSpeed = 1.2,
        maxSpeed = 2.35,
        acceleration = 0.12,
        brake = 0.12,
        friction = 0.025,
        invincible = 90,
        smokeCooldown = 0
    }
    player.x, player.y = tileToWorld(1, 1)

    enemies = {
        { x = 0, y = 0, dir = "left", speed = 1, stun = 0 },
        { x = 0, y = 0, dir = "left", speed = 1, stun = 0 },
        { x = 0, y = 0, dir = "right", speed = 1, stun = 0 }
    }
    enemies[1].x, enemies[1].y = tileToWorld(18, 13)
    enemies[2].x, enemies[2].y = tileToWorld(18, 1)
    enemies[3].x, enemies[3].y = tileToWorld(1, 13)
    enemies[1].dir = "left"
    enemies[2].dir = "left"
    enemies[3].dir = "right"

    generateMaze()
    randomizeFlags()

    smoke = {}
    particles = {}
    celebrationCar = {
        x = -20,
        y = 211,
        dir = "right",
        speed = 2.4,
        smokeTimer = 0
    }
    titleCar = {
        x = SCREEN_W + 24,
        y = 32,
        dir = "left",
        speed = 2.4,
        smokeTimer = 0
    }

    if showTitle then
        startTitleMusic()
    else
        stopTitleMusic()
    end
end

local function loseLife()
    game.lives -= 1
    playCrashSound()

    if game.lives <= 0 then
        game.state = "gameover"
        game.message = "GAME OVER"
        game.messageTimer = 90
        game.gameOverTimer = 90
        game.newHighScore = game.score > highScore
        playGameOverSound()
        if game.newHighScore then
            highScore = game.score
            saveHighScore()
            smoke = {}
            celebrationCar = {
                x = -20,
                y = 211,
                dir = "right",
                speed = 2.4,
                smokeTimer = 0
            }
        end
        return
    end

    player.x, player.y = tileToWorld(1, 1)
    player.dir = "none"
    player.queuedDir = "none"
    player.speed = 0
    player.invincible = 120
    smoke = {}

    enemies[1].x, enemies[1].y = tileToWorld(18, 13)
    enemies[2].x, enemies[2].y = tileToWorld(18, 1)
    enemies[3].x, enemies[3].y = tileToWorld(1, 13)
    enemies[1].dir = "left"
    enemies[2].dir = "left"
    enemies[3].dir = "right"
    for _, enemy in ipairs(enemies) do
        enemy.stun = 0
    end
end

local function nextLevel()
    playLevelClearSound()
    game.level += 1
    game.collected = 0
    game.fuel = math.min(100, game.fuel + 40)
    game.state = "levelintro"
    game.message = "STAGE " .. game.level
    game.messageTimer = LEVEL_INTRO_FRAMES

    player.x, player.y = tileToWorld(1, 1)
    player.dir = "none"
    player.queuedDir = "none"
    player.speed = 0
    player.invincible = 120

    enemies[1].x, enemies[1].y = tileToWorld(18, 13)
    enemies[2].x, enemies[2].y = tileToWorld(18, 1)
    enemies[3].x, enemies[3].y = tileToWorld(1, 13)
    enemies[1].dir = "left"
    enemies[2].dir = "left"
    enemies[3].dir = "right"
    for index, enemy in ipairs(enemies) do
        enemy.speed = game.level >= 3 and 2 or 1
        enemy.stun = 0
    end

    generateMaze()
    randomizeFlags()
    smoke = {}
    particles = {}
end

local function chooseEnemyDirection(enemy)
    local tx, ty = worldToTile(enemy.x, enemy.y)
    local px, py = worldToTile(player.x, player.y)
    local options = {}

    for name, dir in pairs(DIRS) do
        if name ~= "none" and name ~= OPPOSITE[enemy.dir] and not isWall(tx + dir.x, ty + dir.y) then
            options[#options + 1] = name
        end
    end

    if #options == 0 and canMove(enemy, OPPOSITE[enemy.dir]) then
        return OPPOSITE[enemy.dir]
    end

    local best = options[1] or enemy.dir
    local bestScore = 9999
    for _, name in ipairs(options) do
        local dir = DIRS[name]
        local dist = math.abs((tx + dir.x) - px) + math.abs((ty + dir.y) - py)
        if dist < bestScore or (dist == bestScore and math.random(1, 4) == 1) then
            bestScore = dist
            best = name
        end
    end

    return best
end

local function queueAbsoluteDirection(dirName)
    player.queuedDir = dirName
end

local function queueRelativeTurn(turn)
    if player.dir == "none" then
        player.queuedDir = turn == "left" and "left" or "right"
        return
    end

    player.queuedDir = turn == "left" and LEFT_TURN[player.dir] or RIGHT_TURN[player.dir]
end

local function emitSmokeFrom(x, y, dirName, speed, amount)
    local rear = DIRS[OPPOSITE[dirName]]
    local side = { x = -rear.y, y = rear.x }
    local baseX = x + rear.x * 10
    local baseY = y + rear.y * 10
    local carSpeed = math.max(speed, 0.8)

    for _ = 1, amount do
        local spread = math.random(-35, 35) / 10
        local push = math.random(8, 22) / 10
        smoke[#smoke + 1] = {
            x = baseX + side.x * spread,
            y = baseY + side.y * spread,
            vx = rear.x * (push + carSpeed * 0.35) + side.x * math.random(-10, 10) / 20,
            vy = rear.y * (push + carSpeed * 0.35) + side.y * math.random(-10, 10) / 20,
            radius = math.random(2, 5),
            grow = math.random(3, 8) / 100,
            life = math.random(46, 82),
            maxLife = 82,
            drag = math.random(88, 95) / 100
        }
    end
end

local function emitSmokeBurst()
    if not isDirection(player.dir) then
        return
    end

    emitSmokeFrom(player.x, player.y, player.dir, player.speed, 22)
end

local function moveEntity(entity, speed)
    local dir = DIRS[entity.dir]
    if dir.x == 0 and dir.y == 0 then
        return
    end

    if isCentered(entity) then
        snapToCenter(entity)
        if not canMove(entity, entity.dir) then
            return
        end
    end

    entity.x += dir.x * speed
    entity.y += dir.y * speed
end

local function updateInput()
    if pd.buttonIsPressed(pd.kButtonUp) then
        queueAbsoluteDirection("up")
    elseif pd.buttonIsPressed(pd.kButtonDown) then
        queueAbsoluteDirection("down")
    elseif pd.buttonIsPressed(pd.kButtonLeft) then
        queueAbsoluteDirection("left")
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        queueAbsoluteDirection("right")
    end

    if not pd.isCrankDocked() then
        local ticks = pd.getCrankTicks(4)
        if ticks < 0 then
            queueRelativeTurn("left")
        elseif ticks > 0 then
            queueRelativeTurn("right")
        end
    end

    if isDirection(player.queuedDir) and isCentered(player) and canMove(player, player.queuedDir) then
        snapToCenter(player)
        player.dir = player.queuedDir
        player.speed = math.max(player.speed, player.minSpeed)
    end

    if pd.buttonJustPressed(pd.kButtonA) and player.smokeCooldown <= 0 and game.fuel > 8 then
        emitSmokeBurst()
        playSmokeSound()
        game.fuel -= 8
        player.smokeCooldown = 28
    end
end

local function updatePlayer()
    local isBraking = pd.buttonIsPressed(pd.kButtonB)

    if isCentered(player) then
        snapToCenter(player)
        if isDirection(player.queuedDir) and canMove(player, player.queuedDir) then
            player.dir = player.queuedDir
        elseif not canMove(player, player.dir) then
            player.dir = "none"
            player.speed = 0
        end
    end

    if player.dir ~= "none" then
        if isBraking then
            player.speed = math.max(player.minSpeed * 0.5, player.speed - player.brake)
        else
            player.speed = math.min(player.maxSpeed, player.speed + player.acceleration)
        end
    else
        player.speed = math.max(0, player.speed - player.friction)
    end

    moveEntity(player, player.speed)

    game.fuel -= 0.012 + player.speed * 0.008
    player.invincible = math.max(0, player.invincible - 1)
    player.smokeCooldown = math.max(0, player.smokeCooldown - 1)

    if game.fuel <= 0 then
        game.fuel = 0
        loseLife()
    end
end

local function updateEnemies()
    for _, enemy in ipairs(enemies) do
        if enemy.stun > 0 then
            enemy.stun -= 1
        elseif isCentered(enemy) then
            snapToCenter(enemy)
            if not canMove(enemy, enemy.dir) then
                enemy.dir = chooseEnemyDirection(enemy)
            elseif math.random(1, 3) == 1 then
                enemy.dir = chooseEnemyDirection(enemy)
            end
        end

        local speed = enemy.stun > 0 and 0.25 or enemy.speed
        moveEntity(enemy, speed)
    end
end

local function updateSmoke()
    for index = #smoke, 1, -1 do
        local particle = smoke[index]
        particle.x += particle.vx
        particle.y += particle.vy
        particle.vx *= particle.drag
        particle.vy *= particle.drag
        particle.radius += particle.grow
        particle.life -= 1

        if particle.life <= 0 then
            table.remove(smoke, index)
        end
    end
end

local function updateParticles()
    for index = #particles, 1, -1 do
        local particle = particles[index]
        particle.x += particle.vx
        particle.y += particle.vy
        particle.life -= 1
        if particle.life <= 0 then
            table.remove(particles, index)
        end
    end
end

local function updateCelebration()
    if not shouldShowCelebration() then
        return
    end

    celebrationCar.x += celebrationCar.speed
    if celebrationCar.x > SCREEN_W + 24 then
        celebrationCar.x = -24
        celebrationCar.y = math.random(203, 218)
    end

    celebrationCar.smokeTimer -= 1
    if celebrationCar.smokeTimer <= 0 then
        emitSmokeFrom(celebrationCar.x, celebrationCar.y, celebrationCar.dir, celebrationCar.speed, 5)
        celebrationCar.smokeTimer = 4
    end

    updateSmoke()
end

local function updateTitleAnimation()
    titleCar.x -= titleCar.speed
    if titleCar.x < -28 then
        titleCar.x = SCREEN_W + 28
        titleCar.y = math.random(24, 42)
    end

    titleCar.smokeTimer -= 1
    if titleCar.smokeTimer <= 0 then
        emitSmokeFrom(titleCar.x, titleCar.y, titleCar.dir, titleCar.speed, 4)
        titleCar.smokeTimer = 5
    end

    updateSmoke()
end

local function addPickupBurst(x, y)
    for _ = 1, 8 do
        particles[#particles + 1] = {
            x = x,
            y = y,
            vx = math.random(-14, 14) / 10,
            vy = math.random(-14, 14) / 10,
            life = math.random(12, 24)
        }
    end
end

local function checkCollisions()
    local ptx, pty = worldToTile(player.x, player.y)
    for _, flag in ipairs(flags) do
        if not flag.collected and flag.x == ptx and flag.y == pty then
            flag.collected = true
            game.collected += 1
            game.score += 100 * game.collected
            local fx, fy = tileToWorld(flag.x, flag.y)
            addPickupBurst(fx, fy)
            playPickupSound()

            if game.collected == #flags then
                nextLevel()
            end
        end
    end

    for _, enemy in ipairs(enemies) do
        for _, particle in ipairs(smoke) do
            local dx = enemy.x - particle.x
            local dy = enemy.y - particle.y
            local stunRadius = particle.radius + 8
            if dx * dx + dy * dy < stunRadius * stunRadius and enemy.stun <= 0 then
                enemy.stun = 135
                game.score += 50
                particle.life = math.min(particle.life, 18)
                playStunSound()
            end
        end

        if player.invincible <= 0 and math.abs(enemy.x - player.x) < 11 and math.abs(enemy.y - player.y) < 11 then
            loseLife()
            return
        end
    end
end

local function updateGame()
    game.frame += 1

    if game.state == "title" then
        updateTitleAnimation()
        if pd.buttonJustPressed(pd.kButtonA) then
            stopTitleMusic()
            game.state = "levelintro"
            game.message = "STAGE 1"
            game.messageTimer = LEVEL_INTRO_FRAMES
            smoke = {}
            playStageStartSound()
        end
        return
    end

    if game.state == "gameover" then
        game.gameOverTimer -= 1
        if game.gameOverTimer <= 0 then
            resetGame(true)
            return
        end
        updateCelebration()
        return
    end

    if game.state == "levelintro" then
        game.messageTimer -= 1
        if game.messageTimer <= 0 then
            game.state = "playing"
            game.messageTimer = 0
        end
        return
    end

    if game.messageTimer > 0 then
        game.messageTimer -= 1
    end

    updateInput()
    updatePlayer()
    updateEnemies()
    updateSmoke()
    updateParticles()
    checkCollisions()
end

local function drawMaze()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, WORLD_W, SCREEN_H)

    for y = 0, GRID_H - 1 do
        for x = 0, GRID_W - 1 do
            if isWall(x, y) then
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRoundRect(x * CELL + 1, y * CELL + 1, CELL - 2, CELL - 2, 2)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(x * CELL + 3, y * CELL + 3, CELL - 6, CELL - 6)
            else
                gfx.setColor(gfx.kColorWhite)
                gfx.setDitherPattern(0.12, gfx.image.kDitherTypeBayer8x8)
                gfx.fillRect(x * CELL, y * CELL, CELL, CELL)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawPixel(x * CELL + CELL / 2, y * CELL + CELL / 2)
                gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
            end
        end
    end
end

local function drawFlags()
    for _, flag in ipairs(flags) do
        if not flag.collected then
            local x, y = tileToWorld(flag.x, flag.y)
            flag.pulse += 0.12
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x, y, 5)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawLine(x - 2, y + 4, x - 2, y - 5)
            gfx.fillTriangle(x - 2, y - 5, x + 5, y - 2, x - 2, y + 1)
        end
    end
end

local function drawSmoke()
    for _, particle in ipairs(smoke) do
        local age = 1 - particle.life / particle.maxLife
        local dither = age < 0.35 and 0.72 or 0.42
        gfx.setColor(gfx.kColorWhite)
        gfx.setDitherPattern(dither, gfx.image.kDitherTypeBayer8x8)
        gfx.fillCircleAtPoint(particle.x, particle.y, particle.radius)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(particle.x, particle.y, particle.radius)
    end
    gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
end

local function drawPlayer()
    if player.invincible > 0 and game.frame % 8 < 4 then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(player.x - 7, player.y - 5, 14, 10, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(player.x - 3, player.y - 7, 7, 5)
    gfx.fillCircleAtPoint(player.x - 4, player.y + 5, 2)
    gfx.fillCircleAtPoint(player.x + 5, player.y + 5, 2)

    local dir = DIRS[player.dir]
    gfx.drawLine(player.x, player.y, player.x + dir.x * 9, player.y + dir.y * 9)
end

local function drawScreenCar(car)
    local facing = car.dir == "left" and -1 or 1

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(car.x - 13, car.y - 5, 26, 10, 2)
    gfx.fillTriangle(
        car.x + facing * 7, car.y - 5,
        car.x + facing * 16, car.y,
        car.x + facing * 7, car.y + 5
    )
    gfx.fillTriangle(
        car.x - facing * 9, car.y - 5,
        car.x - facing * 2, car.y - 12,
        car.x + facing * 7, car.y - 5
    )
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(car.x - facing * 5, car.y - 6, car.x + facing * 4, car.y - 6)
    gfx.fillRect(car.x - facing * 2 - 3, car.y - 10, 6, 4)
    gfx.fillCircleAtPoint(car.x - facing * 7, car.y + 5, 3)
    gfx.fillCircleAtPoint(car.x + facing * 9, car.y + 5, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(car.x - facing * 7, car.y + 5, 1)
    gfx.fillCircleAtPoint(car.x + facing * 9, car.y + 5, 1)
end

local function drawCelebrationCar()
    if not shouldShowCelebration() then
        return
    end

    drawScreenCar(celebrationCar)
end

local function drawEnemies()
    for _, enemy in ipairs(enemies) do
        gfx.setColor(gfx.kColorWhite)
        if enemy.stun > 0 then
            gfx.setDitherPattern(0.35, gfx.image.kDitherTypeBayer8x8)
        end
        gfx.fillRect(enemy.x - 6, enemy.y - 6, 12, 12)
        gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(enemy.x - 4, enemy.y - 2, enemy.x + 4, enemy.y - 2)
        gfx.fillCircleAtPoint(enemy.x - 3, enemy.y + 5, 2)
        gfx.fillCircleAtPoint(enemy.x + 3, enemy.y + 5, 2)
    end
end

local function drawParticles()
    gfx.setColor(gfx.kColorWhite)
    for _, particle in ipairs(particles) do
        gfx.fillRect(particle.x, particle.y, 2, 2)
    end
end

local function drawRadar()
    local radarX = HUD_X + 8
    local radarY = 128
    local radarW = HUD_W - 16
    local radarH = 66
    local sx = radarW / WORLD_W * game.radarZoom
    local sy = radarH / SCREEN_H * game.radarZoom

    gfx.setColor(gfx.kColorWhite)
    gfx.drawText("RADAR", radarX, radarY - 14)
    gfx.drawRect(radarX, radarY, radarW, radarH)

    local function plot(wx, wy, size)
        local x = radarX + math.floor(wx * sx) % radarW
        local y = radarY + math.floor(wy * sy) % radarH
        gfx.fillRect(x - size // 2, y - size // 2, size, size)
    end

    for _, flag in ipairs(flags) do
        if not flag.collected then
            local x, y = tileToWorld(flag.x, flag.y)
            plot(x, y, 3)
        end
    end

    plot(player.x, player.y, 5)

    gfx.setColor(gfx.kColorBlack)
    for _, enemy in ipairs(enemies) do
        plot(enemy.x, enemy.y, 4)
    end
end

local function drawHud()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(HUD_X, 0, HUD_W, SCREEN_H)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(HUD_X, 0, HUD_X, SCREEN_H)

    gfx.drawText("SCORE", HUD_X + 8, 8)
    gfx.drawTextAligned(tostring(game.score), SCREEN_W - 8, 25, kTextAlignment.right)

    gfx.drawText("FUEL", HUD_X + 8, 44)
    gfx.drawRect(HUD_X + 8, 62, HUD_W - 16, 9)
    gfx.fillRect(HUD_X + 10, 64, math.max(0, (HUD_W - 20) * game.fuel / 100), 5)

    gfx.drawText("LIVES", HUD_X + 8, 80)
    for i = 1, game.lives do
        gfx.fillCircleAtPoint(HUD_X + 10 + i * 12, 101, 4)
    end

    drawRadar()

    gfx.drawText("A SMOKE", HUD_X + 8, 204)
    gfx.drawText("B BRAKE", HUD_X + 8, 221)
end

local function drawMessageOverlay()
    if game.messageTimer <= 0 then
        return
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.65, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(42, 86, 236, 56)
    gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(42, 86, 236, 56)
    gfx.drawTextAligned(game.message, 160, 102, kTextAlignment.center)
end

local function drawStandaloneScreen(title, subtitle, prompt, detail, promptY)
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    useArcadeFont()
    drawWhiteCenteredText(title, SCREEN_W / 2, 74)
    gfx.drawLine(112, 102, 288, 102)
    drawWhiteCenteredText(subtitle, SCREEN_W / 2, 122)

    if detail ~= nil then
        drawWhiteCenteredText(detail, SCREEN_W / 2, 140)
    end

    if prompt ~= nil and game.frame % 60 < 42 then
        drawWhiteCenteredText(prompt, SCREEN_W / 2, promptY or 162)
    end

    if shouldShowCelebration() then
        drawSmoke()
        drawCelebrationCar()
        if game.newHighScore then
            drawWhiteCenteredText("NEW HIGH SCORE", SCREEN_W / 2, 38)
        end
    end
end

local function drawTitleScreen()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    useArcadeFont()
    drawSmoke()
    drawScreenCar(titleCar)
    drawWhiteCenteredText("RALLY RUN", SCREEN_W / 2, 64)
    gfx.drawLine(112, 92, 288, 92)
    -- drawWhiteCenteredText("COLLECT FLAGS", SCREEN_W / 2, 116)

    if game.frame % 60 < 42 then
        drawWhiteCenteredText("PRESS A", SCREEN_W / 2, 158)
    end

    drawWhiteCenteredText("HIGH SCORE " .. highScore, SCREEN_W / 2, 199)
end

local function drawGame()
    gfx.clear(gfx.kColorWhite)
    useArcadeFont()

    if game.state == "title" then
        drawTitleScreen()
        return
    elseif game.state == "gameover" then
        drawStandaloneScreen("GAME OVER", "SCORE " .. game.score, nil, "HIGH SCORE " .. highScore)
        return
    elseif game.state == "levelintro" then
        drawStandaloneScreen("STAGE " .. game.level, "GET READY")
        return
    end

    drawMaze()
    drawFlags()
    drawSmoke()
    drawParticles()
    drawPlayer()
    drawEnemies()
    drawHud()
    drawMessageOverlay()
end

function pd.update()
    updateGame()
    updateAudio()
    drawGame()
    pd.timer.updateTimers()
end

math.randomseed(pd.getSecondsSinceEpoch())
setupAudio()
loadHighScore()
resetGame(true)
