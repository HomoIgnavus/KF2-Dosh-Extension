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

Class Ext_TraitRapidSurgery extends Ext_TraitBase;

static function AddDefaultInventory(KFPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Ext_PerkFieldMedic MedicPerk;
	local int i;
	
	MedicPerk = Ext_PerkFieldMedic(Perk);
	i = Player.DefaultInventory.Find(class'KFWeap_Knife_FieldMedic');
	if (i != -1)
		Player.DefaultInventory[i] = class'ExtWeap_Knife_FieldMedicRapid';

	if (MedicPerk != none)
	{
		MedicPerk.PrimaryMelee = class'ExtWeap_Knife_FieldMedicRapid';
	}
}

static function ApplyEffectOn(ExtHumanPawn Player, Ext_PerkBase Perk, byte Level, optional Ext_TraitDataStore Data)
{
	local Inventory Inv;

	Inv = Player.FindInventoryType(class'KFWeap_Knife_FieldMedic');
	if (Inv!=None)
		Inv.Destroy();

	if (Player.FindInventoryType(class'ExtWeap_Knife_FieldMedicRapid')==None)
	{
		Inv = Player.CreateInventory(class'ExtWeap_Knife_FieldMedicRapid', Player.Weapon!=None);
		if (KFWeapon(Inv)!=None)
			KFWeapon(Inv).bGivenAtStart = true;
	}
}

defaultproperties
{
	SupportedPerk=class'Ext_PerkFieldMedic'
	TraitGroup=class'Ext_TGroupRapidScalpel'
	NumLevels=1
	
	DefLevelCosts(0)=100
}