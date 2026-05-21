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

Class Ext_TraitSA_MysticEyes extends Ext_TraitSA_Base;

var float Duration[3];
var float DmgMultiplier[3];

static function AddDefaultInventory(KFPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkBerserker BerserkerPerk;
	local int i;
	
	BerserkerPerk = Ext_PerkBerserker(Perk);
	i = Player.DefaultInventory.Find(class'KFWeap_Knife_Berserker');
	if (i != -1)
		Player.DefaultInventory[i] = class'ExtWeap_Knife_Berserker_Mystic';

	if (BerserkerPerk != none)
	{
		BerserkerPerk.PrimaryMelee = class'ExtWeap_Knife_Berserker_Mystic';
	}
}

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Inventory Inv;
	local Ext_PerkBerserker BerserkerPerk;

	BerserkerPerk = Ext_PerkBerserker(Perk);
	if (BerserkerPerk == None) return;

	BerserkerPerk.bHasMysticEyes = true;
	BerserkerPerk.MysticEyesDuration = Default.Duration[Level-1];
	BerserkerPerk.MysticEyesDmgMultiplier = Default.DmgMultiplier[Level-1];

	Inv = Player.FindInventoryType(class'KFWeap_Knife_Berserker');
	if (Inv!=None)
		Inv.Destroy();

	if (Player.FindInventoryType(class'ExtWeap_Knife_Berserker_Mystic')==None)
	{
		Inv = Player.CreateInventory(class'ExtWeap_Knife_Berserker_Mystic', Player.Weapon!=None);
		if (KFWeapon(Inv)!=None)
			KFWeapon(Inv).bGivenAtStart = true;
	}
	AddAbility(Player, SpAbil_MysticEyes);
}

static function CancelEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Inventory Inv;
	local Ext_PerkBerserker BerserkerPerk;

	BerserkerPerk = Ext_PerkBerserker(Perk);
	if (BerserkerPerk == None) return;

	BerserkerPerk.bHasMysticEyes = false;
	BerserkerPerk.MysticEyesDuration = 0.0;
	BerserkerPerk.MysticEyesDmgMultiplier = 1.0;

	RemoveAbility(Player, SpAbil_MysticEyes);
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkBerserker'
	NumLevels=3

	DefLevelCosts(0)=100
	DefLevelCosts(0)=200
	DefLevelCosts(0)=400

	Duration[0]=10
	Duration[1]=20
	Duration[2]=30

	DmgMultiplier[0]=1.2
	DmgMultiplier[1]=1.4
	DmgMultiplier[2]=1.6
}