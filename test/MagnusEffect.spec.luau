local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effect = require(ReplicatedStorage.BallPhysics.Effects.MagnusEffect)

return function()
	describe("MagnusEffect", function()
		local function mock(linVel: Vector3, angVel: Vector3, density: number?)
			return {
				AssemblyLinearVelocity = linVel,
				AssemblyAngularVelocity = angVel,
				CustomPhysicalProperties = if density then { Density = density } else nil,
			}
		end

		it("has correct metadata", function()
			expect(Effect.property).to.equal("Force")
			expect(Effect.instance).to.equal("MagnusForce")
			expect(Effect.enabled).to.equal(true)
		end)

		it("returns zero when both velocity and angular velocity are zero", function()
			local result = Effect.compute(mock(Vector3.zero, Vector3.zero) :: any, 0)
			expect(result:FuzzyEq(Vector3.zero)).to.equal(true)
		end)

		it("returns zero when only angular velocity is zero", function()
			local result = Effect.compute(mock(Vector3.new(0, 0, 50), Vector3.zero) :: any, 0)
			expect(result:FuzzyEq(Vector3.zero)).to.equal(true)
		end)

		it("produces a non-zero force for a spinning ball in flight", function()
			local result = Effect.compute(mock(Vector3.new(0, 0, 100), Vector3.new(0, 1000, 0)) :: any, 0)
			expect(result.Magnitude > 0).to.equal(true)
		end)

		it("force direction follows omega:Cross(velocity) (X-axis curl)", function()
			-- omega = (0, omegaY, 0), velocity = (0, 0, v)  ->  force along +X
			-- omega:Cross(velocity) = (omegaY * vz, 0, 0) = positive X
			local result = Effect.compute(mock(Vector3.new(0, 0, 50), Vector3.new(0, 100, 0)) :: any, 0)
			expect(result.X > 0).to.equal(true)
			expect(math.abs(result.Y) < 0.01).to.equal(true)
			expect(math.abs(result.Z) < 0.01).to.equal(true)
		end)

		it("scales proportionally with density", function()
			local linVel = Vector3.new(0, 0, 80)
			local angVel = Vector3.new(500, 0, 0)
			local low = Effect.compute(mock(linVel, angVel, 0.3) :: any, 0)
			local high = Effect.compute(mock(linVel, angVel, 1.2) :: any, 0)
			expect(high.Magnitude > low.Magnitude).to.equal(true)
		end)

		it("is not affected by deltaTime", function()
			local ball = mock(Vector3.new(0, 0, 80), Vector3.new(300, 0, 0))
			local resultNoDelta = Effect.compute(ball :: any, 0)
			local resultWithDelta = Effect.compute(ball :: any, 1)
			expect(resultNoDelta:FuzzyEq(resultWithDelta)).to.equal(true)
		end)

		it("guards against NaN from infinite inputs", function()
			local result = Effect.compute(mock(Vector3.new(math.huge, 0, 0), Vector3.new(0, math.huge, 0)) :: any, 0)
			local hasNaN = result.X ~= result.X or result.Y ~= result.Y or result.Z ~= result.Z
			expect(hasNaN).to.equal(false)
		end)
	end)
end
