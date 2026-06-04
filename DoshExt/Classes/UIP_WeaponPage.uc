class UIP_WeaponPage extends KFGUI_MultiComponent
    config(DoshExtWeapons);

var ExtPlayerController KFPC;
var ExtPlayerReplicationInfo KFPRI;
var KFGUI_ColumnList InventoryList;
var KFGUI_ColumnList SaleList;
var KFGUI_Base WeaponIconDisplay; // For displaying weapon icon
var KFGUI_Button BuyWeaponButton; // Upgrade button below icon
var int WeaponIdx;

var KFGUI_ComponentList WeaponStatsList;
var array<UIR_WeaponStatRow> StatRows;

var localized string ColumnWeaponText;
var localized string ColumnPriceText;
var localized string ColumnDamageText;
var localized string ColumnPenetrationText;

var Array<int> SaleListMap; // Maps SaleList row indices to WeaponDefList indices

var config Array<string> WeapDef;

// var array< class<ExtWeapon> > TraderWeapList;
var Array<Ext_WeaponProperties> AvailableWeapons;
var int SelectedInventoryIdx;
var int SelectedTraderIdx;
var Array<Ext_WeaponProperties> OwnedWeapList;
var bool bIsInventorySelected;

var int SelectedPerkIdx;
var KFGUI_ComboBox PerkDropdown;
var array<class<KFPerk> > DropdownPerkList;

