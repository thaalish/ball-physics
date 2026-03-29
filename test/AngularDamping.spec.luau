local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effect = require(ReplicatedStorage.BallPhysics.Effects.AngularDamping)

return function()
	describe("AngularDamping", function()
		-- Position set high so isTouchingGround() raycasts miss (airborne path).
		local function mock(angVel: Vector3)
			return {
				Position = Vector3.new(0, 500, 0),
				Size = Vector3.new(2, 2, 2),
				AssemblyAngularVelocity = angVel,
			}
		end

		it("has correct metadata", function()
			expect(Effect.property).to.equal("AssemblyAngularVelocity")
			expect(Effect.enabled).to.equal(true)
		end)

		it("returns zero for zero angular velocity", function()
			local result = Effect.compute(mock(Vector3.zero) :: any, 0.016)
			expect(result:FuzzyEq(Vector3.zero)).to.equal(true)
		end)

		it("output magnitude is less than input (dampening reduces spin)", function()
			local angVel = Vector3.new(10, 5, 3)
			local result = Effect.compute(mock(angVel) :: any, 0.016)
			expect(result.Magnitude < angVel.Magnitude).to.equal(true)
		end)

		it("direction is preserved after dampening", function()
			local angVel = Vector3.new(0, 1, 0)
			local result = Effect.compute(mock(angVel) :: any, 0.016)
			expect(result:Dot(angVel) > 0).to.equal(true)
		end)

		it("larger deltaTime produces more dampening", function()
			local ball = mock(Vector3.new(1, 0, 0))
			local resultSmallDelta = Effect.compute(ball :: any, 0.016)
			local resultLargeDelta = Effect.compute(ball :: any, 0.5)
			expect(resultSmallDelta.Magnitude > resultLargeDelta.Magnitude).to.equal(true)
		end)

		it("matches the analytical formula: exp(-airRate * deltaTime) * omega  (airborne)", function()
			local AIR_RATE = 0.65
			local deltaTime = 0.1
			local angVel = Vector3.new(3, 0, 0)
			local result = Effect.compute(mock(angVel) :: any, deltaTime)
			local expected = math.exp(-AIR_RATE * deltaTime) * 3
			expect(math.abs(result.X - expected) < 1e-5).to.equal(true)
		end)

		it("asymptotically approaches zero for a very large deltaTime", function()
			local result = Effect.compute(mock(Vector3.new(100, 100, 100)) :: any, 100)
			expect(result.Magnitude < 0.001).to.equal(true)
		end)
	end)
end
