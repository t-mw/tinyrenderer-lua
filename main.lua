-- requires 'lua-sdl2'
local SDL= require "SDL"
local image= require "SDL.image"

local ret, err = SDL.init { SDL.flags.Video }
if not ret then
    error(err)
end

local formats, ret, err = image.init { image.flags.PNG }
if not ret then
    error(err)
end

WIDTH = 640
HEIGHT = 640
local win, err = SDL.createWindow {
    title="Image",
    width=WIDTH,
    height=HEIGHT
}

if not win then
    error(err)
end

local rdr, err = SDL.createRenderer(win, 0, 0)
if not rdr then
    error(err)
end

MODEL_PATH = 'obj/african_head.obj'

function drawPoint(x, y, color)
    rdr:setDrawColor(color)
    -- invert y-coordinate to set origin to bottom-left corner of screen
    rdr:drawPoint({x=x, y=HEIGHT-y})
end

function line(x0, y0, x1, y1, color)
    local function round(v)
        return math.floor(v+0.5)
    end
    local xMag = math.abs(x1 - x0)
    local yMag = math.abs(y1 - y0)
    local useX = (xMag > yMag)
    local t0 = useX and math.min(x0, x1) or math.min(y0, y1)
    local t1 = useX and math.max(x0, x1) or math.max(y0, y1)
    local sign = (t1 - t0 > 0 and 1 or -1)
    for t = t0, t1, sign do
        local tFrac = (t - t0) / (t1 - t0)
        local x = round(x0 * (1 - tFrac) + x1 * tFrac)
        local y = round(y0 * (1 - tFrac) + y1 * tFrac)
        drawPoint(x, y, color)
    end
end

function parseObj(path)
    local faces = {}
    local verts = {}

    local f = assert(io.open(path, "r"))
    while true do
        local line = f:read("*line")
        if line == nil then
            break
        else
            local vx, vy, vz = string.match(line, "v (%S+) (%S+) (%S+)")
            local vertMatch = (vx ~= nil)
            if vertMatch then
                table.insert(verts, {tonumber(vx), tonumber(vy), tonumber(vz)})
            else
                local fv1, fv2, fv3 = string.match(line, "f (%d+)/%d+/%d+ (%d+)/%d+/%d+ (%d+)/%d+/%d+")
                local faceMatch = (fv1 ~= nil)
                if faceMatch then
                    table.insert(faces, {verts={tonumber(fv1), tonumber(fv2), tonumber(fv3)}})
                end
            end
        end
    end
    f:close()
    return faces, verts
end

local function drawModel(modelPath)
    local faces, verts = parseObj(modelPath)
    for _, face in ipairs(faces) do
        for i = 1, 3 do
            local v0 = verts[face.verts[i]]
            local v1 = verts[face.verts[i % 3 + 1]]
            line(
                (v0[1] + 1) * WIDTH / 2,      -- x0
                (v0[2] + 1) * HEIGHT / 2,     -- y0
                (v1[1] + 1) * WIDTH / 2,      -- x1
                (v1[2] + 1) * HEIGHT / 2,     -- y1
                {r=255, g=255, b=255, a=255}  -- color
            )
        end
    end
end

rdr:setDrawColor(0x000000)
rdr:clear()

drawModel(MODEL_PATH)
rdr:present()

for i = 1, 50 do
    SDL.delay(100)
end