function LoadAvailableWeapons()
{
    local int i;
    local array<WeaponInfo> Weaponlist;
    local WeaponInfo WPI;
    local Ext_WeaponProperties WPP;

    if (KFPC.WeaponList.WeapInfos.Length == 0)
    {
        KFPC.ClientSyncWeaponList();
    }
    WeaponList = KFPC.WeaponList.WeapInfos;
    if (WeaponList.Length == 0)
    {
        return;
    }

    for (i = 0; i < WeaponList.Length; i++)
    {
        WPI = WeaponList[i];
        if (WPI.bBuyable)
        {
            WPP = new class'Ext_WeaponProperties';
            WPP.DefInit(WPI.WeaponDef, WPI.Remark);
            AvailableWeapons.AddItem(WPP);
        }
    }
    `log("LoadAvailableWeapons(): Loaded " @ AvailableWeapons.Length @ " available weapons from WeaponList.");
}

function FColumnItem NewFColumnItem(string Text, float Width)
{
    local FColumnItem NewItem;
    NewItem.Text = Text;
    NewItem.Width = Width;
    return NewItem;
}

/** Subobjects from defaultproperties are not duplicated reliably for `new(Self)` pages;
 *  leave Components empty in defaults and build here (see log: None in Components broke CaptureMouse). */
private function EnsureComponentsBuilt()
{
    local KFGUI_Base Icon;
    local KFGUI_GreenButton Btn;
    local KFGUI_ColumnList Inv, SaleComp;
    local KFGUI_ComponentList StatsComp;

    if (FindComponentID('WeaponUpgradeButton') != None)
        return;

    Components.Length = 0;

    Icon = new (Self) class'KFGUI_MultiComponent';
    Icon.ID = 'WeaponIconDisplay';
    Icon.XPosition = 0.01;
    Icon.YPosition = 0.02;
    Icon.XSize = 0.16;
    Icon.YSize = 0.25;
    Components.AddItem(Icon);
    Icon.Owner = Owner;
    Icon.ParentComponent = Self;

    Btn = new (Self) class'KFGUI_GreenButton';
    Btn.ID = 'WeaponUpgradeButton';
    Btn.XPosition = 0.01;
    Btn.YPosition = 0.28;
    Btn.XSize = 0.16;
    Btn.YSize = 0.05;
    Btn.ButtonText = "Upgrade";
    Components.AddItem(Btn);
    Btn.Owner = Owner;
    Btn.ParentComponent = Self;

    // Weapon stats ComponentList
    StatsComp = new (Self) class'KFGUI_ComponentList';
    StatsComp.ID = 'WeaponStatsList';
    StatsComp.XPosition = 0.18;
    StatsComp.YPosition = 0.02;
    StatsComp.XSize = 0.30;
    StatsComp.YSize = 0.28;
    StatsComp.ListItemsPerPage = 4;
    Components.AddItem(StatsComp);
    StatsComp.Owner = Owner;
    StatsComp.ParentComponent = Self;

    Inv = new (Self) class'KFGUI_ColumnList';
    Inv.ID = 'Weapons';
    Inv.XPosition = 0.01;
    Inv.YPosition = 0.34;
    Inv.XSize = 0.48;
    Inv.YSize = 0.64;
    Inv.BackgroundColor.R = 4;
    Inv.BackgroundColor.G = 30;
    Inv.BackgroundColor.B = 8;
    Inv.BackgroundColor.A = 255;
    Components.AddItem(Inv);
    Inv.Owner = Owner;
    Inv.ParentComponent = Self;

    SaleComp = new (Self) class'KFGUI_ColumnList';
    SaleComp.ID = 'Sale';
    SaleComp.XPosition = 0.50;
    SaleComp.YPosition = 0.08;
    SaleComp.XSize = 0.48;
    SaleComp.YSize = 0.90;

    PerkDropdown = new (Self) class'KFGUI_ComboBox';
    PerkDropdown.ID = 'PerkDropdown';
    PerkDropdown.XPosition = 0.50;
    PerkDropdown.YPosition = 0.02;
    PerkDropdown.XSize = 0.48;
    PerkDropdown.YSize = 0.05;
    PerkDropdown.ListBackgroundColor = MakeColor(4, 30, 8, 255);
    PerkDropdown.ListBorderColor = MakeColor(8, 60, 16, 255);
    PerkDropdown.ListHoverColor = MakeColor(32, 128, 32, 255);
    PerkDropdown.BoxColor = MakeColor(4, 30, 8, 255);
    PerkDropdown.SelectedTextColor = MakeColor(128, 255, 128, 255);
    Components.AddItem(PerkDropdown);
    PerkDropdown.Owner = Owner;
    PerkDropdown.ParentComponent = Self;
    SaleComp.BackgroundColor.R = 4;
    SaleComp.BackgroundColor.G = 30;
    SaleComp.BackgroundColor.B = 8;
    SaleComp.BackgroundColor.A = 255;
    Components.AddItem(SaleComp);
    SaleComp.Owner = Owner;
    SaleComp.ParentComponent = Self;
}

function InitMenu()
{
    KFPC = ExtPlayerController(GetPlayer());
    if (KFPC == None)
    {
        `log("Error: UIP_WeaponPage could not get player controller reference.");
        return;
    }
    KFPC.WeaponPage = Self;
    KFPRI = ExtPlayerReplicationInfo(KFPC.PlayerReplicationInfo);

    EnsureComponentsBuilt();

    LoadAvailableWeapons();

    WeaponIconDisplay = FindComponentID('WeaponIconDisplay');
    BuyWeaponButton = KFGUI_Button(FindComponentID('WeaponUpgradeButton'));

    InventoryList = KFGUI_ColumnList(FindComponentID('Weapons'));
    InventoryList.Columns.AddItem(NewFColumnItem(ColumnWeaponText, 0.32));
    // WeaponList.Columns.AddItem(NewFColumnItem(ColumnPriceText, 0.10));
    InventoryList.Columns.AddItem(NewFColumnItem(ColumnDamageText, 0.10));
    InventoryList.Columns.AddItem(NewFColumnItem(ColumnPenetrationText, 0.12));

    SaleList = KFGUI_ColumnList(FindComponentID('Sale'));
    SaleList.Columns.AddItem(NewFColumnItem(ColumnWeaponText, 0.32));
    SaleList.Columns.AddItem(NewFColumnItem(ColumnPriceText, 0.10));
    SaleList.Columns.AddItem(NewFColumnItem(ColumnDamageText, 0.10));
    SaleList.Columns.AddItem(NewFColumnItem(ColumnPenetrationText, 0.12));

    // InitWeaponProperties();

    Super.InitMenu();

    if (PerkDropdown != None)
    {
        PerkDropdown.OnComboChanged = OnPerkDropdownChanged;
    }

    InventoryList.OnSelectedRow = OnInventorySelected;
    SaleList.OnSelectedRow = OnTraderSelected;

    if (BuyWeaponButton != None)
    {
        BuyWeaponButton.OnClickLeft = OnBuyWeaponClicked;
        BuyWeaponButton.OnClickRight = OnBuyWeaponClicked;
    }

    // Find stats component list
    WeaponStatsList = KFGUI_ComponentList(FindComponentID('WeaponStatsList'));
}

