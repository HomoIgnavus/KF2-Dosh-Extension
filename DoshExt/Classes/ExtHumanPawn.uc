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

Class ExtHumanPawn extends KFPawn_Human;

// Forrests backpack weapon and first person legs.
var SkeletalMeshComponent AttachedBackItem;
var SkeletalMeshComponent FPBodyMesh;
var repnotify class<KFWeapon> BackpackWeaponClass;
var KFWeapon PlayerOldWeapon;

var transient float NextRedeemTimer,BHopSpeedMod;
var float KnockbackResist,NoRagdollChance;
var AnimSet WakeUpAnimSet;
var name FeignRecoverAnim;
var byte UnfeignFailedCount,RepRegenHP,BHopAccelSpeed;
var repnotify bool bFeigningDeath;
var bool bPlayingFeignDeathRecovery,bRagdollFromFalling,bRagdollFromBackhit,bRagdollFromMomentum,bCanBecomeRagdoll,bRedeadMode,bPendingRedead,bHasBunnyHop,bOnFirstPerson,bFPLegsAttached,bFPLegsInit,bThrowAllWeaponsOnDeath;
var repnotify int ArmorInt;
var int MaxArmorInt;

var byte HealingShieldMod,HealingSpeedBoostMod,HealingDamageBoostMod;

var bool bCanParryProj;
var bool bCanReflectProj;

var int SpWeaponCount;
var int SpWeaponMax;

var public float ArmorEfficiency;
var public float AirBagRate; // for berserker's Ext_TraitAirbagArmor

// special abilities
// var private bool bIsUsingAbility;
var public int AbilityGauge;
var public int AbilityCount;
var public int MaxAbilityCount;

var bool bIsUsingMGRs;
var public int MGRs_BaseDamage;
var public int MGRs_DamageMod;
var public int MGRs_BasePenetration;
var public int MGRs_PenetrationMod;
var public int MGRs_CurrentAmmo;

// for quantum shield owner
var bool bOwnsQuantumShield;
var float QuantumShieldDuration;
var float QuantumShieldDmgMultiplier;
var public int QuantumShieldArmorConsumed;
var int QuantumShieldMultiplier;
var ParticleSystemComponent QuantumShieldPSC;
var ParticleSystem QuantumShieldFX;
// for quantum shield recipients
var repnotify ExtHumanPawn QuantumShieldOwner;

// for dense rounds
var bool bIsUsingDenseRounds;
var float DenseRoundDuration;
var float DenseRounds_DamageMod;
var float DenseRounds_PenetrationMod;
var ExtWeap_DenseRounds DenseRoundsWeapon;

replication
{
	if (true)
		bFeigningDeath,RepRegenHP,BackpackWeaponClass,ArmorInt,MaxArmorInt,bIsUsingMGRs,AbilityGauge,AbilityCount,MaxAbilityCount,QuantumShieldOwner,QuantumShieldDuration,QuantumShieldDmgMultiplier;
	if (bNetOwner)
		bHasBunnyHop, DenseRoundsWeapon;
	if (bNetDirty)
		HealingSpeedBoostMod, HealingDamageBoostMod, HealingShieldMod;
}

simulated event PreBeginPlay()
{
	super.PreBeginPlay();
	Armor = 0;
	MaxArmor = 10;
}

/***
Below are armor related functions overriden to use int instead of byte, so that the armor value can get higher than 255
 */
function TakeDamage(int Damage, Controller InstigatedBy, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
{
	if (KnockbackResist<1)
		Momentum *= KnockbackResist;

	Super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
}

function AddArmor( int Amount )
{
	ArmorInt = Min( ArmorInt + Amount, MaxArmorInt);
	NotifyArmorChanged();
}

function GiveMaxArmor()
{
	ArmorInt = MaxArmorInt;
	NotifyArmorChanged();
}

function OverloadArmor()
{
	ArmorInt += MaxArmorInt;
	NotifyArmorChanged();
}

function int GetMaxArmor()
{
	return MaxArmorInt;
}

function ShieldAbsorb( out int InDamage )
{
	local int AbsorbedDmg;

	AbsorbedDmg = Min(Round(ArmorEfficiency * InDamage), ArmorInt);
	// reduce damage and armor
	ArmorInt -= AbsorbedDmg;
	InDamage -= AbsorbedDmg;
	NotifyArmorChanged();
}

function AdjustDamage(out int InDamage, out vector Momentum, Controller InstigatedBy, vector HitLocation, class<DamageType> DamageType, TraceHitInfo HitInfo, Actor DamageCauser)
{
	local KFPerk MyKFPerk;
	local float TempDamage;
	local bool bHasSacrificeSkill;
	local Projectile ProjectileCauser;

	super.AdjustDamage(InDamage, Momentum, InstigatedBy, HitLocation, DamageType, HitInfo, DamageCauser);

	// nullify damage during trader time
	if (KFGameReplicationInfo(KFGameInfo(WorldInfo.Game).GameReplicationInfo).bTraderIsOpen)
	{
		InDamage = 0;
		return;
	}

	MyKFPerk = GetPerk();
	if( MyKFPerk != none )
	{
		MyKFPerk.ModifyDamageTaken( InDamage, DamageType, InstigatedBy );
		bHasSacrificeSkill = MyKFPerk.ShouldSacrifice();
	}

	TempDamage = InDamage;

	if( TempDamage > 0 && class'KFPerk_Demolitionist'.static.IsDmgTypeExplosiveResistable( DamageType ) && HasExplosiveResistance() )
	{
		class'KFPerk_Demolitionist'.static.ModifyExplosiveDamage( TempDamage );
		TempDamage = TempDamage < 1.f ? 1.f : TempDamage;
	}

	TempDamage *= GetHealingShieldModifier();
	InDamage = Round( TempDamage );

	// quantum shield damage absorption
	if (InDamage > 0 && QuantumShieldOwner != None && QuantumShieldOwner.ArmorInt > 0)
	{
		QuantumShieldAbsorb(InDamage);
		if (InDamage <= 0)
		{
			AddHitFX(InDamage, InstigatedBy, GetHitZoneIndex(HitInfo.BoneName), HitLocation, Momentum, class<KFDamageType>(DamageType));
		}
	}

	// Reduce damage based on you current armor integrity
	if( InDamage > 0 && ArmorInt > 0 && DamageType.default.bArmorStops )
	{
		ShieldAbsorb( InDamage );

		//Shield has taken all the damage.  Setup the HitFXInfo for replication so we can
		//		respond to hit through the normal hit FX chain.
		if (InDamage <= 0)
		{
			AddHitFX(InDamage, InstigatedBy, GetHitZoneIndex(HitInfo.BoneName), HitLocation, Momentum, class<KFDamageType>(DamageType));
		}
	}

	if (KFPlayerController_WeeklySurvival(Controller) != none)
	{
		KFPlayerController_WeeklySurvival(Controller).AdjustVIPDamage(InDamage, InstigatedBy);
	}	
	else if (KFPlayerController_WeeklySurvival(InstigatedBy) != none)
	{
		KFPlayerController_WeeklySurvival(InstigatedBy).AdjustVIPDamage(InDamage, InstigatedBy);
	}

	if( bHasSacrificeSkill && Health >= 5 && Health - InDamage < 5 )
	{
		Health = InDamage + 5;
		SacrificeExplode();
	}

	// register damage to divide up score
	if( InstigatedBy != none )
	{
		AddTakenDamage( InstigatedBy, FMin(Health, InDamage), DamageCauser, class<KFDamageType>(DamageType) );
	// `log("ExtHumanPawn.AdjustDamage() adjusted InDamage="$InDamage$", ArmorInt="$ArmorInt);
	}


	// (Cheats) Dont allow dying if demigod mode is enabled
`if(`__TW_SDK_)
	if ( Controller != none &&  Controller.bDemiGodMode && InDamage >= Health )
	{
		// Increase your health when you are going to get killed... so the amount of damage in semigod is not always just 1...
		// Some ais do different reactions depending on the amount of damaged caused in the last x seconds...
		if ( Health == 1 )
		{
			Health = HealthMax * 0.25f;
		}
		if( InDamage >= Health )
		{
			InDamage = Health - 1;
		}
	}
`endif

	if (KFPlayerController_WeeklySurvival(Controller) != none)
	{
		KFPlayerController_WeeklySurvival(Controller).UpdateVIPDamage();
	}

	// parry projectile damage the the pawn can

	ProjectileCauser = Projectile(DamageCauser);
	if (bCanParryProj && ProjectileCauser != None) 
	{
		`log("ExtHumanPawn.AdjustDamage() DamageType=" @ DamageType);
		if (ParryProjectile(ProjectileCauser))
		{
			InDamage = 0;
			Momentum.Y = 0;
			Momentum.Z = 0;
		}
	}
}

function bool ParryProjectile(Projectile ProjCauser)
{
	local ExtPerkManager ExtPM;
	local Ext_PerkBerserker BerserkerPerk;
	local KFWeap_MeleeBase MeleeWeap;
	local float FacingDot;
	local vector Dir2d;

	ExtPM = ExtPerkManager(GetPerk());
	if (ExtPM == None)
	{
		// `log("ExtHumanPawn.ParryProjectile() ExtPM == None");
		return false;
	}

	BerserkerPerk = Ext_PerkBerserker(ExtPM.CurrentPerk);
	if (BerserkerPerk == None)
	{
		// `log("ExtHumanPawn.ParryProjectile() BerserkerPerk == None");
		return false;
	}

	if (BerserkerPerk.bIsParryCoolingDown)
		return false;

	MeleeWeap = KFWeap_MeleeBase(MyKFWeapon);
	if (MeleeWeap != None && MeleeWeap.IsInState('MeleeBlocking'))
	{
		if (ProjCauser.Instigator != None)
		{
			Dir2d = Normal2d(ProjCauser.Instigator.Location - ProjCauser.Location);
		}
		else
		{
			Dir2d = Normal2d(ProjCauser.Location - Location);
		}
		FacingDot = vector(Rotation) dot Dir2d;

		if (FacingDot > 0.087f && !IsSameTeam(ProjCauser.Instigator))
		{
			
			if (MeleeWeap.IsTimerActive('ParryCheckTimer'))
			{
				// `log("ExtHumanPawn.AdjustDamage() blocked projectile!");
				
				// ExtPM.SetSuccessfullBlock();
				// BerserkerPerk.TriggerParryExplosion(DamageCauser.Instigator, false);
				BerserkerPerk.TriggerTraitParry(ProjCauser.Instigator);
				
				if (bCanReflectProj)
					ReflectProj(ProjCauser);

				return true;
			}
		}
	}
	
	return false;
}

