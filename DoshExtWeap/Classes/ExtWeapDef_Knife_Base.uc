class ExtWeapDef_Knife_Base extends KFWeapDef_Knife_Medic
	abstract
	hidedropdown;

var localized string WeaponName;

static function string GetItemName()
{
	return default.WeaponName;
}

DefaultProperties
{
	BuyPrice=600
}
