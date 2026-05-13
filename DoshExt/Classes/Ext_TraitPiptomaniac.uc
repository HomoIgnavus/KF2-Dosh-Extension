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

Class Ext_TraitPiptomaniac extends Ext_TraitBase;

var float FallDamageScale[5];

static function bool MeetsRequirements(byte Lvl, Ext_PerkBase Perk)
{
	local int Idx;
	// First check level.
	if (Perk.CurrentLevel<Default.MinLevel || Perk.CurrentPrestige < 2)
		return false;

	// Prerequisite: Bombzerker
	idx = Perk.PerkTraits.Find('TraitType', class'Ext_TraitBombzerker');
	if (Idx < 0 || Perk.PerkTraits[idx].CurrentLevel < 1)
		return false;

	return true;
}

static function TraitActivate(Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkBerserker ZerkerPerk;
	ZerkerPerk = Ext_PerkBerserker(Perk);

	if (ZerkerPerk == none) return;

	ZerkerPerk.FallDamageScale = default.FallDamageScale[Level - 1];
}

static function TraitDeActivate(Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkBerserker ZerkerPerk;
	ZerkerPerk = Ext_PerkBerserker(Perk);

	if (ZerkerPerk == none) return;

	ZerkerPerk.FallDamageScale = 1.0;
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkBerserker'
	TraitGroup=class'Ext_TGroupBombzerker'
	NumLevels=5
	DefLevelCosts(0)=50
	DefLevelCosts(1)=100
	DefLevelCosts(2)=200
	DefLevelCosts(3)=300
	DefLevelCosts(4)=400
	
	FallDamageScale(0)=1.5
	FallDamageScale(1)=2.0
	FallDamageScale(2)=3.0
	FallDamageScale(3)=5.0
	FallDamageScale(4)=10.0
}