function ReflectProj(Projectile Proj)
{
	local Projectile RefProj;
	local vector ReflectDir;
	local KFProjectile KFRefProj;
	local vector SpawnLocation;

	ReflectDir = Proj.Instigator.Location - Proj.Location;
	Proj.Destroy();

	RefProj = Spawn(Proj.class, Weapon, , self.Location, rotator(ReflectDir),, true);
	if (RefProj != None)
	{
		// Initialize the projectile with proper direction
		RefProj.Init(ReflectDir);
		
		// Ensure proper multiplayer replication and collision
		KFRefProj = KFProjectile(RefProj);
		if (KFRefProj != None)
		{
			SpawnLocation = self.Location + (ReflectDir * 3.0);
			// Set OriginalLocation for client-side position sync
			KFRefProj.OriginalLocation = SpawnLocation;
			
			// Force synchronization of visual mesh with physical location
			KFRefProj.SyncOriginalLocation();
			
			// Ensure projectile can collide with all actors including zombies
			KFRefProj.bBlockedByInstigator = true;
		}
		
		`log("ExtHumanPawn.ReflectProj() RefProj.Velocity="$RefProj.Velocity$" Proj.Velocity="$Proj.Velocity);
	}
}

/***
End of armor related functions
 */

simulated function bool Died(Controller Killer, class<DamageType> damageType, vector HitLocation)
{
	local ExtPlayerController C;
	local class<Pawn> KillerPawn;
	local PlayerReplicationInfo KillerPRI;
	local SeqAct_Latent Action;

	if (WorldInfo.NetMode!=NM_Client && PlayerReplicationInfo!=None)
	{
		if (Killer==None || Killer==Controller)
		{
			KillerPRI = PlayerReplicationInfo;
			KillerPawn = None;
		}
		else
		{
			KillerPRI = Killer.PlayerReplicationInfo;
			if (KillerPRI==None || KillerPRI.Team!=PlayerReplicationInfo.Team)
			{
				KillerPawn = Killer.Pawn!=None ? Killer.Pawn.Class : None;
				if (PlayerController(Killer)==None) // If was killed by a monster, don't broadcast PRI along with it.
					KillerPRI = None;
			}
			else KillerPawn = None;
		}
		foreach WorldInfo.AllControllers(class'ExtPlayerController',C)
			C.ClientKillMessage(damageType,PlayerReplicationInfo,KillerPRI,KillerPawn);
	}
	// If got killed by a zombie, turn player into a ragdoll and let em take control of a newly spawned ZED over the ragdoll.
	if (bRedeadMode && WorldInfo.NetMode!=NM_Client && damageType!=None && Killer!=None && Killer!=Controller && Killer.GetTeamNum()!=0)
	{
		if (bDeleteMe || WorldInfo.Game == None || WorldInfo.Game.bLevelChange)
			return FALSE;
		bPendingRedead = true;
		if (WorldInfo.Game.PreventDeath(self, Killer, damageType, HitLocation))
		{
			bPendingRedead = false;
			Health = max(Health, 1);
			return false;
		}
		Health = 0;
		foreach LatentActions(Action)
			Action.Abortfor (self);
		if (Controller != None)
			WorldInfo.Game.Killed(Killer, Controller, self, damageType);
		else WorldInfo.Game.Killed(Killer, Controller(Owner), self, damageType);

		if (InvManager != None)
			InvManager.OwnerDied();

		Health = 1;
		if (!bFeigningDeath)
			PlayFeignDeath(true,,true);
		Health = 0;
		ClearTimer('UnsetFeignDeath');
		GoToState('TransformZed');
		return true;
	}
	return Super.Died(Killer, DamageType, HitLocation);
}

simulated function BroadcastDeathMessage(Controller Killer);

simulated event NotifyOutOfBattery(){ return; }

function SetBatteryRate(float Rate)
{
	BatteryDrainRate = 0.0;
	NVGBatteryDrainRate = 0.0;
	ClientSetBatteryRate(0.0);
}

simulated reliable client function ClientSetBatteryRate(float Rate)
{
	BatteryDrainRate = Default.BatteryDrainRate*Rate;
	NVGBatteryDrainRate = Default.NVGBatteryDrainRate*Rate;
}

event bool HealDamage(int Amount, Controller Healer, class<DamageType> DamageType, optional bool bCanRepairArmor=true, optional bool bMessageHealer=true)
{
	local int DoshEarned,UsedHealAmount;
	local float ScAmount;
	local KFPlayerReplicationInfo InstigatorPRI;
	local ExtPlayerController InstigatorPC, KFPC;
	local KFPerk InstigatorPerk;
	local class<KFDamageType> KFDT;
	local int i;
	local bool bRepairedArmor;
	local ExtPlayerReplicationInfo EPRI;
	local Ext_PerkBase InstigatorExtPerk;

	InstigatorPC = ExtPlayerController(Healer);
	InstigatorPerk = InstigatorPC.GetPerk();

	if (InstigatorPerk != None && bCanRepairArmor)
		bRepairedArmor = InstigatorPC.GetPerk().RepairArmor(self);

	EPRI = ExtPlayerReplicationInfo(InstigatorPC.PlayerReplicationInfo);
	if (EPRI != none)
	{
		InstigatorExtPerk = ExtPlayerController(Controller).ActivePerkManager.CurrentPerk;
		if (InstigatorExtPerk != none && Ext_PerkFieldMedic(InstigatorExtPerk) != none)
		{
			if (Ext_PerkFieldMedic(InstigatorExtPerk).bHealingBoost)
				UpdateHealingSpeedBoostMod(InstigatorPC);

			if (Ext_PerkFieldMedic(InstigatorExtPerk).bHealingDamageBoost)
				UpdateHealingDamageBoostMod(InstigatorPC);

			if (Ext_PerkFieldMedic(InstigatorExtPerk).bHealingShield)
				UpdateHealingShieldMod(InstigatorPC);
		}
	}

	if (Amount > 0 && IsAliveAndWell() && Health < HealthMax)
	{
		// Play any healing effects attached to this damage type
		KFDT = class<KFDamageType>(DamageType);
		if (KFDT != none && KFDT.default.bNoPain)
			PlayHeal(KFDT);

		if (Role == ROLE_Authority)
		{
			if (Healer==None || Healer.PlayerReplicationInfo == None)
				return false;

			InstigatorPRI = KFPlayerReplicationInfo(Healer.PlayerReplicationInfo);
			ScAmount = Amount;
			if (InstigatorPerk != none)
				InstigatorPerk.ModifyHealAmount(ScAmount);
			UsedHealAmount = ScAmount;

			// You can never have a HealthToRegen value that's greater than HealthMax
			if (Health + HealthToRegen + UsedHealAmount > HealthMax)
				UsedHealAmount = Min(HealthMax - (Health + HealthToRegen),255-HealthToRegen);
			else UsedHealAmount = Min(UsedHealAmount,255-HealthToRegen);

			HealthToRegen += UsedHealAmount;
			RepRegenHP = HealthToRegen;
			if (!IsTimerActive('GiveHealthOverTime'))
				SetTimer(HealthRegenRate, true, 'GiveHealthOverTime');

			// Give the healer money/XP for helping a teammate
			if (Healer.Pawn != none && Healer.Pawn != self)
			{
				DoshEarned = (UsedHealAmount / float(HealthMax)) * HealerRewardScaler;
				if (InstigatorPRI!=None)
					InstigatorPRI.AddDosh(Max(DoshEarned, 0), true);
				if (InstigatorPC!=None)
					InstigatorPC.AddHealPoints(UsedHealAmount);
			}

			if (Healer.bIsPlayer)
			{
				if (Healer != Controller)
				{
					if (InstigatorPC!=None)
					{
						if (!InstigatorPC.bClientHideNumbers)
							InstigatorPC.ClientNumberMsg(UsedHealAmount,Location,DMG_Heal);
						InstigatorPC.ReceiveLocalizedMessage(class'KFLocalMessage_Game', GMT_HealedPlayer, PlayerReplicationInfo);
					}
					KFPC = ExtPlayerController(Controller);
					if (KFPC!=None)
						KFPC.ReceiveLocalizedMessage(class'KFLocalMessage_Game', GMT_HealedBy, Healer.PlayerReplicationInfo);
				}
				else if (bMessageHealer && InstigatorPC!=None)
					InstigatorPC.ReceiveLocalizedMessage(class'KFLocalMessage_Game', GMT_HealedSelf, PlayerReplicationInfo);
			}

			// don't play dialog for healing done through perk skills (e.g. berserker vampire skill)
			if (bMessageHealer)
			{
				`DialogManager.PlayHealingDialog(KFPawn(Healer.Pawn), self, float(Health + HealthToRegen) / float(HealthMax));
			}

			// Reduce burn duration and damage in half if you heal while burning
			for (i = 0; i < DamageOverTimeArray.Length; ++i)
			{
				if (DamageOverTimeArray[i].DoT_Type == DOT_Fire)
				{
					DamageOverTimeArray[i].Duration *= 0.5;
					DamageOverTimeArray[i].Damage *= 0.5;
					break;
				}
			}

			return true;
		}
	}

	return bRepairedArmor;
}

