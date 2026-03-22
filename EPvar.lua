local EP = {}

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

--// Player
EP.lplr = Players.LocalPlayer

--// Device
EP.isMobile = UIS.TouchEnabled
EP.isPC = not UIS.TouchEnabled

--// Character
local function setupChar(char)
    EP.character = char
    EP.humanoid = char:WaitForChild("Humanoid")
    EP.root = char:WaitForChild("HumanoidRootPart")
end

setupChar(EP.lplr.Character or EP.lplr.CharacterAdded:Wait())
EP.lplr.CharacterAdded:Connect(setupChar)

--// Camera
EP.camera = Workspace.CurrentCamera

--// FPS
EP.fps = 0
do
    local frames = 0
    local last = tick()
    RunService.RenderStepped:Connect(function()
        frames += 1
        if tick() - last >= 1 then
            EP.fps = frames
            frames = 0
            last = tick()
        end
    end)
end

--// Ping
EP.getPing = function()
    return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
end

--// =========================
--// UTILS (CUSTOM)
--// =========================

EP.safeWaitForChild = function(obj, child)
    return obj:FindFirstChild(child) or obj:WaitForChild(child)
end

EP.getPlayers = function(config)
    config = config or {}

    local includeSelf = config.includeSelf or false
    local onlyAlive = config.onlyAlive or false

    local t = {}

    for _,v in pairs(Players:GetPlayers()) do
        if (includeSelf or v ~= EP.lplr) then
            if not onlyAlive or (v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0) then
                table.insert(t, v)
            end
        end
    end

    return t
end

EP.isPlayerValid = function(plr)
    return plr
        and plr.Character
        and plr.Character:FindFirstChild("HumanoidRootPart")
end

EP.getClosestPlayer = function(config)
    config = config or {}

    local maxDistance = config.maxDistance or math.huge
    local ignore = config.ignore or {}

    local closest, dist = nil, maxDistance

    for _,v in pairs(Players:GetPlayers()) do
        if v ~= EP.lplr and not table.find(ignore, v) and EP.isPlayerValid(v) then
            local mag = (EP.root.Position - v.Character.HumanoidRootPart.Position).Magnitude
            if mag < dist then
                dist = mag
                closest = v
            end
        end
    end

    return closest, dist
end

EP.worldToScreen = function(pos, config)
    local vec, vis = EP.camera:WorldToViewportPoint(pos)
    if config and config.vector2 then
        return Vector2.new(vec.X, vec.Y), vis
    end
    return vec, vis
end

EP.getDistance = function(a,b)
    return (a - b).Magnitude
end

EP.isAlive = function()
    return EP.humanoid and EP.humanoid.Health > 0
end

EP.loop = function(fn)
    return RunService.RenderStepped:Connect(fn)
end

EP.notify = function(t, txt, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = t,
            Text = txt,
            Duration = duration or 3
        })
    end)
end

--// =========================
--// OVERLAY (CUSTOM)
--// =========================

function EP:CreateOverlay(config)
    config = config or {}

    local settings = {
        position = config.position or UDim2.new(0,10,0,10),
        size = config.size or UDim2.new(0,200,0,80),
        bgColor = config.bgColor or Color3.fromRGB(20,20,20),
        textColor = config.textColor or Color3.new(1,1,1),
        showFPS = config.showFPS ~= false,
        showPing = config.showPing ~= false,
        showPlayers = config.showPlayers ~= false,
        updateRate = config.updateRate or 0,
        customText = config.customText
    }

    local gui = Instance.new("ScreenGui", game.CoreGui)
    local label = Instance.new("TextLabel", gui)

    label.Size = settings.size
    label.Position = settings.position
    label.BackgroundColor3 = settings.bgColor
    label.BackgroundTransparency = 0.3
    label.TextColor3 = settings.textColor
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top

    Instance.new("UICorner", label)

    local last = 0

    local connection = EP.loop(function()
        if settings.updateRate > 0 and tick() - last < settings.updateRate then return end
        last = tick()

        if settings.customText then
            label.Text = settings.customText()
            return
        end

        local txt = ""

        if settings.showFPS then
            txt ..= "FPS: "..EP.fps.."\n"
        end
        if settings.showPing then
            txt ..= "Ping: "..math.floor(EP.getPing()).."\n"
        end
        if settings.showPlayers then
            txt ..= "Players: "..#Players:GetPlayers()
        end

        label.Text = txt
    end)

    return {
        destroy = function()
            connection:Disconnect()
            gui:Destroy()
        end
    }