function PopulatePerkDropdown()
{
    local int i;
    local int CurrentPerkIdx;
    local ExtPerkManager CurrentManager;
    local class<KFPerk> BP;

    if (PerkDropdown == None || KFPC == None) return;

    DropdownPerkList.Length = 0;
    PerkDropdown.Values.Length = 0;
    
    DropdownPerkList.AddItem(None);
    PerkDropdown.Values.AddItem("All Perks");

    CurrentPerkIdx = -1;

    CurrentManager = KFPC.ActivePerkManager;
    if (CurrentManager != None)
    {
        for (i = 0; i < CurrentManager.UserPerks.Length; i++)
        {
            if (CurrentManager.UserPerks[i] == None) continue;

            BP = CurrentManager.UserPerks[i].BasePerk;
            DropdownPerkList.AddItem(BP);
            PerkDropdown.Values.AddItem(BP.default.PerkName);
            
            if (KFPRI != None && KFPRI.ECurrentPerk.default.BasePerk == BP)
            {
                SelectedPerkIdx = i + 1;
            }
        }
    }
    
    PerkDropdown.SelectedIndex = SelectedPerkIdx;
}

function OnPerkDropdownChanged(KFGUI_ComboBox Sender)
{
    if (Sender.SelectedIndex >= 0 && Sender.SelectedIndex < DropdownPerkList.Length)
    {
        SelectedPerkIdx = Sender.SelectedIndex;
    }
    else
    {
        SelectedPerkIdx = -1;
    }
    
    Timer();
}

function ShowMenu()
{
    Super.ShowMenu();
    
    PopulatePerkDropdown();
    
    class'Ext_WeaponProperties'.static.SetMaxLvs(KFPRI);

    SetTimer(2.0, true);
    Timer();
}

function CloseMenu()
{
    Super.CloseMenu();
    SetTimer(0, false);
    
    // Clear selection state
    // SelectedInventoryIdx = -1;
    // SelectedTraderIdx = -1;
}

function bool CanAfford(Ext_WeaponProperties WPP)
{
    if (WPP == None)
        return false;
    return KFPRI.Score >= WPP.BasePrice;
}

