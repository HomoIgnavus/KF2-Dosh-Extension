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

Class Ext_TraitSA_QuantumShield extends Ext_TraitSA_Base;

var float ShieldDuration[3];
var float ExpDmgMod[3];

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	super.AddAbility(Player, SpAbil_QuantumShield);

	Player.QuantumShieldDuration = default.ShieldDuration[Level - 1];
	Player.QuantumShieldDmgMultiplier = default.ExpDmgMod[Level - 1];
}

static function CancelEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	super.RemoveAbility(Player, SpAbil_QuantumShield);

	Player.QuantumShieldDuration = 0.f;
	Player.QuantumShieldDmgMultiplier = 0.f;
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkSWAT'
	NumLevels=3

	ShieldDuration[0]=10.f
	ShieldDuration[1]=15.f
	ShieldDuration[2]=20.f

	ExpDmgMod[0]=1.f
	ExpDmgMod[1]=2.f
	ExpDmgMod[2]=5.f
}
