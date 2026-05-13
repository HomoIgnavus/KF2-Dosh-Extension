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

Class Ext_TraitScavenger extends Ext_TraitBase;

var public float HealthRegen[3];
var public float ArmorRegen[3];
var public float AmmoRegen[3];
var public int AmmoRegenSingleShot[3];

static function TraitActivate(Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkSurvivalist SurPerk;
	local int Idx;

	SurPerk = Ext_PerkSurvivalist(Perk);
	if (SurPerk == none) return;

	Idx = Level - 1;

	SurPerk.ApplyTraitScavenger(Default.HealthRegen[Idx], Default.ArmorRegen[Idx], Default.AmmoRegen[Idx], Default.AmmoRegenSingleShot[Idx]);
}

static function TraitDeActivate(Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkSurvivalist SurPerk;
	local int Idx;

	SurPerk = Ext_PerkSurvivalist(Perk);
	if (SurPerk == none) return;

	SurPerk.ApplyTraitScavenger(0.f, 0.f, 0.f, 0, false);
}

defaultproperties
{
	NumLevels=3
	DefLevelCosts(0)=50
	DefLevelCosts(1)=100
	DefLevelCosts(2)=200

	HealthRegen(0)=0.01
	HealthRegen(1)=0.02
	HealthRegen(2)=0.04
	
	ArmorRegen(0)=0.01
	ArmorRegen(1)=0.02
	ArmorRegen(2)=0.04
	
	AmmoRegen(0)=0.2
	AmmoRegen(1)=0.4
	AmmoRegen(2)=0.8
	
	AmmoRegenSingleShot(0)=1
	AmmoRegenSingleShot(1)=2
	AmmoRegenSingleShot(2)=3
}