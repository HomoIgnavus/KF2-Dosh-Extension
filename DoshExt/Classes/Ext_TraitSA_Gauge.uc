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
Class Ext_TraitSA_Gauge extends Ext_TraitBase;

var int GuagePerKill[3];
var int MaxCount[3];
var int InitialCount[3];

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local ExtPlayerController EPC;

	if (Player == None) return;

	EPC = ExtPlayerController(Player.Controller);
	if (EPC == None) return;

	EPC.AbilityGaugePerKill = default.GuagePerKill[Level - 1];
	if (Player.AbilityCount == 0)
	{
		Player.AbilityCount = default.InitialCount[Level - 1];
	}
	EPC.EHP.MaxAbilityCount = default.MaxCount[Level - 1];
}
static function CancelEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local ExtPlayerController EPC;
	
	if (Player == None) return;

	EPC = ExtPlayerController(Player.Controller);
	if (EPC == None) return;

	EPC.AbilityGaugePerKill = 0;
	EPC.EHP.MaxAbilityCount = 0;
}

defaultproperties
{
	TraitGroup=class'Ext_TGroupSpAbility'

	NumLevels=3
	
	DefLevelCosts(0)=50
	DefLevelCosts(1)=100
	DefLevelCosts(2)=200

	GuagePerKill(0)=1
	GuagePerKill(1)=2
	GuagePerKill(2)=3

	MaxCount(0)=3
	MaxCount(1)=5
	MaxCount(2)=9

	InitialCount(0)=0
	InitialCount(1)=1
	InitialCount(2)=2
}