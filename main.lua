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

local function subV3(v0, v1)
    return { v0[1] - v1[1], v0[2] - v1[2], v0[3] - v1[3] }
end

local function crossV3(v0, v1)
    return {
        v0[2] * v1[3] - v0[3] * v1[2],
        v0[3] * v1[1] - v0[1] * v1[3],
        v0[1] * v1[2] - v0[2] * v1[1]
    }
end

local function dotV3(v0, v1)
    return v0[1] * v1[1] + v0[2] * v1[2] + v0[3] * v1[3]
end

local function lenV3(v)
    return math.sqrt(dotV3(v, v))
end

local function normalizeV3(v)
    local len = lenV3(v)
    return { v[1] / len, v[2] / len, v[3] / len }
end

function barycentric(v0, v1, v2, p)
    local u = crossV3({ v2[1]-v0[1], v1[1]-v0[1], v0[1]-p[1] }, { v2[2]-v0[2], v1[2]-v0[2], v0[2]-p[2] })
    if math.abs(u[3]) < 1 then
        return { -1, 1, 1 } -- triangle is degenerate
    else
        return { 1.0 - (u[1] + u[2]) / u[3], u[2] / u[3], u[1] / u[3] }
    end
end

local zBuffer = {}

local function setZ(x, y, z)
    zBuffer[x + y * HEIGHT] = z
end

local function getZ(x, y)
    return zBuffer[x + y * HEIGHT]
end

function triangle(v0, v1, v2, color)
    local xIdx, yIdx = 1, 2
    local minXV, _, maxXV = orderPointsBy(v0, v1, v2, xIdx)
    local minYV, _, maxYV = orderPointsBy(v0, v1, v2, yIdx)
    for x = math.floor(minXV[xIdx]), math.ceil(maxXV[xIdx]) do
        for y = math.floor(minYV[yIdx]), math.ceil(maxYV[yIdx]) do
            local bcScreen = barycentric(v0, v1, v2, {x, y})
            if (bcScreen[1] >= 0 and bcScreen[2] >= 0 and bcScreen[3] >= 0) then
                local z =
                    bcScreen[1] * v0[3] +
                    bcScreen[2] * v1[3] +
                    bcScreen[3] * v2[3]
                local existingZ = getZ(x, y)
                if (existingZ == nil or z > existingZ) then
                    setZ(x, y, z)
                    drawPoint(x, y, color)
                end
            end
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
    local lightDir = { 0, 0, -1 }

    function transformVToScreenSpace(v)
        local c = 4
        local x = v[1] / (1 - v[3] / c)
        local y = v[2] / (1 - v[3] / c)
        local z = v[3] / (1 - v[3] / c)
        local xScaled = (x + 1) * WIDTH / 2
        local yScaled = (y + 1) * HEIGHT / 2
        return { xScaled, yScaled, z }
    end

    for _, face in ipairs(faces) do
        local v0 = verts[face.verts[1]]
        local v1 = verts[face.verts[2]]
        local v2 = verts[face.verts[3]]
        local n = normalizeV3(crossV3(subV3(v2, v0), subV3(v1, v0)))
        local intensity = math.max(0, dotV3(n, lightDir))
        triangle(
            transformVToScreenSpace(v0),
            transformVToScreenSpace(v1),
            transformVToScreenSpace(v2),
            {r=intensity * 255, g=intensity * 255, b=intensity * 255, a=255}
        )
    end
end

rdr:setDrawColor(0x000000)
rdr:clear()

drawModel(MODEL_PATH)
rdr:present()

for i = 1, 50 do
    SDL.delay(100)
end