function GiveHealthOverTime()
{
	local KFPlayerReplicationInfo KFPRI;
	local int RegenAmt;

	if( HealthToRegen > 0 && Health < HealthMax )
	{
		RegenAmt = Min(HealthToRegen, HealthMax * 0.01);
		Health += RegenAmt;
		HealthToRegen -= RegenAmt;

        WorldInfo.Game.ScoreHeal(RegenAmt, Health - RegenAmt, Controller, self, none);

		KFPRI = KFPlayerReplicationInfo( PlayerReplicationInfo );
		if( KFPRI != none )
		{
			KFPRI.PlayerHealth = Health;
			KFPRI.PlayerHealthPercent = FloatToByte( float(Health) / float(HealthMax) );
		}

		if (KFPlayerController_WeeklySurvival(Controller) != none)
		{
			KFPlayerController_WeeklySurvival(Controller).UpdateVIPDamage();
		}
	}
	else
	{
		HealthToRegen = 0;
	 	ClearTimer( nameof( GiveHealthOverTime ) );
	}

	RepRegenHP = HealthToRegen;
}

simulated event ReplicatedEvent(name VarName)
{
	switch (VarName)
	{
	case 'bFeigningDeath':
		PlayFeignDeath(bFeigningDeath);
		break;
	case 'BackpackWeaponClass':
		SetBackpackWeapon(BackpackWeaponClass);
		break;
	case 'ArmorInt':
		NotifyArmorChanged();
		break;
	case 'QuantumShieldOwner':
		UpdateQuantumShieldFX();
		break;
	default:
		Super.ReplicatedEvent(VarName);
	}
}

// ==================================================================
// Feign death triggers:
function PlayHit(float Damage, Controller InstigatedBy, vector HitLocation, class<DamageType> damageType, vector Momentum, TraceHitInfo HitInfo)
{
	if (damageType!=class'DmgType_Fell') // Not from falling!
	{
		if (bRagdollFromMomentum && Damage>2 && VSizeSq(Momentum)>1000000.f && Rand(3)==0) // Square(1000)
			SetFeignDeath(3.f+FRand()*2.5f); // Randomly knockout a player if hit by a huge force.
		else if (bRagdollFromBackhit && Damage>20 && VSizeSq(Momentum)>40000.f && (vector(Rotation) Dot Momentum)>0.f && Rand(4)==0)
			SetFeignDeath(2.f+FRand()*3.f); // Randomly knockout a player if hit from behind.
	}
	Super.PlayHit(Damage,InstigatedBy,HitLocation,damageType,Momentum,HitInfo);
}

event Landed(vector HitNormal, actor FloorActor)
{
	local float ExcessSpeed;

	Super.Landed(HitNormal, FloorActor);
	if (bRagdollFromFalling)
	{
		ExcessSpeed = Velocity.Z / (-MaxFallSpeed);
		if (ExcessSpeed>1.25) // Knockout a player after landed from too high.
		{
			Velocity.Z = 0; // Dont go clip through floor now...
			Velocity.X*=0.5;
			Velocity.Y*=0.5;
			SetFeignDeath((3.f+FRand())*ExcessSpeed);
		}
	}
	else if (BHopAccelSpeed>0)
		SetTimer((IsLocallyControlled() ? 0.17 : 1.f),false,'ResetBHopAccel'); // Replicating from client to server here because Server Tickrate may screw clients over from executing bunny hopping.
}

// ==================================================================
// Bunny hopping:
function bool DoJump(bool bUpdating)
{
	local float V;

	if (Super.DoJump(bUpdating))
	{
		// Accelerate if bunnyhopping.
		if (bHasBunnyHop && VSizeSq2D(Velocity)>Square(GroundSpeed*0.75))
		{
			if (BHopAccelSpeed<20)
			{
				if (BHopAccelSpeed==0)
					BHopSpeedMod = 1.f;

				if (BHopAccelSpeed<5)
					V = 1.15;
				else
				{
					V = 1.05;
					AirControl = 0.8;
				}
				BHopSpeedMod *= V;
				GroundSpeed *= V;
				SprintSpeed *= V;
				Velocity.X *= V;
				Velocity.Y *= V;
				++BHopAccelSpeed;
			}
			ClearTimer('ResetBHopAccel');
		}
		return true;
	}
	return false;
}

simulated function ResetBHopAccel(optional bool bSkipRep) // Set on Landed, or Tick if falling 2D speed is too low.
{
	if (BHopAccelSpeed>0)
	{
		BHopAccelSpeed = 0;
		AirControl = Default.AirControl;
		GroundSpeed /= BHopSpeedMod;
		UpdateGroundSpeed();
		if (WorldInfo.NetMode==NM_Client && !bSkipRep)
			NotifyHasStopped();
	}
}

function UpdateGroundSpeed()
{
	local KFInventoryManager InvM;
	local float HealthMod;

	if (Role < ROLE_Authority)
		return;

	InvM = KFInventoryManager(InvManager);
	HealthMod = (InvM != None) ? InvM.GetEncumbranceSpeedMod() : 1.f * (1.f - LowHealthSpeedPenalty);
	if (BHopAccelSpeed>0)
		HealthMod *= BHopSpeedMod;

	// First reset to default so multipliers do not stack
	GroundSpeed = default.GroundSpeed * HealthMod;
	// reset sprint too, because perk may want to scale it
	SprintSpeed = default.SprintSpeed * HealthMod;

	// Ask our perk to set the new ground speed based on weapon type
	if (GetPerk() != none)
	{
		GetPerk().ModifySpeed(GroundSpeed);
		GetPerk().ModifySpeed(SprintSpeed);
	}
}

simulated function NotifyArmorChanged()
{
	local ExtPerkManager PM;
	local Ext_PerkSWAT SwatPerk;
	local ExtPlayerController EPC;

	UpdateGroundSpeed();

	PM = ExtPerkManager(GetPerk());
	if (PM != None)
	{
		SwatPerk = Ext_PerkSWAT(PM.CurrentPerk);
		if (SwatPerk != None)
		{
			SwatPerk.UpdateFoFMods(self);
		}
	}

	if (bOwnsQuantumShield && ArmorInt <= 0)
	{
		EPC = ExtPlayerController(Controller);
		if (EPC != None)
		{
			EPC.OnQuantumShieldDstroyed();
		}
	}
}

reliable server function NotifyHasStopped()
{
	ResetBHopAccel(true);
}

// ==================================================================
// Feign death (UT3):
simulated function Tick(float Delta)
{
	Super.Tick(Delta);
	if (bPlayingFeignDeathRecovery)
	{
		// interpolate Controller yaw to our yaw so that we don't get our rotation snapped around when we get out of feign death
		Mesh.PhysicsWeight = FMax(Mesh.PhysicsWeight-(Delta*2.f),0.f);
		if (Mesh.PhysicsWeight<=0)
			StartFeignDeathRecoveryAnim();
	}
	if (BHopAccelSpeed>0)
	{
		if (Physics==PHYS_Falling && VSizeSq2D(Velocity)<Square(GroundSpeed*0.7))
			ResetBHopAccel(true);
	}
	if (WorldInfo.NetMode!=NM_Client && BackpackWeaponClass!=none && (PlayerOldWeapon==None || PlayerOldWeapon.Instigator==None))
	{
		PlayerOldWeapon = None;
		SetBackpackWeapon(None);
	}
}

function DelayedRagdoll()
{
	SetFeignDeath(2.f+FRand()*3.f);
}

exec function FeignDeath(float Time)
{
	SetFeignDeath(Time);
}

function SetFeignDeath(float Time)
{
	if (WorldInfo.NetMode!=NM_Client && !bFeigningDeath && Health>0 && bCanBecomeRagdoll && NoRagdollChance<1.f && (NoRagdollChance==0.f || FRand()>NoRagdollChance))
	{
		Time = FMax(1.f,Time);
		PlayFeignDeath(true);
		SetTimer(Time,false,'UnsetFeignDeath');
	}
}

function UnsetFeignDeath()
{
	if (bFeigningDeath)
		PlayFeignDeath(false);
}

