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

Class Ext_TraitFightOrFlight extends Ext_TraitBase;

var float DamageBonusRate[3];
var float SpeedBonusRate[3];

static function TraitActivate(Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkSWAT SwatPerk;

	SwatPerk = Ext_PerkSWAT(Perk);
	if (SwatPerk == none) return;

	SwatPerk.bHasFoF = true;
	SwatPerk.FoFDmgStep = default.DamageBonusRate[Level-1];
	SwatPerk.FoFSpeedStep = default.SpeedBonusRate[Level-1];
	SwatPerk.UpdateFoFMods(ExtHumanPawn(SwatPerk.PlayerOwner.Pawn));
}

static function TraitDeActivate(Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkSWAT SwatPerk;

	SwatPerk = Ext_PerkSWAT(Perk);
	if (SwatPerk == none) return;

	SwatPerk.bHasFoF = false;
	SwatPerk.FoFDmgStep = 0.f;
	SwatPerk.FoFSpeedStep = 0.f;
	SwatPerk.UpdateFoFMods(ExtHumanPawn(SwatPerk.PlayerOwner.Pawn));
}

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	if (Level <= 1)
		return;

	Level == 2 ? Player.AddArmor(50) : Player.AddArmor(Player.MaxArmorInt);
}

defaultproperties
{
	NumLevels=3
	DefLevelCosts(0)=50
	DefLevelCosts(1)=100
	DefLevelCosts(2)=200
	DefMinLevel=50

	DamageBonusRate(0)=0.2
	DamageBonusRate(1)=0.5
	DamageBonusRate(2)=1.0

	SpeedBonusRate(0)=0.2
	SpeedBonusRate(1)=0.5
	SpeedBonusRate(2)=1.0
}