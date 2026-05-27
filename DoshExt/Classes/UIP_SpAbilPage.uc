class UIP_SpAbilPage extends KFGUI_MultiComponent
    config(DoshExtWeapons)
    dependson(Ext_TraitSA_Base);

var ExtPlayerController ExtPC;
var KFGUI_ColumnList SpAbilList;
var KFGUI_Base WeaponIconDisplay;
var KFGUI_Button UseWeaponButton;
var int SelectedIdx; // The "Selected Sp Weapon" variable

var localized string ColumnWeaponText;
var localized string ColumnDescriptionText;
var localized string AbilName_PerkGrenade;
var localized string AbilName_RocketJump;
var localized string AbilName_MGRs;
var localized string AbilName_HemoStrike;
var localized string AbilName_MysticEyes;
var localized string AbilName_QuantumShield;
var localized string AbilName_Unknown;

function InitMenu()
{
    ExtPC = ExtPlayerController(GetPlayer());

    EnsureComponentsBuilt();

    WeaponIconDisplay = FindComponentID('WeaponIconDisplay');
    UseWeaponButton = KFGUI_Button(FindComponentID('UseWeaponButton'));

    SpAbilList = KFGUI_ColumnList(FindComponentID('SpWeaponList'));
    SpAbilList.Columns.AddItem(NewFColumnItem("Special weapon list", 1.0));

    Super.InitMenu();

    SpAbilList.OnSelectedRow = OnSpAbilSelected;

    if (UseWeaponButton != None)
    {
        UseWeaponButton.OnClickLeft = OnUseAbilClicked;
        UseWeaponButton.OnClickRight = OnUseAbilClicked;
    }
}

function ShowMenu()
{
    Super.ShowMenu();
    
    // Load special abilities from player controller
    LoadSpecialAbilities();
}

function CloseMenu()
{
    Super.CloseMenu();
    
    // Clear the list when closing
    SpAbilList.EmptyList();
}

function FColumnItem NewFColumnItem(string Text, float Width)
{
    local FColumnItem NewItem;
    NewItem.Text = Text;
    NewItem.Width = Width;
    return NewItem;
}

private function EnsureComponentsBuilt()
{
    local KFGUI_Base Icon;
    local KFGUI_GreenButton Btn;
    local KFGUI_ColumnList SpList;

    if (FindComponentID('UseWeaponButton') != None)
        return;

    Components.Length = 0;

    // Left side - Icon at the top
    Icon = new (Self) class'KFGUI_MultiComponent';
    Icon.ID = 'WeaponIconDisplay';
    Icon.XPosition = 0.01;
    Icon.YPosition = 0.02;
    Icon.XSize = 0.45;
    Icon.YSize = 0.40;
    Components.AddItem(Icon);
    Icon.Owner = Owner;
    Icon.ParentComponent = Self;

    // Left side - Button at the bottom
    Btn = new (Self) class'KFGUI_GreenButton';
    Btn.ID = 'UseWeaponButton';
    Btn.XPosition = 0.01;
    Btn.YPosition = 0.88;
    Btn.XSize = 0.45;
    Btn.YSize = 0.10;
    Btn.ButtonText = "Use";
    Components.AddItem(Btn);
    Btn.Owner = Owner;
    Btn.ParentComponent = Self;

    // Right side - Special weapon list
    SpList = new (Self) class'KFGUI_ColumnList';
    SpList.ID = 'SpWeaponList';
    SpList.XPosition = 0.50;
    SpList.YPosition = 0.02;
    SpList.XSize = 0.48;
    SpList.YSize = 0.96;
    SpList.BackgroundColor.R = 4;
    SpList.BackgroundColor.G = 30;
    SpList.BackgroundColor.B = 8;
    SpList.BackgroundColor.A = 255;
    Components.AddItem(SpList);
    SpList.Owner = Owner;
    SpList.ParentComponent = Self;
}

