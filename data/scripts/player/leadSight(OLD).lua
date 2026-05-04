package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")


LeadSight = {}

----Calculus-----------------------
local enabled = false
local inputLocked = false
local eps = 0.00001
local ticks = 0

local maxTickValue = 1000000
local meanProjectileSpeed = 0
local rangeMax = 0
local rangeMin = 0
----------HUD-------------------------
local effects = {}
local nominalLineWidth = 0.5 --10*m
local closeClippingDistance = 10 --10*m
local blue = Color()
	blue.a = 1.0
	blue.r = 0.0
	blue.g = 0.0
	blue.b = 1.0
local green = Color()
	green.a = 1.0
	green.r = 0.0
	green.g = 1.0
	green.b = 0.0
local red = Color()
	red.a = 1.0
	red.r = 1.0
	red.g = 0.0
	red.b = 0.0
local yellow = Color()
	yellow.a = 1.0
	yellow.r = 0.8
	yellow.g = 0.6
	yellow.b = 0.0
local cian = Color()
	yellow.a = 1.0
	yellow.r = 0.8
	yellow.g = 0.6
	yellow.b = 0.0
local magenta = Color()
	yellow.a = 1.0
	yellow.r = 1.0
	yellow.g = 0.6
	yellow.b = 0.0	
local clear = Color()
	clear.a = 0.0
	clear.r = 0.0
	clear.g = 0.0
	clear.b = 0.0
	
local lightGreen = Color()
	lightGreen.a = 1.0
	lightGreen.r = 0.2
	lightGreen.g = 1.0
	lightGreen.b = 0.4
	
local lightOrange = Color()
    lightOrange.a = 1.0
	lightOrange.r = 0.8
	lightOrange.g = 0.6
	lightOrange.b = 0.0
	
local lightRed = Color()
	lightRed.a = 1.0
	lightRed.r = 1.0
	lightRed.g = 0.1
	lightRed.b = 0.1

local nextEffectToFetch = 0

-----------------------

function getUpdateInterval()
    return 0.02
end

function initialize()
     print("Initialize")
end

function updateClient(timeStep)

	LeadSight.clearEffects(ticks)
	if enabled then
		LeadSight.updateReticle(ticks)
	end

	if (Keyboard():keyPressed(KeyboardKey.Slash) and not inputLocked) then
		playSound("interface/confirm_order", 1, 0.35)
		enabled = not enabled
		--local player = Player()
		-- if enabled then
			-- player:sendChatMessage("Lead sight is set to: ON", 2)
		-- else
			-- player:sendChatMessage("Lead sight is set to: OFF", 2)
		-- end
		inputLocked = true
	end
	if (not Keyboard():keyPressed(KeyboardKey.Slash) and inputLocked) then
		inputLocked = false
	end


	
	ticks = ticks + 1
	if (ticks > maxTickValue) then
		ticks = 0
	end
end