function Timer()
{
    local class<KFWeaponDefinition> WPD;
    local class<KFWeapon> WPC;
    local Ext_WeaponProperties WPP;
    local KFWeapon KFW;
    local Pawn P;
    local int Dmg;
    local int Pnt;
    local int Price;
    local ExtPlayerController LocalPC;
    local int idx;
    local int PropIdx;
    local bool bHasWeapon;
    local array< class<KFPerk> > WeaponPerks;

    LocalPC = ExtPlayerController(GetPlayer());
    if (LocalPC == none) return;

    // Update max levels if perk info is now available
    if (KFPRI != None && KFPRI.FCurrentPerk != None)
    {
        class'Ext_WeaponProperties'.static.SetMaxLvs(KFPRI);
    }

    P = LocalPC.Pawn;
    if (P == None || P.InvManager == None) return;

    // weapon inventory list
    InventoryList.EmptyList();
    OwnedWeapList = LocalPC.InvProperties;
    if (SelectedInventoryIdx <= 0 || SelectedInventoryIdx >= OwnedWeapList.Length) 
    {
        SelectedInventoryIdx = 0;
    }
        
    for (idx = 0; idx < OwnedWeapList.Length; idx++)
    {
        WPP = OwnedWeapList[idx];
        KFW = OwnedWeapList[idx].WeaponInstance;
        if (KFW == None) continue;
        
        Dmg = Round(KFW.InstantHitDamage[0]);
        Pnt = KFW.PenetrationPower[0];
        InventoryList.AddLine(WPP.WeaponDef.static.GetItemName() @ "\n" @ Dmg @ "\n" @ Pnt, idx);
    }

    // trader weapon list
    SaleList.EmptyList();
    SaleListMap.Length = 0;
    if (SelectedTraderIdx <= 0 || SelectedTraderIdx >= AvailableWeapons.Length) 
    {
        SelectedTraderIdx = 0;
    }

    for (idx = 0; idx < AvailableWeapons.Length; idx++)
    {
        WPP = AvailableWeapons[idx];
        WPC = WPP.WeaponClass;
        WPD = WPP.WeaponDef;
        if (WPP == None)
        {
            `log("WeaponPage: WPP is None for index " @ idx);
            continue;
        }
        
        // Check if player already has this weapon in inventory
        bHasWeapon = false;
        // Skip if player already owns this weapon
        if (KFPC.FindWeaponProperties(WPC, PropIdx))
        {
            // `log("WeaponPage: Player already owns " @ WPD.default.WeaponClassPath);
            continue;
        }
        
        // Add to visible list and map
        SaleListMap.AddItem(idx);
        
        // hide weapons of different perks
        WeaponPerks = WPC.static.GetAssociatedPerkClasses();
        if (SelectedPerkIdx != -1 && WeaponPerks.Find(DropdownPerkList[SelectedPerkIdx]) == INDEX_NONE)
        {
            continue;
        }

        Price = WPP.BasePrice;
        Dmg = Round(WPC.static.CalculateTraderWeaponStatDamage());
        Pnt = Round(WPC.default.PenetrationPower[0]);
        SaleList.AddLine(WPD.static.GetItemName() @ "\n" @ Price @ "\n" @ Dmg @ "\n" @ Pnt, SaleListMap.Length - 1);
        `log("WeaponPage: Added " @ WPD.static.GetItemName() @ " to sale list with price " @ Price);
    }

    // SelectedInventoryWeap = KeepInvWeap;

    // Update weapon icon display if a weapon is selected
    UpdateWeaponIconDisplay();
}

function OnInventorySelected(KFGUI_ListItem Item, int Row, bool bRight, bool bDblClick)
{
    if (Item != None && Item.Value >= 0 && Item.Value < OwnedWeapList.Length)
    {
        SelectedInventoryIdx = Item.Value;
        bIsInventorySelected = true;
        BuyWeaponButton.SetDisabled(false);
        UpdateWeaponIconDisplay();
    }
}

function OnTraderSelected(KFGUI_ListItem Item, int Row, bool bRight, bool bDblClick)
{
    if (Item != None && Item.Value >= 0 && Item.Value < SaleListMap.Length)
    {
        SelectedTraderIdx = SaleListMap[Item.Value];
        bIsInventorySelected = false;
        BuyWeaponButton.SetDisabled(false);
        UpdateWeaponIconDisplay();
    }
}

function OnBuyWeaponClicked(KFGUI_Button Sender)
{
    local Ext_WeaponProperties WPP;
    local ExtPlayerController EXTPC;
    local ExtPlayerReplicationInfo ExtPri;
    local ExtHumanPawn EXTP;
    local KFWeapon SpawnedWeapon;

    EXTPC = ExtPlayerController(GetPlayer());
    if (EXTPC == None)
        return;

    ExtPri = ExtPlayerReplicationInfo(EXTPC.PlayerReplicationInfo);
    if (ExtPri == None)
        return;

    EXTP = ExtHumanPawn(EXTPC.Pawn);
    if (EXTP == None)
        return;

    if (bIsInventorySelected)
    {
        // Sell the selected inventory weapon
        if (SelectedInventoryIdx < 0)
            return;
        SellSelectedWeapon(EXTPC, EXTP);
    }
    else
    {
        // Buy the selected trader weapon
        WPP = AvailableWeapons[SelectedTraderIdx];
        
        if (WPP == None || !CanAfford(WPP)) return;

        `log("Purchase weapon: " @ WPP.WeaponClass @ " for " @ WPP.BasePrice);
        
        // Call server function to purchase weapon and deduct dosh atomically
        EXTPC.ServerPurchaseWeapon(WPP.WeaponClass, WPP.BasePrice);

    }
    Timer();
}