simulated function PlayFeignDeath(bool bEnable, optional bool bForce, optional bool bTransformMode)
{
	local vector FeignLocation, HitLocation, HitNormal, TraceEnd, Impulse;
	local rotator NewRotation;
	local float UnFeignZAdjust;

	if (Health<=0 && WorldInfo.NetMode!=NM_Client)
		return; // If dead, don't do it.

	NotifyOutOfBattery(); // Stop nightvision on client.

	bFeigningDeath = bEnable;
	if (bEnable)
	{
		if (bFPLegsAttached)
		{
			bFPLegsAttached = false;
			DetachComponent(FPBodyMesh);
		}
		WeaponAttachmentTemplate = None;
		WeaponAttachmentChanged();

		bPlayingFeignDeathRecovery = false;
		ClearTimer('OnWakeUpFinished');
		if (!bTransformMode)
			GotoState('FeigningDeath');

		// if we had some other rigid body thing going on, cancel it
		if (Physics == PHYS_RigidBody)
		{
			//@note: Falling instead of None so Velocity/Acceleration don't get cleared
			setPhysics(PHYS_Falling);
		}

		PrepareRagdoll();

		SetPawnRBChannels(TRUE);
		Mesh.ForceSkelUpdate();

		// Move into post so that we are hitting physics from last frame, rather than animated from this
		SetTickGroup(TG_PostAsyncWork);

		// Turn collision on for skelmeshcomp and off for cylinder
		CylinderComponent.SetActorCollision(false, false);
		Mesh.SetActorCollision(true, true);
		Mesh.SetTraceBlocking(true, true);

		Mesh.SetHasPhysicsAssetInstance(false);

		if (!InitRagdoll()) // Ragdoll error!
		{
			if (PlayerController(Controller)!=None)
				PlayerController(Controller).ClientMessage("Error: InitRagdoll() failed!");
			return;
		}

		// Ensure we are always updating kinematic
		Mesh.MinDistFactorForKinematicUpdate = 0.0;

		Mesh.bUpdateKinematicBonesFromAnimation=FALSE;

		// Set all kinematic bodies to the current root velocity, since they may not have been updated during normal animation
		// and therefore have zero derived velocity (this happens in 1st person camera mode).
		UnFeignZAdjust = VSize(Velocity);
		if (UnFeignZAdjust>700.f) // Limit by a maximum velocity force to prevent from going through walls.
			Mesh.SetRBLinearVelocity((Velocity/UnFeignZAdjust)*700.f, false);
		else Mesh.SetRBLinearVelocity(Velocity, false);

		// reset mesh translation since adjustment code isn't executed on the server
		// but the ragdoll code uses the translation so we need them to match up for the
		// most accurate simulation
		Mesh.SetTranslation(vect(0,0,1) * BaseTranslationOffset);
		// we'll use the rigid body collision to check for falling damage
		Mesh.ScriptRigidBodyCollisionThreshold = MaxFallSpeed;
		Mesh.SetNotifyRigidBodyCollision(true);
	}
	else
	{
		// fit cylinder collision into location, crouching if necessary
		FeignLocation = Location;
		CollisionComponent = CylinderComponent;
		TraceEnd = Location + vect(0,0,1) * GetCollisionHeight();
		if (Trace(HitLocation, HitNormal, TraceEnd, Location, true, GetCollisionExtent()) == None)
		{
			HitLocation = TraceEnd;
		}
		if (!SetFeignEndLocation(HitLocation, FeignLocation) && WorldInfo.NetMode!=NM_Client)
		{
			UnfeignFailedCount++;
			if (UnFeignfailedCount > 4 || bForce)
			{
				SetLocation(PickNearestNode()); // Just teleport to nearest pathnode.
			}
			else
			{
				CollisionComponent = Mesh;
				SetLocation(FeignLocation);
				bFeigningDeath = true;
				Impulse = VRand();
				Impulse.Z = 0.5;
				Mesh.AddImpulse(800.0*Impulse, Location);
				SetTimer(1.f,false,'UnsetFeignDeath');
				return;
			}
		}

		PreRagdollCollisionComponent = None;

		// Calculate how far we just moved the actor up.
		UnFeignZAdjust = Location.Z - FeignLocation.Z;
		// If its positive, move back down by that amount until it hits the floor
		if (UnFeignZAdjust > 0.0)
		{
			moveSmooth(vect(0,0,-1) * UnFeignZAdjust);
		}

		UnfeignFailedCount = 0;

		bPlayingFeignDeathRecovery = true;

		// Reset collision.
		Mesh.SetActorCollision(true, false);
		Mesh.SetTraceBlocking(true, false);

		SetTickGroup(TG_PreAsyncWork);

		// don't need collision events anymore
		Mesh.SetNotifyRigidBodyCollision(false);

		// don't allow player to move while animation is in progress
		SetPhysics(PHYS_None);

		// physics weight interpolated to 0 in C++, then StartFeignDeathRecoveryAnim() is called
		Mesh.PhysicsWeight = 1.0;

		// force rotation to match the body's direction so the blend to the getup animation looks more natural
		NewRotation = Rotation;
		NewRotation.Yaw = rotator(Mesh.GetBoneAxis(HeadBoneName, AXIS_X)).Yaw;
		// flip it around if the head is facing upwards, since the animation for that makes the character
		// end up facing in the opposite direction that its body is pointing on the ground
		// FIXME: generalize this somehow (stick it in the AnimNode, I guess...)
		if (Mesh.GetBoneAxis(HeadBoneName, AXIS_Y).Z < 0.0)
		{
			NewRotation.Yaw += 32768;
			FeignRecoverAnim = 'Getup_B_V1';
		}
		else FeignRecoverAnim = 'Getup_F_V1';

		// Init wakeup anim.
		if (Mesh.AnimSets.Find(WakeUpAnimSet)==-1)
			Mesh.AnimSets.AddItem(WakeUpAnimSet);
		BodyStanceNodes[EAS_FullBody].bNoNotifies = true;
		BodyStanceNodes[EAS_FullBody].PlayCustomAnim(FeignRecoverAnim,0.025f,,,,true);

		SetRotation(NewRotation);
	}
}

final function vector PickNearestNode()
{
	local NavigationPoint N,Best;
	local float Dist,BestDist;

	foreach WorldInfo.AllNavigationPoints(class'NavigationPoint',N)
	{
		Dist = VSizeSq(N.Location-Location);
		if (Best==None || Dist<BestDist)
		{
			Best = N;
			BestDist = Dist;
		}
	}
	return (Best!=None ? Best.Location : Location);
}

simulated function bool SetFeignEndLocation(vector HitLocation, vector FeignLocation)
{
	local vector NewDest;

	if (SetLocation(HitLocation) && CheckValidLocation(FeignLocation))
	{
		return true;
	}

	// try crouching
	ForceCrouch();
	if (SetLocation(HitLocation) && CheckValidLocation(FeignLocation))
	{
		return true;
	}

	newdest = HitLocation + GetCollisionRadius() * vect(1,1,0);
	if (SetLocation(newdest) && CheckValidLocation(FeignLocation))
		return true;
	newdest = HitLocation + GetCollisionRadius() * vect(1,-1,0);
	if (SetLocation(newdest) && CheckValidLocation(FeignLocation))
		return true;
	newdest = HitLocation + GetCollisionRadius() * vect(-1,1,0);
	if (SetLocation(newdest) && CheckValidLocation(FeignLocation))
		return true;
	newdest = HitLocation + GetCollisionRadius() * vect(-1,-1,0);
	if (SetLocation(newdest) && CheckValidLocation(FeignLocation))
		return true;

	return false;
}

simulated function bool CheckValidLocation(vector FeignLocation)
{
	local vector HitLocation, HitNormal, DestFinalZ;

	// try trace down to dest
	if (Trace(HitLocation, HitNormal, Location, FeignLocation, false, vect(10,10,10),, TRACEFLAG_Bullet) == None)
	{
		return true;
	}

	// try trace straight up, then sideways to final location
	DestFinalZ = FeignLocation;
	FeignLocation.Z = Location.Z;
	if (Trace(HitLocation, HitNormal, DestFinalZ, FeignLocation, false, vect(10,10,10)) == None &&
		Trace(HitLocation, HitNormal, Location, DestFinalZ, false, vect(10,10,10),, TRACEFLAG_Bullet) == None)
	{
		return true;
	}
	return false;
}

simulated function SetPawnRBChannels(bool bRagdollMode)
{
	if (bRagdollMode)
	{
		Mesh.SetRBChannel(RBCC_DeadPawn);
		Mesh.SetRBCollidesWithChannel(RBCC_Default,TRUE);
		Mesh.SetRBCollidesWithChannel(RBCC_Pawn,FALSE);
		Mesh.SetRBCollidesWithChannel(RBCC_Vehicle,TRUE);
		Mesh.SetRBCollidesWithChannel(RBCC_Untitled3,FALSE);
		Mesh.SetRBCollidesWithChannel(RBCC_BlockingVolume,TRUE);
		Mesh.SetRBCollidesWithChannel(RBCC_DeadPawn, false);
	}
	else
	{
		Mesh.SetRBChannel(RBCC_Pawn);
		Mesh.SetRBCollidesWithChannel(RBCC_Default,FALSE);
		Mesh.SetRBCollidesWithChannel(RBCC_Pawn,FALSE);
		Mesh.SetRBCollidesWithChannel(RBCC_Vehicle,FALSE);
		Mesh.SetRBCollidesWithChannel(RBCC_Untitled3,TRUE);
		Mesh.SetRBCollidesWithChannel(RBCC_BlockingVolume,FALSE);
	}
}

simulated function PlayRagdollDeath(class<DamageType> DamageType, vector HitLoc)
{
	local TraceHitInfo HitInfo;
	local vector HitDirection;

	Mesh.SetHasPhysicsAssetInstance(false);
	Mesh.SetHasPhysicsAssetInstance(true);
	if (bFPLegsAttached)
	{
		bFPLegsAttached = false;
		DetachComponent(FPBodyMesh);
	}

	// Ensure we are always updating kinematic
	Mesh.MinDistFactorForKinematicUpdate = 0.0;

	PrepareRagdoll();

	if (InitRagdoll())
	{
		// Switch to a good RigidBody TickGroup to fix projectiles passing through the mesh
		// https://udn.unrealengine.com/questions/190581/projectile-touch-not-called.html
		//Mesh.SetTickGroup(TG_PostAsyncWork);
		SetTickGroup(TG_PostAsyncWork);

		// Allow all ragdoll bodies to collide with all physics objects (ie allow collision with things marked RigidBodyIgnorePawns)
		SetPawnRBChannels(true);

		// Call CheckHitInfo to give us a valid BoneName
		HitDirection = Normal(TearOffMomentum);
		CheckHitInfo(HitInfo, Mesh, HitDirection, HitLoc);

		// Play ragdoll death animation (bSkipReplication=TRUE)
		if (CanDoSpecialMove(SM_DeathAnim) && ClassIsChildOf(DamageType, class'KFDamageType'))
		{
			DoSpecialMove(SM_DeathAnim, TRUE,,,TRUE);
			KFSM_DeathAnim(SpecialMoves[SM_DeathAnim]).PlayDeathAnimation(DamageType, HitDirection, HitInfo.BoneName);
		}
		else
		{
			StopAllAnimations(); // stops non-RBbones from animating (fingers)
		}
	}
}

