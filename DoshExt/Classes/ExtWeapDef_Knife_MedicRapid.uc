//=============================================================================
// KFWeaponDefintion
//=============================================================================
// A lightweight container for basic weapon properties that can be safely
// accessed without a weapon actor (UI, remote clients). 
//=============================================================================
// Killing Floor 2
// Copyright (C) 2015 Tripwire Interactive LLC
//=============================================================================
class ExtWeapDef_Knife_MedicRapid extends KFWeapDef_Knife_Medic
	abstract
	hidedropdown;

var localized string ItemName;

static function string GetItemName()
{
	return default.ItemName;
}

DefaultProperties
{
	WeaponClassPath="DoshExt.ExtWeap_Knife_FieldMedicRapid"
	ImagePath="ui_weaponselect_tex.UI_WeaponSelect_MedicKnife"

	BuyPrice=600
}