function LeadSight.updateReticle(ticks)
	local player = Player()
	--print("Obtained Player:" .. player.name)
	
	local target = Entity(player.selectedObject)
	local craft = player.craft
	
	if (target == nil or craft == nil) then
		return
	end
	
	if (craft.numTurrets == 0) then
		return
	end
	
	--every tenth tick - update mean projectile speed
	if (ticks % 10 == 0) then
		LeadSight.refreshWeaponsData(craft)
	end
	
	--turrets inactive or beams
	if (meanProjectileSpeed < eps) then
		return
	end
	
	local craftVelocity = Velocity(craft.id).velocity
	local targetVelocity = Velocity(target.id).velocity
	
	--target velocity relative to the player ship as if the player ship was still
	local cc = {}
	
	local targetVelocityStill = targetVelocity:__sub(craftVelocity);
	
	--no targeting needed
	if (LeadSight.length(targetVelocityStill) < eps) then
		return
	end
	
	local targetPos = target.position.position
	local craftPos = craft.position.position
	local relativePos = targetPos:__sub(craftPos)
	cc.sinAlpha = LeadSight.getVectorsAngSin(targetVelocityStill, relativePos)
	cc.cosAlpha = LeadSight.sineCosine(cc.sinAlpha)
	cc.distance = LeadSight.length(relativePos)
	cc.enemySpeed = LeadSight.length(targetVelocityStill)
	cc.projSpeed = meanProjectileSpeed
	
	local enemyMovementPlane = LeadSight.getPlaneEquation(
	targetPos.x, targetPos.y, targetPos.z, 
	craftPos.x, craftPos.y, craftPos.z, 
	targetVelocityStill.x, targetVelocityStill.y, targetVelocityStill.z)
	
	--A velocity that is required to accomodate projectiles travel speed change
	local projectedCraftSpeed = LeadSight.projectVectorOnPlane(craftVelocity, enemyMovementPlane)
	cc.shipSpeedSin = LeadSight.getVectorsAngSin(projectedCraftSpeed, relativePos)
	cc.shipSpeedCos = LeadSight.sineCosine(cc.shipSpeedSin)
	cc.shipSpeed = LeadSight.length(projectedCraftSpeed)
	
	
	local alteredShootingSpeed = LeadSight.getMaxShootingSpeed(cc)
	
	if (math.abs(alteredShootingSpeed) <= eps) then
		--impossible to hit
		return
	end
	
	
	local sinShootingAngleOpt = cc.sinAlpha * cc.enemySpeed / (alteredShootingSpeed)
	if (math.abs(sinShootingAngleOpt) > 1) then
		--impossible to hit
		return
	end
	local distanceUntilHitOpt = LeadSight.calculateDistanceUntilHit(sinShootingAngleOpt, cc)
	
	local reticlePos = targetPos:__add(LeadSight.vec3Mul(targetVelocityStill, distanceUntilHitOpt))
	
	local projectileTravelDistance = LeadSight.length(reticlePos:__sub(craftPos))
	
	--Determine if the weapons could reach
	local drawColor = lightOrange
	if projectileTravelDistance > rangeMax then
		drawColor = lightRed
	end
	
	local blinking = false
	if projectileTravelDistance < rangeMax and projectileTravelDistance > rangeMin then
		drawColor = lightOrange
		blinking = true
	end
	
	if projectileTravelDistance < rangeMin then
		drawColor = lightGreen
	end

	--LeadSight.drawCross(drawColor, reticlePos, projectileTravelDistance, 2, 0.5)
	
	LeadSight.drawFlatCross(drawColor, reticlePos, reticlePos:__sub(craftPos), projectileTravelDistance, 3, 0.5)
	LeadSight.drawLine(drawColor, reticlePos, targetPos, projectileTravelDistance, 0.1)
end

---HUD------------------------------------------------------------------

	
function LeadSight.clearEffects()
	local hardClean = false
	if (ticks % 50 == 0) then
		hardClean = true
	end
  --  print("Clear effects")
	local sector = Sector()
	   -- print("Effects used " .. nextEffectToFetch)
	for i,e in ipairs(effects) do
		if (i >= nextEffectToFetch or hardClean) then
			sector:removeLaser(e)
			effects[i] = nil
		end
	end
	if hardClean then
		effects = {}
	end
	nextEffectToFetch = 1
end