simulated function StartFeignDeathRecoveryAnim()
{
	if (FPBodyMesh!=None && !bFPLegsAttached && bOnFirstPerson && Class'ExtPlayerController'.Default.bShowFPLegs)
	{
		bFPLegsAttached = true;
		AttachComponent(FPBodyMesh);
	}

	bPlayingFeignDeathRecovery = false;

	// we're done with the ragdoll, so get rid of it
	Mesh.PhysicsWeight = 0.f;
	Mesh.PhysicsAssetInstance.SetAllBodiesFixed(TRUE);
	Mesh.PhysicsAssetInstance.SetFullAnimWeightBonesFixed(FALSE, Mesh);
	SetPawnRBChannels(FALSE);
	Mesh.bUpdateKinematicBonesFromAnimation=TRUE;

	// Turn collision on for cylinder and off for skelmeshcomp
	CylinderComponent.SetActorCollision(true, true);

	BodyStanceNodes[EAS_FullBody].PlayCustomAnim(FeignRecoverAnim,1.2f,,,,true);
	SetTimer(1.7f,false,'OnWakeUpFinished');
}

function bool CanBeRedeemed()
{
	return true;
}

simulated function OnWakeUpFinished();

function AddDefaultInventory()
{
	local ExtPlayerController EPC;
	local KFPerk MyPerk;

	MyPerk = GetPerk();
	if (MyPerk != none)
		MyPerk.AddDefaultInventory(self);

	Super(KFPawn).AddDefaultInventory();

	EPC = ExtPlayerController(Controller);
	if (EPC != none)
	{
		EPC.ServerRecreateWeaponProperties();
		// ability counts
	}
	else
	{
		`log("ExtHumanAddDefaultInventory: EPC is none, cannot recreate weapon properties");
	}
}

simulated event FellOutOfWorld(class<DamageType> dmgType)
{
	if (Role==ROLE_Authority && NextRedeemTimer<WorldInfo.TimeSeconds) // Make sure to not to spam deathmessages while ghosting.
		Super.FellOutOfWorld(dmgType);
}

simulated event OutsideWorldBounds()
{
	if (Role==ROLE_Authority && NextRedeemTimer<WorldInfo.TimeSeconds)
		Super.OutsideWorldBounds();
}

simulated function KFCharacterInfoBase GetCharacterInfo()
{
	if (ExtPlayerReplicationInfo(PlayerReplicationInfo)!=None)
		return ExtPlayerReplicationInfo(PlayerReplicationInfo).GetSelectedArch();
	return Super.GetCharacterInfo();
}

simulated function SetCharacterArch(KFCharacterInfoBase Info, optional bool bForce)
{
	local KFPlayerReplicationInfo KFPRI;

	KFPRI = KFPlayerReplicationInfo(PlayerReplicationInfo);
	if (Info != CharacterArch || bForce)
	{
		// Set Family Info
		CharacterArch = Info;
		CharacterArch.SetCharacterFromArch(self, KFPRI);
		class'ExtCharacterInfo'.Static.SetCharacterMeshFromArch(KFCharacterInfo_Human(CharacterArch), self, KFPRI);
		class'ExtCharacterInfo'.Static.SetFirstPersonArmsFromArch(KFCharacterInfo_Human(CharacterArch), self, KFPRI);

		SetCharacterAnimationInfo();

		// Sounds
		SoundGroupArch = Info.SoundGroupArch;

		if (WorldInfo.NetMode != NM_DedicatedServer)
		{
			// refresh weapon attachment (attachment bone may have changed)
			if (WeaponAttachmentTemplate != None)
			{
				WeaponAttachmentChanged(true);
			}
		}
		if (WorldInfo.NetMode != NM_DedicatedServer)
		{
			// Attach/Reattach flashlight components when mesh is set
			if (Flashlight == None && FlashLightTemplate != None)
			{
				Flashlight = new(self) Class'KFFlashlightAttachment' (FlashLightTemplate);
			}
			if (FlashLight != None)
			{
				Flashlight.AttachFlashlight(Mesh);
			}
		}
		if (CharacterArch != none)
		{
			if (CharacterArch.VoiceGroupArchName != "")
				VoiceGroupArch = class<KFPawnVoiceGroup>(class'ExtCharacterInfo'.Static.SafeLoadObject(CharacterArch.VoiceGroupArchName, class'Class'));
		}
	}
}

simulated state FeigningDeath
{
ignores FaceRotation, SetMovementPhysics;

	function SetSprinting(bool bNewSprintStatus)
	{
		bIsSprinting = false;
	}
	simulated event RigidBodyCollision(PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent, const out CollisionImpactData RigidCollisionData, int ContactIndex)
	{
		// only check fall damage for Z axis collisions
		if (Abs(RigidCollisionData.ContactInfos[0].ContactNormal.Z) > 0.5)
		{
			Velocity = Mesh.GetRootBodyInstance().PreviousVelocity;
			TakeFallingDamage();
			// zero out the z velocity on the body now so that we don't get stacked collisions
			Velocity.Z = 0.0;
			Mesh.SetRBLinearVelocity(Velocity, false);
			Mesh.GetRootBodyInstance().PreviousVelocity = Velocity;
			Mesh.GetRootBodyInstance().Velocity = Velocity;
		}
	}
	simulated event bool CanDoSpecialMove(ESpecialMove AMove, optional bool bForceCheck)
	{
		return (bForceCheck ? Global.CanDoSpecialMove(AMove,bForceCheck) : false);
	}
	function bool CanBeGrabbed(KFPawn GrabbingPawn, optional bool bIgnoreFalling, optional bool bAllowSameTeamGrab)
	{
		return false;
	}
	simulated function OnWakeUpFinished()
	{
		if (Physics == PHYS_RigidBody)
			setPhysics(PHYS_Falling);
		Mesh.MinDistFactorForKinematicUpdate = default.Mesh.MinDistFactorForKinematicUpdate;
		GotoState('Auto');
	}

	event bool EncroachingOn(Actor Other)
	{
		// don't abort moves in ragdoll
		return false;
	}

	simulated function bool CanThrowWeapon()
	{
		return false;
	}

	simulated function Tick(float DeltaTime)
	{
		local rotator NewRotation;

		if (bPlayingFeignDeathRecovery)
		{
			if (PlayerController(Controller) != None)
			{
				// interpolate Controller yaw to our yaw so that we don't get our rotation snapped around when we get out of feign death
				NewRotation = Controller.Rotation;
				NewRotation.Yaw = RInterpTo(NewRotation, Rotation, DeltaTime, 2.0).Yaw;
				Controller.SetRotation(NewRotation);
			}
			Mesh.PhysicsWeight = FMax(Mesh.PhysicsWeight-(DeltaTime*2.f),0.f);
			if (Mesh.PhysicsWeight<=0)
				StartFeignDeathRecoveryAnim();
		}
	}

	simulated event BeginState(name PreviousStateName)
	{
		local KFWeapon UTWeap;

		// Abort current special move
		if (IsDoingSpecialMove())
			SpecialMoveHandler.EndSpecialMove();

		bCanPickupInventory = false;
		StopFiring();
		bNoWeaponFiring = true;

		UTWeap = KFWeapon(Weapon);
		if (UTWeap != None)
		{
			UTWeap.SetIronSights(false);
			UTWeap.PlayWeaponPutDown(0.5f);
		}
		if (WorldInfo.NetMode!=NM_Client)
		{
			if (ExtPlayerController(Controller)!=None)
				ExtPlayerController(Controller).EnterRagdollMode(true);
			else if (Controller!=None)
				Controller.ReplicatedEvent('RagdollMove');
		}
	}
	simulated function WeaponAttachmentChanged(optional bool bForceReattach)
	{
		// Keep weapon hidden!
		if (WeaponAttachment != None)
		{
			WeaponAttachment.DetachFrom(self);
			WeaponAttachment.Destroy();
			WeaponAttachment = None;
		}
	}
	function bool CanBeRedeemed()
	{
		if (bFeigningDeath)
			PlayFeignDeath(false,true);
		NextRedeemTimer = WorldInfo.TimeSeconds+0.25;
		return false;
	}
	simulated function EndState(name NextStateName)
	{
		local KFWeapon UTWeap;

		Mesh.AnimSets.RemoveItem(WakeUpAnimSet);
		BodyStanceNodes[EAS_FullBody].bNoNotifies = false;
		if (NextStateName != 'Dying')
		{
			bNoWeaponFiring = default.bNoWeaponFiring;
			bCanPickupInventory = default.bCanPickupInventory;

			UTWeap = KFWeapon(Weapon);
			if (UTWeap != None)
			{
				WeaponAttachmentTemplate = UTWeap.AttachmentArchetype;
				UTWeap.PlayWeaponEquip(0.5f);
			}

			Global.SetMovementPhysics();
			bPlayingFeignDeathRecovery = false;
			if (WorldInfo.NetMode!=NM_Client)
			{
				if (ExtPlayerController(Controller)!=None)
					ExtPlayerController(Controller).EnterRagdollMode(false);
				else if (Controller!=None)
					Controller.ReplicatedEvent('EndRagdollMove');
			}

			Global.WeaponAttachmentChanged();
		}
	}
}

// VS mode.
state TransformZed extends FeigningDeath
{
Ignores FaceRotation, SetMovementPhysics, UnsetFeignDeath, Tick, TakeDamage, Died;

	simulated event BeginState(name PreviousStateName)
	{
		bCanPickupInventory = false;
		bNoWeaponFiring = true;
		if (ExtPlayerController(Controller)!=None)
			ExtPlayerController(Controller).EnterRagdollMode(true);
		else if (Controller!=None)
			Controller.ReplicatedEvent('RagdollMove');

		SetTimer(2,false,'TransformToZed');
	}
	simulated function EndState(name NextStateName)
	{
	}
	function bool CanBeRedeemed()
	{
		return false;
	}
	function TransformToZed()
	{
		local VS_ZedRecentZed Z;

		if (Controller==None)
		{
			Destroy();
			return;
		}
		PlayFeignDeath(false);
		SetCollision(false,false);
		Z = Spawn(class'VS_ZedRecentZed',,,Location,Rotation,,true);
		if (Z==None)
		{
			Super.Died(None,Class'DamageType',Location);
			return;
		}
		else
		{
			Z.SetPhysics(PHYS_Falling);
			Z.LastStartTime = WorldInfo.TimeSeconds;
			Controller.Pawn = None;
			Controller.Possess(Z,false);
			WorldInfo.Game.ChangeTeam(Controller,255,true);
			WorldInfo.Game.SetPlayerDefaults(Z);
			if (ExtPlayerController(Controller)!=None)
				Controller.GoToState('RagdollMove');
			else if (Controller!=None)
				Controller.ReplicatedEvent('RagdollMove');
			Z.WakeUp();
			if (ExtPlayerReplicationInfo(Controller.PlayerReplicationInfo)!=None)
			{
				ExtPlayerReplicationInfo(Controller.PlayerReplicationInfo).PlayerHealth = Min(Z.Health,255);
				ExtPlayerReplicationInfo(Controller.PlayerReplicationInfo).PlayerHealthPercent = FloatToByte(float(Z.Health) / float(Z.HealthMax));
			}
		}
		Controller = None;
		Destroy();
	}
}

function AbsorbFallingDamage(out int ActualDamage, out int AbsorbedDamage)
{
	if (AirBagRate <= 0.0) 
	{
		AbsorbedDamage = 0;
		return;
	}

	AbsorbedDamage = Min(Round(float(ActualDamage) * AirBagRate), ArmorInt);
	ArmorInt -= AbsorbedDamage;
	ActualDamage -= AbsorbedDamage;
	NotifyArmorChanged();
}

function TakeFallingDamage()
{
	local float EffectiveSpeed;
	local int FallDmg;
	local ExtPerkManager PM;
	local Ext_PerkBerserker ZerkerPerk;
	local int AbsorbedDamage;

	PM = ExtPerkManager(GetPerk());
	if (PM == none) return;

	ZerkerPerk = Ext_PerkBerserker(PM.CurrentPerk);
	if (ZerkerPerk == none) 
	{
		super.TakeFallingDamage();
		return;
	}

	// bombzerker
	if (Velocity.Z < -0.5 * MaxFallSpeed)
	{
		if ( Role == ROLE_Authority )
		{
			MakeNoise(1.0);
			if (Velocity.Z < -1 * MaxFallSpeed)
			{
				EffectiveSpeed = Velocity.Z;
				if (TouchingWaterVolume())
				{
					EffectiveSpeed += 100;
				}
				if (EffectiveSpeed < -1 * MaxFallSpeed)
				{
					FallDmg = -100 * (EffectiveSpeed + MaxFallSpeed) / MaxFallSpeed;
					// `log("TakeFallingDamage(): FallDmg before = " @ FallDmg);
					FallDmg *= ZerkerPerk.FallDamageScale;
					`log("TakeFallingDamage(): FallDmg = " @ FallDmg);

					AbsorbFallingDamage(FallDmg, AbsorbedDamage);

					if (ZerkerPerk.bIsAtomic)
					{
						// `log("TakeFallingDamage(): Is Atomic");
						FallDmg = Min(self.Health - 1, FallDmg);
					}
					// `log("TakeFallingDamage(): FallDmg after = " @ FallDmg);

					TakeDamage(FallDmg, None, Location, vect(0,0,0), class'KFDT_Falling');

					if (PM != None && ZerkerPerk != None)
					{
						ZerkerPerk.TriggerFallExplosion(FallDmg + AbsorbedDamage);
					}
				}
			}
		}
	}
	else if (Velocity.Z < -1.4 * JumpZ)
		MakeNoise(0.5);
	else if ( Velocity.Z < -0.8 * JumpZ )
		MakeNoise(0.2);
}

