// This file is part of Server Extension.
// Server Extension - a mutator for Killing Floor 2.
//
// Copyright (C) 2016-2024 The Server Extension authors and contributors
//
// Server Extension is free software: you can redistribute it
// and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Server Extension is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with Server Extension. If not, see <https://www.gnu.org/licenses/>.

Class Ext_PerkBerserker extends Ext_PerkBase;

var float VampRegenRate,ZedTimeMeleeAtkRate;

// parry trait explosion
var private bool bIsParryBuffActive;
var private bool bIsParryMasterActive;
var private float ParryDmgReduction;
var private float ParryBuffDuration;
var GameExplosion ParryExploTemplate;

var private bool bIsParryHealActive;
var private float ParryExpDmg;
var private float ParryHealPct;
var private float ParryArmorPct;

var private bool bIsParryExplosionActive;
var public bool bIsParryCoolingDown;
// var private float ParryExpDmg;
// var private float ParryExpAoE;

// fall explosion
var private bool bHasTraitBombzerker;
var private float BombzerkerDmgRatio;
var private float BombzerkerRadiusRatio;

var GameExplosion FallExplosion;
var GameExplosion FallExploTemplateNormal;
var GameExplosion FallExploTemplateNuke;

var public float FallDamageScale;
var public bool bIsAtomic; // won't die from fall damage

// Special Ability
var public bool bHasMysticEyes;
var public float MysticEyesDuration;
var public float MysticEyesDmgMultiplier;

replication
{
	// Things the server should send to the client.
	if (true)
		ZedTimeMeleeAtkRate;
}

