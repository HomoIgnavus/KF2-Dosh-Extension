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

// Military Grade Rounds
Class Ext_TraitSA_DenseRounds extends Ext_TraitSA_Base;

var float Duration[3];
var float DmgRatio[3];
var float PntRatio[3];

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local int Idx;
	super.AddAbility(Player, SpAbil_DenseRounds);

	Idx = Level - 1;

	Player.ApplyTraitDenseRounds(default.Duration[Idx], default.DmgRatio[Idx], default.PntRatio[Idx]);
}

static function CancelEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	super.RemoveAbility(Player, SpAbil_DenseRounds);

	Player.ApplyTraitDenseRounds(0.0, 0.0, 0.0);
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkSupport'
	NumLevels=3
	
	Duration(0)=5.0
	Duration(1)=10.0
	Duration(2)=15.0

	DmgRatio(0)=0.5
    DmgRatio(1)=0.7
    DmgRatio(2)=1.0
	
	PntRatio(0)=0.5
	PntRatio(1)=0.8
	PntRatio(2)=1.5
}