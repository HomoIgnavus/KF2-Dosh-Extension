class UI_FinanceMenu extends KFGUI_FloatingWindow;

var localized string BankingButtonText;
var localized string TraderButtonText;
var localized string AbilityButtonText;
var localized string CloseButtonText;
var localized string CloseButtonToolTip;

enum DoshMenuButtonIDs
{
    DoshMenuWeapon,
    DoshMenuAbility,
    DoshMenuBanking,
    DoshMenuUndefined,
};

var array<KFGUI_MultiComponent> SubPages;
var array<KFGUI_Button> TabButtons;
var DoshMenuButtonIDs CurrentPageIndex;
var int PageComponentIndex;

function InitMenu()
{
    local KFGUI_GreenButton B;
    local UIP_TransferPage BankingPage;
    local UIP_WeaponPage TraderPage;
    local UIP_SpAbilPage SpAbilPage;

    Super.InitMenu();
    SubPages.Length = DoshMenuUndefined;

    TraderPage = new (Self) class'UIP_WeaponPage';
    TraderPage.Owner = Owner;
    TraderPage.ParentComponent = Self;
    TraderPage.XPosition = 0.01;
    TraderPage.YPosition = 0.145;
    TraderPage.XSize = 0.98;
    TraderPage.YSize = 0.775;
    TraderPage.InitMenu();
    SubPages[DoshMenuWeapon] = TraderPage;

    SpAbilPage = new (Self) class'UIP_SpAbilPage';
    SpAbilPage.Owner = Owner;
    SpAbilPage.ParentComponent = Self;
    SpAbilPage.XPosition = 0.01;
    SpAbilPage.YPosition = 0.145;
    SpAbilPage.XSize = 0.98;
    SpAbilPage.YSize = 0.775;
    SpAbilPage.InitMenu();
    SubPages[DoshMenuAbility] = SpAbilPage;

    // Create and initialize sub-pages (NOT via AddComponent — avoids double InitMenu)
    BankingPage = new (Self) class'UIP_TransferPage';
    BankingPage.Owner = Owner;
    BankingPage.ParentComponent = Self;
    BankingPage.XPosition = 0.01;
    BankingPage.YPosition = 0.145;
    BankingPage.XSize = 0.98;
    BankingPage.YSize = 0.775;
    BankingPage.InitMenu();
    SubPages[DoshMenuBanking] = BankingPage;

    // Trader tab button (to the right of banking)
    B = new (Self) class'KFGUI_GreenButton';
    B.ButtonText = TraderButtonText;
    B.OnClickLeft = TabClicked;
    B.OnClickRight = TabClicked;
    B.IDValue = DoshMenuWeapon;
    B.XPosition = 0.01;
    B.YPosition = 0.08;
    B.XSize = 0.18;
    B.YSize = 0.055;
    TabButtons.AddItem(B);
    AddComponent(B);

    // Sp Weapon tab button (to the right of trader)
    B = new (Self) class'KFGUI_GreenButton';
    B.ButtonText = AbilityButtonText;
    B.OnClickLeft = TabClicked;
    B.OnClickRight = TabClicked;
    B.IDValue = DoshMenuAbility;
    B.XPosition = 0.20;
    B.YPosition = 0.08;
    B.XSize = 0.18;
    B.YSize = 0.055;
    TabButtons.AddItem(B);
    AddComponent(B);

    // Banking tab button
    B = new (Self) class'KFGUI_GreenButton';
    B.ButtonText = BankingButtonText;
    B.OnClickLeft = TabClicked;
    B.OnClickRight = TabClicked;
    B.IDValue = DoshMenuBanking;
    B.XPosition = 0.39;
    B.YPosition = 0.08;
    B.XSize = 0.18;
    B.YSize = 0.055;
    B.ExtravDir = 1;
    TabButtons.AddItem(B);
    AddComponent(B);

    // Close button at the bottom center
    B = new (Self) class'KFGUI_GreenButton';
    B.ButtonText = CloseButtonText;
    B.ToolTip = CloseButtonToolTip;
    B.OnClickLeft = CloseClicked;
    B.OnClickRight = CloseClicked;
    B.ID = 'Close';
    B.XPosition = 0.4;
    B.YPosition = 0.93;
    B.XSize = 0.2;
    B.YSize = 0.05;
    AddComponent(B);

    SelectPage(0);
}

function TabClicked(KFGUI_Button Sender)
{
    SelectPage(DoshMenuButtonIDs(Sender.IDValue));
}