private function SellSelectedWeapon(ExtPlayerController EXTPC, ExtHumanPawn EXTP)
{
    local Inventory Inv;

    if (SelectedInventoryIdx < 0)
        return;

    // Call server function to sell weapon and add dosh atomically
    EXTPC.ServerSellWeapon(SelectedInventoryIdx);

    // Clear selection and refresh
    SelectedInventoryIdx = -1;
    bIsInventorySelected = false;
    Timer();
}

function UpdateWeaponIconDisplay()
{
    if (BuyWeaponButton != None)
    {
        if (bIsInventorySelected)
        {
            BuyWeaponButton.ButtonText = "Sell";
        }
        else
        {
            BuyWeaponButton.ButtonText = "Buy";
        }
    }
    UpdateStatsDisplay();
}

function UpdateStatsDisplay()
{
    local ExtPlayerController LocalPC;
    local ExtPlayerReplicationInfo ExtPri;

    LocalPC = ExtPlayerController(GetPlayer());
    if (LocalPC == None || !bIsInventorySelected || SelectedInventoryIdx < 0 || SelectedInventoryIdx >= LocalPC.InvProperties.Length)
    {
        ClearStatRows();
        return;
    }

    if (LocalPC.InvProperties[SelectedInventoryIdx].bCanBeSold)
        BuyWeaponButton.SetDisabled(false);
    else
        BuyWeaponButton.SetDisabled(true);

    ExtPRI = ExtPlayerReplicationInfo(LocalPC.PlayerReplicationInfo);
    if (ExtPRI == None)
    {
        ClearStatRows();
        return;
    }

    UpdateStatRows(LocalPC.InvProperties[SelectedInventoryIdx]);
}

private function ClearStatRows()
{
    local int i;

    if (WeaponStatsList == None) return;

    for (i = 0; i < StatRows.Length; i++)
        StatRows[i].CloseMenu();
    StatRows.Length = 0;
    WeaponStatsList.ItemComponents.Length = 0;
}

private function UpdateStatRows(Ext_WeaponProperties WPP)
{
    local UIR_WeaponStatRow StatRow;
    local int i;
    local array<UpgradeTypes> Upgradables;
    local UpgradeTypes UT;

    if (WPP == None || WeaponStatsList == None)
    {
        ClearStatRows();
        return;
    }

    // Rebuild only if the set of upgradable stats has changed
    if (StatRowsMatch(WPP))
    {
        // Same stats, just update values
        for (i = 0; i < StatRows.Length; i++)
        {
            switch (StatRows[i].StatType)
            {
            case DamageUp:
                StatRows[i].SetStatInfo("Damage:" @ WPP.GetUpgradeInfo(DamageUp), WPP.NextDmgCost, WPP.CanAddDamage());
                break;
            case AoEUp:
                StatRows[i].SetStatInfo("AoE:" @ WPP.GetUpgradeInfo(AoEUp), WPP.NextAoECost, WPP.CanAddAoE());
                break;
            case PenetrationUp:
                StatRows[i].SetStatInfo("Penetration:" @ WPP.GetUpgradeInfo(PenetrationUp), WPP.NextPenetrationCost, WPP.CanAddPenetration());
                break;
            case DoTUp:
                StatRows[i].SetStatInfo("DoT:" @ WPP.GetUpgradeInfo(DoTUp), WPP.NextDoTCost, WPP.CanAddDot());
                break;
            }
        }
        return;
    }

    // Stats changed, rebuild rows
    ClearStatRows();

    // Get upgradable stats and create rows dynamically
    Upgradables = WPP.GetUpgradables();
    // `log("WeaponPage: Upgradables.Length=" @ Upgradables.Length);
    
    for (i = 0; i < Upgradables.Length; i++)
    {
        UT = Upgradables[i];
        StatRow = UIR_WeaponStatRow(WeaponStatsList.AddListComponent(class'UIR_WeaponStatRow'));
        StatRow.ParentPage = Self;
        StatRow.InitMenu();
        
        switch (UT)
        {
            case DamageUp:
                StatRow.StatType = UT;
                StatRow.SetStatInfo("Damage:" @ WPP.GetUpgradeInfo(DamageUp), WPP.NextDmgCost, WPP.CanAddDamage());
                break;
            case AoEUp:
                StatRow.StatType = UT;
                StatRow.SetStatInfo("AoE:" @ WPP.GetUpgradeInfo(AoEUp), WPP.NextAoECost, WPP.CanAddAoE());
                break;
            case PenetrationUp:
                StatRow.StatType = UT;
                StatRow.SetStatInfo("Penetration:" @ WPP.GetUpgradeInfo(PenetrationUp), WPP.NextPenetrationCost, WPP.CanAddPenetration());
                break;
            case DoTUp:
                StatRow.StatType = UT;
                StatRow.SetStatInfo("DoT:" @ WPP.GetUpgradeInfo(DoTUp), WPP.NextDoTCost, WPP.CanAddDot());
                break;
        }
        
        StatRows.AddItem(StatRow);
    }
}

