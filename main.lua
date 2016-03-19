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
 function round(v)
     return math.floor(v+0.5)
 end

function line(v0, v1, color)
    local x0 = v0[1]
    local y0 = v0[2]
    local x1 = v1[1]
    local y1 = v1[2]
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

function orderPointsBy(p0, p1, p2, dimIdx)
    local lowP = nil
    local midP = nil
    local highP = nil
    if p1[dimIdx] <= p0[dimIdx] and p0[dimIdx] <= p2[dimIdx] then
        lowP = p1
        midP = p0
        highP = p2
    elseif p2[dimIdx] <= p0[dimIdx] and p0[dimIdx] <= p1[dimIdx] then
        lowP = p2
        midP = p0
        highP = p1
    elseif p0[dimIdx] <= p1[dimIdx] and p1[dimIdx] <= p2[dimIdx] then
        lowP = p0
        midP = p1
        highP = p2
    elseif p2[dimIdx] <= p1[dimIdx] and p1[dimIdx] <= p0[dimIdx] then
        lowP = p2
        midP = p1
        highP = p0
    elseif p1[dimIdx] <= p2[dimIdx] and p2[dimIdx] <= p0[dimIdx] then
        lowP = p1
        midP = p2
        highP = p0
    elseif p0[dimIdx] <= p2[dimIdx] and p2[dimIdx] <= p1[dimIdx] then
        lowP = p0
        midP = p2
        highP = p1
    end
    return lowP, midP, highP
end

function triangle(v0, v1, v2, color)
    local yIdx = 2
    local lowV, midV, highV = orderPointsBy(v0, v1, v2, yIdx)
    local fracY = (midV[2] - lowV[2]) / (highV[2] - lowV[2])
    local midVFrac = {lowV[1] + fracY * (highV[1] - lowV[1]), midV[2]}

    for y = lowV[2], midV[2] do
        local subFracY = (y - lowV[2]) / (midV[2] - lowV[2])
        local x1 = round(lowV[1] + subFracY * (midVFrac[1] - lowV[1]))
        local x2 = round(lowV[1] + subFracY * (midV[1] - lowV[1]))
        for x = math.min(x1, x2), math.max(x1, x2) do
            drawPoint(x, y, color)
        end
    end

    for y = midV[2], highV[2] do
        local subFracY = (y - midV[2]) / (highV[2] - midV[2])
        local x1 = round(midVFrac[1] + subFracY * (highV[1] - midVFrac[1]))
        local x2 = round(midV[1] + subFracY * (highV[1] - midV[1]))
        for x = math.min(x1, x2), math.max(x1, x2) do
            drawPoint(x, y, color)
        end
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

    function transformVToScreenSpace(v)
        return {(v[1] + 1) * WIDTH / 2, (v[2] + 1) * HEIGHT / 2}
    end

    for _, face in ipairs(faces) do
        local v0 = verts[face.verts[1]]
        local v1 = verts[face.verts[2]]
        local v2 = verts[face.verts[3]]
        triangle(transformVToScreenSpace(v0), transformVToScreenSpace(v1), transformVToScreenSpace(v2), {r=255, g=255, b=255, a=255})
    end
end

rdr:setDrawColor(0x000000)
rdr:clear()

drawModel(MODEL_PATH)
rdr:present()

for i = 1, 50 do
    SDL.delay(100)
end
