class ExtWeapDef_Knife_Base extends KFWeapDef_Knife_Medic
	abstract
	hidedropdown;

var localized string ItemName;

static function string GetItemName()
{
	return default.ItemName;
}

DefaultProperties
{
	BuyPrice=600
}