end

--// =========================
--// UI SYSTEM MELHORADO
--// =========================

EP.UI = {}

function EP.UI:CreateWindow(title, config)
    config = config or {}

    local gui = Instance.new("ScreenGui", game.CoreGui)

    local Main = Instance.new("Frame", gui)
    Main.Size = config.size or UDim2.new(0,300,0,350)
    Main.Position = config.position or UDim2.new(0.5,-150,0.5,-175)
    Main.BackgroundColor3 = config.bgColor or Color3.fromRGB(25,25,25)

    Instance.new("UICorner", Main)

    local Title = Instance.new("TextLabel", Main)
    Title.Size = UDim2.new(1,0,0,30)
    Title.Text = title
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.new(1,1,1)

    local Container = Instance.new("Frame", Main)
    Container.Size = UDim2.new(1,0,1,-30)
    Container.Position = UDim2.new(0,0,0,30)
    Container.BackgroundTransparency = 1

    Instance.new("UIListLayout", Container)

    local Window = {}

    function Window:Button(text, cb)
        local b = Instance.new("TextButton", Container)
        b.Size = UDim2.new(1,-10,0,40)
        b.Text = text
        b.BackgroundColor3 = Color3.fromRGB(40,40,40)
        b.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(cb)
    end

    function Window:Toggle(text, cb, default)
        local state = default or false

        local b = Instance.new("TextButton", Container)
        b.Size = UDim2.new(1,-10,0,40)
        b.BackgroundColor3 = Color3.fromRGB(40,40,40)
        b.TextColor3 = Color3.new(1,1,1)

        local function update()
            b.Text = text.." ["..(state and "ON" or "OFF").."]"
        end

        update()

        Instance.new("UICorner", b)

        b.MouseButton1Click:Connect(function()
            state = not state
            update()
            cb(state)
        end)
    end

    function Window:Label(text)
        local l = Instance.new("TextLabel", Container)
        l.Size = UDim2.new(1,-10,0,30)
        l.Text = text
        l.BackgroundTransparency = 1
        l.TextColor3 = Color3.new(1,1,1)
    end

    return Window
end

--// =========================
--// TEMPLATE
--// =========================

function EP:CreateBasicUI(title)
    local ui = EP.UI:CreateWindow(title)

    ui:Label("EP Loaded")

    ui:Button("Notify", function()
        EP.notify("EP","Funcionando")
    end)

    ui:Button("Closest Player", function()
        local p = EP.getClosestPlayer()
        print(p and p.Name)
    end)

    ui:Toggle("Overlay", function(v)
        if v then
            EP._overlay = EP:CreateOverlay()
        else
            if EP._overlay then EP._overlay.destroy() end
        end
    end)

    return ui
end

--// =========================
--// MOUSE / TOUCH UTILS
--// =========================

EP.mouse = (not EP.isMobile) and EP.lplr:GetMouse() or nil

EP.getMousePosition = function()
    if EP.isMobile then
        local pos = UIS:GetMouseLocation()
        return Vector2.new(pos.X, pos.Y)
    else
        return UIS:GetMouseLocation()
    end
end

EP.getMouseRay = function()
    local pos = EP.getMousePosition()
    return EP.camera:ViewportPointToRay(pos.X, pos.Y)
end

EP.mouseHit = function(config)
    config = config or {}

    local ray = EP.getMouseRay()

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = config.ignore or {EP.character}
    params.FilterType = Enum.RaycastFilterType.Blacklist

    local result = Workspace:Raycast(ray.Origin, ray.Direction * (config.distance or 1000), params)

    if result then
        return result.Position, result.Instance, result
    end

    return ray.Origin + ray.Direction * 1000, nil, nil
end

return EP