simulated final function InitFPLegs()
{
	local int i;

	bFPLegsInit = true;

	FPBodyMesh.AnimSets = CharacterArch.AnimSets;
	FPBodyMesh.SetAnimTreeTemplate(CharacterArch.AnimTreeTemplate);
	FPBodyMesh.SetSkeletalMesh(Mesh.SkeletalMesh);

	FPBodyMesh.SetActorCollision(false, false);
	FPBodyMesh.SetNotifyRigidBodyCollision(false);
	FPBodyMesh.SetTraceBlocking(false, false);

	for (i=0; i<Mesh.Materials.length; i++)
		FPBodyMesh.SetMaterial(i, Mesh.Materials[i]);

	FPBodyMesh.HideBoneByName('neck', PBO_None);
	FPBodyMesh.HideBoneByName('Spine2', PBO_None);
	FPBodyMesh.HideBoneByName('RightShoulder', PBO_None);
	FPBodyMesh.HideBoneByName('LeftShoulder', PBO_None);
}

// ForrestMarkX's third person backpack weapon and first person legs:
simulated function SetMeshVisibility(bool bVisible)
{
	Super.SetMeshVisibility(bVisible);

	if (Health>0)
	{
		bOnFirstPerson = !bVisible;
		if (AttachedBackItem!=None)
			AttachedBackItem.SetHidden(bOnFirstPerson);
		UpdateFPLegs();
	}
}

simulated final function UpdateFPLegs()
{
	if (FPBodyMesh!=None)
	{
		if (!bFPLegsAttached && Physics!=PHYS_RigidBody && bOnFirstPerson && Class'ExtPlayerController'.Default.bShowFPLegs)
		{
			bFPLegsAttached = true;
			AttachComponent(FPBodyMesh);

			if (!bFPLegsInit && CharacterArch!=None)
				InitFPLegs();
		}
		FPBodyMesh.SetHidden(!bOnFirstPerson || !Class'ExtPlayerController'.Default.bShowFPLegs);
	}
}

simulated event PostInitAnimTree(SkeletalMeshComponent SkelComp)
{
	if (SkelComp==Mesh) // Do not allow first person legs eat up animation slots.
		Super.PostInitAnimTree(SkelComp);
}

simulated final function SetBackpackWeapon(class<KFWeapon> WC)
{
	local KFCharacterInfo_Human MyCharacter;
	local Rotator MyRot;
	local Vector MyPos;
	local name WM,B;
	local int i;

	BackpackWeaponClass = WC;
	if (WorldInfo.NetMode==NM_DedicatedServer)
		return;

	if (WC!=None)
	{
		if (AttachedBackItem==None)
		{
			AttachedBackItem = new(Self) class'SkeletalMeshComponent';
			AttachedBackItem.SetHidden(false);
			AttachedBackItem.SetLightingChannels(PawnLightingChannel);
		}
		AttachedBackItem.SetSkeletalMesh(WC.Default.AttachmentArchetype.SkelMesh);
		for (i=0; i<WC.Default.AttachmentArchetype.SkelMesh.Materials.length; i++)
		{
			AttachedBackItem.SetMaterial(i, WC.Default.AttachmentArchetype.SkelMesh.Materials[i]);
		}

		Mesh.DetachComponent(AttachedBackItem);

		MyCharacter = KFPlayerReplicationInfo(PlayerReplicationInfo).CharacterArchetypes[KFPlayerReplicationInfo(PlayerReplicationInfo).RepCustomizationInfo.CharacterIndex];
		WM = WC.Default.AttachmentArchetype.SkelMesh.Name;

		if (ClassIsChildOf(WC, class'KFWeap_Edged_Knife'))
		{
			MyPos = vect(0,0,10);
			MyRot = rot(-16384,-8192,0);
			B = 'LeftUpLeg';
		}
		else if (class<KFWeap_Welder>(WC) != none || class<KFWeap_Healer_Syringe>(WC) != none || class<KFWeap_Pistol_Medic>(WC) != none || class<KFWeap_SMG_Medic>(WC) != none || ClassIsChildOf(WC, class'KFWeap_PistolBase') || ClassIsChildOf(WC, class'KFWeap_SMGBase') || ClassIsChildOf(WC, class'KFWeap_ThrownBase'))
		{
			MyPos = vect(0,0,10);
			MyRot = rot(0,0,16384);

			B = 'LeftUpLeg';
		}
		else if (ClassIsChildOf(WC, class'KFWeap_MeleeBase'))
		{
			MyPos = vect(-5,15,0);
			MyRot = rot(0,0,0);

			if (class<KFWeap_Edged_Katana>(WC) != none || class<KFWeap_Edged_Zweihander>(WC) != none)
				MyPos.Z = -20;

			B = 'Spine';
		}
		else
		{
			MyPos = vect(-18.5,16.5,-18);
			MyRot = rot(0,0,0);

			if (MyCharacter == KFCharacterInfo_Human'CHR_Playable_ARCH.chr_DJSkully_archetype')
				MyRot.Roll = 8192;

			switch (WM)
			{
			case 'Wep_3rdP_MB500_Rig':
				MyPos.X = -45;
				break;
			case 'Wep_3rdP_M4Shotgun_Rig':
				MyPos.X = -25;
				break;
			case 'Wep_3rdP_SawBlade_Rig':
				MyPos.X = -75;
				MyRot.Roll = 16384;
				break;
			case 'Wep_3rdP_RPG7_Rig':
				MyPos.X = 10;
				break;
			}

			B = 'Spine2';
		}

		AttachedBackItem.SetTranslation(MyPos);
		AttachedBackItem.SetRotation(MyRot);
		Mesh.AttachComponent(AttachedBackItem, B);
		AttachedBackItem.SetHidden(bOnFirstPerson);
	}
	else if (AttachedBackItem!=None)
		AttachedBackItem.SetHidden(true);
}

