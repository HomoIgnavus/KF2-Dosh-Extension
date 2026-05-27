class UIR_TransferPlayer extends KFGUI_MultiComponent;

var KFGUI_TextLable InfoText;
var KFGUI_NumericBox AmountBox;
var KFGUI_Button TransferButton;

var KFPlayerReplicationInfo MyPRI;
var KFPlayerReplicationInfo TargetPRI;

var localized string TransferButtonToolTip;
var localized string AmountBoxToolTip;

function InitMenu()
{
	MyPRI = KFPlayerReplicationInfo(GetPlayer().PlayerReplicationInfo);
	InfoText = KFGUI_TextLable(FindComponentID('Info'));
	AmountBox = KFGUI_NumericBox(FindComponentID('AmountBox'));
	TransferButton = KFGUI_Button(FindComponentID('AddBox'));
	
	TransferButton.ToolTip = TransferButtonToolTip;
	TransferButton.OnClickLeft = OnTransferClicked;
	AmountBox.ToolTip = AmountBoxToolTip;
	
	Super.InitMenu();
}

function OnTransferClicked(KFGUI_Button Sender)
{
	local int AmountTransfered;
	if (MyPRI == none || TargetPRI == none) return;

	AmountTransfered = int(AmountBox.Value);
	MyPRI.AddDosh(-AmountTransfered);
	TargetPRI.AddDosh(AmountTransfered);
}

function ShowMenu()
{
	Super.ShowMenu();
	if (TargetPRI != None)
	{
		SetTimer(0.1, true);
		Timer();
	}
}

function CloseMenu()
{
	Super.CloseMenu();
	TargetPRI = None;
	SetTimer(0, false);
}

function SetTargetPRI(KFPlayerReplicationInfo PRI)
{
	TargetPRI = PRI;
	AmountBox.Value = "50";
	Timer();
}

function Timer()
{
	local int MyScore;

	if (TargetPRI == None || GetPlayer() == None || GetPlayer().PlayerReplicationInfo == None)
	{
		SetTimer(0, false);
		return;
	}

	MyPRI = KFPlayerReplicationInfo(GetPlayer().PlayerReplicationInfo);
	MyScore = int(MyPRI.Score);
	
	InfoText.SetText(TargetPRI.PlayerName @ "(" $ int(TargetPRI.Score) $ ")");
	
	AmountBox.MaxValue = MyScore;
	if (AmountBox.MaxValue == 0)
	{
		AmountBox.MinValue = 0;
	}
	else
	{
		AmountBox.MinValue = 1;
	}
	AmountBox.ChangeValue(AmountBox.Value);
	
	TransferButton.SetDisabled(MyScore <= 0 || AmountBox.GetValueInt() <= 0);
}

function BuyStatPoint(KFGUI_Button Sender)
{
	local int Amount;

	Amount = AmountBox.GetValueInt();
	if (Amount > 0 && TargetPRI != None)
	{
		GetPlayer().ConsoleCommand("mutate SendDosh " $ TargetPRI.PlayerID $ " " $ Amount);
	}
}

defaultproperties
{
	Begin Object Class=KFGUI_TextLable Name=InfoLable
		ID="Info"
		XPosition=0
		YPosition=0.2
		XSize=0.71
		YSize=0.7
		AlignX=0
		AlignY=1
		TextFontInfo=(bClipText=true)
	End Object
	Begin Object Class=KFGUI_NumericBox Name=BuyCount
		ID="AmountBox"
		XPosition=0.72
		YPosition=0.1
		XSize=0.18
		YSize=0.8
		MaxValue=99999
		MinValue=1
		bScaleByFontSize=false
	End Object
	Begin Object Class=KFGUI_Button Name=AddSButton
		ID="AddBox"
		XPosition=0.91
		YPosition=0.1
		XSize=0.08
		YSize=0.8
		ButtonText="+"
		OnClickLeft=BuyStatPoint
		OnClickRight=BuyStatPoint
	End Object

	Components.Add(InfoLable)
	Components.Add(BuyCount)
	Components.Add(AddSButton)
}
