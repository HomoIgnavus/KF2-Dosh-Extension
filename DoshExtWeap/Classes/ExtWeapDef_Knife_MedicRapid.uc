//=============================================================================
// KFWeaponDefintion
//=============================================================================
// A lightweight container for basic weapon properties that can be safely
// accessed without a weapon actor (UI, remote clients). 
//=============================================================================
// Killing Floor 2
// Copyright (C) 2015 Tripwire Interactive LLC
//=============================================================================
class ExtWeapDef_Knife_MedicRapid extends ExtWeapDef_Knife_Base
	abstract
	hidedropdown;

DefaultProperties
{
	WeaponClassPath="DoshExtWeap.ExtWeap_Knife_FieldMedicRapid"
	ImagePath="ui_weaponselect_tex.UI_WeaponSelect_MedicKnife"
}