function LeadSight.fetchNextEffect()

	if (nextEffectToFetch >= #effects) then
		local newEffect = Sector():createLaser(vec3(0,0,0), vec3(0,0,0), blue, 1)
		newEffect.auraWidth = 0
		newEffect.soundMaxRadius = 0
		newEffect.soundVolume = 0
		table.insert(effects, newEffect)
	end
	
	local result = effects[nextEffectToFetch]
	nextEffectToFetch = nextEffectToFetch + 1
	return result
end

function LeadSight.drawDot(color, position, distance, size)
	if (distance <= closeClippingDistance) then
		return 
	end
	
	local lineWidth = LeadSight.getWeightedWidth(distance, size)
	
	local position1 = vec3(position.x - lineWidth/2, position.y, position.z)
	local position2 = vec3(position.x + lineWidth/2, position.y, position.z)
	
	local laser = LeadSight.fetchNextEffect()
	laser.from = position1
	laser.to = position2
	laser.origin = position1
	laser.ending = position2
	laser.innerColor = color
	laser.outerColor = color
	laser.width = lineWidth
	
end

function LeadSight.drawFlatCross(color, position, normalVector, distance, size, width)

	local s = LeadSight.getWeightedWidth(distance, size)/2
	local holeSize = 0.7
	
	local plane = LeadSight.getPlaneEquationFromNormal(normalVector, position) 
	
	local i,j = LeadSight.getPlaneBasisVectors(plane)
	
	
	local x1 = LeadSight.map2dVectorTo3d(i, j, position, vec2(- s, 0))
	local x2 = LeadSight.map2dVectorTo3d(i, j, position, vec2(- s*holeSize, 0))
	local x3 = LeadSight.map2dVectorTo3d(i, j, position, vec2(s*holeSize, 0))
	local x4 = LeadSight.map2dVectorTo3d(i, j, position, vec2(s, 0))
	
	local y1 = LeadSight.map2dVectorTo3d(i, j, position, vec2(0, - s, z0))
	local y2 = LeadSight.map2dVectorTo3d(i, j, position, vec2(0, - s*holeSize))
	local y3 = LeadSight.map2dVectorTo3d(i, j, position, vec2(0, s*holeSize))
	local y4 = LeadSight.map2dVectorTo3d(i, j, position, vec2(0, s))
	
	
	LeadSight.drawLine(color, x2, x1, distance, width)
	LeadSight.drawLine(color, x3, x4, distance, width)
	
	LeadSight.drawLine(color, y2, y1, distance, width)
	LeadSight.drawLine(color, y3, y4, distance, width)
	
end

function LeadSight.drawCross(color, position, distance, size, width) 

	local s = LeadSight.getWeightedWidth(distance, size)

	local x0 = position.x
	local y0 = position.y
	local z0 = position.z
	
	local sx = s/2
	local sy = s/2
	local sz = s/2
	
	local holeSize = 0.7
	
	local x1 = vec3(x0 - sx, y0, z0)
	local x2 = vec3(x0 - sx*holeSize, y0, z0)
	local x3 = vec3(x0 + sx*holeSize, y0, z0)
	local x4 = vec3(x0 + sx, y0, z0)
	
	local y1 = vec3(x0, y0 - sy, z0)
	local y2 = vec3(x0, y0 - sy*holeSize, z0)
	local y3 = vec3(x0, y0 + sy*holeSize, z0)
	local y4 = vec3(x0, y0 + sy, z0)
	
	local z1 = vec3(x0, y0, z0 - sz)
	local z2 = vec3(x0, y0, z0 - sz*holeSize)
	local z3 = vec3(x0, y0, z0 + sz*holeSize)
	local z4 = vec3(x0, y0, z0 + sz)
	
	LeadSight.drawLine(color, x2, x1, distance, width)
	LeadSight.drawLine(color, x3, x4, distance, width)
	
	LeadSight.drawLine(color, y2, y1, distance, width)
	LeadSight.drawLine(color, y3, y4, distance, width)
	
	LeadSight.drawLine(color, z2, z1, distance, width)
	LeadSight.drawLine(color, z3, z4, distance, width)
end

function LeadSight.drawLine(color, position1, position2, distance, width)
	if (distance <= closeClippingDistance) then
		return 
	end
	
	local lineWidth = LeadSight.getWeightedWidth(distance, width)
	
	local laser = LeadSight.fetchNextEffect()
	laser.from = position1
	laser.to = position2
	laser.width = lineWidth
	laser.innerColor = color
	laser.outerColor = color
end


function LeadSight.drawCube(color, position, size, distance, width, orientation)
	
	local sx = size.x/2
	local sy = size.y/2
	local sz = size.z/2
	
	local a1o = vec3(- sx, - sy, sz)
	local a2o = vec3(- sx, sy, sz)
	local a3o = vec3(sx, sy, sz)
	local a4o = vec3(sx, - sy, sz)
	
	local b1o = vec3(- sx,  - sy, - sz)
	local b2o = vec3(- sx,  sy,  - sz)
	local b3o = vec3(sx,  sy,  - sz)
	local b4o = vec3(sx,  - sy,  - sz)
	
	
	local a1r = orientation:transformCoord(a1o)
	local a2r = orientation:transformCoord(a2o)
	local a3r = orientation:transformCoord(a3o)
	local a4r = orientation:transformCoord(a4o)
	
	local b1r = orientation:transformCoord(b1o)
	local b2r = orientation:transformCoord(b2o)
	local b3r = orientation:transformCoord(b3o)
	local b4r = orientation:transformCoord(b4o)

	local a1 = position:__add(a1r)--vec3(x0 - sx, y0 - sy, z0 + sz)
	local a2 = position:__add(a2r)--vec3(x0 - sx, y0 + sy, z0 + sz)
	local a3 = position:__add(a3r)--vec3(x0 + sx, y0 + sy, z0 + sz)
	local a4 = position:__add(a4r)--vec3(x0 + sx, y0 - sy, z0 + sz)
	
	local b1 = position:__add(b1r)--vec3(x0 - sx, y0 - sy, z0 - sz)
	local b2 = position:__add(b2r)--vec3(x0 - sx, y0 + sy, z0 - sz)
	local b3 = position:__add(b3r)--vec3(x0 + sx, y0 + sy, z0 - sz)
	local b4 = position:__add(b4r)--vec3(x0 + sx, y0 - sy, z0 - sz)
	
	LeadSight.drawLine(color, a1, a2, distance, width)
	LeadSight.drawLine(color, a2, a3, distance, width)
	LeadSight.drawLine(color, a3, a4, distance, width)
	LeadSight.drawLine(color, a4, a1, distance, width)
	
	
	LeadSight.drawLine(color, b1, b2, distance, width)
	LeadSight.drawLine(color, b2, b3, distance, width)
	LeadSight.drawLine(color, b3, b4, distance, width)
	LeadSight.drawLine(color, b4, b1, distance, width)
	
	
	LeadSight.drawLine(color, a1, b1, distance, width)
	LeadSight.drawLine(color, a2, b2, distance, width)
	LeadSight.drawLine(color, a3, b3, distance, width)
	LeadSight.drawLine(color, a4, b4, distance, width)
	
end


function LeadSight.getWeightedWidth(distance, width)
	return width * (distance/closeClippingDistance)^0.65
end


---Calculations------------------------------------------------------------------



function LeadSight.refreshWeaponsData(craft)
	minProjectileSpeed = 1000000
	maxProjectileSpeed = 0
	meanProjectileSpeed = 0
	rangeMin = 10000000
	rangeMax = 0
	local turretCount = craft.numTurrets
	--print("Turrets:" .. turretCount)
	local shotSpeedSum = 0
	local weaponCount = 0
	for i = 0, turretCount-1 do
		local t = craft:getTurret(i)
		local weapon = ReadOnlyWeapons(t.id)
		
		if weapon.armed --actual weapon - not a mine or salvage laser
			and not weapon.seeker --has no seek
			and not (weapon.shotSpeed < eps) --has ok shot speed
			and not (weapon.shotSpeed > 10000) --has not instant shot speed
			and not weapon.continuousBeam --not a beam
			then
			weaponCount = weaponCount + 1
			shotSpeedSum = shotSpeedSum + weapon.shotSpeed
			if (maxProjectileSpeed < weapon.shotSpeed) then
				maxProjectileSpeed = weapon.shotSpeed
			end
			if (minProjectileSpeed > weapon.shotSpeed) then
				minProjectileSpeed = weapon.shotSpeed
			end
			if (rangeMax < weapon.reach) then
				rangeMax = weapon.reach
			end
			if (rangeMin > weapon.reach) then
				rangeMin = weapon.reach
			end
		end
	end
	if (weaponCount == 0) then
		return
	end

	meanProjectileSpeed = shotSpeedSum/weaponCount
		--print("meanProjectileSpeed:" .. meanProjectileSpeed)
end


--calculates distance until enemy is hit 
function LeadSight.calculateDistanceUntilHit(sinShootingAngle, calculationConstants)
local cc = calculationConstants
	local cosAlpha = LeadSight.sineCosine(cc.sinAlpha)
	local cosShootingAngle = LeadSight.sineCosine(sinShootingAngle)
	--third angle of the triangle - enemy - hitpoint - player
    local sinGamma = cc.sinAlpha * cosShootingAngle - cc.cosAlpha * sinShootingAngle
	local distanceUntilHit = cc.distance * sinShootingAngle / sinGamma
	
	return math.abs(distanceUntilHit)
end


--multiplies vector by value
function LeadSight.vec3Mul(vector, value)
	local lengthV = LeadSight.length(vector)
	return vec3(vector.x/lengthV * value, vector.y/lengthV * value, vector.z/lengthV * value)
end

--length of vector
function LeadSight.length(vector)
	return math.sqrt(vector.x*vector.x + vector.y*vector.y + vector.z*vector.z)
end


--dot product of two vectors
function LeadSight.dot(vector1, vector2)
	return vector1.x * vector2.x + vector1.y * vector2.y + vector1.z * vector2.z
end

--cross product of two vectors
function LeadSight.cross(vector1, vector2)
	local x1 = vector1.x
	local y1 = vector1.y
	local z1 = vector1.z
	
	local x2 = vector2.x
	local y2 = vector2.y
	local z2 = vector2.z
	
	return vec3(y1 * z2 - y2 * z1, - x1 * z2 + x2 * z1, x1 * y2 - x2 * y1)
end

--Transforms sine to cosine and vice versa
function LeadSight.sineCosine(sineCosineValue)
	return math.sqrt(1 - sineCosineValue * sineCosineValue);
end

--Gets a sine of angle between two vectors
function LeadSight.getVectorsAngSin(vector1, vector2)
	local vec1Len = LeadSight.length(vector1)
	local vec2Len = LeadSight.length(vector2)

	if (vec1Len < eps or vec2Len < eps) then
		return 1
	end	
	
	local vectorsCos = LeadSight.dot(vector1, vector2) / (vec1Len * vec2Len);

	return LeadSight.sineCosine(vectorsCos);
end

--gets plane parameters by 3 points
function LeadSight.getPlaneEquation(x1,  y1,  z1,  x2,  y2,  z2,  x3,  y3,  z3)
    local a1 = x2 - x1
    local b1 = y2 - y1
    local c1 = z2 - z1
    local a2 = x3 - x1
    local b2 = y3 - y1
    local c2 = z3 - z1
    local a = b1 * c2 - b2 * c1
    local b = a2 * c1 - a1 * c2
    local c = a1 * b2 - b1 * a2
    local d = (- a * x1 - b * y1 - c * z1)
    
	return vec4(a, b, c, d)
end

function LeadSight.getPlaneEquationFromNormal(normal, point) 
	local l = LeadSight.length(normal)
	local n = vec3(normal.x/l, normal.y/l, normal.z/l)
	return vec4(n.x, n.y, n.z, -n.x*point.x - n.y*point.y - n.z*point.z)
end


--returns 2 vectors laying within a given plane
function LeadSight.getPlaneBasisVectors(plane)
	local A = plane.x
	local B = plane.y
	local C = plane.z
	local D = plane.w

	--Just a point lying inside a given plane
	local genericPoint = vec3(0.0, 0.0, -D/C)
	local genericPoint2 = vec3(0.0, -D/B, 0.0)
	
	local i = genericPoint - genericPoint2
	local inorm = i/LeadSight.length(i)
		--second vector is orthogonal to the first one and plane normal
	local j = LeadSight.cross(inorm, vec3(plane.x, plane.y, plane.z))
	
	local jnorm = j/LeadSight.length(j)

	
	return inorm, jnorm

end


function LeadSight.map2dVectorTo3d(i, j, origin, vector)
	return i:__mul(vector.x) + j:__mul(vector.y) + origin
end

function LeadSight.projectVectorOnPlane(vector, plane)
	local t = - (plane.x * vector.x + plane.y * vector.y + plane.z * vector.z + plane.w)/ (plane.x * plane.x + plane.y * plane.y + plane.z * plane.z)
	return vec3(plane.x*t + vector.x, plane.y*t + vector.y, plane.z*t + vector.z)
end

--Gets maximum possible solution for projectile speed taking into account player's ship speed
function LeadSight.getMaxShootingSpeed(calculationConstants)
	local cc = calculationConstants
	local a = cc.shipSpeed * cc.sinAlpha * cc.enemySpeed * cc.shipSpeedSin
    local b = -2 * cc.projSpeed
    local c = - cc.shipSpeedCos*cc.shipSpeedCos * cc.shipSpeed*cc.shipSpeed + 2*a + cc.projSpeed * cc.projSpeed
    local d= -2 * cc.projSpeed * a
    local e= (cc.sinAlpha * cc.enemySpeed * cc.shipSpeed * cc.shipSpeedCos)* (cc.sinAlpha * cc.enemySpeed * cc.shipSpeed * cc.shipSpeedCos) + a*a
	local alteredSpeeds = LeadSight.solve_quartic(b,c,d,e)

	--No solution found
	if #alteredSpeeds == 0 then
		return -1
	end
	
	
	local maxSpeed = 0.0
	for i, s in ipairs(alteredSpeeds) do
		if maxSpeed < s then
			maxSpeed = s
		end
	end
	
	return maxSpeed
end

function LeadSight.solveP2(a, b, c)
	local d = math.sqrt(b*b - 4*a*c)
	local x1 = (-b + d)/(2*a)
	local x2 = (-b - d)/(2*a)
	return x1, -x1
end

-- Solvers are taken from https://github.com/sasamil/Quartic/blob/master Big thanks!
function LeadSight.solveP3(a ,b ,c) 

    local result = {}
	local a2 = a*a
    local q  = (a2 - 3*b)/9
	local r  = (a*(2*a2-9*b) + 27*c)/54
	local r2 = r*r
	local q3 = q*q*q
	local A,B
	
    if r2<q3 then
    		local t=r/math.sqrt(q3)
    		if t<-1 then t=-1 end
    		if t> 1 then t= 1 end
    		t=math.acos(t)
    		a = a/3
			q=-2*math.sqrt(q)
			
    		table.insert(result, q*math.cos(t/3)-a)
    		table.insert(result, q*math.cos((t+math.pi*2.0)/3)-a)
    		table.insert(result, q*math.cos((t-math.pi*2.0)/3)-a)
    		return 3, result;
    else
    		A = -((math.abs(r)+math.sqrt(r2-q3)) ^ 0.3333);
    		if r < 0 then  
				A=-A;
			end
			if A == 0 then
				B = 0
			else
				B = q/A
			end

			a = a/3
			table.insert(result, (A+B)-a)
			table.insert(result, -0.5*(A+B)-a)
			table.insert(result, 0.5*math.sqrt(3.0)*(A-B))
			if math.abs(result[3]) < eps  then 
				result[3] = result[2]
				return 2, result
			end
			
			return 1, result
	end
end

---------------------------------------------------------------------------
-- Solve quartic equation x^4 + a*x^3 + b*x^2 + c*x + d
-- (attention - this function returns dynamically allocated array. It has to be released afterwards)
function LeadSight.solve_quartic(a, b, c, d)

	local a3 = -b
	local b3 =  a*c -4.0*d
	local c3 = -a*a*d - c*c + 4.0*b*d

	-- cubic resolvent
	-- y^3 ? b*y^2 + (ac?4d)*y ? a^2*d?c^2+4*b*d = 0

	local iZeroes, x3 = LeadSight.solveP3(a3, b3, c3)

	local q1, q2, p1, p2, D, sqD, y

	y = x3[1]
	-- THE ESSENCE - choosing Y with maximal absolute value !
	if(iZeroes ~= 1) then
		if math.abs(x3[2]) > math.abs(y) then y = x3[2] end
		if math.abs(x3[3]) > math.abs(y) then y = x3[3] end
	end

	-- h1+h2 = y && h1*h2 = d  <=>  h^2 -y*h + d = 0    (h === q)

	D = y*y - 4*d;
	if math.abs(D) < eps then --//in other words - D==0
		q1 = y * 0.5
		q2 = q1
		-- g1+g2 = a && g1+g2 = b-y   <=>   g^2 - a*g + b-y = 0    (p === g)
		D = a*a - 4*(b-y)
		if math.abs(D) < eps then--//in other words - D==0
			p1 = a * 0.5
			p2 = p1

		else
			sqD = math.sqrt(D)
			p1 = (a + sqD) * 0.5
			p2 = (a - sqD) * 0.5
		end
	else
		sqD = math.sqrt(D)
		q1 = (y + sqD) * 0.5
		q2 = (y - sqD) * 0.5
		-- g1+g2 = a && g1*h2 + g2*h1 = c       ( && g === p )  Krammer
		p1 = (a*q1-c)/(q1-q2)
		p2 = (c-a*q2)/(q1-q2)
	end

    local retval = {}

	-- solving quadratic eq. - x^2 + p1*x + q1 = 0
	D = p1*p1 - 4*q1;
	if D < 0.0 then
		table.insert(retval, -p1 * 0.5 );
		--retval[0].imag( math.sqrt(-D) * 0.5 ); --Complex roots are ignored
	    ---retval[1] = std::conj(retval[0]);
	else
	
		sqD = math.sqrt(D)
		table.insert(retval, (-p1 + sqD) * 0.5 )
		table.insert(retval, (-p1 - sqD) * 0.5 )
	end

	-- solving quadratic eq. - x^2 + p2*x + q2 = 0
	D = p2*p2 - 4*q2;
	if D < 0.0 then
		table.insert(retval, -p2 * 0.5 )
		--retval[2].imag( math.sqrt(-D) * 0.5 )
		--retval[3] = std::conj(retval[2])
	else
		sqD = math.sqrt(D)
		table.insert(retval, (-p2 + sqD) * 0.5 )
		table.insert(retval, (-p2 - sqD) * 0.5 )
	end

    return retval
end

--- Deprecated ----------------------------------------------------------
--sinAlpha - sine of the angle between enemy position vector relatively to the player's ship and enemy velocity vector 
-- function dichotomysearch(minRange, maxRange, calculationConstants)
	-- local a = -1
	-- local b = 1
	
	-- local x1 = a + phi * (b - a)
	-- local x2 = b - phi * (b - a)
	
	-- local fx1 = calculateProjectileDistance(x1, calculationConstants)
	-- local fx2 = calculateProjectileDistance(x2, calculationConstants)
	
	-- while 1 do
		-- if (fx1 < fx2) then
			-- b = x2
			-- --print (a .. " " .. b)
			-- if (b - a) < dichEps then
				-- return x1
			-- end
			-- x2 = x1 
			-- fx2 = fx1
			-- x1 = a + phi * (b - a)
		    -- fx1 = calculateProjectileDistance(x1, calculationConstants)
		-- else
			-- a = x1
			-- --print (a .. " " .. b)
			-- if (b - a) < dichEps then
				-- return x2
			-- end	
			-- x1 = x2 
			-- fx1 = fx2
			-- x2 = b - phi * (b - a)
			-- fx2 = calculateProjectileDistance(x2, calculationConstants)
		-- end
	-- end

-- end


-- --sinAlpha - sine of the angle between enemy position vector relatively to the player's ship and enemy velocity vector 
-- function calculateProjectileDistance(cosShootingAngle, calculationConstants)
	-- local cc = calculationConstants

	-- -- print("sinAlpha:" .. cc.sinAlpha)
	-- -- print("cosAlpha:" .. cc.cosAlpha)
	-- -- print("projSpeed:" .. cc.projSpeed)
	-- -- print("distance:" .. cc.distance)

	-- local sinShootingAngle = sineCosine(cosShootingAngle)
	-- --local cosShootingAngle = sineCosine(sinShootingAngle)
	-- local projAlteredSpeed = cc.projSpeed - cc.shipSpeed * (cosShootingAngle * cc.shipSpeedCos - sinShootingAngle * cc.shipSpeedSin)
	
    -- local sinGamma = cc.sinAlpha * cosShootingAngle - cc.cosAlpha * sinShootingAngle
	
	-- local projectileTime = cc.distance * cc.sinAlpha / (sinGamma * projAlteredSpeed)
	-- local enemyTravelDistance = projectileTime * cc.enemySpeed
	-- local distanceUntilHit = cc.distance * sinShootingAngle / sinGamma
	
		-- -- print("shipSpeed:" .. cc.shipSpeed)
			-- -- print("shipSpeedCos:" .. cc.shipSpeedCos)
	-- -- print("projAlteredSpeed:" .. projAlteredSpeed)
	-- -- print("sinGamma:" .. sinGamma)
	-- -- print("projectileTime:" .. projectileTime)
	-- -- print("enemyTravelDistance:" .. enemyTravelDistance)
	-- -- print("distanceUntilHit:" .. distanceUntilHit)
	-- -- print("anglecos:" .. cosShootingAngle)
	-- -- print("hit distance:" .. math.abs(enemyTravelDistance - distanceUntilHit))
	
	-- return math.abs(enemyTravelDistance - distanceUntilHit)
-- end