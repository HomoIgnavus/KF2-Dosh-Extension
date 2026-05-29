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

Class Ext_TraitSA_ArmorOverload extends Ext_TraitSA_Base;

var float ShieldDuration[3];
var float ExpDmgMod[3];

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkSWAT SwatPerk;

	SwatPerk = Ext_PerkSWAT(Perk);
	if (SwatPerk != None)
	{
		SwatPerk.bHasArmorOverload = True;
	}
}

static function CancelEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkSWAT SwatPerk;

	SwatPerk = Ext_PerkSWAT(Perk);
	if (SwatPerk != None)
	{
		SwatPerk.bHasArmorOverload = False;
	}
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkSWAT'
	NumLevels=1
	LevelCosts[0] = 400
}
