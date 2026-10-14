--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Magnets = require(ReplicatedStorage.Shared.MagnetDefinitions)
local Shop = require(ReplicatedStorage.Shared.ShopRules)

local Magnet = {}
type Piece = { part: Part, offset: CFrame }
type Arm = { joint: Motor6D, original: CFrame, grip: Attachment }

function Magnet.start()
	local player = Players.LocalPlayer
	local model: Model? = nil
	local pieces: { Piece } = {}
	local controls: { IKControl } = {}
	local arms: { Arm } = {}
	local owner: Model? = nil
	local equippedTier = 0
	local poseReady = false
	local boundHumanoid: Humanoid? = nil
	local boundAnimator: Instance? = nil
	local boundRigType: Enum.HumanoidRigType? = nil
	local boundParts: { [string]: BasePart } = {}
	local leftGrip: Attachment? = nil
	local rightGrip: Attachment? = nil

	local function clearPose()
		for _, control in controls do control:Destroy() end
		for _, arm in arms do
			if arm.joint.Parent then arm.joint.Transform = arm.original end
		end
		table.clear(controls)
		table.clear(arms)
		table.clear(boundParts)
		boundHumanoid = nil
		boundAnimator = nil
		boundRigType = nil
		poseReady = false
	end

	local function clear()
		clearPose()
		if model then model:Destroy() end
		model = nil
		owner = nil
		equippedTier = 0
		poseReady = false
		leftGrip = nil
		rightGrip = nil
		table.clear(pieces)
		table.clear(controls)
		table.clear(arms)
	end

	local function create(character: Model, definition: Magnets.Definition)
		local newModel = Instance.new("Model")
		newModel.Name = "LocalMagnet"
		local function piece(name: string, size: Vector3, offset: CFrame, color: Color3): Part
			local part = Instance.new("Part")
			part.Name = name
			part.Size = size
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Material = Enum.Material.Metal
			part.Color = color
			part.Parent = newModel
			table.insert(pieces, { part = part, offset = offset })
			return part
		end
		local bodyColor = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
		local silver = Color3.fromRGB(205, 215, 225)
		local bridge = piece("Bridge", Vector3.new(1.6, 0.35, 0.4), CFrame.new(0, -0.45, 0), bodyColor)
		for _, side in { -1, 1 } do
			piece("Pole", Vector3.new(0.35, 0.85, 0.4), CFrame.new(side * 0.625, 0, 0), bodyColor)
			piece("PoleTip", Vector3.new(0.35, 0.25, 0.4), CFrame.new(side * 0.625, 0.55, 0), silver)
			if definition.style == "Industrial" then
				piece("IndustrialCollar", Vector3.new(0.5, 0.18, 0.55), CFrame.new(side * 0.625, 0.3, 0), silver)
			elseif definition.style == "Royal" then
				piece("RoyalCrest", Vector3.new(0.18, 0.3, 0.18), CFrame.new(side * 0.3, -0.15, 0), bodyColor)
			end
		end
		if definition.style == "Royal" then
			piece("RoyalGem", Vector3.new(0.25, 0.25, 0.15), CFrame.new(0, -0.45, -0.25), Color3.fromRGB(90, 220, 245))
		end
		local function grip(name: string, x: number): Attachment
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			attachment.CFrame = CFrame.new(x, 0.1, 0.15)
			attachment.Parent = bridge
			return attachment
		end
		leftGrip = grip("LeftGrip", -0.625)
		rightGrip = grip("RightGrip", 0.625)
		-- Locally created anchored visuals only: never weld or move the avatar/root.
		newModel.Parent = workspace
		model = newModel
		owner = character
		equippedTier = definition.tier
	end

	local function bindPose(character: Model, humanoid: Humanoid)
		local left = leftGrip
		local right = rightGrip
		if poseReady then
			local matches = boundHumanoid == humanoid and boundRigType == humanoid.RigType
				and boundAnimator == humanoid:FindFirstChildOfClass("Animator")
			for name, part in boundParts do
				if character:FindFirstChild(name) ~= part then matches = false end
			end
			for _, arm in arms do
				local torso = boundParts.Torso
				local limb = boundParts[arm.grip == left and "Left Arm" or "Right Arm"]
				if not torso or torso:FindFirstChild(arm.joint.Name) ~= arm.joint
					or arm.joint.Part0 ~= torso or arm.joint.Part1 ~= limb then matches = false end
			end
			for _, ik in controls do
				if ik.Parent ~= humanoid then matches = false end
			end
			if matches then return end
			clearPose()
		end
		if not left or not right then return end
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			local leftUpper = character:FindFirstChild("LeftUpperArm")
			local rightUpper = character:FindFirstChild("RightUpperArm")
			local leftLower = character:FindFirstChild("LeftLowerArm")
			local rightLower = character:FindFirstChild("RightLowerArm")
			local leftHand = character:FindFirstChild("LeftHand")
			local rightHand = character:FindFirstChild("RightHand")
			-- Partial R15 rigs are retried; never reinterpret them as R6.
			if not humanoid:FindFirstChildOfClass("Animator")
				or not leftUpper or not leftUpper:IsA("BasePart")
				or not rightUpper or not rightUpper:IsA("BasePart")
				or not leftLower or not leftLower:IsA("BasePart")
				or not rightLower or not rightLower:IsA("BasePart")
				or not leftHand or not leftHand:IsA("BasePart")
				or not rightHand or not rightHand:IsA("BasePart") then return end
			local function control(name: string, upper: BasePart, hand: BasePart, target: Attachment)
				local ik = Instance.new("IKControl")
				ik.Name = name
				ik.Type = Enum.IKControlType.Position
				ik.ChainRoot = upper
				ik.EndEffector = hand
				ik.Target = target
				ik.Weight = 1
				ik.SmoothTime = 0.05
				ik.Priority = 10
				ik.Enabled = true
				ik.Parent = humanoid
				table.insert(controls, ik)
			end
			boundParts = { LeftUpperArm = leftUpper, RightUpperArm = rightUpper,
				LeftLowerArm = leftLower, RightLowerArm = rightLower, LeftHand = leftHand, RightHand = rightHand }
			control("LocalMagnetLeftHold", leftUpper, leftHand, left)
			control("LocalMagnetRightHold", rightUpper, rightHand, right)
		elseif humanoid.RigType == Enum.HumanoidRigType.R6 then
			local torso = character:FindFirstChild("Torso")
			local leftArm = character:FindFirstChild("Left Arm")
			local rightArm = character:FindFirstChild("Right Arm")
			local leftJoint = torso and torso:FindFirstChild("Left Shoulder")
			local rightJoint = torso and torso:FindFirstChild("Right Shoulder")
			if not torso or not torso:IsA("BasePart")
				or not leftArm or not leftArm:IsA("BasePart")
				or not rightArm or not rightArm:IsA("BasePart")
				or not leftJoint or not leftJoint:IsA("Motor6D")
				or not rightJoint or not rightJoint:IsA("Motor6D")
				or leftJoint.Part0 ~= torso or leftJoint.Part1 ~= leftArm
				or rightJoint.Part0 ~= torso or rightJoint.Part1 ~= rightArm then return end
			boundParts = { Torso = torso, ["Left Arm"] = leftArm, ["Right Arm"] = rightArm }
			table.insert(arms, { joint = leftJoint, original = leftJoint.Transform, grip = left })
			table.insert(arms, { joint = rightJoint, original = rightJoint.Transform, grip = right })
		else
			return
		end
		boundHumanoid = humanoid
		boundAnimator = humanoid:FindFirstChildOfClass("Animator")
		boundRigType = humanoid.RigType
		poseReady = true
	end

	-- R6 has rigid arms, so place both grips on their actual shoulder-reach
	-- spheres. This moves only the cosmetic prop, never the torso or shoulders.
	local function r6Base(): CFrame?
		if #arms ~= 2 then return nil end
		local torso = arms[1].joint.Part0
		if not torso or arms[2].joint.Part0 ~= torso then return nil end
		local centers: { Vector3 } = {}
		local reaches: { number } = {}
		for _, arm in arms do
			local limb = arm.joint.Part1
			if not limb then return nil end
			local shoulder = torso.CFrame * arm.joint.C0
			local gripOffset = pieces[1].offset:PointToWorldSpace(arm.grip.Position)
			table.insert(centers, torso.CFrame:PointToObjectSpace(shoulder.Position) - gripOffset)
			local reach = (Vector3.new(0, -limb.Size.Y / 2, 0) - arm.joint.C1.Position).Magnitude
			if reach <= 0.001 then return nil end
			table.insert(reaches, reach)
		end
		local separation = centers[2] - centers[1]
		local distance = separation.Magnitude
		-- Degenerate or nonintersecting custom rigs cannot satisfy both grips.
		if distance <= 0.001 or distance > reaches[1] + reaches[2]
			or distance < math.abs(reaches[1] - reaches[2]) then return nil end
		local axis = separation.Unit
		local along = (reaches[1] ^ 2 - reaches[2] ^ 2 + distance ^ 2) / (2 * distance)
		local radiusSquared = reaches[1] ^ 2 - along ^ 2
		if radiusSquared <= 0.000001 then return nil end
		local circleCenter = centers[1] + axis * along
		local projectedUp = Vector3.new(0, 1, 0) - axis * axis:Dot(Vector3.new(0, 1, 0))
		if projectedUp.Magnitude <= 0.001 then return nil end
		local up = projectedUp.Unit
		local front = axis:Cross(up).Unit
		if front.Z > 0 then front = -front end
		local radius = math.sqrt(radiusSquared)
		local vertical = math.clamp((Vector3.new(0, 0.1, 0) - circleCenter):Dot(up), -radius * 0.75, radius * 0.75)
		local depth = math.sqrt(math.max(0, radiusSquared - vertical ^ 2))
		return torso.CFrame * CFrame.new(circleCenter + up * vertical + front * depth)
	end

	local function update(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player:GetAttribute("DataReady") ~= true or not character or not character.Parent
			or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			clear()
			return false
		end
		local definition = Shop.definitionFor(Magnets, player:GetAttribute("MagnetTier")) or Magnets[1]
		if owner ~= character or equippedTier ~= definition.tier then
			clear()
			create(character, definition)
		end
		bindPose(character, humanoid)
		local base: CFrame? = root.CFrame * CFrame.new(0, 0.1, -1.6)
		if humanoid.RigType == Enum.HumanoidRigType.R6 then base = r6Base() end
		if not poseReady or not base then
			-- Unsupported/partial rigs hide the prop rather than pretend to hold it.
			if model then model.Parent = nil end
			for _, arm in arms do
				if arm.joint.Parent then arm.joint.Transform = arm.original end
			end
			return false
		end
		if model then model.Parent = workspace end
		for _, item in pieces do item.part.CFrame = base * item.offset end
		return true
	end

	-- Set targets before Animator/IK evaluation; preserve walking and leg animation.
	RunService.PreAnimation:Connect(update)
	-- Animator overwrites Motor6D.Transform before PreSimulation. Override only
	-- R6 shoulders here, rotating the true pivot-to-hand vector toward its grip.
	RunService.PreSimulation:Connect(function()
		if not update() then return end
		for _, arm in arms do
			local joint = arm.joint
			local torso = joint.Part0
			local limb = joint.Part1
			if joint.Parent and torso and limb then
				local shoulder = torso.CFrame * joint.C0
				local direction = arm.grip.WorldPosition - shoulder.Position
				if direction.Magnitude > 0.001 then
					local handFromPivot = Vector3.new(0, -limb.Size.Y / 2, 0) - joint.C1.Position
					if handFromPivot.Magnitude > 0.001 then
						local targetDirection = direction.Unit
						local handDirection = handFromPivot.Unit
						-- Avoid an ambiguous roll when a reach vector is parallel to world up.
						local targetUp = if math.abs(targetDirection.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
						local handUp = if math.abs(handDirection.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
						local rotation = CFrame.lookAt(Vector3.zero, targetDirection, targetUp)
							* CFrame.lookAt(Vector3.zero, handDirection, handUp):Inverse()
						local center = shoulder.Position - rotation:VectorToWorldSpace(joint.C1.Position)
						local desired = CFrame.new(center) * rotation
						joint.Transform = shoulder:ToObjectSpace(desired * joint.C1)
					end
				end
			end
		end
	end)
	-- Keep the carried prop centered on the rendered body after physics movement.
	RunService.RenderStepped:Connect(update)
end

return Magnet