simulated function ModifyDamageGiven(out int InDamage, optional Actor DamageCauser, optional KFPawn_Monster MyKFPM, optional KFPlayerController DamageInstigator, optional class<KFDamageType> DamageType, optional int HitZoneIdx)
{
	super.ModifyDamageGiven(InDamage, DamageCauser, MyKFPM, DamageInstigator, DamageType, HitZoneIdx);

	`log("Ext_PerkBerserker::ModifyDamageGiven() HitZoneIdx="$ HitZoneIdx);
}

simulated function ModifyMeleeAttackSpeed(out float InDuration)
{
	InDuration *= Modifiers[ExtStat_MeleeSpeed];
	if (ZedTimeMeleeAtkRate<1.f && WorldInfo.TimeDilation<1.f)
		InDuration *= ZedTimeMeleeAtkRate;
}

simulated function ModifyRateOfFire(out float InRate, KFWeapon KFW)
{
	if (IsWeaponOnPerk(KFW))
	{
		InRate *= Modifiers[ExtStat_Spread];
		if (ZedTimeMeleeAtkRate<1.f && WorldInfo.TimeDilation<1.f)
			InRate *= ZedTimeMeleeAtkRate;
	}
}

simulated function TriggerTraitParry(Actor Target = none)
{
	local ExtHumanPawn ExtP;

	if (!bIsParryMasterActive) return;
	
	ExtP = ExtHumanPawn(PlayerOwner.Pawn);
	if (ExtP == None)
		return;

	if (bIsParryCoolingDown) return;
	bIsParryCoolingDown = true;
		
	ActivateParryBuff();

	if (bIsParryExplosionActive)
	{	
		if (Target == none)
			Target = ExtP;
		TriggerParryExplosion(Target);
	}
	
	if (bIsParryHealActive)
		TriggerParryHeal(ExtP);

	SetTimer(0.5f, false, 'ClearParryCoolDown');
}

function ClearParryCoolDown()
{
	bIsParryCoolingDown = false;
}

// simulated function TriggerParryProj(KFWeap_MeleeBase ActiveWeapon, Actor Target)
// {
// 	local AkBaseSoundObject Sound;
// 	local ParticleSystem PSTemplate;
	
// 	ActiveWeapon.GetParryEffects(255, Sound, PSTemplate);
// 	ActiveWeapon.PlayLocalBlockEffects(Sound, PSTemplate);
// 	TriggerTraitParry(Target);
// }

simulated function TriggerParryHeal(ExtHumanPawn ExtP)
{
	if (PlayerOwner == None || PlayerOwner.Pawn == None || !PlayerOwner.Pawn.IsAliveAndWell())
		return;

	ExtP = ExtHumanPawn(PlayerOwner.Pawn);
	if (ExtP == None)
		return;

	ExtP.HealDamage(Max(ExtP.HealthMax*ParryHealPct,1), PlayerOwner, class'KFDT_Healing', false, false);
	if (ParryArmorPct > 0.f)
	{
		ExtP.AddArmor(Max(ExtP.MaxArmorInt * ParryArmorPct, 1));
	}
}

simulated function TriggerParryExplosion(Actor Target)
{
	local vector HitLocation;
	local KFExplosionActorReplicated ExploActor;

	if (PlayerOwner == None || PlayerOwner.Pawn == None || !PlayerOwner.Pawn.IsAliveAndWell())
		return;

	if (Role == ROLE_Authority)
	{
		// Spawn EMP-like explosion centered on the player
		HitLocation = Target.Location;

		ExploActor = Spawn(class'KFExplosionActorReplicated', self,, HitLocation, rotator(vect(0,0,1)),, true);
		if (ExploActor != None)
		{
			ExploActor.InstigatorController = PlayerOwner;
			ExploActor.Instigator = PlayerOwner.Pawn;
			ExploActor.bIgnoreInstigator = true;
			ExploActor.Explode(ParryExploTemplate);
		}
	}
}

function ActivateParryBuff()
{
	bIsParryBuffActive = true;
	
	SetTimer(ParryBuffDuration, false, 'DeactivateParryBuff');
}

function DeactivateParryBuff()
{
	bIsParryBuffActive = false;
}

function ApplyTraitParryMaster(float Reduction, float Duration)
{
	ParryDmgReduction = Reduction;
	ParryBuffDuration = Duration;

	bIsParryMasterActive = ParryDmgReduction > 0.f || ParryBuffDuration > 0.f;
}

function ApplyTraitParryExplosion(float Damage, float Radius)
{
	// ParryExploTemplate = default.ParryExploTemplate;
	ParryExploTemplate.DamageRadius = Radius;
	ParryExploTemplate.Damage = Damage;
	ParryExpDmg = Damage;

	bIsParryExplosionActive = Damage > 0.f || Radius > 0.f;
	// `log("ParryExploTemplate.DamageRadius=" @ ParryExploTemplate.DamageRadius @ " ParryExploTemplate.Damage=" @ ParryExploTemplate.Damage @ " bIsParryExplosionActive=" @ bIsParryExplosionActive);
}

function ApplyTraitParryHealing(float HealthPct, float ArmorPct)
{
	ParryHealPct = HealthPct;
	ParryArmorPct = ArmorPct;

	bIsParryHealActive = ParryHealPct > 0.f || ParryArmorPct > 0.f;
}