final function SelectPage(DoshMenuButtonIDs ButtonID)
{
    local ExtPlayerController EPC;

    if (CurrentPageIndex >= 0 && PageComponentIndex >= 0)
    {
        TabButtons[CurrentPageIndex].bIsHighlighted = false;
        SubPages[CurrentPageIndex].CloseMenu();
        Components.Remove(PageComponentIndex, 1);
        PageComponentIndex = -1;
    }
    CurrentPageIndex = ButtonID;

    if (CurrentPageIndex == DoshMenuWeapon)
    {
        EPC = ExtPlayerController(GetPlayer());
        if (EPC != None)
        {
            EPC.ServerSetWeaponMaxLevels();
        }
    }

    TabButtons[CurrentPageIndex].bIsHighlighted = true;
    SubPages[CurrentPageIndex].ShowMenu();
    PageComponentIndex = Components.Length;
    Components.AddItem(SubPages[CurrentPageIndex]);
}

function DoClose()
{
    local ExtPlayerController KFPC;
	// apply weapon upgrade
    KFPC = ExtPlayerController(GetPlayer());
    if (KFPC != None && KFPC.bShouldApplyUpgrades)
    {
        KFPC.ApplyAllUpgrades();
    }

    super.DoClose();
}

function CloseClicked(KFGUI_Button Sender)
{
    DoClose();
}

function DrawMenu()
{
    local int XS, YS, CornerSlope, TitleHeight;
    local GUIStyleBase Style;

    Style = Owner.CurrentStyle;
    XS = Style.Canvas.ClipX - Style.Canvas.OrgX;
    YS = Style.Canvas.ClipY - Style.Canvas.OrgY;
    CornerSlope = Style.DefaultHeight * 0.4;
    TitleHeight = Style.DefaultHeight;

    if (bWindowFocused)
        Style.Canvas.SetDrawColor(2, 180, 30, 255);
    else
        Style.Canvas.SetDrawColor(1, 80, 15, FrameOpacity);

    Style.Canvas.SetPos(0, 0);
    Style.DrawCornerTex(CornerSlope, 0);
    Style.Canvas.SetPos(0, TitleHeight);
    Style.DrawCornerTex(CornerSlope, 3);
    Style.Canvas.SetPos(XS - CornerSlope, 0);
    Style.DrawCornerTex(CornerSlope, 1);
    Style.Canvas.SetPos(XS - CornerSlope, TitleHeight);
    Style.DrawCornerTex(CornerSlope, 2);

    Style.Canvas.SetPos(0, CornerSlope);
    Style.DrawWhiteBox(XS, TitleHeight - CornerSlope);
    Style.Canvas.SetPos(CornerSlope, 0);
    Style.DrawWhiteBox(XS - (CornerSlope * 2), CornerSlope);

    if (bWindowFocused)
        Style.Canvas.SetDrawColor(4, 30, 8, 255);
    else
        Style.Canvas.SetDrawColor(2, 15, 4, FrameOpacity);

    Style.Canvas.SetPos(0, TitleHeight);
    Style.DrawCornerTex(CornerSlope, 0);
    Style.Canvas.SetPos(XS - CornerSlope, TitleHeight);
    Style.DrawCornerTex(CornerSlope, 1);
    Style.Canvas.SetPos(0, YS - CornerSlope);
    Style.DrawCornerTex(CornerSlope, 2);
    Style.Canvas.SetPos(XS - CornerSlope, YS - CornerSlope);
    Style.DrawCornerTex(CornerSlope, 3);

    Style.Canvas.SetPos(CornerSlope, TitleHeight);
    Style.DrawWhiteBox(XS - (CornerSlope * 2), YS - TitleHeight);
    Style.Canvas.SetPos(0, TitleHeight + CornerSlope);
    Style.DrawWhiteBox(CornerSlope, YS - (CornerSlope * 2) - TitleHeight);
    Style.Canvas.SetPos(XS - CornerSlope, TitleHeight + CornerSlope);
    Style.DrawWhiteBox(CornerSlope, YS - (CornerSlope * 2) - TitleHeight);

    if (WindowTitle != "")
    {
        Style.Canvas.SetDrawColor(250, 250, 250, FrameOpacity);
        Style.Canvas.SetPos(CornerSlope, 0);
        Style.DrawText(Style.DefaultFontSize, WindowTitle);
    }

    if (HeaderComp != None)
    {
        HeaderComp.CompPos[3] = Style.DefaultHeight;
        HeaderComp.YSize = HeaderComp.CompPos[3] / CompPos[3];
    }
}

defaultproperties
{
    WindowTitle="Finance"
    XPosition=0.1
    YPosition=0.1
    XSize=0.8
    YSize=0.8
    CurrentPageIndex=-1
    PageComponentIndex=-1
}