// Check if existing stat rows still match the weapon's upgradable stats
private function bool StatRowsMatch(Ext_WeaponProperties WPP)
{
    local int i;
    local array<int> AvailableUpgrades;
    local array<UpgradeTypes> Upgradables;
    local UpgradeTypes UT;

    // Get the list of upgradable stats from the weapon properties
    Upgradables = WPP.GetUpgradables();
    
    // Convert UpgradeTypes enum to StatType integers
    for (i = 0; i < Upgradables.Length; i++)
    {
        UT = Upgradables[i];
        switch (UT)
        {
            case DamageUp:
                AvailableUpgrades.AddItem(UT);
                break;
            case AoEUp:
                AvailableUpgrades.AddItem(UT);
                break;
            case PenetrationUp:
                AvailableUpgrades.AddItem(UT);
                break;
            case DoTUp:
                AvailableUpgrades.AddItem(UT);
                break;
        }
    }

    if (StatRows.Length != AvailableUpgrades.Length)
        return false;

    for (i = 0; i < StatRows.Length; i++)
    {
        if (StatRows[i].StatType != AvailableUpgrades[i])
            return false;
    }
    return true;
}

simulated function OnUpgradeClicked(KFGUI_Button Sender, UpgradeTypes StatType, bool bMax = false)
{
    local ExtPlayerController EXTPC;
    local Ext_WeaponProperties WPP;

    // `log("UIP_WeaponPage.OnUpgradeDamage: bIsInventorySelected=" @ bIsInventorySelected @ " SelectedInventoryIdx=" @ SelectedInventoryIdx);

    if (!bIsInventorySelected || SelectedInventoryIdx < 0)
    {
        // `log("UIP_WeaponPage.OnUpgradeDamage: Early return - invalid selection state");
        return;
    }

    EXTPC = ExtPlayerController(GetPlayer());
    `log("UIP_WeaponPage.OnUpgradeDamage: EXTPC=" @ EXTPC);
    if (EXTPC == None)
    {
        // `log("UIP_WeaponPage.OnUpgradeDamage: Early return - EXTPC is None");
        return;
    }
    
    // Verify the weapon property exists before calling server
    if (SelectedInventoryIdx >= EXTPC.InvProperties.Length)
    {
        // `log("UIP_WeaponPage.OnUpgradeDamage: ERROR - SelectedInventoryIdx (" @ SelectedInventoryIdx @ ") >= InvProperties.Length (" @ EXTPC.InvProperties.Length @ ")");
        return;
    }
    
    WPP = EXTPC.InvProperties[SelectedInventoryIdx];
    if (WPP == None)
    {
        // `log("UIP_WeaponPage.OnUpgradeDamage: ERROR - InvProperties[" @ SelectedInventoryIdx @ "] is None");
        return;
    }
    
    // `log("UIP_WeaponPage.OnUpgradeDamage: Valid weapon found - " @ WPP.WeaponDef.default.WeaponClassPath);
    // `log("UIP_WeaponPage.OnUpgradeDamage: Calling ServerUpgradeWeaponDamage(" @ SelectedInventoryIdx @ ")");
    if (bMax)
        EXTPC.ServerUpgradeMax(SelectedInventoryIdx, StatType);
    else
        EXTPC.ServerUpgradeWeapon(SelectedInventoryIdx, StatType);
}