simulated function TriggerFallExplosion(int FallDmg)
{
	local vector HitLocation;
	local KFExplosionActorReplicated ExploActor;
	local float ExpDmg;
	local float ExpRadius;
	local float ExpAnimScale;

	if (PlayerOwner == None || PlayerOwner.Pawn == None || !PlayerOwner.Pawn.IsAliveAndWell() || !bHasTraitBombzerker)
		return;

	if (Role == ROLE_Authority)
	{
		ExpDmg = FallDmg * BombzerkerDmgRatio;
		ExpRadius = FallDmg * BombzerkerRadiusRatio;
		ExpAnimScale = ExpRadius / 200.f;

		FallExplosion.Damage = ExpDmg;
		FallExplosion.DamageRadius = ExpRadius;
		FallExplosion.ExplosionEmitterScale = ExpAnimScale;
		`log("TriggerFallExplosion(): Dmg=" @ FallExplosion.Damage @ " Radius=" @ FallExplosion.DamageRadius @ " ExpAnimScale=" @ FallExplosion.ExplosionEmitterScale);
		// Spawn explosion centered on the player
		HitLocation = PlayerOwner.Pawn.Location;
		ExploActor = Spawn(class'KFExplosionActorReplicated', self,, HitLocation, rotator(vect(0,0,1)),, true);
		if (ExploActor != None)
		{
			ExploActor.InstigatorController = PlayerOwner;
			ExploActor.Instigator = PlayerOwner.Pawn;
			ExploActor.bIgnoreInstigator = true;
			ExploActor.Explode(FallExplosion);
		}
	}
}

function ApplyTraitBombzerker(float DmgRatio, float RadiusRatio, bool bActivate = true)
{
	bHasTraitBombzerker = bActivate;
	BombzerkerDmgRatio = DmgRatio;
	BombzerkerRadiusRatio = RadiusRatio;
	FallExplosion = FallExploTemplateNormal;
}

function ApplyTraitAtomic(int Level)
{
	if (Level <= 0)
	{
		bIsAtomic = false;
		return;
	}

	bIsAtomic = true;
	if (Level == 1)
		FallExplosion = FallExploTemplateNormal;
	else
		FallExplosion = FallExploTemplateNuke;
}

simulated function ModifyDamageTaken(out int InDamage, optional class<DamageType> DamageType, optional Controller InstigatedBy)
{
	super.ModifyDamageTaken(InDamage,DamageType,InstigatedBy);
	if (bIsParryBuffActive)
	{
		InDamage = Max(InDamage * ParryDmgReduction, 1);
	}
}


function PlayerKilled(KFPawn_Monster Victim, class<DamageType> DT)
{
	if (VampRegenRate>0 && PlayerOwner.Pawn!=None && PlayerOwner.Pawn.Health>0 && class<KFDamageType>(DT)!=None && class<KFDamageType>(DT).Default.ModifierPerkList.Find(BasePerk)>=0)
		PlayerOwner.Pawn.HealDamage(Max(PlayerOwner.Pawn.HealthMax*VampRegenRate,1), PlayerOwner, class'KFDT_Healing', false, false);
}

defaultproperties
{
	PerkIcon=Texture2D'UI_PerkIcons_TEX.UI_PerkIcon_Berserker'
	DefTraitList.Add(class'Ext_TraitWPBers')
	DefTraitList.Add(class'Ext_TraitUnGrab')
	DefTraitList.Add(class'Ext_TraitBombzerker')
	DefTraitList.Add(class'Ext_TraitPiptomaniac')
	DefTraitList.Add(class'Ext_TraitAtomic')
	DefTraitList.Add(class'Ext_TraitSA_MysticEyes')
	DefTraitList.Add(class'Ext_TraitVampire')
	DefTraitList.Add(class'Ext_TraitParryMaster')
	DefTraitList.Add(class'Ext_TraitParryHealing')
	DefTraitList.Add(class'Ext_TraitParryExplosion')
	DefTraitList.Add(class'Ext_TraitParryProjectile')
	DefTraitList.Add(class'Ext_TraitSpartan')
	DefTraitList.Add(class'Ext_TraitAirbagArmor')
	// DefPerkStats(15)=(bHiddenConfig=false) // Poison damage.
	BasePerk=class'KFPerk_Berserker'

	PrimaryMelee=class'KFWeap_Knife_Berserker'
	PrimaryWeapon=class'KFWeap_Blunt_Crovel'
	PerkGrenade=class'KFProj_EMPGrenade'

	PrimaryWeaponDef=class'KFWeapDef_Crovel'
	KnifeWeaponDef=class'KFweapDef_Knife_Berserker'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_Berserker'

	AutoBuyLoadOutPath=(class'KFWeapDef_Crovel', class'KFWeapDef_Nailgun', class'KFWeapDef_Pulverizer', class'KFWeapDef_Eviscerator')

	ZedTimeMeleeAtkRate=1.0

	// EMP-style parry explosion (mirrors KFProj_EMPGrenade.ExploTemplate0)
	Begin Object Class=KFGameExplosion Name=ParryExploTemplate0
		Damage=25
		DamageRadius=200
		DamageFalloffExponent=1
		DamageDelay=0.f

		MyDamageType=class'KFDT_EMP_EMPGrenade'
		FractureMeshRadius=200.0
		FracturePartVel=500.0
		ExplosionEffects=KFImpactEffectInfo'FX_Impacts_ARCH.Explosions.EMPGrenade_Explosion'
		ExplosionSound=AkEvent'WW_WEP_EXP_Grenade_EMP.Play_WEP_EXP_Grenade_EMP_Explosion'

		CamShake=CameraShake'FX_CameraShake_Arch.Grenades.Default_Grenade'
		CamShakeInnerRadius=200
		CamShakeOuterRadius=900
		CamShakeFalloff=1.5f
		bOrientCameraShakeTowardsEpicenter=true

		bIgnoreInstigator=true
		ActorClassToIgnoreForDamage=class'KFPawn_Human'
	End Object
	ParryExploTemplate=ParryExploTemplate0

	// RPG7-style fall explosion (mirrors KFProj_Rocket_RPG7.ExploTemplate0)
	Begin Object Class=KFGameExplosion Name=FallExploTemplate0
		Damage=750
		DamageRadius=400
		DamageFalloffExponent=2
		DamageDelay=0.f

		MyDamageType=class'KFDT_Explosive_RPG7'
		KnockDownStrength=0
		FractureMeshRadius=200.0
		FracturePartVel=500.0
		ExplosionEffects=KFImpactEffectInfo'WEP_RPG7_ARCH.RPG7_Explosion'
		ExplosionSound=AkEvent'WW_WEP_SA_RPG7.Play_WEP_SA_RPG7_Explosion'

		CamShake=CameraShake'FX_CameraShake_Arch.Misc_Explosions.Light_Explosion_Rumble'
		CamShakeInnerRadius=200
		CamShakeOuterRadius=900
		CamShakeFalloff=1.5f
		bOrientCameraShakeTowardsEpicenter=true

		bIgnoreInstigator=true
		ActorClassToIgnoreForDamage=class'KFPawn_Human'
	End Object
	FallExploTemplateNormal=FallExploTemplate0

	// nuke explosion
	Begin Object Class=KFGameExplosion Name=FallExploTemplate1
		Damage=45 //15
		DamageRadius=450
		DamageFalloffExponent=1.f
		DamageDelay=0.f
		MyDamageType=class'KFDT_Toxic_DemoNuke'
		//bIgnoreInstigator is set to true in PrepareExplosionTemplate

		// Damage Effects
		KnockDownStrength=0
		KnockDownRadius=0
		FractureMeshRadius=200.0
		FracturePartVel=500.0
		ExplosionEffects=KFImpactEffectInfo'FX_Impacts_ARCH.Explosions.Nuke_Explosion'
		ExplosionSound=AkEvent'WW_GLO_Runtime.Play_WEP_Nuke_Explo'
		MomentumTransferScale=1.f

		// Camera Shake
		CamShake=CameraShake'FX_CameraShake_Arch.Grenades.Default_Grenade'
		CamShakeInnerRadius=200
		CamShakeOuterRadius=900
		CamShakeFalloff=1.5f
		bOrientCameraShakeTowardsEpicenter=true
	End Object
	FallExploTemplateNuke=FallExploTemplate1

	bHasTraitBombzerker = false
	FallDamageScale = 1.0;
	bIsAtomic = false
	bIsParryCoolingDown = false

	bHasMysticEyes = false;
	MysticEyesDuration = 0.0;
	MysticEyesDmgMultiplier = 1.0;
}