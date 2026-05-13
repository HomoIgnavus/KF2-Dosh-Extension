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

Class Ext_TraitSA_HemoStrike extends Ext_TraitSA_Base;

var int MisslesPerShot[3];
var float StrikeRadius[3];

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkFieldMedic MedicPerk;
	MedicPerk = Ext_PerkFieldMedic(Perk);

	if (MedicPerk != None)
	{
		MedicPerk.MisslesPerShot = default.MisslesPerShot[Level-1];
		MedicPerk.HemoStrikeRadius = default.StrikeRadius[Level-1];
	}
	super.AddAbility(Player, SpAbil_HemoStrike);
}

static function CancelEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkFieldMedic MedicPerk;
	MedicPerk = Ext_PerkFieldMedic(Perk);

	if (MedicPerk != None)
	{
		MedicPerk.MisslesPerShot = 0;
		MedicPerk.HemoStrikeRadius = 0.0;
	}
	super.RemoveAbility(Player, SpAbil_HemoStrike);
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkFieldMedic'
	NumLevels=3
	
	DefLevelCosts(0)=100
	DefLevelCosts(1)=200
	DefLevelCosts(2)=400

	MisslesPerShot(0)=1
	MisslesPerShot(1)=2
	MisslesPerShot(2)=3
	
	StrikeRadius(0)=600.0
	StrikeRadius(1)=1000.0
	StrikeRadius(2)=2000.0	
}