function LoadSpecialAbilities()
{
    local int i;
    local string AbilName;
    
    if (ExtPC == None) 
        ExtPC = ExtPlayerController(GetPlayer());

    if (ExtPC == None || SpAbilList == None)
        return;
    
    // Clear existing list
    SpAbilList.EmptyList();
    
    `log("UIP_SpAbilPage.LoadSpecialAbilities: Loading " @ ExtPC.SpecialAbil.Length @ " special abilities");
    
    // Add each special ability to the list
    for (i = 0; i < ExtPC.SpecialAbil.Length; i++)
    {
        AbilName = GetSpecialAbilityName(ExtPC.SpecialAbil[i]);
        // `log("UIP_SpAbilPage.LoadSpecialAbilities:   [" @ i @ "] = " @ ExtPC.SpecialAbil[i] @ " -> " @ AbilName);
        SpAbilList.AddLine(AbilName, i);
    }
}

function string GetSpecialAbilityName(SpecialAbilities Ability)
{
    switch (Ability)
    {
        case SpAbil_PerkGrenade:
            return AbilName_PerkGrenade;
        case SpAbil_RocketJump:
            return AbilName_RocketJump;
        case SpAbil_MGRs:
            return AbilName_MGRs;
        case SpAbil_HemoStrike:
            return AbilName_HemoStrike;
        case SpAbil_MysticEyes:
            return AbilName_MysticEyes;
        case SpAbil_QuantumShield:
            return AbilName_QuantumShield;
        default:
            return AbilName_Unknown;
    }
}

function OnSpAbilSelected(KFGUI_ListItem Item, int Row, bool bRight, bool bDblClick)
{
    if (Item != None)
    {
        SelectedIdx = Item.Value; // sets the "Selected Sp Weapon" variable
    }
}

function OnUseAbilClicked(KFGUI_Button Sender)
{

    if (!GetExtPlayer(ExtPC) || SpAbilList == None)
        return;

    // Implementation for setting the sp weapon
    `log("OnUseAbilClicked called for " @ SelectedIdx @ ": " @ ExtPC.SpecialAbil[SelectedIdx]);
    if (SelectedIdx >= 0 && SelectedIdx < ExtPC.SpecialAbil.Length)
        ExtPC.SetSpAbil(ExtPC.SpecialAbil[SelectedIdx]);
}

function DrawMenu()
{
    local string AbilName;
    local string AbilDescription;
    
    if (!GetExtPlayer(ExtPC))
        return;
    
    Super.DrawMenu();
    
    // Draw description text in the middle of the left side
    Canvas.SetPos(CompPos[0] + CompPos[2] * 0.01, CompPos[1] + CompPos[3] * 0.01);
    Canvas.SetDrawColor(255, 255, 255, 255);
    GetAbilityText(ExtPC.SpecialAbil[SelectedIdx], AbilName, AbilDescription);
    Canvas.DrawText(AbilName);
    Canvas.DrawText(AbilDescription);
}

function GetAbilityText(SpecialAbilities Ability, out string AbilName, out string Description)
{
    // `log("UIP_SpAbilPage.GetAbilityText: " @ Ability);
    switch (Ability)
    {
        case SpAbil_PerkGrenade:
            AbilName = AbilName_PerkGrenade;
            Description = "Toss your perk's grenade";
            break;
        case SpAbil_RocketJump:
            AbilName = AbilName_RocketJump;
            Description = class'Ext_TraitSA_RocketJump'.default.Description;
            break;
        case SpAbil_MGRs:
            AbilName = AbilName_MGRs;
            Description = class'Ext_TraitSA_MGRs'.default.Description;
            break;
        case SpAbil_QuantumShield:
            AbilName = AbilName_QuantumShield;
            Description = class'Ext_TraitSA_QuantumShield'.default.Description;
            break;
        default:
            AbilName = "No ability selected.";
            Description = "";
            break;
    }
}