simulated function PlayDying(class<DamageType> DamageType, vector HitLoc)
{
	FPBodyMesh.SetHidden(true);
	if (AttachedBackItem!=None)
		AttachedBackItem.SetHidden(true);
	Super.PlayDying(DamageType,HitLoc);
}

simulated function SetCharacterAnimationInfo()
{
	Super.SetCharacterAnimationInfo();

	if (!bFPLegsInit && bFPLegsAttached)
		InitFPLegs();
}

simulated function SetMeshLightingChannels(LightingChannelContainer NewLightingChannels)
{
	Super.SetMeshLightingChannels(NewLightingChannels);

	if (AttachedBackItem != none)
		AttachedBackItem.SetLightingChannels(NewLightingChannels);
	FPBodyMesh.SetLightingChannels(NewLightingChannels);
}

simulated function PlayWeaponswitch (Weapon OldWeapon, Weapon NewWeapon)
{
	Super.PlayWeaponswitch (OldWeapon, NewWeapon);

	if (WorldInfo.NetMode!=NM_Client)
	{
		PlayerOldWeapon = KFWeapon(OldWeapon);
		SetBackpackWeapon(PlayerOldWeapon!=None ? PlayerOldWeapon.Class : None);
	}
}

simulated function UpdateHealingSpeedBoostMod(ExtPlayerController Healer)
{
	local Ext_PerkFieldMedic MedPerk;

	MedPerk = GetMedicPerk(Healer);
	if (MedPerk == None)
		return;

	HealingSpeedBoostMod = Min(HealingSpeedBoostMod + MedPerk.GetHealingSpeedBoost(), MedPerk.GetMaxHealingSpeedBoost());
	SetTimer(MedPerk.GetHealingSpeedBoostDuration(),, nameOf(ResetHealingSpeedBoost));

	UpdateGroundSpeed();
}

simulated function float GetHealingSpeedModifier()
{
	return 1 + (float(HealingSpeedBoostMod) / 100);
}

simulated function ResetHealingSpeedBoost()
{
	HealingSpeedBoostMod = 0;
	UpdateGroundSpeed();

	if (IsTimerActive(nameOf(ResetHealingSpeedBoost)))
		ClearTimer(nameOf(ResetHealingSpeedBoost));
}

simulated function UpdateHealingDamageBoostMod(ExtPlayerController Healer)
{
	local Ext_PerkFieldMedic MedPerk;

	MedPerk = GetMedicPerk(Healer);
	if (MedPerk == None)
		return;

	HealingDamageBoostMod = Min(HealingDamageBoostMod + MedPerk.GetHealingDamageBoost(), MedPerk.GetMaxHealingDamageBoost());
	SetTimer(MedPerk.GetHealingDamageBoostDuration(),, nameOf(ResetHealingDamageBoost));
}

simulated function float GetHealingDamageBoostModifier()
{
	return 1 + (float(HealingDamageBoostMod) / 100);
}

simulated function ResetHealingDamageBoost()
{
	HealingDamageBoostMod = 0;
	if (IsTimerActive(nameOf(ResetHealingDamageBoost)))
		ClearTimer(nameOf(ResetHealingDamageBoost));
}

simulated function UpdateHealingShieldMod(ExtPlayerController Healer)
{
	local Ext_PerkFieldMedic MedPerk;

	MedPerk = GetMedicPerk(Healer);
	if (MedPerk == None)
		return;

	HealingShieldMod = Min(HealingShieldMod + MedPerk.GetHealingShield(), MedPerk.GetMaxHealingShield());
	SetTimer(MedPerk.GetHealingShieldDuration(),, nameOf(ResetHealingShield));
}

simulated function float GetHealingShieldModifier()
{
	return 1 - (float(HealingShieldMod) / 100);
}

simulated function ResetHealingShield()
{
	HealingShieldMod = 0;
	if (IsTimerActive(nameOf(ResetHealingShield)))
		ClearTimer(nameOf(ResetHealingShield));
}

function SacrificeExplode()
{
	local Ext_PerkDemolition DemoPerk;

	Super.SacrificeExplode();

	DemoPerk = Ext_PerkDemolition(ExtPlayerController(Controller).ActivePerkManager.CurrentPerk);
	if (DemoPerk != none)
		DemoPerk.bUsedSacrifice = true;
}

simulated function Ext_PerkFieldMedic GetMedicPerk(ExtPlayerController Healer)
{
	local Ext_PerkFieldMedic MedPerk;

	MedPerk = Ext_PerkFieldMedic(ExtPlayerController(Controller).ActivePerkManager.CurrentPerk);
	if (MedPerk != None)
		return MedPerk;

	return None;
}

reliable client function ClientAbilityUpdated(int NewGauge, int NewCount)
{
    AbilityGauge = NewGauge;
    AbilityCount = NewCount;
	// `log("ClientAbilityUpdated(): AbilityGauge: " @ AbilityGauge @ " AbilityCount: " @ AbilityCount @ " MaxAbilityCount: " @ MaxAbilityCount);
}

// function SetAbilityDuration(float duration)
// {
// 	OnAbilityStart();
// 	ClearTimer(nameOf(OnAbilityEnd));
// 	SetTimer(Duration, false, nameOf(OnAbilityEnd));
// }

// function OnAbilityStart()
// {
// 	bIsUsingAbility = true;
// }

// function OnAbilityEnd()
// {
// 	bIsUsingAbility = false;
// }

function AddAbilityGauge(int AP)
{
	// if (bIsUsingAbility) return;

	AbilityGauge += AP;

	// assuming that AbilityGauge won't be >= 200
	if (AbilityGauge >= 100)
	{
		if (AbilityCount < MaxAbilityCount)
		{
			AbilityCount++;
			AbilityGauge -= 100;
		}
		else
		{
			AbilityGauge = 99;
		}
	}
	if (Role == ROLE_Authority)
    {
        ClientAbilityUpdated(AbilityGauge, AbilityCount);
    }
	// `log("AddAbilityGauge(): AbilityGauge: " @ AbilityGauge @ " AbilityCount: " @ AbilityCount @ " MaxAbilityCount: " @ MaxAbilityCount);
}

simulated function StartFire(byte FireModeNum)
{
	if (bIsUsingDenseRounds && FireModeNum == 0)
	{
		FireDenseRound();
		// return;
	}

    Super.StartFire(FireModeNum);
}

