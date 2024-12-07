SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.ViewModel = Model("models/weapons/c_arms.mdl")
SWEP.WorldModel = Model("models/error.mdl")

SWEP.UseHands = true

SWEP.Primary = BAS.Util.GenerateAmmoTable()
SWEP.Secondary = BAS.Util.GenerateAmmoTable()

-- Extension things
AccessorFunc(SWEP, "m_iReloadAnimation", "ReloadAnimation", FORCE_NUMBER)
AccessorFunc(SWEP, "m_iOwnerReloadAnimation", "OwnerReloadAnimation", FORCE_NUMBER)

AccessorFunc(SWEP, "m_iPrimaryAttackAnimation", "PrimaryAttackAnimation", FORCE_NUMBER)
AccessorFunc(SWEP, "m_iOwnerPrimaryAttackAnimation", "OwnerPrimaryAttackAnimation", FORCE_NUMBER)

AccessorFunc(SWEP, "m_iSecondaryAttackAnimation", "SecondaryAttackAnimation", FORCE_NUMBER)
AccessorFunc(SWEP, "m_iOwnerSecondaryAttackAnimation", "OwnerSecondaryAttackAnimation", FORCE_NUMBER)

AccessorFunc(SWEP, "m_bInPrimaryFire", "InPrimaryFire", FORCE_BOOL)
AccessorFunc(SWEP, "m_bInSecondaryFire", "InSecondaryFire", FORCE_BOOL)

-- Hooks
function SWEP:Initialize()
	self:SetReloadAnimation(ACT_VM_RELOAD)
	self:SetOwnerReloadAnimation(PLAYER_RELOAD)

	self:SetPrimaryAttackAnimation(ACT_VM_PRIMARYATTACK)
	self:SetOwnerPrimaryAttackAnimation(PLAYER_ATTACK1)

	self:SetSecondaryAttackAnimation(ACT_VM_SECONDARYATTACK)
	self:SetOwnerSecondaryAttackAnimation(PLAYER_ATTACK1)

	self:OnInitialized()
end

function SWEP:OnInitialized()
	-- For override
end

function SWEP:CanReload()
	if not IsFirstTimePredicted() then return false end

	-- For override

	return true
end

function SWEP:Reload()
	if not self:CanReload() then return end

	local DefaultSuccess = self:DefaultReload(self:GetReloadAnimation())

	if DefaultSuccess then
		self:CallOnOwner("SetAnimation", self:GetOwnerReloadAnimation())
	end

	return self:OnReload(DefaultSuccess)
end

function SWEP:OnReload(DefaultSuccess)
	-- For override
end

function SWEP:CanPrimaryAttack()
	if not IsFirstTimePredicted() then return false end
	if not self.Primary.Enabled then return false end

	if CurTime() < self:GetNextPrimaryFire() then return false end

	if self.Primary.UsesAmmo and (not self:HasAmmo() or self:Clip1() <= 0) then
		self:Reload()

		return false
	end

	return true
end

function SWEP:CanSecondaryAttack()
	if not IsFirstTimePredicted() then return false end
	if not self.Secondary.Enabled then return false end

	if CurTime() < self:GetNextSecondaryFire() then return false end

	local Clip = self:GetPrimaryAmmoType() == self:GetSecondaryAmmoType() and self:Clip1() or self:Clip2()

	if self.Secondary.UsesAmmo and (not self:HasAmmo() or Clip <= 0) then
		return false
	end

	return true
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end

	self:SetInPrimaryFire(true)
	do
		local _, BlockAnimations = xpcall(self.OnPrimaryAttack, ErrorNoHaltWithStack, self)

		if BlockAnimations ~= false then
			self:SendWeaponAnim(self:GetPrimaryAttackAnimation())
			self:CallOnOwner("SetAnimation", self:GetOwnerPrimaryAttackAnimation())
		end
	end
	self:SetInPrimaryFire(false)
end

