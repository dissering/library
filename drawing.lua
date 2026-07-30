-- drawing.lua - Fork of wows.lua with gradient + outline + image support
-- Original: norbyv1/Lua-Drawing-Library (fork of solara's drawing)
-- Outline: black, +1 thickness on all drawing types

do
	local CoreGui = game:GetService("CoreGui")
	local DrawingUI = Instance.new("ScreenGui")
	DrawingUI.Name = "IhwaDrawing"
	DrawingUI.IgnoreGuiInset = true
	DrawingUI.DisplayOrder = 0x7fffffff
	DrawingUI.Parent = CoreGui

	local MergeTable = function(base, override)
		local result = table.clone(base)
		for k, v in override do
			result[k] = v
		end
		return result
	end

	local ConvertTransparency = function(transparency)
		return math.clamp(1 - transparency, 0, 1)
	end

	local RandomString = function(length)
		local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
		local result = {}
		for i = 1, length do
			local index = math.random(1, #charset)
			table.insert(result, charset:sub(index, index))
		end
		return table.concat(result)
	end

	local BaseDrawingObj = setmetatable({
		Visible = true,
		ZIndex = 0,
		Transparency = 1,
		Color = Color3.new(),
		__OBJECT_EXISTS = true,
		Remove = function(self)
			if self.__OBJECT_EXISTS == false then return end
			self.__OBJECT_EXISTS = false
			self.Visible = false
		end,
		Destroy = function(self)
			if self.__OBJECT_EXISTS == false then return end
			self.__OBJECT_EXISTS = false
			self.Visible = false
		end,
	}, {
		__add = function(t1, t2) return MergeTable(t1, t2) end
	})

	local FontEnum = {
		[0] = Font.fromEnum(Enum.Font.Roboto),
		[1] = Font.fromEnum(Enum.Font.Legacy),
		[2] = Font.fromEnum(Enum.Font.SourceSans),
		[3] = Font.fromEnum(Enum.Font.RobotoMono),
	}

	getgenv().Drawing = {}

	getgenv().Drawing.Fonts = {
		UI = 0, System = 1, Plex = 2, Monospace = 3,
	}
	table.freeze(getgenv().Drawing.Fonts)

	getgenv().Drawing.clear = newcclosure(function()
		pcall(function()
			DrawingUI:ClearAllChildren()
			delfolder(".Drawing/CustomAssets")
		end)
	end)
	getgenv().cleardrawcache = getgenv().Drawing.clear

	-- Helper: apply or update gradient on a frame
	-- Supports: ColorStart+ColorEnd (2-color), ColorSequence (multi-color)
	local function ApplyGradient(frame, gradData)
		if not gradData or (not gradData.ColorStart and not gradData.ColorSequence) then
			local existing = frame:FindFirstChildOfClass("UIGradient")
			if existing then existing:Destroy() end
			return
		end
		local grad = frame:FindFirstChildOfClass("UIGradient")
		if not grad then
			grad = Instance.new("UIGradient")
			grad.Parent = frame
		end
		if gradData.ColorSequence then
			grad.Color = gradData.ColorSequence
		elseif gradData.ColorStart and gradData.ColorEnd then
			grad.Color = ColorSequence.new(gradData.ColorStart, gradData.ColorEnd)
		end
		if gradData.Rotation then
			grad.Rotation = gradData.Rotation
		end
		if gradData.Offset then
			grad.Offset = gradData.Offset
		end
	end

	-- Helper: load image from URL or raw bytes
	local imageCache = {}
	local function LoadImage(urlOrData)
		if not urlOrData or urlOrData == "" then return nil end
		-- check cache first (by URL)
		if imageCache[urlOrData] then return imageCache[urlOrData] end
		local filename = ".Drawing/CustomAssets/" .. RandomString(8) .. ".png"
		local success = pcall(function()
			local data
			if type(urlOrData) == "string" and (urlOrData:sub(1, 4) == "http" or urlOrData:sub(1, 5) == "https") then
				data = game:HttpGet(urlOrData)
			else
				data = urlOrData
			end
			-- make sure folder exists
			if not isfolder(".Drawing/CustomAssets") then
				makefolder(".Drawing/CustomAssets")
			end
			writefile(filename, data)
		end)
		if success then
			local asset = getcustomasset(filename)
			if type(urlOrData) == "string" and urlOrData:sub(1, 4) == "http" then
				imageCache[urlOrData] = asset
			end
			return asset
		end
		return nil
	end

	getgenv().Drawing.new = newcclosure(function(Type)
		assert(typeof(Type) == "string", "invalid argument #1 to 'Drawing.new' (string expected, got " .. typeof(Type) .. ")")

		local CreateFrame = function(Name)
			local Frame = Instance.new("Frame")
			Frame.Name = Name
			Frame.BorderSizePixel = 0
			Frame.AnchorPoint = Vector2.new(0.5, 0.5)
			Frame.BackgroundTransparency = 1
			Frame.ZIndex = 0
			Frame.Visible = true
			return Frame
		end

		if Type == "Line" then
			local Obj = MergeTable(BaseDrawingObj, {
				From = Vector2.zero,
				To = Vector2.zero,
				Thickness = 1,
				Outline = false,
				OutlineColor = Color3.new(0, 0, 0),
			})

			local LineFrame = CreateFrame("Line")
			LineFrame.BackgroundColor3 = Obj.Color
			LineFrame.Visible = Obj.Visible
			LineFrame.ZIndex = Obj.ZIndex
			LineFrame.BackgroundTransparency = ConvertTransparency(Obj.Transparency)
			LineFrame.Size = UDim2.new()
			LineFrame.Parent = DrawingUI

			-- outline frame (behind, +1 thickness, black)
			local OutlineFrame = CreateFrame("LineOutline")
			OutlineFrame.BackgroundColor3 = Color3.new(0, 0, 0)
			OutlineFrame.ZIndex = Obj.ZIndex - 1
			OutlineFrame.Size = UDim2.new()
			OutlineFrame.Parent = DrawingUI

			local function updateLine()
				local Direction = Obj.To - Obj.From
				local Center = (Obj.To + Obj.From) / 2
				local Distance = Direction.Magnitude
				local Theta = math.deg(math.atan2(Direction.Y, Direction.X))
				LineFrame.Position = UDim2.fromOffset(Center.X, Center.Y)
				LineFrame.Rotation = Theta
				LineFrame.Size = UDim2.fromOffset(Distance, Obj.Thickness)
				if Obj.Outline then
					OutlineFrame.Position = LineFrame.Position
					OutlineFrame.Rotation = Theta
					OutlineFrame.Size = UDim2.fromOffset(Distance, Obj.Thickness + 1)
					OutlineFrame.Visible = Obj.Visible
				else
					OutlineFrame.Visible = false
				end
			end

			return setmetatable({}, {
				__newindex = function(_, Key, Value)
					if Obj.__OBJECT_EXISTS == false then return end
					if Obj[Key] == nil then return end
					if Key == "From" or Key == "To" then
						Obj[Key] = Value
						updateLine()
					elseif Key == "Thickness" then
						Obj.Thickness = Value
						updateLine()
					elseif Key == "Visible" then
						Obj.Visible = Value
						LineFrame.Visible = Value
						OutlineFrame.Visible = Value and Obj.Outline
					elseif Key == "ZIndex" then
						Obj.ZIndex = Value
						LineFrame.ZIndex = Value
						OutlineFrame.ZIndex = Value - 1
					elseif Key == "Transparency" then
						Obj.Transparency = Value
						LineFrame.BackgroundTransparency = ConvertTransparency(Value)
						OutlineFrame.BackgroundTransparency = ConvertTransparency(Value)
					elseif Key == "Color" then
						Obj.Color = Value
						LineFrame.BackgroundColor3 = Value
					elseif Key == "Outline" then
						Obj.Outline = Value
						updateLine()
					elseif Key == "OutlineColor" then
						Obj.OutlineColor = Value
						OutlineFrame.BackgroundColor3 = Value
					end
				end,
				__index = function(_, Key)
					if Key == "Remove" or Key == "Destroy" then
						return function()
							LineFrame:Destroy()
							OutlineFrame:Destroy()
							Obj:Remove()
						end
					end
					return Obj[Key]
				end,
				__tostring = function() return "Drawing" end,
			})

		elseif Type == "Text" then
			local Obj = MergeTable(BaseDrawingObj, {
				Text = "",
				Font = Drawing.Fonts.UI,
				Size = 14,
				Position = Vector2.zero,
				Center = false,
				Outline = false,
				OutlineColor = Color3.new(0, 0, 0),
			})

			local TextLabel = Instance.new("TextLabel")
			local UIStroke = Instance.new("UIStroke")
			TextLabel.Name = "Text"
			TextLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			TextLabel.BorderSizePixel = 0
			TextLabel.BackgroundTransparency = 1
			TextLabel.Visible = Obj.Visible
			TextLabel.TextColor3 = Obj.Color
			TextLabel.TextTransparency = ConvertTransparency(Obj.Transparency)
			TextLabel.ZIndex = Obj.ZIndex
			TextLabel.FontFace = FontEnum[Obj.Font]
			TextLabel.TextSize = Obj.Size
			TextLabel.Text = Obj.Text
			UIStroke.Thickness = 1
			UIStroke.Enabled = Obj.Outline
			UIStroke.Color = Obj.OutlineColor
			UIStroke.Parent = TextLabel
			TextLabel.Parent = DrawingUI

			local updatePosition = function()
				local bounds = TextLabel.TextBounds
				local offsetX = Obj.Center and 0 or bounds.X / 2
				local offsetY = bounds.Y / 2
				local posX = (typeof(Obj.Position) == "Vector2") and Obj.Position.X or 0
				local posY = (typeof(Obj.Position) == "Vector2") and Obj.Position.Y or 0
				TextLabel.Size = UDim2.fromOffset(bounds.X, bounds.Y)
				TextLabel.Position = UDim2.fromOffset(posX + offsetX, posY + offsetY)
			end

			return setmetatable({}, {
				__newindex = function(_, Key, Value)
					if Obj.__OBJECT_EXISTS == false then return end
					if Obj[Key] == nil or Obj[Key] == Value then return end
					if Key == "Text" then
						Obj.Text = Value; TextLabel.Text = Value; updatePosition()
					elseif Key == "Font" then
						Obj.Font = math.clamp(Value, 0, 3); TextLabel.FontFace = FontEnum[Obj.Font]; updatePosition()
					elseif Key == "Size" then
						Obj.Size = Value; TextLabel.TextSize = Value; updatePosition()
					elseif Key == "Position" or Key == "Center" then
						Obj[Key] = Value; updatePosition()
					elseif Key == "Outline" then
						Obj.Outline = Value; UIStroke.Enabled = Value
					elseif Key == "OutlineColor" then
						Obj.OutlineColor = Value; UIStroke.Color = Value
					elseif Key == "Visible" then
						Obj.Visible = Value; TextLabel.Visible = Value
					elseif Key == "ZIndex" then
						Obj.ZIndex = Value; TextLabel.ZIndex = Value
					elseif Key == "Transparency" then
						Obj.Transparency = Value
						local t = ConvertTransparency(Value)
						TextLabel.TextTransparency = t; UIStroke.Transparency = t
					elseif Key == "Color" then
						Obj.Color = Value; TextLabel.TextColor3 = Value
					end
				end,
				__index = function(_, Key)
					if Key == "Remove" or Key == "Destroy" then
						return function() TextLabel:Destroy(); Obj:Remove() end
					elseif Key == "TextBounds" then return TextLabel.TextBounds end
					return Obj[Key]
				end,
				__tostring = function() return "Drawing" end,
			})

		elseif Type == "Circle" then
			local Obj = MergeTable(BaseDrawingObj, {
				Radius = 75,
				Position = Vector2.zero,
				Thickness = 1,
				Filled = false,
				NumSides = 60,
				Outline = false,
				OutlineColor = Color3.new(0, 0, 0),
				GradientStart = nil,
				GradientEnd = nil,
				GradientRotation = 0,
				GradientColorSequence = nil,
			})

			local circleFrame = Instance.new("Frame")
			local uiCorner = Instance.new("UICorner")
			local uiStroke = Instance.new("UIStroke")
			local outlineStroke = Instance.new("UIStroke")

			circleFrame.Name = "Circle"
			circleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			circleFrame.BorderSizePixel = 0
			circleFrame.BackgroundColor3 = Obj.Color
			circleFrame.BackgroundTransparency = (Obj.Filled and ConvertTransparency(Obj.Transparency)) or 1
			circleFrame.Position = UDim2.fromOffset(Obj.Position.X, Obj.Position.Y)
			circleFrame.ZIndex = Obj.ZIndex
			circleFrame.Visible = Obj.Visible
			uiCorner.CornerRadius = UDim.new(1, 0)
			uiCorner.Parent = circleFrame
			uiStroke.Thickness = Obj.Thickness
			uiStroke.Enabled = not Obj.Filled
			uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			uiStroke.Color = Obj.Color
			uiStroke.Transparency = ConvertTransparency(Obj.Transparency)
			uiStroke.Parent = circleFrame
			outlineStroke.Thickness = 1
			outlineStroke.Enabled = false
			outlineStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			outlineStroke.Color = Color3.new(0, 0, 0)
			outlineStroke.Transparency = ConvertTransparency(Obj.Transparency)
			outlineStroke.Parent = circleFrame
			circleFrame.Size = UDim2.fromOffset(Obj.Radius * 2, Obj.Radius * 2)
			circleFrame.Parent = DrawingUI

			return setmetatable({}, {
				__newindex = function(_, Key, Value)
					if Obj.__OBJECT_EXISTS == false then return end
					if Obj[Key] == nil then return end
					if Key == "Radius" then
						Obj.Radius = Value
						circleFrame.Size = UDim2.fromOffset(Value * 2, Value * 2)
					elseif Key == "Position" then
						Obj.Position = Value
						circleFrame.Position = UDim2.fromOffset(Value.X, Value.Y)
					elseif Key == "Thickness" then
						Obj.Thickness = math.clamp(Value, 0.6, 1e4)
						uiStroke.Thickness = Obj.Thickness
						if Obj.Outline then outlineStroke.Thickness = Obj.Thickness + 1 end
					elseif Key == "Filled" then
						Obj.Filled = Value
						circleFrame.BackgroundTransparency = (Value and ConvertTransparency(Obj.Transparency)) or 1
						uiStroke.Enabled = not Value
					elseif Key == "Visible" then
						Obj.Visible = Value; circleFrame.Visible = Value
					elseif Key == "Transparency" then
						Obj.Transparency = Value
						local t = ConvertTransparency(Value)
						circleFrame.BackgroundTransparency = (Obj.Filled and t) or 1
						uiStroke.Transparency = t; outlineStroke.Transparency = t
					elseif Key == "Color" then
						Obj.Color = Value
						circleFrame.BackgroundColor3 = Value; uiStroke.Color = Value
					elseif Key == "ZIndex" then
						Obj.ZIndex = Value; circleFrame.ZIndex = Value
					elseif Key == "NumSides" then
						Obj.NumSides = Value
					elseif Key == "Outline" then
						Obj.Outline = Value
						outlineStroke.Enabled = Value
						outlineStroke.Thickness = Obj.Thickness + 1
					elseif Key == "OutlineColor" then
						Obj.OutlineColor = Value; outlineStroke.Color = Value
					elseif Key == "GradientStart" then
						Obj.GradientStart = Value
						ApplyGradient(circleFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					elseif Key == "GradientEnd" then
						Obj.GradientEnd = Value
						ApplyGradient(circleFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					elseif Key == "GradientColorSequence" then
						Obj.GradientColorSequence = Value
						ApplyGradient(circleFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					elseif Key == "GradientRotation" then
						Obj.GradientRotation = Value
						ApplyGradient(circleFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					end
				end,
				__index = function(_, Key)
					if Key == "Remove" or Key == "Destroy" then
						return function() circleFrame:Destroy(); Obj:Remove() end
					end
					return Obj[Key]
				end,
				__tostring = function() return "Drawing" end,
			})

		elseif Type == "Square" then
			local Obj = MergeTable(BaseDrawingObj, {
				Size = Vector2.new(100, 100),
				Position = Vector2.zero,
				Thickness = 1,
				Filled = false,
				Outline = false,
				OutlineColor = Color3.new(0, 0, 0),
				GradientStart = nil,
				GradientEnd = nil,
				GradientRotation = 0,
				GradientColorSequence = nil,
			})

			local squareFrame = Instance.new("Frame")
			local uiStroke = Instance.new("UIStroke")
			local outlineStroke = Instance.new("UIStroke")
			squareFrame.Name = "Square"
			squareFrame.BorderSizePixel = 0
			squareFrame.AnchorPoint = Vector2.new(0, 0)
			squareFrame.BackgroundTransparency = (Obj.Filled and ConvertTransparency(Obj.Transparency)) or 1
			squareFrame.ZIndex = Obj.ZIndex
			squareFrame.BackgroundColor3 = Obj.Color
			squareFrame.Visible = Obj.Visible
			uiStroke.Thickness = Obj.Thickness
			uiStroke.Enabled = not Obj.Filled
			uiStroke.LineJoinMode = Enum.LineJoinMode.Miter
			uiStroke.Color = Obj.Color
			uiStroke.Transparency = ConvertTransparency(Obj.Transparency)
			outlineStroke.Thickness = 1
			outlineStroke.Enabled = false
			outlineStroke.LineJoinMode = Enum.LineJoinMode.Miter
			outlineStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			outlineStroke.Color = Color3.new(0, 0, 0)
			outlineStroke.Transparency = ConvertTransparency(Obj.Transparency)
			squareFrame.Size = UDim2.fromOffset(Obj.Size.X, Obj.Size.Y)
			squareFrame.Position = UDim2.fromOffset(Obj.Position.X, Obj.Position.Y)
			squareFrame.Parent = DrawingUI
			uiStroke.Parent = squareFrame
			outlineStroke.Parent = squareFrame

			return setmetatable({}, {
				__newindex = function(_, Key, Value)
					if Obj.__OBJECT_EXISTS == false then return end
					if Obj[Key] == nil then return end
					if Key == "Size" then
						Obj.Size = Value
						squareFrame.Size = UDim2.fromOffset(Value.X, Value.Y)
					elseif Key == "Position" then
						Obj.Position = Value
						squareFrame.Position = UDim2.fromOffset(Value.X, Value.Y)
					elseif Key == "Thickness" then
						Obj.Thickness = math.clamp(Value, 0.6, 1e4)
						uiStroke.Thickness = Obj.Thickness
						if Obj.Outline then outlineStroke.Thickness = Obj.Thickness + 1 end
					elseif Key == "Filled" then
						Obj.Filled = Value
						squareFrame.BackgroundTransparency = (Value and ConvertTransparency(Obj.Transparency)) or 1
						uiStroke.Enabled = not Value
					elseif Key == "Visible" then
						Obj.Visible = Value; squareFrame.Visible = Value
					elseif Key == "Transparency" then
						Obj.Transparency = Value
						local t = ConvertTransparency(Value)
						squareFrame.BackgroundTransparency = (Obj.Filled and t) or 1
						uiStroke.Transparency = t; outlineStroke.Transparency = t
					elseif Key == "Color" then
						Obj.Color = Value
						uiStroke.Color = Value; squareFrame.BackgroundColor3 = Value
					elseif Key == "ZIndex" then
						Obj.ZIndex = Value; squareFrame.ZIndex = Value
					elseif Key == "Outline" then
						Obj.Outline = Value
						outlineStroke.Enabled = Value
						outlineStroke.Thickness = Obj.Thickness + 1
					elseif Key == "OutlineColor" then
						Obj.OutlineColor = Value; outlineStroke.Color = Value
					elseif Key == "GradientStart" then
						Obj.GradientStart = Value
						ApplyGradient(squareFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					elseif Key == "GradientEnd" then
						Obj.GradientEnd = Value
						ApplyGradient(squareFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					elseif Key == "GradientColorSequence" then
						Obj.GradientColorSequence = Value
						ApplyGradient(squareFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					elseif Key == "GradientRotation" then
						Obj.GradientRotation = Value
						ApplyGradient(squareFrame, {
							ColorStart = Obj.GradientStart, ColorEnd = Obj.GradientEnd,
							ColorSequence = Obj.GradientColorSequence,
							Rotation = Obj.GradientRotation
						})
					end
				end,
				__index = function(_, Key)
					if Key == "Remove" or Key == "Destroy" then
						return function() squareFrame:Destroy(); Obj:Remove() end
					end
					return Obj[Key]
				end,
				__tostring = function() return "Drawing" end,
			})

		elseif Type == "Image" then
			local Obj = MergeTable(BaseDrawingObj, {
				Data = "",
				Size = Vector2.zero,
				Position = Vector2.zero,
			})

			local imageLabel = Instance.new("ImageLabel")
			imageLabel.Name = "Image"
			imageLabel.BorderSizePixel = 0
			imageLabel.ScaleType = Enum.ScaleType.Stretch
			imageLabel.BackgroundTransparency = 1
			imageLabel.Visible = Obj.Visible
			imageLabel.ZIndex = Obj.ZIndex
			imageLabel.ImageTransparency = ConvertTransparency(Obj.Transparency)
			imageLabel.Parent = DrawingUI

			return setmetatable({}, {
				__newindex = function(_, Key, Value)
					if Obj.__OBJECT_EXISTS == false then return end
					if Obj[Key] == nil then return end
					if Key == "Data" then
						Obj.Data = Value
						local asset = LoadImage(Value)
						if asset then
							imageLabel.Image = asset
						end
					elseif Key == "Size" then
						Obj.Size = Value
						imageLabel.Size = UDim2.fromOffset(Value.X, Value.Y)
					elseif Key == "Position" then
						Obj.Position = Value
						imageLabel.Position = UDim2.fromOffset(Value.X, Value.Y)
					elseif Key == "Visible" then
						Obj.Visible = Value; imageLabel.Visible = Value
					elseif Key == "ZIndex" then
						Obj.ZIndex = Value; imageLabel.ZIndex = Value
					elseif Key == "Transparency" then
						Obj.Transparency = Value
						imageLabel.ImageTransparency = ConvertTransparency(Value)
					elseif Key == "Color" then
						Obj.Color = Value; imageLabel.ImageColor3 = Value
					end
				end,
				__index = function(_, Key)
					if Key == "Remove" or Key == "Destroy" then
						return function() imageLabel:Destroy(); Obj:Remove() end
					end
					return Obj[Key]
				end,
				__tostring = function() return "Drawing" end,
			})

		elseif Type == "Quad" then
			local Obj = MergeTable(BaseDrawingObj, {
				Thickness = 1,
				PointA = Vector2.zero, PointB = Vector2.zero,
				PointC = Vector2.zero, PointD = Vector2.zero,
				Filled = false, Outline = false, OutlineColor = Color3.new(0,0,0),
			})
			local LA = Drawing.new("Line")
			local LB = Drawing.new("Line")
			local LC = Drawing.new("Line")
			local LD = Drawing.new("Line")
			return setmetatable({}, {
				__newindex = function(_, Key, Value)
					if Obj.__OBJECT_EXISTS == false then return end
					if Key == "Thickness" then
						LA.Thickness = Value; LB.Thickness = Value; LC.Thickness = Value; LD.Thickness = Value
						Obj.Thickness = Value
					elseif Key == "PointA" then LA.From = Value; LB.To = Value; Obj.PointA = Value
					elseif Key == "PointB" then LB.From = Value; LC.To = Value; Obj.PointB = Value
					elseif Key == "PointC" then LC.From = Value; LD.To = Value; Obj.PointC = Value
					elseif Key == "PointD" then LD.From = Value; LA.To = Value; Obj.PointD = Value
					elseif Key == "Visible" then
						LA.Visible = Value; LB.Visible = Value; LC.Visible = Value; LD.Visible = Value; Obj.Visible = Value
					elseif Key == "Filled" then Obj.Filled = Value
					elseif Key == "Color" then
						LA.Color = Value; LB.Color = Value; LC.Color = Value; LD.Color = Value; Obj.Color = Value
					elseif Key == "ZIndex" then
						LA.ZIndex = Value; LB.ZIndex = Value; LC.ZIndex = Value; LD.ZIndex = Value; Obj.ZIndex = Value
					elseif Key == "Outline" then
						LA.Outline = Value; LB.Outline = Value; LC.Outline = Value; LD.Outline = Value; Obj.Outline = Value
					elseif Key == "OutlineColor" then
						LA.OutlineColor = Value; LB.OutlineColor = Value; LC.OutlineColor = Value; LD.OutlineColor = Value; Obj.OutlineColor = Value
					elseif Key == "Transparency" then
						LA.Transparency = Value; LB.Transparency = Value; LC.Transparency = Value; LD.Transparency = Value; Obj.Transparency = Value
					end
				end,
				__index = function(_, Key)
					if Key == "Remove" or Key == "Destroy" then
						return function()
							if Obj.__OBJECT_EXISTS == false then return end
							LA:Remove(); LB:Remove(); LC:Remove(); LD:Remove(); Obj:Remove()
						end
					end
					return Obj[Key]
				end,
				__tostring = function() return "Drawing" end,
			})

		elseif Type == "Triangle" then
			local Obj = MergeTable(BaseDrawingObj, {
				Thickness = 1,
				PointA = Vector2.zero, PointB = Vector2.zero, PointC = Vector2.zero,
				Filled = false, Outline = false, OutlineColor = Color3.new(0,0,0),
			})
			local LAB = Drawing.new("Line")
			local LBC = Drawing.new("Line")
			local LCA = Drawing.new("Line")
			return setmetatable({}, {
				__newindex = function(_, Key, Value)
					if Obj.__OBJECT_EXISTS == false then return end
					if Key == "Thickness" then
						LAB.Thickness = Value; LBC.Thickness = Value; LCA.Thickness = Value; Obj.Thickness = Value
					elseif Key == "PointA" then LAB.From = Value; LCA.To = Value; Obj.PointA = Value
					elseif Key == "PointB" then LAB.To = Value; LBC.From = Value; Obj.PointB = Value
					elseif Key == "PointC" then LBC.To = Value; LCA.From = Value; Obj.PointC = Value
					elseif Key == "Visible" then
						LAB.Visible = Value; LBC.Visible = Value; LCA.Visible = Value; Obj.Visible = Value
					elseif Key == "Filled" then Obj.Filled = Value
					elseif Key == "Color" then
						LAB.Color = Value; LBC.Color = Value; LCA.Color = Value; Obj.Color = Value
					elseif Key == "ZIndex" then
						LAB.ZIndex = Value; LBC.ZIndex = Value; LCA.ZIndex = Value; Obj.ZIndex = Value
					elseif Key == "Outline" then
						LAB.Outline = Value; LBC.Outline = Value; LCA.Outline = Value; Obj.Outline = Value
					elseif Key == "OutlineColor" then
						LAB.OutlineColor = Value; LBC.OutlineColor = Value; LCA.OutlineColor = Value; Obj.OutlineColor = Value
					elseif Key == "Transparency" then
						LAB.Transparency = Value; LBC.Transparency = Value; LCA.Transparency = Value; Obj.Transparency = Value
					end
				end,
				__index = function(_, Key)
					if Key == "Remove" or Key == "Destroy" then
						return function()
							if Obj.__OBJECT_EXISTS == false then return end
							LAB:Remove(); LBC:Remove(); LCA:Remove(); Obj:Remove()
						end
					end
					return Obj[Key]
				end,
				__tostring = function() return "Drawing" end,
			})
		else
			return warn('Unsupported drawing type: \'' .. tostring(Type) .. '\'')
		end
	end)

	getgenv().isrenderobj = newcclosure(function(Object)
		if typeof(Object) == "userdata" or typeof(Object) == "Instance" or not getmetatable(Object) then
			return false
		end
		if tostring(Object) ~= "Drawing" then return false end
		local ok, exists = pcall(function() return Object.__OBJECT_EXISTS end)
		if ok and exists == false then return false end
		return true
	end)
end