function MGRs_Reload()
{
	local KFWeapon KFW;
	local ExtPlayerReplicationInfo KFPRI;

	// if (AbilityCount <= 0) return;

	KFPRI = ExtPlayerReplicationInfo(PlayerReplicationInfo);
	if (KFPRI == None) return;
	if (KFPRI.Score < KFW.MagazineCapacity[0]) return;


	KFW = KFWeapon(Weapon);
	if (KFW == None) return;
	
	`log("MGRs_Reload() executing");
	KFW.GotoState('Reloading');
	KFW.SpareAmmoCount[0] += KFW.AmmoCount[0];
	KFW.AmmoCount[0] = KFW.MagazineCapacity[0];

	bIsUsingMGRs = true;
	MGRs_CurrentAmmo = KFW.MagazineCapacity[0];
	KFPRI.AddDosh(-MGRs_CurrentAmmo);
	MGRs_BaseDamage = KFW.InstantHitDamage[0];
	MGRs_BasePenetration = KFW.PenetrationPower[0];
	KFW.InstantHitDamage[0] *= MGRs_DamageMod;
	KFW.PenetrationPower[0] *= MGRs_PenetrationMod;

	AbilityCount--;
}

function ResetMGRs()
{
    local KFWeapon KFW;
    
    KFW = KFWeapon(Weapon);
    if (KFW == None) return;

	KFW.InstantHitDamage[0] = MGRs_BaseDamage;
	KFW.PenetrationPower[0] = MGRs_BasePenetration;
    
    bIsUsingMGRs = false;
    MGRs_CurrentAmmo = 0;
}

function ThrowActiveWeapon(optional bool bDestroyWeap)
{
	local KFWeapon TempWeapon;
	local ExtPlayerController EPC;

	// disabled since this causes too much trouble in the weapon upgrade system
	return;

	if( Role < ROLE_Authority )
	{
		return;
	}

	if (Health <= 0 && bThrowAllWeaponsOnDeath)
	{
		if (InvManager != none)
			foreach InvManager.InventoryActors(class'KFWeapon', TempWeapon)
				if (TempWeapon != none && TempWeapon.bDropOnDeath && TempWeapon.CanThrow())
					TossInventory(TempWeapon);
	}
	else
	{
		super.ThrowActiveWeapon(bDestroyWeap);
		// TODO Remove from InvProperties
		EPC = ExtPlayerController(Controller);
		if (EPC != none)
		{	
			TempWeapon = FindBestWeapon();
			EPC.DropWeapon(TempWeapon);
			TossInventory(TempWeapon);
		}
	}
}

simulated function UpdateQuantumShieldFX()
{
	local vector ColorVec, CoreColorVec;

	if (QuantumShieldOwner != None)
	{
		if (QuantumShieldPSC == None)
		{
			// QuantumShieldPSC = WorldInfo.MyEmitterPool.SpawnEmitterMeshAttachment(QuantumShieldFX, Mesh, 'Spine2', true);
			QuantumShieldPSC = WorldInfo.MyEmitterPool.SpawnEmitter(QuantumShieldFX, Location + vect(0,0,-20), Rotation, self);
			if (QuantumShieldPSC != None)
			{
				QuantumShieldPSC.SetAbsolute(false, true, true);
				QuantumShieldPSC.SetScale(0.5f);
				QuantumShieldPSC.SetOwnerNoSee(false);

				if (Mesh != None)
				{
					Mesh.bOverrideAttachmentOwnerVisibility = false;
				}
				
				// Setup cyan/blue colors for the quantum shield so it renders
				ColorVec.X = 0.4196f;
				ColorVec.Y = 1.0f;
				ColorVec.Z = 0.2941f;
				
				CoreColorVec.X = 0.0f;
				CoreColorVec.Y = 0.5f;
				CoreColorVec.Z = 1.0f;

				QuantumShieldPSC.SetVectorParameter('Shield_Color', ColorVec);
				QuantumShieldPSC.SetVectorParameter('Shield_CoreColor', CoreColorVec);
			}
		}
	}
	else
	{
		if (QuantumShieldPSC != None)
		{
			QuantumShieldPSC.DeactivateSystem();
			QuantumShieldPSC = None;
		}

		if (Mesh != None)
		{
			Mesh.bOverrideAttachmentOwnerVisibility = true;
		}
	}
}

simulated function ReceiveQuantumShield(ExtHumanPawn OwnerPawn, float Duration, int Mult)
{
	if (QuantumShieldOwner != None)
	{
		DeactivateQuantumShield();
	}

	QuantumShieldOwner = OwnerPawn;
	QuantumShieldMultiplier = Mult;
	bForceNetUpdate = true;

	if (WorldInfo.NetMode != NM_DedicatedServer)
	{
		UpdateQuantumShieldFX();
	}
}

// used as a recipient
function DeactivateQuantumShield()
{
	QuantumShieldOwner = None;
	QuantumShieldMultiplier = 0;
	bForceNetUpdate = true;

	if (WorldInfo.NetMode != NM_DedicatedServer)
	{
		UpdateQuantumShieldFX();
	}
}

function QuantumShieldAbsorb(out int InDamage)
{
	local int AbsorbedDmg;

	if (QuantumShieldOwner == None || QuantumShieldOwner.ArmorInt <= 0)
		return;

	AbsorbedDmg = Min(InDamage, QuantumShieldOwner.ArmorInt);
	QuantumShieldOwner.ArmorInt -= AbsorbedDmg;
	QuantumShieldOwner.QuantumShieldArmorConsumed += AbsorbedDmg;
	InDamage -= AbsorbedDmg;

	QuantumShieldOwner.NotifyArmorChanged();
}

simulated function ApplyTraitDenseRounds(float InDuration, float InDamageMod, float InPenetrationMod)
{
	if (Role == ROLE_AUTHORITY)
	{
		ClientApplyTraitDenseRounds(InDuration, InDamageMod, InPenetrationMod);
		if (DenseRoundsWeapon == None)
		{
			DenseRoundsWeapon = Spawn(class'ExtWeap_DenseRounds', self);
		}
	}

	DenseRoundDuration = InDuration;
	DenseRounds_DamageMod = InDamageMod;
	DenseRounds_PenetrationMod = InPenetrationMod;
}

reliable client function ClientApplyTraitDenseRounds(float InDuration, float InDamageMod, float InPenetrationMod)
{
	ApplyTraitDenseRounds(InDuration, InDamageMod, InPenetrationMod);
}

reliable server function ServerActivateDenseRounds()
{
	SetUsingDenseRounds(true);

	if (DenseRoundsWeapon == None)
	{
		DenseRoundsWeapon = Spawn(class'ExtWeap_DenseRounds', self);
		DenseRoundsWeapon.Instigator = self;
	}

	SetTimer(DenseRoundDuration, false, nameOf(ServerDeActivateDenseRounds));
	ClientActivateDenseRounds();
}

unreliable server function ServerDeActivateDenseRounds()
{
	SetUsingDenseRounds(false);
}

unreliable client function ClientActivateDenseRounds()
{
	SetUsingDenseRounds(true);
	SetTimer(DenseRoundDuration, false, nameOf(ClientDeActivateDenseRounds));
}

unreliable client function ClientDeActivateDenseRounds()
{
	SetUsingDenseRounds(false);
}

simulated function SetUsingDenseRounds(bool Activate = true)
{
	`log("SetDenseRounds(" @ Activate @ ") called!");
	bIsUsingDenseRounds = Activate;
}


reliable server function ServerFireDenseRound()
{
	FireDenseRound();
}

simulated function FireDenseRound()
{
	local KFWeapon KFW;
	local float DRDmg;
	local float DRPnt;
	local float AmmoMod;
	local Class<KFProjectile> ProjClass;
	local KFProjectile DenseBullet;
	local vector RealStartLoc, AimDir, StartTrace;


	if (Role < ROLE_Authority)
	{
		ServerFireDenseRound();
	}

	KFW = KFWeapon(Weapon);
	if (KFW == None) return;

	ProjClass = KFW.GetKFProjectileClass();
	if (ProjClass == None) return;

	FiringMode = 0;

	if (KFW.AmmoCount[0] <= 0) return;

	AmmoMod = KFW.AmmoCount[0] * KFW.NumPellets[0];
	DRDmg = KFW.InstantHitDamage[0]  * DenseRounds_DamageMod * AmmoMod;
	DRPnt = KFW.PenetrationPower[0] * DenseRounds_PenetrationMod * AmmoMod;
	KFW.AmmoCount[0] = 0;

	`log("FireDenseRound() DRDmg:" @ DRDmg @ " DRPnt:" @ DRPnt);

	// 2. Play the weapon's fire effects (animation, sound, muzzle flash)
	KFW.PlayFireEffects(0);
	// Replicate 3P fire effects to other clients from the server
	if (Role == ROLE_Authority)
	{
		KFW.IncrementFlashCount();
	}
	// 3. Manually construct and spawn the bullet (Only run on Server, or Client for client-side hit detection)
	if (Role == ROLE_AUTHORITY || 
		(ProjClass.default.bUseClientSideHitDetection && ProjClass.default.bNoReplicationToInstigator && IsLocallyControlled()))
	{
		// StartTrace = KFW.GetSafeStartTraceLocation();
		StartTrace = GetWeaponStartTraceLocation();
		AimDir = Vector(KFW.GetAdjustedAim(StartTrace));
		
		if (KFW.UseFixedPhysicalFireLocation)
		{
			RealStartLoc = KFW.GetFixedPhysicalFireStartLoc();
		}
		else
		{
			RealStartLoc = KFW.GetPhysicalFireStartLoc(AimDir);
		}

		if (DenseRoundsWeapon != None)
		{
			DenseRoundsWeapon.Instigator = self;
			DenseRoundsWeapon.SetDamage(DRDmg);
			DenseRoundsWeapon.SetPenetration(DRPnt);
			DenseRoundsWeapon.SetDamageType(KFW.InstantHitDamageTypes[0]);

			DenseBullet = Spawn(ProjClass, DenseRoundsWeapon,, RealStartLoc);
			if (DenseBullet != None && !DenseBullet.bDeleteMe)
			{
				// Apply damage and penetration directly to the projectile instance without altering the weapon
				DenseBullet.Instigator = self;
				DenseBullet.Damage = DRDmg;
				DenseBullet.MyDamageType = KFW.InstantHitDamageTypes[0];
				DenseBullet.InitialPenetrationPower = DRPnt;
				DenseBullet.PenetrationPower = DRPnt;
				
				// Scale the projectile visual size to 5x larger
				DenseBullet.SetDrawScale(5.0);

				// Initialize the projectile direction & movement
				DenseBullet.Init(AimDir);
			}
		}
	}
}


defaultproperties
{
	HealthRegenRate=0.2
	ArmorInt=0
	MaxArmorInt=100
	ArmorEfficiency=0.2
	QuantumShieldFX=ParticleSystem'ZED_Matriarch_EMIT.FX_Matriarch_Shield'
	bIsUsingDenseRounds=false
	DenseRounds_DamageMod=0.0
	DenseRounds_PenetrationMod=0.0

	AbilityCount=0
	AbilityGauge=0
	MaxAbilityCount=0

	ArmorEfficiency = 1.0
	AirBagRate = 0.0

	bCanParryProj=false
	bCanReflectProj=false
	
	KnockbackResist=1

	// Ragdoll mode:
	bReplicateRigidBodyLocation=true
	bCanBecomeRagdoll=true
	InventoryManagerClass=class'ExtInventoryManager'
	WakeUpAnimSet=AnimSet'ZED_Clot_Anim.Alpha_Clot_Master'

	Begin Object Name=SpecialMoveHandler_0
		SpecialMoveClasses(SM_Emote)=class'DoshExt.ExtSM_Player_Emote'
	End Object

	DefaultInventory.Empty()
	DefaultInventory.Add(class'ExtWeap_Pistol_9mm')
	// DefaultInventory.Add(class'KFWeap_Pistol_9mm')
	DefaultInventory.Add(class'KFWeap_Healer_Syringe')
	DefaultInventory.Add(class'KFWeap_Welder')
	DefaultInventory.Add(class'KFInventory_Money')

	Begin Object Class=SkeletalMeshComponent Name=FP_BodyComp
		MinDistFactorForKinematicUpdate=0.0
		bSkipAllUpdateWhenPhysicsAsleep=True
		bIgnoreControllersWhenNotRendered=True
		bHasPhysicsAssetInstance=False
		bUpdateKinematicBonesFromAnimation=False
		bPerBoneMotionBlur=True
		bOverrideAttachmentOwnerVisibility=True
		bChartDistanceFactor=True
		DepthPriorityGroup=SDPG_Foreground
		RBChannel=RBCC_Pawn
		RBDominanceGroup=20
		HiddenGame=True
		bOnlyOwnerSee=True
		bAcceptsDynamicDecals=True
		bUseOnePassLightingOnTranslucency=True
		Translation=(X=-65.876999,Y=0.900000,Z=-95.500000)
		Scale=1.210000
		ScriptRigidBodyCollisionThreshold=200.000000
		PerObjectShadowCullDistance=4000.000000
		bAllowPerObjectShadows=True
		bAllowPerObjectShadowBatching=True
	End Object
	FPBodyMesh=FP_BodyComp
}

simulated function bool CanBeHealed()
{
	return true;
}