function SWEP:SecondaryAttack()
	if not self:CanSecondaryAttack() then return end

	self:SetInSecondaryFire(true)
	do
		local _, BlockAnimations = xpcall(self.OnSecondaryAttack, ErrorNoHaltWithStack, self)

		if BlockAnimations ~= false then
			self:SendWeaponAnim(self:GetSecondaryAttackAnimation())
			self:CallOnOwner("SetAnimation", self:GetOwnerSecondaryAttackAnimation())
		end
	end
	self:SetInSecondaryFire(false)
end

function SWEP:OnPrimaryAttack()
	-- For override
	-- Return false to prevent animations
end

function SWEP:OnSecondaryAttack()
	-- For override
	-- Return false to prevent animations
end

-- Utilities
function SWEP:CallOnOwner(FunctionName, ...)
	local Owner = self:GetOwner()
	if not IsValid(Owner) then return end

	-- Let it error on purpose to alert retardation
	return Owner[FunctionName](Owner, ...)
end

function SWEP:GetCurrentFireFlags(IgnoreInFire)
	local InPrimaryFire = self:GetInPrimaryFire()
	local InSecondaryFire = self:GetInSecondaryFire()

	if not IgnoreInFire and (not InPrimaryFire and not InSecondaryFire) then
		return error("Tried to do fire operation outside of fire!")
	end

	return InPrimaryFire, InSecondaryFire
end

function SWEP:GetCurrentFireTable()
	local InPrimaryFire = self:GetCurrentFireFlags()

	return InPrimaryFire and self.Primary or self.Secondary
end

function SWEP:ApplyNextFireTime()
	local InPrimaryFire = self:GetCurrentFireFlags()

	if self:GetCurrentFireFlags() then
		self:SetNextPrimaryFire(CurTime() + self.Primary.FireRate)
	else
		self:SetNextSecondaryFire(CurTime() + self.Secondary.FireRate)
	end
end

function SWEP:ApplyViewPunch()
	local Owner = self:GetOwner()
	if not Owner:IsPlayer() then return end -- Don't call on invalid owner kthx

	local PunchCone = self:GetCurrentFireTable().ViewPunch
	if PunchCone:IsZero() then return end

	local VeritcalPunch = math.Rand(-math.abs(PunchCone.x), 0)
	if PunchCone.x < 0 then VeritcalPunch = -VeritcalPunch end

	local HorizontalPunch = math.Rand(-PunchCone.y, PunchCone.y)

	Owner:ViewPunch(Angle(VeritcalPunch, HorizontalPunch))
end

function SWEP:ApplyAimPunch()
	local PunchCone = self:GetCurrentFireTable().AimPunch
	if PunchCone:IsZero() then return end

	local Owner = self:GetOwner()

	local VeritcalPunch = math.Rand(-PunchCone.x, PunchCone.x)
	local HorizontalPunch = math.Rand(-PunchCone.y, PunchCone.y)

	local EyeAngles = Owner:EyeAngles()

	EyeAngles.pitch = EyeAngles.pitch + VeritcalPunch
	EyeAngles.yaw = EyeAngles.yaw + HorizontalPunch

	if Owner:IsPlayer() then
		Owner:SetEyeAngles(EyeAngles)
	else
		Owner:SetAngles(EyeAngles)
	end
end

function SWEP:GenerateBullet(Output)
	local FireTable = self:GetCurrentFireTable()
	local Owner = self:GetOwner()

	Output = Output or {}

	Output.Attacker = Owner
	Output.IgnoreEntity = Owner

	Output.Src = Owner:EyePos()
	Output.Dir = Owner:EyeAngles():Forward()
	Output.Spread = Vector(FireTable.BulletSpread)

	Output.AmmoType = FireTable.Ammo
	Output.Damage = FireTable.BulletDamage
	Output.Distance = FireTable.BulletDistance
	Output.Force = 0
	Output.HullSize = 0
	Output.Num = 1
	Output.Tracer = 1

	return Output
end

function SWEP:RunTrace(StartPos, EndPos)
	local TraceData = BAS.Util.ResetTrace()

	TraceData.start = StartPos
	TraceData.endpos = EndPos
	TraceData.filter = { self, self:GetOwner() }

	return BAS.Util.RunTrace()
end
