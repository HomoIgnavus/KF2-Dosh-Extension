//=============================================================================
// KFWeap_Knife_FieldMedic
//=============================================================================
// Class Description
//=============================================================================
// Killing Floor 2
// Copyright (C) 2015 Tripwire Interactive LLC
//  - Author 4/14/2014
//=============================================================================

class ExtWeap_Knife_FieldMedicRapid extends KFWeap_Knife_FieldMedic;

var float RapidSurgerySpeedMod;
var float RapidSurgerySpeedStep;

// var InterpCurveFloat baseFatigueCurve;

var float RapidSurgeryDmgMod;
var float RapidSurgeryDmgStep;

var int RapidSurgeryStacks;
var const int RapidSurgeryMaxStacks;

var bool bCanHemoExplode;
var float HemoExplosionChance;
var KFGameExplosion HemoExploTemplate;

simulated function NotifyMeleeCollision(Actor HitActor, optional vector HitLocation)
{
	local int idx;

	super.NotifyMeleeCollision(HitActor, HitLocation);

	if (!ClassIsChildOf(HitActor.Class, class'KFPawn_Monster'))
	{
		return;
	}
	
	// rapid surgery
	ClearTimer('ResetRapidSurgery');

	if (RapidSurgeryStacks < RapidSurgeryMaxStacks)
	{
		++RapidSurgeryStacks;

		RapidSurgerySpeedMod = 1.0 - RapidSurgerySpeedStep * RapidSurgeryStacks;
		RapidSurgeryDmgMod = 1.0 + RapidSurgeryDmgStep * RapidSurgeryStacks;
		
		// `log("ExtWeap_Knife_FieldMedicRapid Rapid Surgery Stack: " @ RapidSurgeryStacks@ " Dmg Mod: " @ RapidSurgeryDmgMod @ " Speed Mod: " @ RapidSurgerySpeedMod);
	}

	if (bCanHemoExplode)
	{
		AttemptHemoExplosion(HitLocation);
	}

	SetTimer(3.0, false, 'ResetRapidSurgery');

}

simulated function AttemptHemoExplosion(vector ExpLocation)
{
	local float RandNum;
	local KFExplosionActorReplicated ExploActor;

	// `log("TriggerHemoExplosion() called on " @ Role);
	RandNum = FRand();
	if (RandNum > HemoExplosionChance)
	{
		return;
	}

	if (Role == ROLE_Authority)
	{
		ExploActor = Spawn(class'KFExplosionActorReplicated', self,, ExpLocation, rotator(vect(0,0,1)),, true);
		if (ExploActor != None)
		{
			ExploActor.InstigatorController = KFPlayer;
			ExploActor.Instigator = KFPlayer.Pawn;
			ExploActor.bIgnoreInstigator = false;
			ExploActor.Explode(HemoExploTemplate);
		}
	}
}

// overridden to apply rapid surgery speed boost
simulated function ModifyMeleeAttackSpeed(out float InSpeed, optional int FireMode = DEFAULT_FIREMODE, optional int UpgradeIndex = INDEX_NONE, optional KFPerk CurrentPerk)
{
	InSpeed = GetUpgradedStatValue(InSpeed, EWeaponUpgradeStat(EWUS_MeleeSpeed0 + UpgradeFireModes[FireMode]), CurrentWeaponUpgradeIndex);
	InSpeed *= RapidSurgerySpeedMod;

	if (CurrentPerk == none)
	{
		CurrentPerk = GetPerk();
	}

	if (CurrentPerk != none)
	{
		CurrentPerk.ModifyMeleeAttackSpeed(InSpeed, self);
	}
}

simulated function int GetModifiedDamage(byte FireModeNum, optional vector RayDir)
{
	local int dmg;

	dmg = super.GetModifiedDamage(FireModeNum, RayDir);
	dmg *= RapidSurgeryDmgMod;
	return dmg;
}

simulated function ResetRapidSurgery()
{
	RapidSurgeryStacks = 0;
	RapidSurgeryDmgMod = default.RapidSurgeryDmgMod;
	RapidSurgerySpeedMod = default.RapidSurgerySpeedMod;
}

defaultproperties
{
	RapidSurgerySpeedMod=1.0
	RapidSurgerySpeedStep=0.02

	RapidSurgeryDmgMod=1.0
	RapidSurgeryDmgStep=0.1
	RapidSurgeryStacks=0

	bCanHemoExplode=false
	HemoExplosionChance=0f

	RapidSurgeryMaxStacks=20

		Begin Object Class=KFGameExplosion Name=ExploTemplate0
		Damage=225 //200
		DamageRadius=500
		DamageFalloffExponent=0.f
		DamageDelay=0.f
		MyDamageType=class'KFDT_Toxic_MedicBatGas'
		HealingAmount=15 //20 //30

		// Damage Effects
		KnockDownStrength=0
		KnockDownRadius=0
		FractureMeshRadius=0
		FracturePartVel=0
		ExplosionEffects=KFImpactEffectInfo'WEP_Medic_Bat_ARCH.Medic_Bat_Explosion'
		ExplosionSound=AkEvent'WW_WEP_MEL_MedicBat.Play_WEP_MedicBat_Smoke_Explode'
		MomentumTransferScale=0
		bIgnoreInstigator=false

		// Dynamic Light
		//ExploLight=ExplosionPointLight
		//ExploLightStartFadeOutTime=7.0
		//ExploLightFadeOutTime=1.0
		//ExploLightFlickerIntensity=5.f
		//ExploLightFlickerInterpSpeed=15.f

		// Camera Shake
		CamShake=none
		CamShakeInnerRadius=0
		CamShakeOuterRadius=0
		CamShakeFalloff=1.5f
		bOrientCameraShakeTowardsEpicenter=true
	End Object

	HemoExploTemplate=ExploTemplate0
}
