Class UIR_WeaponStatRow extends KFGUI_MultiComponent;

var KFGUI_TextLable InfoText;
var KFGUI_Button UpgradeButton;
var KFGUI_Button MaxButton;

var UpgradeTypes StatType; // 0=Damage, 1=AoE, 2=Penetration, 3=DoT
var UIP_WeaponPage ParentPage;

var localized string UpgradeText;
var localized string MaxText;

function InitMenu()
{
    InfoText = KFGUI_TextLable(FindComponentID('Info'));
    UpgradeButton = KFGUI_Button(FindComponentID('UpgradeBtn'));
    MaxButton = KFGUI_Button(FindComponentID('MaxBtn'));

    Super.InitMenu();
}

function SetStatInfo(string Info, int Cost, bool bCanUpgrade)
{
    if (InfoText != None)
        InfoText.SetText(Info);

    if (UpgradeButton != None)
    {
        UpgradeButton.ButtonText = "+1";
        UpgradeButton.SetDisabled(!bCanUpgrade);
    }
    if (MaxButton != None)
    {
        MaxButton.ButtonText = "Max";
        MaxButton.SetDisabled(!bCanUpgrade);
    }
}

function OnMaxClicked(KFGUI_Button Sender)
{
    if (ParentPage == None) return;

    ParentPage.OnUpgradeClicked(Sender, StatType, true);
}

function OnUpgradeClicked(KFGUI_Button Sender)
{
    if (ParentPage == None) return;

    ParentPage.OnUpgradeClicked(Sender, StatType);
}

defaultproperties
{
    Begin Object Class=KFGUI_TextLable Name=StatInfoLabel
        ID="Info"
        XPosition=0.01
        YPosition=0.2
        XSize=0.6
        YSize=0.7
        AlignX=0
        AlignY=1
        TextFontInfo=(bClipText=true)
    End Object
    Begin Object Class=KFGUI_Button Name=StatUpgradeBtn
        ID="UpgradeBtn"
        XPosition=0.78
        YPosition=0.1
        XSize=0.1
        YSize=0.8
        ButtonText="0"
        OnClickLeft=OnUpgradeClicked
        OnClickRight=OnUpgradeClicked
    End Object
    Begin Object Class=KFGUI_Button Name=StatMaxBtn
        ID="MaxBtn"
        XPosition=0.9
        YPosition=0.1
        XSize=0.15
        YSize=0.8
        ButtonText="0"
        OnClickLeft=OnMaxClicked
        OnClickRight=OnMaxClicked
    End Object

    Components.Add(StatInfoLabel)
    Components.Add(StatUpgradeBtn)
    Components.Add(StatMaxBtn)
}
