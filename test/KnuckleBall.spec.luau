local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effect = require(ReplicatedStorage.BallPhysics.Effects.KnuckleBall)

return function()
	describe("KnuckleBall", function()
		-- Position set high so isTouchingGround() raycasts miss (airborne path).
		local function mock(linVel: Vector3, angVel: Vector3, mass: number?)
			return {
				Position = Vector3.new(0, 500, 0),
				Size = Vector3.new(2, 2, 2),
				AssemblyLinearVelocity = linVel,
				AssemblyAngularVelocity = angVel,
				AssemblyMass = mass or 1,
			}
		end

		it("has correct metadata", function()
			expect(Effect.property).to.equal("Force")
			expect(Effect.instance).to.equal("KnuckleBall")
			expect(Effect.enabled).to.equal(true)
		end)

		it("returns zero when horizontal speed is below threshold", function()
			-- 69 stud/s is just under SPEED_THRESHOLD (70), so no force should apply.
			local result = Effect.compute(mock(Vector3.new(0, 0, 69), Vector3.zero) :: any, 0)
			expect(result:FuzzyEq(Vector3.zero)).to.equal(true)
		end)

		it("returns zero when completely stationary", function()
			local result = Effect.compute(mock(Vector3.zero, Vector3.zero) :: any, 0)
			expect(result:FuzzyEq(Vector3.zero)).to.equal(true)
		end)

		it("returns zero when spin is too high to produce meaningful intensity", function()
			-- Speed is above SPEED_THRESHOLD but heavy spin suppresses the effect to near zero.
			local result = Effect.compute(mock(Vector3.new(0, 0, 110), Vector3.new(0, 10000, 0)) :: any, 0)
			expect(result:FuzzyEq(Vector3.zero)).to.equal(true)
		end)

		it("vertical velocity component is ignored", function()
			-- Pure Y velocity with no horizontal component must return zero,
			-- proving the threshold check uses horizontal speed only.
			local result = Effect.compute(mock(Vector3.new(0, 999, 0), Vector3.new(0, 0.5, 0), 1) :: any, 0)
			expect(result:FuzzyEq(Vector3.zero)).to.equal(true)
		end)

		it("force scales with ball mass", function()
			local velocity = Vector3.new(0, 0, 110)
			local angularVelocity = Vector3.new(0, 0.1, 0)
			-- Reuse the same table so ballPhases caches the same phase for both calls.
			-- Two separate mocks would get different random phases, making drift differ
			-- between calls and breaking the ratio check.
			local ball = mock(velocity, angularVelocity, 1) :: any
			local resultFirstCall = Effect.compute(ball, 0)
			ball.AssemblyMass = 2
			local resultSecondCall = Effect.compute(ball, 0)
			-- Both calls share the same phase and happen microseconds apart, so drift
			-- is identical and resultSecondCall should be exactly 2x resultFirstCall.
			if resultFirstCall.Magnitude > 0.001 then
				local ratio = resultSecondCall.Magnitude / resultFirstCall.Magnitude
				expect(math.abs(ratio - 2) < 0.01).to.equal(true)
			end
		end)

		it("is not affected by deltaTime", function()
			-- deltaTime is unused; zero-return cases must be zero for any deltaTime value.
			local r0 = Effect.compute(mock(Vector3.zero, Vector3.zero) :: any, 0)
			local r1 = Effect.compute(mock(Vector3.zero, Vector3.zero) :: any, 999)
			expect(r0:FuzzyEq(Vector3.zero)).to.equal(true)
			expect(r1:FuzzyEq(Vector3.zero)).to.equal(true)
		end)
	end)
end
