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

Class Ext_TraitHemoExplosion extends Ext_TraitBase;

var float ExpChance[3];

static function bool MeetsRequirements(byte Lvl, Ext_PerkBase Perk)
{
	local int TraitIdx;

	// First check level.
	if (Perk.CurrentLevel < Default.MinLevel || Perk.CurrentPrestige < 1)
		return false;

	TraitIdx = Perk.PerkTraits.Find('TraitType', class'Ext_TraitRapidSurgery');
	if (TraitIdx < 0 || Perk.PerkTraits[TraitIdx].CurrentLevel < 1)
		return false;
	
	return true;
}

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkFieldMedic MedicPerk;
	local ExtWeap_Knife_FieldMedicRapid Scalpel;

	MedicPerk = Ext_PerkFieldMedic(Perk);
	if (MedicPerk == None) return;

	Scalpel = ExtWeap_Knife_FieldMedicRapid(Player.FindInventoryType(class'ExtWeap_Knife_FieldMedicRapid'));
	if (Scalpel == None) return;

	Scalpel.bCanHemoExplode = true;
	Scalpel.HemoExplosionChance = default.ExpChance[Level-1];
}

static function CancelEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkFieldMedic MedicPerk;
	local ExtWeap_Knife_FieldMedicRapid Scalpel;

	MedicPerk = Ext_PerkFieldMedic(Perk);
	if (MedicPerk == None) return;

	Scalpel = ExtWeap_Knife_FieldMedicRapid(Player.FindInventoryType(class'ExtWeap_Knife_FieldMedicRapid'));
	if (Scalpel == None) return;

	Scalpel.bCanHemoExplode = false;
	Scalpel.HemoExplosionChance = 0.0
	;
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkFieldMedic'
	TraitGroup=class'Ext_TGroupRapidScalpel'
	NumLevels=3
	
	DefLevelCosts(0)=100
	DefLevelCosts(1)=200
	DefLevelCosts(2)=400

	ExpChance(0)=0.01
	ExpChance(1)=0.05
	ExpChance(2)=0.08	
}