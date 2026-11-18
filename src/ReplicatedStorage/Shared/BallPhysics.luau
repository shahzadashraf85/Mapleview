--!strict
-- BallPhysics.luau
-- Shared deterministic-style ball physics including Magnus curve, air drag, and turf bounce.

local Config = require(script.Parent.Config)

local BallPhysics = {}

export type BallState = {
	Position: Vector3,
	Velocity: Vector3,
	Spin: Vector3, -- Angular velocity vector; Spin:Cross(Velocity) produces Magnus curve
}

function BallPhysics.Step(state: BallState, dt: number, pitchHalfLength: number, pitchHalfWidth: number): (BallState, boolean)
	local b = Config.Ball
	local pos = state.Position
	local vel = state.Velocity
	local spin = state.Spin
	local bounced = false

	-- 1. Gravity
	vel += Vector3.new(0, -b.Gravity * dt, 0)

	-- 2. Magnus Effect (curve in flight: F_m ~ spin x velocity)
	if spin.Magnitude > 0.01 and vel.Magnitude > 1 then
		local magnusAccel = spin:Cross(vel) * b.MagnusCoefficient
		vel += magnusAccel * dt
	end

	-- 3. Aerodynamic Drag
	local dragFactor = math.max(0, 1 - b.AirDrag * dt)
	vel *= dragFactor

	-- Clamp max speed
	if vel.Magnitude > b.MaxSpeed then
		vel = vel.Unit * b.MaxSpeed
	end

	-- 4. Integrate position
	pos += vel * dt

	-- 5. Ground collision (pitch surface is at Y = 0)
	local minY = b.Radius
	if pos.Y <= minY then
		pos = Vector3.new(pos.X, minY, pos.Z)
		if vel.Y < -2.5 then
			vel = Vector3.new(vel.X, -vel.Y * b.BounceRestitution, vel.Z)
			bounced = true
		else
			vel = Vector3.new(vel.X, 0, vel.Z)
		end

		-- Grass rolling friction
		local friction = math.pow(b.GrassFriction, dt * 60)
		vel = Vector3.new(vel.X * friction, vel.Y, vel.Z * friction)
		spin *= math.pow(b.SpinDecay, dt * 60)
	else
		-- Slight air spin decay
		spin *= math.pow(0.997, dt * 60)
	end

	-- 6. Stadium outer wall safety clamp (so ball never falls into the void)
	local maxBoundX = pitchHalfWidth + 45
	local maxBoundZ = pitchHalfLength + 45
	if math.abs(pos.X) > maxBoundX then
		pos = Vector3.new(math.sign(pos.X) * maxBoundX, pos.Y, pos.Z)
		vel = Vector3.new(-vel.X * 0.5, vel.Y, vel.Z)
	end
	if math.abs(pos.Z) > maxBoundZ then
		pos = Vector3.new(pos.X, pos.Y, math.sign(pos.Z) * maxBoundZ)
		vel = Vector3.new(vel.X, vel.Y, -vel.Z * 0.5)
	end

	return {
		Position = pos,
		Velocity = vel,
		Spin = spin,
	}, bounced
end

-- Computes a trajectory preview array for curving free kicks / shots
function BallPhysics.PredictTrajectory(
	startPos: Vector3,
	initialVel: Vector3,
	spin: Vector3,
	steps: number,
	stepDt: number,
	pitchHalfLength: number,
	pitchHalfWidth: number
): { Vector3 }
	local points = table.create(steps)
	local state: BallState = {
		Position = startPos,
		Velocity = initialVel,
		Spin = spin,
	}
	for i = 1, steps do
		state = BallPhysics.Step(state, stepDt, pitchHalfLength, pitchHalfWidth)
		points[i] = state.Position
	end
	return points
end

return BallPhysics