function DrawWeaponIcon(class<KFWeapon> KFW, Canvas C, float X, float Y, float Width, float Height)
{
    local Texture2D Tex;
    local float DrawW, DrawH;

    if (KFW != None)
    {
        Tex = KFW.default.WeaponSelectTexture;
        if (Tex != None)
        {
            DrawW = Width;
            DrawH = DrawW * (float(Tex.SizeY) / float(Tex.SizeX));
            if (DrawH > Height)
            {
                DrawH = Height;
                DrawW = DrawH * (float(Tex.SizeX) / float(Tex.SizeY));
            }
            X += (Width - DrawW) / 2.0;
            Y += (Height - DrawH) / 2.0;

            C.SetPos(X, Y);
            C.DrawTile(Tex, DrawW, DrawH, 0, 0, Tex.SizeX, Tex.SizeY);
        }
    }
}

// function DrawWeaponClassIcon(class<KFWeapon> WPC, Canvas C, float X, float Y, float Width, float Height)
// {
//     local Texture2D Tex;
//     local float DrawW, DrawH;

//     if (WPC != None)
//     {
//         Tex = WPC.default.WeaponSelectTexture;
//         if (Tex != None)
//         {
//             DrawW = Width;
//             DrawH = DrawW * (float(Tex.SizeY) / float(Tex.SizeX));
//             if (DrawH > Height)
//             {
//                 DrawH = Height;
//                 DrawW = DrawH * (float(Tex.SizeX) / float(Tex.SizeY));
//             }
//             X += (Width - DrawW) / 2.0;
//             Y += (Height - DrawH) / 2.0;

//             C.SetPos(X, Y);
//             C.DrawTile(Tex, DrawW, DrawH, 0, 0, Tex.SizeX, Tex.SizeY);
//         }
//     }
// }

function Ext_WeaponProperties GetWeaponProperties(class<KFWeapon> KFW)
{
    local Ext_WeaponProperties WPP;
    foreach AvailableWeapons(WPP)
    {
        if (WPP.WeaponClass == KFW)
            return WPP;
    }
    return None;
}

function DrawMenu()
{
    local float X, Y, W, H;
    local int idx, i;
    local class<KFWeapon> WP2Draw;
    
    Super.DrawMenu();
    
    if (WeaponIconDisplay != None)
    {
        // Coordinates must be relative to the Component's origin!
        X = WeaponIconDisplay.CompPos[0] - CompPos[0];
        Y = WeaponIconDisplay.CompPos[1] - CompPos[1];
        W = WeaponIconDisplay.CompPos[2];
        H = WeaponIconDisplay.CompPos[3];
        
        Canvas.SetDrawColor(255, 255, 255, 255);
        
        if (bIsInventorySelected)
        {
            if (SelectedInventoryIdx < 0) return;
            WP2Draw = OwnedWeapList[SelectedInventoryIdx].WeaponClass;
        }
        else
        {
            if (SelectedTraderIdx == -1 || SelectedTraderIdx >= AvailableWeapons.Length) return;
            WP2Draw = AvailableWeapons[SelectedTraderIdx].WeaponClass;
        }

        DrawWeaponIcon(WP2Draw, Canvas, X, Y, W, H);
    }
}

defaultproperties
{
}