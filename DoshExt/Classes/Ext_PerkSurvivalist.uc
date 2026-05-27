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

Class Ext_PerkSurvivalist extends Ext_PerkBase;

var public bool bHasTraitScavenger;
var float ScavengerHealth;
var float ScavengerArmor;
var float ScavengerAmmo;
var int ScavengerAmmoSingle;

public function ApplyTraitScavenger(float HealthReg, float ArmorReg, float AmmoReg, int AmmoRegSingle, bool bActivate = true)
{
	ScavengerHealth = HealthReg;
	ScavengerArmor = ArmorReg;
	ScavengerAmmo = AmmoReg;
	ScavengerAmmoSingle = AmmoRegSingle;
	bHasTraitScavenger = bActivate;
}

public function PlayerKilled(KFPawn_Monster Victim, Class<DamageType> DamageType)
{
	local ExtHumanPawn EHP;
	local int RandomEffect;
	local int MaxHealth;
	local int MaxArmor;

	super.PlayerKilled(Victim, DamageType);

	if (!bHasTraitScavenger) return;

	EHP = ExtHumanPawn(PlayerOwner.Pawn);
	if (EHP == none) return;


	RandomEffect = rand(3);
	switch (RandomEffect)
	{
		// +health
		case 0:
			MaxHealth = EHP.HealthMax;
			EHP.HealDamage(ScavengerHealth * MaxHealth, PlayerOwner, none);
			break;
		// +armor
		case 1:
			MaxArmor = EHP.MaxArmorInt;
			EHP.AddArmor(ScavengerArmor * MaxArmor);
			break;
		// +ammo
		case 2:
			Scavenger_RegenAmmo();
			break;
		default:
			break;
	}
}

function Scavenger_RegenAmmo()
{
	local KFweapon KFW;
	local int idx;
	local int AmmoAdded;

	KFW = KFWeapon(PlayerOwner.Pawn.Weapon);
	if (KFW == none) return;
	
	for (idx = 0; idx < 2; idx++)
	{
		if (KFW.MagazineCapacity[idx] > 1)
		{
			AmmoAdded = Max(ScavengerAmmo * KFW.MagazineCapacity[idx], 1);
			KFW.AddAmmo(AmmoAdded);
		}
		else if (KFW.MagazineCapacity[idx] > 0)
		{
			AmmoAdded = Max(ScavengerAmmo * KFW.MagazineCapacity[idx], ScavengerAmmoSingle);
			KFW.AddAmmo(AmmoAdded);
		}
	}
}

// not being used since ammo refill doesn't seem to be working
function bool RandomWeaponFromInventory(out KFWeapon WeaponOut)
{
	local int RandomWeapon;
	local Inventory Inv;
	local KFWeapon KFW;
	local array<KFWeapon> WeaponArray;

	WeaponOut = none;

	for (Inv = PlayerOwner.Pawn.InvManager.InventoryChain; Inv != none; Inv = Inv.Inventory)
	{
		KFW = KFWeapon(Inv);
		if (
			KFW == none || 
			KFW.Class != class'ExtWeap_Pistol_9mm' || 
			KFW.Class != class'ExtWeap_Pistol_MedicS' || 
			KFW.Class != class'KFWeap_MeleeBase' ||
			KFW.Class != class'KFWeap_Welder' ||
			KFW.Class != class'KFWeap_Healer_Syringe'
		)
		{
			return false;
		}
		WeaponArray.AddItem(KFW);
	}

	if (WeaponArray.Length > 0)
	{
		RandomWeapon = rand(WeaponArray.Length);
		WeaponOut = WeaponArray[RandomWeapon];
		return true;
	}

	return false;
}

defaultproperties
{
	PerkIcon=Texture2D'UI_PerkIcons_TEX.UI_PerkIcon_Survivalist'
	DefTraitList.Add(class'Ext_TraitWPSurv')
	DefTraitList.Add(class'Ext_TraitScavenger')
	BasePerk=class'KFPerk_Survivalist'

	PrimaryMelee=class'KFWeap_Random'
	PrimaryWeapon=class'KFWeap_Knife_Support'
	PerkGrenade=class'KFProj_HEGrenade'

	PrimaryWeaponDef=class'KFWeapDef_Random'
	KnifeWeaponDef=class'KFweapDef_Knife_Support'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_Commando'

	AutoBuyLoadOutPath=(class'KFWeapDef_DragonsBreath', class'KFWeapDef_M16M203', class'KFWeapDef_MedicRifle')

	bHasTraitScavenger=false
	ScavengerHealth=0.0f
	ScavengerArmor=0.0f
	ScavengerAmmo=0.0f
}