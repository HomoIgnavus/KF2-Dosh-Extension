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

Class ExtPlayerController extends KFPlayerController
	dependson(Ext_TraitSA_Base);

var public ExtHumanPawn EHP;
var public ExtInventoryManager EIM;

var localized string GotItemText;
var localized string KilledHimselfWith;
var localized string WasBurnedToDeath;
var localized string WasBlownIntoPeaces;
var localized string HadSuddenHeartAttack;
var localized string WasKilledBy;
var localized string WasIncineratedBy;
var localized string WasBlownUpBy;
var localized string ConnectionError;
var localized string Disconnecting;
var localized string NowViewingFrom;
var localized string ViewingFromOwnCamera;

var UIP_WeaponPage WeaponPage;
var Ext_WeaponList WeaponList;
var array<Ext_WeaponProperties> InvProperties;

var array<SpecialAbilities> SpecialAbil;
var int AbilityGaugePerKill;

var public bool bCanRocketJump;

// medic hemo strike
var private array<vector> HemoStrikeLocs;
var private int HemoStrikeIdx;
var private int HemoStrikeMissilePerShot;
var private float HemoStrikeInterval;
var private bool bIsFiringHemoStrike;

// quantum shield
var KFGameExplosion QuantumShieldExploTemplate;

struct FAdminCmdType
{
	var string Cmd,Info;
};
enum EDmgMsgType
{
	DMG_PawnDamage,
	DMG_EXP,
	DMG_Heal,
};
var string ServerMOTD,PendingMOTD;

var ExtPerkManager ActivePerkManager;
var class<KFGUI_Page> MidGameMenuClass;
var class<Ext_PerkBase> PendingPerkClass;
var private transient rotator OldViewRot;
var private transient float LastMisfireTime,LastFireTime,MisfireTimer;
var private transient byte MisfireCount,MisrateCounter;
var transient float NextSpectateChange,NextCommTime;
var array<FAdminCmdType> AdminCommands;
var transient byte DropCount;
var transient Object UserAPI;
var transient SoundCue BonusMusic;
var transient Object BonusFX;

// Stats
var transient byte TransitListNum;
var transient int TransitIndex;

// Dramatic end-game camera.
var transient vector EndGameCamFocusPos[2],CalcViewLocation;
var transient rotator EndGameCamRot,CalcViewRotation;
var transient float EndGameCamTimer,LastPlayerCalcView;
var transient bool bEndGameCamFocus;

var globalconfig bool bShowFPLegs,bHideNameBeacons,bHideKillMsg,bHideDamageMsg,bHideNumberMsg,bNoMonsterPlayer,bNoScreenShake,bRenderModes,bUseKF2DeathMessages,bUseKF2KillMessages;
var globalconfig int SelectedEmoteIndex;
var bool bMOTDReceived,bNamePlateShown,bNamePlateHidden,bClientHideKillMsg,bClientHideDamageMsg,bClientHideNumbers,bNoDamageTracking,bClientNoZed,bSetPerk;

var byte CurrentSpecialAbility;

var repnotify WeaponUpgradeState WeaponUpgradeStates[15];
var bool bShouldApplyUpgrades;

struct SavedSkins
{
	var int ID;
	var class<KFWeaponDefinition> WepDef;
};
var globalconfig array<SavedSkins> SavedWeaponSkins;

replication
{
	// Things the server should send to the client.
	if (bNetDirty)
		MidGameMenuClass, ActivePerkManager, WeaponUpgradeStates, bShouldApplyUpgrades;
}

simulated event ReplicatedEvent(name VarName)
{
    if (Role < ROLE_Authority)
    {
		if (VarName == 'WeaponUpgradeStates')
        {
			// `log("ExtPlayerController.ReplicatedEvent: WeaponUpgradeStates replicated, syncing all upgrades");
			SyncPropAndUpgrades();
        	ApplyAllUpgrades();
			bShouldApplyUpgrades = false;
		}
    }
    
    Super.ReplicatedEvent(VarName);
}

event Possess(Pawn aPawn, bool bVehicleTransition)
{
	local class<Pawn> PawnClass;
    
    super.Possess(aPawn, bVehicleTransition);
    
    EHP = ExtHumanPawn(aPawn);
	EIM = ExtInventoryManager(aPawn.InvManager);

	if (aPawn != None)
		PawnClass = aPawn.Class;
	else
		PawnClass = class'Pawn';
	
	`log("ExtPlayerController.Possess: Role=" @ Role @ " aPawn=" @ aPawn @ " aPawn.Class=" @ string(PawnClass));
}

event UnPossess()
{
	super.UnPossess();
	EHP = None;
	EIM = None;
}

private function bool HasWeaponPropertyIndex(int PropIdx)
{
	return PropIdx >= 0 && PropIdx < InvProperties.Length && InvProperties[PropIdx] != None;
}

// recreate weapon upgrade states from the current weapon properties
private reliable server function ServerSyncWeaponUpgrades()
{
	local int PropIdx;
	local int UpIdx;

	for (PropIdx = 0; PropIdx < InvProperties.Length && PropIdx < 15; PropIdx++)
	{
		WeaponUpgradeStates[PropIdx] = InvProperties[PropIdx].GetUpgradeState();
	}

	// empty the remaining entries
	for (UpIdx = PropIdx; UpIdx < 15; UpIdx++)
	{
		WeaponUpgradeStates[UpIdx].bHasData = false;
	}
}

reliable server function ServerRecreateUpgradeStates()
{
	local int Idx;
	ServerClearUpgradeStates();
	
	for (Idx = 0; Idx < InvProperties.Length; Idx++)
	{
		WeaponUpgradeStates[Idx] = InvProperties[Idx].GetUpgradeState();
	}
	// bClientRecreateUpgradeStates = true;
}

reliable server function ServerRecreateWeaponProperties()
{
	local int Idx;
	local Inventory Inv;
	local KFWeapon KFW;
	local Ext_WeaponProperties WPP;
	local WeaponUpgradeState WUS;

	// clear existing stuffs
	InvProperties.Length = 0;
	ServerClearUpgradeStates();

	for (Inv = EHP.InvManager.InventoryChain; Inv != None; Inv = Inv.Inventory)
	{
		KFW = KFWeapon(Inv);
		if (
			KFW != None && WeaponList.IsUpgradable(KFW.Class)
			// KFW != None && 
			// (
			// 	(
			// 		!ClassIsChildOf(KFW.Class, class'KFweapDef_Knife_Base') &&
			// 		KFW.Class != class'ExtWeap_Pistol_9mm' && 
			// 		KFW.Class != class'ExtWeap_Pistol_MedicS' && 
			// 		KFW.Class != class'KFWeap_Welder' &&
			// 		KFW.Class != class'KFWeap_Healer_Syringe'
			// 	) ||
			// 	KFW.Class == class'ExtWeap_Knife_FieldMedicRapid' ||
			// 	KFW.Class == class'ExtWeap_Knife_Berserker_Mystic'
			// )
		)
		{
			WPP = new class'Ext_WeaponProperties';
			WPP.PCInit(self, KFW);
			InvProperties.AddItem(WPP);

			WUS = WPP.GetUpgradeState();
			WeaponUpgradeStates[InvProperties.Length - 1] = WUS;
		}
	}

	`log("ServerRecreateWeaponProperties() Created " @ InvProperties.Length @ " weapon properties");
}

// recreate Weapon Properties from the replicated upgrade states
reliable client function ClientRecreateWeaponProperties()
{
	local int Idx;
	local Inventory Inv;
	local KFPawn KFP;
	local KFWeapon KFW;
	local Ext_WeaponProperties WPP;
	local WeaponUpgradeState WUS;

	`log("ClientRecreateWeaponProperties called");

	KFP = KFPawn(Pawn);
	if (KFP == None)
	{ 
		`log("ExtPlayerController.ClientRecreateWeaponProperties: KFPawn is None, retrying in 1 second");
		SetTimer(1, false, 'ClientRecreateWeaponProperties');
		return;
	}

	if (KFP.InvManager == None)
	{
		`log("ExtPlayerController.ClientRecreateWeaponProperties: KFP.InvManager is None, retrying in 1 second");
		SetTimer(1, false, 'ClientRecreateWeaponProperties');
		return;
	}

	InvProperties.Length = 0;
	for (Idx = 0; Idx < 15; Idx++)
	{
		WUS = WeaponUpgradeStates[Idx];
		if (!WUS.bHasData) break;

		for (Inv = KFP.InvManager.InventoryChain; Inv != None; Inv = Inv.Inventory)
		{
			KFW = KFWeapon(Inv);
			if (KFW != None && KFW.Class == WUS.WeaponClass)
			{
					WPP = new class'Ext_WeaponProperties';
				WPP.PCInit(self, KFW);
				WPP.SyncUpgradeState(WUS);
				InvProperties.AddItem(WPP);
			}
		}
	}

	`log("ClientRecreateWeaponProperties() Created " @ InvProperties.Length @ " weapon properties");
}

function SyncPropAndUpgrades()
{
	if (Role == ROLE_Authority)
		ServerRecreateUpgradeStates();
	else
		ClientRecreateWeaponProperties();
}

function int GetStatesCount()
{
	local int idx;
	local int StatesCount;

	StatesCount = 0;
	for (Idx = 0; Idx < 15; Idx++)
	{
		if (!WeaponUpgradeStates[Idx].bHasData) break;
		StatesCount++;
	}

	return StatesCount;
}

function CheckPropAndUpgrades()
{
	local int idx;

	if (InvProperties.Length != GetStatesCount())
	{
		`log("ExtPlayerController.CheckPropAndUpgrades: InvProperties.Length != GetStatesCount()");
		SyncPropAndUpgrades();
		return;
	}

	for (idx = 0; idx < InvProperties.Length; idx++)
	{
		if (!WeaponUpgradeStates[idx].bHasData || InvProperties[idx].WeaponClass != WeaponUpgradeStates[idx].WeaponClass)
		{
			`log("ExtPlayerController.CheckPropAndUpgrades: Mismatch found at index " @ idx);
			SyncPropAndUpgrades();
			return;
		}
	}

	// check for excessive upgrade states
	for (idx = InvProperties.Length; idx < 15; idx++)
	{
		if (WeaponUpgradeStates[idx].bHasData)
		{
			`log("ExtPlayerController.CheckPropAndUpgrades: Unexpected upgrade state found at index " @ idx);
			WeaponUpgradeStates[idx].bHasData = false;
		}
	}
}

private function ApplyWeaponUpgrade(int PropIdx)
{

	if (InvProperties[PropIdx].WeaponInstance == None) 
	{
		`log("ExtPlayerController.ApplyWeaponUpgrade: WeaponInstance is None for PropIdx=" @ PropIdx);
		return;
	}

	if (!WeaponUpgradeStates[PropIdx].bHasData)
	{
		`log("ExtPlayerController.ApplyWeaponUpgrade: No upgrade data for PropIdx=" @ PropIdx);
		return;
	}

	if (WeaponUpgradeStates[PropIdx].WeaponClass != InvProperties[PropIdx].WeaponClass)
	{
		`log("ExtPlayerController.ApplyWeaponUpgrade: Mismatched weapon class for PropIdx=" @ PropIdx@ " on "@Role);
		CheckPropAndUpgrades();
	}

	// InvProperties[PropIdx].SyncUpgradeState(WeaponUpgradeStates[PropIdx]);
	InvProperties[PropIdx].ApplyModifiers();
	// `log("ExtPlayerController.ApplyWeaponUpgrade: weapon=" @ InvProperties[PropIdx].WeaponClass.Name @ " states=" @ WeaponUpgradeStates[PropIdx].DamageLv @ ", " @ WeaponUpgradeStates[PropIdx].AoELv @ ", " @ WeaponUpgradeStates[PropIdx].PenetrationLv @ ", " @ WeaponUpgradeStates[PropIdx].DotLv);
}

reliable server function ServerApplyAllUpgrades()
{
	ApplyAllUpgrades();
}

function ApplyAllUpgrades()
{
	local int Idx;
	// `log("ExtPlayerController.ApplyAllUpgrades: Executed on " @ Role);

	if (Role < ROLE_Authority)
	{
		ServerApplyAllUpgrades();
	}

	CheckPropAndUpgrades();
	
	for (Idx = 0; Idx < InvProperties.Length; Idx++)
	{
		ApplyWeaponUpgrade(Idx);
	}
	bShouldApplyUpgrades = false;
}

reliable server function ServerUpgradeWeapon(int PropIdx, UpgradeTypes UpType)
{
	local int AmountCharged;
	local KFPlayerReplicationInfo KFPRI;

	KFPRI = KFPlayerReplicationInfo(PlayerReplicationInfo);
	if (KFPRI == none) return;

	KFPRI.AddDosh(-UpgradeWeaponStat(PropIdx, UpType));
}

reliable client function ClientUpgradeWeaponStat(int PropIdx, UpgradeTypes UpType)
{
	UpgradeWeaponStat(PropIdx, UpType);
}

function int UpgradeWeaponStat(int PropIdx, UpgradeTypes UpType)
{
	local int AmountCharged;
	// local int AmountCharged;
	if (Role == role_Authority) 
	{
		ClientUpgradeWeaponStat(PropIdx, UpType);
	}

	`log("UpgradeWeaponStat executed on " @ Role);
	
	if (!HasWeaponPropertyIndex(PropIdx))
	{
		// `log("ExtPlayerController.ServerUpgradeWeaponDamage: FAILED - Invalid PropIdx");
		return 0;
	}

	// `log("ExtPlayerController.ServerUpgradeWeaponDamage: Calling AddDamage on InvProperties[" @ PropIdx @ "]");
	switch (UpType)
	{
		case DamageUp: 
			AmountCharged = InvProperties[PropIdx].AddDamage(); 
			if (AmountCharged > 0)
			{	
				WeaponUpgradeStates[PropIdx].DamageLv++;
			}
			break;
		case AoEUp: 
			AmountCharged = InvProperties[PropIdx].AddAoE(); 
			if (AmountCharged > 0)
			{	
				WeaponUpgradeStates[PropIdx].AoELv++;
			}
			break;
		case PenetrationUp: 
			AmountCharged = InvProperties[PropIdx].AddPenetration();
			if (AmountCharged > 0)
			{	
				WeaponUpgradeStates[PropIdx].PenetrationLv++;
			}
			break;
		case DoTUp: 
			AmountCharged = InvProperties[PropIdx].AddDot(); 
			if (AmountCharged > 0)
			{	
				WeaponUpgradeStates[PropIdx].DotLv++;
			}
			break;
		default:
			break;
	}

	bShouldApplyUpgrades = true;
	return AmountCharged;
	// `log("ExtPlayerController.ServerUpgradeWeaponDamage: Upgrade complete");
}

reliable server function ServerUpgradeMax(int PropIdx, UpgradeTypes UpType)
{
	local KFPlayerReplicationInfo KFPRI;

	KFPRI = KFPlayerReplicationInfo(PlayerReplicationInfo);
	if (KFPRI == none) return;

	KFPRI.AddDosh(-UpgradeMax(PropIdx, UpType, KFPRI.Score));
}

reliable client function ClientUpgradeMax(int PropIdx, UpgradeTypes UpType, int TotalCash)
{
	UpgradeMax(PropIdx, UpType, TotalCash);
}

function int UpgradeMax(int PropIdx, UpgradeTypes UpType, int TotalCash)
{
	local int LastCharged;
	local int TotalCharged;


	if (Role < ROLE_Authority)
	{
		ClientUpgradeMax(PropIdx, UpType, TotalCash);
	}
	
	`log("UpgradeMax executed on " @ Role);

	TotalCharged = 0;

	switch (UpType)
	{
		case DamageUp: 
			while (true)
			{
				LastCharged = InvProperties[PropIdx].AddDamage();
				if (LastCharged > 0 && LastCharged <= TotalCash)
				{
					WeaponUpgradeStates[PropIdx].DamageLv++;
					TotalCharged += LastCharged;
					TotalCash -= LastCharged;
				}
				else
					break;
			}
			break;
		case AoEUp: 
			while (true)
			{
				LastCharged = InvProperties[PropIdx].AddAoE();
				if (LastCharged > 0 && LastCharged <= TotalCash)
				{
					WeaponUpgradeStates[PropIdx].AoELv++;
					TotalCharged += LastCharged;
					TotalCash -= LastCharged;
				}
				else
					break;
			}
			break;
		case PenetrationUp: 
			while (true)
			{
				LastCharged = InvProperties[PropIdx].AddPenetration();
				if (LastCharged > 0 && LastCharged <= TotalCash)
				{
					WeaponUpgradeStates[PropIdx].PenetrationLv++;
					TotalCharged += LastCharged;
					TotalCash -= LastCharged;
				}
				else
					break;
			}
			break;
		case DoTUp: 
			while (true)
			{
				LastCharged = InvProperties[PropIdx].AddDot();
				if (LastCharged > 0 && LastCharged <= TotalCash)
				{
					WeaponUpgradeStates[PropIdx].DotLv++;
					TotalCharged += LastCharged;
					TotalCash -= LastCharged;
				}
				else
					break;
			}
			break;
		default:
			break;
	}

	bShouldApplyUpgrades = true;
	return TotalCharged;
}

simulated function PostBeginPlay()
{
	SetSpAbil(SpecialAbil[0]);
	
	InvProperties.Length = 0;
	if (WeaponList == None)
	{
		WeaponList = new class'Ext_WeaponList';
		WeaponList.LoadWeapons();
	}
	Super.PostBeginPlay();
	if (WorldInfo.NetMode!=NM_Client && ActivePerkManager==None)
	{
		ActivePerkManager = Spawn(class'ExtPerkManager',Self);
		ActivePerkManager.PlayerOwner = Self;
		ActivePerkManager.PRIOwner = ExtPlayerReplicationInfo(PlayerReplicationInfo);
		if (ActivePerkManager.PRIOwner!=None)
			ActivePerkManager.PRIOwner.PerkManager = ActivePerkManager;
		SetTimer(0.1,true,'CheckPerk');
	}

	InitWeaponProperties();
}

simulated function Destroyed()
{
	if (ActivePerkManager!=None)
		ActivePerkManager.PreNotifyPlayerLeave();
	Super.Destroyed();
	if (ActivePerkManager!=None)
		ActivePerkManager.Destroy();
}

function CheckPerk()
{
	if (CurrentPerk != ActivePerkManager)
	{
		CurrentPerk = ActivePerkManager;
		if (KFPlayerReplicationInfo(PlayerReplicationInfo)!=None)
		{
			KFPlayerReplicationInfo(PlayerReplicationInfo).NetPerkIndex = 0;
			if (ActivePerkManager.CurrentPerk != None)
			{
				KFPlayerReplicationInfo(PlayerReplicationInfo).CurrentPerkClass = ActivePerkManager.CurrentPerk.BasePerk;
			}
		}
	}
}

reliable client function AddAdminCmd(string S)
{
	local int i,j;

	j = InStr(S,":");
	i = AdminCommands.Length;
	AdminCommands.Length = i+1;
	if (j==-1)
	{
		AdminCommands[i].Cmd = S;
		AdminCommands[i].Info = S;
	}
	else
	{
		AdminCommands[i].Cmd = Left(S,j);
		AdminCommands[i].Info = Mid(S,j+1);
	}
}

reliable client function ClientSetHUD(class<HUD> newHUDType)
{
	Super.ClientSetHUD(newHUDType);
	SendServerSettings();
}

reliable client function ClientSetBonus(SoundCue C, Object FX)
{
	BonusMusic = C;
	BonusFX = FX;
}

simulated final function SendServerSettings()
{
	if (LocalPlayer(Player)!=None)
		ServerSetSettings(bHideKillMsg,bHideDamageMsg,bHideNumberMsg,bNoMonsterPlayer);
}

reliable server function ServerSetSettings(bool bHideKill, bool bHideDmg, bool bHideNum, bool bNoZ)
{
	bClientHideKillMsg = bHideKill;
	bClientHideDamageMsg = bHideDmg;
	bClientHideNumbers = bHideNum;
	bNoDamageTracking = (bHideDmg && bHideNum);
	bClientNoZed = bNoZ;
}

unreliable server function NotifyFixed(byte Mode)
{
	if (Mode==1 && (Pawn==None || (WorldInfo.TimeSeconds-Pawn.SpawnTime)<5.f))
		return;
	OnClientFixed(Self,Mode);
	if (Default.bRenderModes && ExtPlayerReplicationInfo(PlayerReplicationInfo)!=None)
		ExtPlayerReplicationInfo(PlayerReplicationInfo).SetFixedData(Mode);
}

delegate OnClientFixed(ExtPlayerController PC, byte Mode);

reliable client event ReceiveLocalizedMessage(class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	if (Message!=class'KFLocalMessage_PlayerKills' && (Message!=class'KFLocalMessage_Game' || (Switch!=KMT_Suicide && Switch!=KMT_Killed)))
		Super.ReceiveLocalizedMessage(Message,Switch,RelatedPRI_1,RelatedPRI_2,OptionalObject);
}

function AddZedKill(class<KFPawn_Monster> MonsterClass, byte Difficulty, class<DamageType> DT, bool bKiller)
{
	local int multiplyer;
	// Stats.
	if (ActivePerkManager!=None)
	{
		ActivePerkManager.TotalKills++;
		ActivePerkManager.PRIOwner.RepKills++;
	}

	if (EHP != None)
	{
		if (MonsterClass.static.IsABoss() || ClassIsChildOf(MonsterClass, class'KFPawn_MonsterBoss'))
		{
			multiplyer = 20;
		}
		else if (MonsterClass.static.IsLargeZed())
		{
			multiplyer = 5;
		}
		else
		{
			multiplyer = 1;
		}

		EHP.AddAbilityGauge(AbilityGaugePerKill * multiplyer);
	}
}

unreliable client function ClientPlayCameraShake(CameraShake Shake, optional float Scale=1.f, optional bool bTryForceFeedback, optional ECameraAnimPlaySpace PlaySpace=CAPS_CameraLocal, optional rotator UserPlaySpaceRot)
{
	if (!bNoScreenShake)
		Super.ClientPlayCameraShake(Shake,Scale,bTryForceFeedback,PlaySpace,UserPlaySpaceRot);
}

exec final function AwardXP(int XP, optional byte Mode)
{
	if (WorldInfo.NetMode!=NM_Client && ActivePerkManager!=None)
		ActivePerkManager.EarnedEXP(XP,Mode);
}

/** Perk xp stat */
function OnPlayerXPAdded(INT XP, class<KFPerk> PerkClass)
{
	AwardXP(XP);
}

function AddSmallRadiusKill(byte Difficulty, class<KFPerk> PerkClass)
{
	AwardXP(class'KFPerk_Berserker'.static.GetSmallRadiusKillXP(Difficulty));
}

function AddWeldPoints(int PointsWelded)
{
	AwardXP(PointsWelded,1);
}

function AddHealPoints(int PointsHealed)
{
	AwardXP(PointsHealed,2);
}

function AddShotsHit(int AddedHits)
{
	local KFWeapon W;
	local float T;

	Super.AddShotsHit(AddedHits);
	W = KFWeapon(Pawn.Weapon);
	if (W==None)
	{
		if (LastMisfireTime>WorldInfo.TimeSeconds)
		{
			if (++MisfireCount>15 && (WorldInfo.TimeSeconds-MisfireTimer)>10.f)
				NotifyFixed(8);
			LastMisfireTime = WorldInfo.TimeSeconds+2.f;
			return;
		}
		MisfireCount = 0;
		LastMisfireTime = WorldInfo.TimeSeconds+2.f;
		MisfireTimer = WorldInfo.TimeSeconds;
		return;
	}
	if (!W.HasAmmo(W.CurrentFireMode))
	{
		if (LastMisfireTime>WorldInfo.TimeSeconds)
		{
			if (++MisfireCount>15 && (WorldInfo.TimeSeconds-MisfireTimer)>10.f)
				NotifyFixed(16);
			LastMisfireTime = WorldInfo.TimeSeconds+2.f;
			return;
		}
		MisfireCount = 0;
		LastMisfireTime = WorldInfo.TimeSeconds+2.f;
		MisfireTimer = WorldInfo.TimeSeconds;
		return;
	}
	T = W.GetFireInterval(W.CurrentFireMode);
	ActivePerkManager.ModifyRateOfFire(T,W);
	if ((WorldInfo.TimeSeconds-LastFireTime)<(T*0.5) || !W.IsFiring())
	{
		if ((WorldInfo.TimeSeconds-LastFireTime)>4.f)
			MisrateCounter = 0;
		LastFireTime = WorldInfo.TimeSeconds;
		if (MisrateCounter<5)
		{
			++MisrateCounter;
			return;
		}
		if (LastMisfireTime>WorldInfo.TimeSeconds)
		{
			if (++MisfireCount>15 && (WorldInfo.TimeSeconds-MisfireTimer)>10.f)
				NotifyFixed(2);
			LastMisfireTime = WorldInfo.TimeSeconds+1.f;
			return;
		}
		MisfireCount = 0;
		LastMisfireTime = WorldInfo.TimeSeconds+1.f;
		MisfireTimer = WorldInfo.TimeSeconds;
	}
	else MisrateCounter = 0;
}

// Message of the day.
Delegate OnSetMOTD(ExtPlayerController PC, string S);
reliable client function ReceiveServerMOTD(string S, bool bFinal)
{
	ServerMOTD $= S;
	bMOTDReceived = bFinal;
}

reliable server function ServerSetMOTD(string S, bool bFinal)
{
	PendingMOTD $= S;
	if (bFinal && PendingMOTD!="")
	{
		OnSetMOTD(Self,PendingMOTD);
		PendingMOTD = "";
	}
}

// TESTING:
reliable server function ServerItemDropGet(string Item)
{
	if (DropCount>5 || Len(Item)>100)
		return;
	++DropCount;
	WorldInfo.Game.Broadcast(Self,PlayerReplicationInfo.GetHumanReadableName()@GotItemText@Item);
}

reliable client function ReceiveLevelUp(Ext_PerkBase Perk, int NewLevel)
{
	if (Perk!=None)
		MyGFxHUD.LevelUpNotificationWidget.ShowAchievementNotification(class'KFGFxWidget_LevelUpNotification'.Default.LevelUpString, Perk.PerkName, class'KFGFxWidget_LevelUpNotification'.Default.TierUnlockedString, Perk.GetPerkIconPath(NewLevel), false, NewLevel);
}

reliable client function ReceiveKillMessage(class<Pawn> Victim, optional bool bGlobal, optional PlayerReplicationInfo KillerPRI)
{
	if (bHideKillMsg || (bGlobal && KillerPRI==None))
		return;
	if (bUseKF2KillMessages)
	{
		if (MyGFxHUD != none)
		{
			ExtMoviePlayer_HUD(MyGFxHUD).ShowKillMessageX((bGlobal ? KillerPRI : None), None, ,false, Victim);
		}
	}
	else if (KFExtendedHUD(myHUD)!=None && Victim!=None)
		KFExtendedHUD(myHUD).AddKillMessage(Victim,1,KillerPRI,byte(bGlobal));
}

unreliable client function ReceiveDamageMessage(class<Pawn> Victim, int Damage)
{
	if (!bHideDamageMsg && KFExtendedHUD(myHUD)!=None && Victim!=None)
		KFExtendedHUD(myHUD).AddKillMessage(Victim,Damage,None,2);
}

unreliable client function ClientNumberMsg(int Count, vector Pos, EDmgMsgType Type)
{
	if (!bHideNumberMsg && KFExtendedHUD(myHUD)!=None)
		KFExtendedHUD(myHUD).AddNumberMsg(Count,Pos,Type);
}

reliable client event TeamMessage(PlayerReplicationInfo PRI, coerce string S, name Type, optional float MsgLifeTime )
{
	//if (((Type == 'Say') || (Type == 'TeamSay')) && (PRI != None))
	//	SpeakTTS(S, PRI); <- KF built without TTS...

	// since this is on the client, we can assume that if Player exists, it is a LocalPlayer
	if (Player!=None)
	{
		if (((Type == 'Say') || (Type == 'TeamSay')) && (PRI != None))
			S = PRI.GetHumanReadableName()$": "$S;
		LocalPlayer(Player).ViewportClient.ViewportConsole.OutputText("("$Type$") "$S);
	}

	if (MyGFxManager != none && MyGFxManager.PartyWidget != none)
	{
		if (!MyGFxManager.PartyWidget.ReceiveMessage(S))  //Fails if message is for updating perks in a steam lobby
			return;
	}

	if (MyGFxHUD != none)
	{
		switch (Type)
		{
		case 'Log':
			break; // Console only message.
		case 'Music':
			MyGFxHUD.MusicNotification.ShowSongInfo(S);
			break;
		case 'Event':
			MyGFxHUD.HudChatBox.AddChatMessage(S, class 'KFLocalMessage'.default.DefaultColor);
			break;
		case 'DeathMessage':
			//MyGFxHUD.HudChatBox.AddChatMessage(S, "FF0000"); // Console message only.
			break;
		case 'Say':
		case 'TeamSay':
			if (ExtPlayerReplicationInfo(PRI)!=None && ExtPlayerReplicationInfo(PRI).ShowAdminName())
				MyGFxHUD.HudChatBox.AddChatMessage("("$ExtPlayerReplicationInfo(PRI).GetAdminNameAbr()$")"$S, ExtPlayerReplicationInfo(PRI).GetAdminColor());
			else MyGFxHUD.HudChatBox.AddChatMessage(S, "64FE2E");
			break;
		case 'Priority':
			MyGFxHUD.HudChatBox.AddChatMessage(S, class 'KFLocalMessage'.default.PriorityColor);
			break;
		case 'CriticalEvent':
			PopScreenMsg(S); // HIGH|Low|Time
			break;
		case 'LowCriticalEvent':
			MyGFxHUD.ShowNonCriticalMessage(S);
			break;
		default:
			MyGFxHUD.HudChatBox.AddChatMessage(class'KFLocalMessage'.default.SystemString@S, class 'KFLocalMessage'.default.EventColor);
		}
	}
}

final function PopScreenMsg(string S)
{
	local int i;
	local string L;
	local float T;

	T = 4.f;

	// Get lower part.
	i = InStr(S,"|");
	if (i!=-1)
	{
		L = Mid(S,i+1);
		S = Left(S,i);

		// Get time.
		i = InStr(L,"|");
		if (i!=-1)
		{
			T = float(Mid(L,i+1));
			L = Left(L,i);
		}
	}
	MyGFxHUD.DisplayPriorityMessage(S,L,T);
}

reliable client function ClientKillMessage(class<DamageType> DamType, PlayerReplicationInfo Victim, PlayerReplicationInfo KillerPRI, optional class<Pawn> KillerPawn)
{
	local string Msg,S;
	local bool bFF;

	if (Player==None || Victim==None)
		return;

	if (bUseKF2DeathMessages && MyGFxHUD!=None)
	{
		if (Victim==KillerPRI || (KillerPRI==None && KillerPawn==None)) // Suicide
			ExtMoviePlayer_HUD(MyGFxHUD).ShowKillMessageX(None, Victim, ,true);
		else ExtMoviePlayer_HUD(MyGFxHUD).ShowKillMessageX(KillerPRI, Victim, ,true, KillerPawn);
	}
	if (Victim==KillerPRI || (KillerPRI==None && KillerPawn==None)) // Suicide
	{
		if (Victim.GetTeamNum()==0)
		{
			Msg = ParseSuicideMsg(Chr(6)$"O"$Victim.GetHumanReadableName(),DamType);
			class'KFMusicStingerHelper'.static.PlayPlayerDiedStinger(Self);
		}
		else Msg = ParseSuicideMsg(Chr(6)$"K"$Victim.GetHumanReadableName(),DamType);
	}
	else
	{
		if (KillerPRI!=None && Victim.Team!=None && Victim.Team==KillerPRI.Team) // Team-kill
		{
			bFF = true;
			S = KillerPRI.GetHumanReadableName();
			class'KFMusicStingerHelper'.static.PlayTeammateDeathStinger(Self);
		}
		else // Killed by monster.
		{
			bFF = false;
			if (KillerPRI!=None)
			{
				S = KillerPRI.GetHumanReadableName();
			}
			else
			{
				S = class'KFExtendedHUD'.Static.GetNameOf(KillerPawn);
				if (class<KFPawn_Monster>(KillerPawn)!=None && class<KFPawn_Monster>(KillerPawn).Default.MinSpawnSquadSizeType==EST_Boss) // Boss type.
					S = "the "$S;
				else S = class'KFExtendedHUD'.Static.GetNameArticle(S)@S;
			}
			class'KFMusicStingerHelper'.static.PlayZedKillHumanStinger(Self);
		}
		Msg = ParseKillMsg(Victim.GetHumanReadableName(),S,bFF,DamType);
	}
	S = Class'KFExtendedHUD'.Static.StripMsgColors(Msg);
	if (!bUseKF2DeathMessages)
		KFExtendedHUD(myHUD).AddDeathMessage(Msg,S);
	ClientMessage(S,'DeathMessage');
}

reliable client function ClientZedKillMessage(class<DamageType> DamType, string Victim, optional PlayerReplicationInfo KillerPRI, optional class<Pawn> KillerPawn, optional bool bFFKill)
{
	local string Msg,S;

	if (Player==None)
		return;
	if (bUseKF2DeathMessages && MyGFxHUD!=None)
	{
		if (KillerPRI==None && KillerPawn==None) // Suicide
			ExtMoviePlayer_HUD(MyGFxHUD).ShowKillMessageX(None, None, Victim, true);
		else ExtMoviePlayer_HUD(MyGFxHUD).ShowKillMessageX(KillerPRI, None, Victim, true, KillerPawn);
	}
	if (KillerPRI==None && KillerPawn==None) // Suicide
	{
		Msg = ParseSuicideMsg(Chr(6)$"O"$Victim,DamType);
	}
	else
	{
		if (KillerPRI!=None) // Team-kill
		{
			S = KillerPRI.GetHumanReadableName();
		}
		else // Killed by monster.
		{
			S = class'KFExtendedHUD'.Static.GetNameOf(KillerPawn);
			if (class<KFPawn_Monster>(KillerPawn)!=None && class<KFPawn_Monster>(KillerPawn).Default.MinSpawnSquadSizeType==EST_Boss) // Boss type.
				S = "the "$S;
			else S = class'KFExtendedHUD'.Static.GetNameArticle(S)@S;
		}
		Msg = ParseKillMsg(Victim,S,bFFKill,DamType);
	}
	S = Class'KFExtendedHUD'.Static.StripMsgColors(Msg);
	if (!bUseKF2DeathMessages)
		KFExtendedHUD(myHUD).AddDeathMessage(Msg,S);
	ClientMessage(S,'DeathMessage');
}

simulated final function string ParseSuicideMsg(string Victim, class<DamageType> DamType)
{
	local string S;

	S = string(DamType.Name);
	if (Left(S,15)~="KFDT_Ballistic_")
	{
		S = Mid(S,15); // Weapon name.
		return Victim$Chr(6)$"M"@KilledHimselfWith@S;
	}
	else if (class<KFDT_Fire>(DamType)!=None)
		return Victim$Chr(6)$"M"@WasBurnedToDeath;
	else if (class<KFDT_Explosive>(DamType)!=None)
		return Victim$Chr(6)$"M"@WasBlownIntoPeaces;
	return Victim$Chr(6)$"M"@HadSuddenHeartAttack;
}

simulated final function string ParseKillMsg(string Victim, string Killer, bool bFF, class<DamageType> DamType)
{
	local string T,S;

	T = (bFF ? "O" : "K");
	S = string(DamType.Name);
	if (Left(S,15)~="KFDT_Ballistic_")
	{
		S = Mid(S,15); // Weapon name.
		return Chr(6)$"O"$Victim$Chr(6)$"M"@WasKilledBy@Chr(6)$T$Killer$Chr(6)$"M's "$S;
	}
	else if (class<KFDT_Fire>(DamType)!=None)
		return Chr(6)$"O"$Victim$Chr(6)$"M"@WasIncineratedBy@Chr(6)$T$Killer;
	else if (class<KFDT_Explosive>(DamType)!=None)
		return Chr(6)$"O"$Victim$Chr(6)$"M"@WasBlownUpBy@Chr(6)$T$Killer;
	return Chr(6)$"O"$Victim$Chr(6)$"M"@WasKilledBy@Chr(6)$T$Killer;
}

reliable server function ServerCamera(name NewMode)
{
	// <- REMOVED CAMERA LOGGING (PlayerController)
	if (NewMode == '1st')
		NewMode = 'FirstPerson';
	else if (NewMode == '3rd')
		NewMode = 'ThirdPerson';
	SetCameraMode(NewMode);
}

exec function Camera(name NewMode)
{
	ServerCamera(PlayerCamera.CameraStyle=='FirstPerson' ? 'ThirdPerson' : 'FirstPerson');
}

simulated final function ToggleFPBody(bool bEnable)
{
	bShowFPLegs = bEnable;
	Class'ExtPlayerController'.Default.bShowFPLegs = bEnable;

	if (EHP!=None)
		EHP.UpdateFPLegs();
}

/*exec function KickBan(string S)
{
	if (WorldInfo.Game!=None)
		WorldInfo.Game.KickBan(S);
}*/
exec function Kick(string S)
{
	if (WorldInfo.Game!=None)
		WorldInfo.Game.Kick(S);
}

reliable server function SkipLobby();

Delegate OnChangePerk(ExtPlayerController PC, class<Ext_PerkBase> NewPerk);

reliable server function SwitchToPerk(class<Ext_PerkBase> PerkClass)
{
	if (PerkClass!=None)
	{
		OnChangePerk(Self,PerkClass);
	}
}

Delegate OnBoughtStats(ExtPlayerController PC, class<Ext_PerkBase> PerkClass, int iStat, int Amount);

reliable server function BuyPerkStat(class<Ext_PerkBase> PerkClass, int iStat, int Amount)
{
	if (PerkClass!=None && Amount>0 && iStat>=0)
		OnBoughtStats(Self,PerkClass,iStat,Amount);
}

Delegate OnBoughtTrait(ExtPlayerController PC, class<Ext_PerkBase> PerkClass, class<Ext_TraitBase> Trait);

reliable server function BoughtTrait(class<Ext_PerkBase> PerkClass, class<Ext_TraitBase> Trait)
{
	if (PerkClass!=None && Trait!=None)
		OnBoughtTrait(Self,PerkClass,Trait);
}

Delegate OnPerkReset(ExtPlayerController PC, class<Ext_PerkBase> PerkClass, bool bPrestige);

reliable server function ServerResetPerk(class<Ext_PerkBase> PerkClass, bool bPrestige)
{
	if (PerkClass!=None)
		OnPerkReset(Self,PerkClass,bPrestige);
}

Delegate OnAdminHandle(ExtPlayerController PC, int PlayerID, int Action);

reliable server function AdminRPGHandle(int PlayerID, int Action)
{
	OnAdminHandle(Self,PlayerID,Action);
}

simulated reliable client event bool ShowConnectionProgressPopup(EProgressMessageType ProgressType, string ProgressTitle, string ProgressDescription, bool SuppressPasswordRetry = false)
{
	switch (ProgressType)
	{
	case	PMT_ConnectionFailure :
	case	PMT_PeerConnectionFailure :
		KFExtendedHUD(myHUD).NotifyLevelChange();
		KFExtendedHUD(myHUD).ShowProgressMsg(ConnectionError@ProgressTitle$"|"$ProgressDescription$"|"$Disconnecting,true);
		return true;
	case	PMT_DownloadProgress :
		KFExtendedHUD(myHUD).NotifyLevelChange();
	case	PMT_AdminMessage :
		KFExtendedHUD(myHUD).ShowProgressMsg(ProgressTitle$"|"$ProgressDescription);
		return true;
	}
	return false;
}

simulated function CancelConnection()
{
	if (KFExtendedHUD(myHUD)!=None)
		KFExtendedHUD(myHUD).CancelConnection();
	else class'Engine'.Static.GetEngine().GameViewport.ConsoleCommand("Disconnect");
}

function NotifyLevelUp(class<KFPerk> PerkClass, byte PerkLevel, byte NewPrestigeLevel);

function ShowBossNameplate(KFInterface_MonsterBoss KFBoss, optional string PlayerName)
{
	if (!bNamePlateShown) // Dont make multiple bosses pop this up multiple times.
	{
		bNamePlateShown = true;
		Super.ShowBossNameplate(KFBoss,PlayerName);
		SetTimer(8,false,'HideBossNameplate'); // MAKE sure it goes hidden.
	}
}

function HideBossNameplate()
{
	if (!bNamePlateHidden)
	{
		bNamePlateHidden = false;
		Super.HideBossNameplate();
		ClearTimer('HideBossNameplate');
		if (MyGFxHUD!=None)
			MyGFxHUD.MusicNotification.SetVisible(true);
	}
}

function UpdateRotation(float DeltaTime)
{
	if (OldViewRot!=Rotation && Pawn!=None && Pawn.IsAliveAndWell())
		NotifyFixed(1);
	Super.UpdateRotation(DeltaTime);
	OldViewRot = Rotation;
}

reliable server function ServerGetUnloadInfo(byte CallID, class<Ext_PerkBase> PerkClass, bool bUnload)
{
	OnRequestUnload(Self,CallID,PerkClass,bUnload);
}

delegate OnRequestUnload(ExtPlayerController PC, byte CallID, class<Ext_PerkBase> PerkClass, bool bUnload);

reliable client function ClientGotUnloadInfo(byte CallID, byte Code, optional int DataA, optional int DataB)
{
	OnClientGetResponse(CallID,Code,DataA,DataB);
}

delegate OnClientGetResponse(byte CallID, byte Code, int DataA, int DataB);
function DefClientResponse(byte CallID, byte Code, int DataA, int DataB);

reliable client function ClientUsedAmmo(Ext_T_SupplierInteract S)
{
	if (Pawn!=None && S!=None)
		S.UsedOnClient(Pawn);
}

unreliable server function ServerNextSpectateMode()
{
	local Pawn HumanViewTarget;

	if (!IsSpectating())
		return;

	// switch to roaming if human viewtarget is dead
	if (CurrentSpectateMode != SMODE_Roaming)
	{
		HumanViewTarget = Pawn(ViewTarget);
		if (HumanViewTarget == none || !HumanViewTarget.IsAliveAndWell())
		{
			SpectateRoaming();
			return;
		}
	}

	switch (CurrentSpectateMode)
	{
	case SMODE_PawnFreeCam:
		SpectatePlayer(SMODE_PawnThirdPerson);
		break;
	case SMODE_PawnThirdPerson:
		SpectatePlayer(SMODE_PawnFirstPerson);
		break;
	case SMODE_PawnFirstPerson:
	case SMODE_Roaming:
		SpectatePlayer(SMODE_PawnFreeCam);
		break;
	}
}

function ViewAPlayer(int dir)
{
	local PlayerReplicationInfo PRI;

	PRI = GetNextViewablePlayer(dir);
	if (PRI!=None)
	{
		SetViewTarget(PRI);
		ClientMessage(NowViewingFrom@PRI.GetHumanReadableName());
	}
}

exec function ViewPlayerID(int ID)
{
	ServerViewPlayerID(ID);
}

reliable server function ServerViewPlayerID(int ID)
{
	local PlayerReplicationInfo PRI;

	if (!IsSpectating())
		return;

	// Find matching player by ID
	foreach WorldInfo.GRI.PRIArray(PRI)
	{
		if (PRI.PlayerID==ID)
			break;
	}
	if (PRI==None || PRI.PlayerID!=ID || Controller(PRI.Owner)==None || Controller(PRI.Owner).Pawn==None || !WorldInfo.Game.CanSpectate(self, PRI))
		return;

	SetViewTarget(PRI);
	ClientMessage(NowViewingFrom@PRI.GetHumanReadableName());
	if (CurrentSpectateMode==SMODE_Roaming)
		SpectatePlayer(SMODE_PawnFreeCam);
}

reliable server function SpectateRoaming()
{
	local Pawn P;

	P = Pawn(ViewTarget);
	ClientMessage(ViewingFromOwnCamera);
	Super.SpectateRoaming();
	if (P!=None)
	{
		SetLocation(P.Location);
		SetRotation(P.GetViewRotation());
		ClientSetLocation(Location,Rotation);
	}
}

reliable client function ClientSetLocation(vector NewLocation, rotator NewRotation)
{
	SetLocation(NewLocation);
	Super.ClientSetLocation(NewLocation,NewRotation);
}

unreliable server function ServerPlayLevelUpDialog()
{
	if (NextCommTime<WorldInfo.TimeSeconds)
	{
		NextCommTime = WorldInfo.TimeSeconds+2.f;
		Super.ServerPlayLevelUpDialog();
	}
}

unreliable server function ServerPlayVoiceCommsDialog(int CommsIndex)
{
	if (NextCommTime<WorldInfo.TimeSeconds)
	{
		NextCommTime = WorldInfo.TimeSeconds+2.f;
		Super.ServerPlayVoiceCommsDialog(CommsIndex);
	}
}

function int GetAbilityGauge()
{
	local ExtHumanPawn LocalEHP;
	
	// Use Pawn property which is replicated, or fall back to cached EHP
	LocalEHP = ExtHumanPawn(Pawn);
	if (LocalEHP == None)
		LocalEHP = EHP;
	
	if (LocalEHP == None) 
	{
		`log("GetAbilityGauge(): No valid pawn found");
		return 0;
	}
	
	return LocalEHP.AbilityGauge;
}

function int GetGrenadeCount()
{
	local ExtHumanPawn LocalEHP;
	local ExtInventoryManager LocalEIM;
	
	// Use Pawn property which is replicated, or fall back to cached references
	LocalEHP = ExtHumanPawn(Pawn);
	if (LocalEHP == None)
		LocalEHP = EHP;
	
	if (LocalEHP != None && LocalEHP.InvManager != None)
		LocalEIM = ExtInventoryManager(LocalEHP.InvManager);
	else if (EIM != None)
		LocalEIM = EIM;
	
	if (LocalEHP == None || LocalEIM == None) 
		return 0;

	if (CurrentSpecialAbility == 0) // SpAbil_PerkGrenade
		return LocalEIM.GrenadeCount;
	
	return LocalEHP.AbilityCount;
}

/****************************************
	Special Abilities
 */
delegate int AbilDelegate();

function UseAbility()
{
	if (AbilDelegate == none)
	{
		return;
	}
	EHP = ExtHumanPawn(Pawn);
	if (ConsumeAbilityPoints())
		AbilDelegate();
}

function SetSpAbil(SpecialAbilities SpAbil)
{
	CurrentSpecialAbility = SpAbil;
	switch (SpAbil)
	{
		case SpAbil_PerkGrenade:
			break;
		case SpAbil_RocketJump:
			AbilDelegate = SA_RocketJump;
			break;
		case SpAbil_MysticEyes:
			AbilDelegate = SA_MysticEyes;
			break;
		case SpAbil_HemoStrike:
			AbilDelegate = SA_HemoStrike;
			break;
		case SpAbil_MGRs:
			AbilDelegate = SA_MGRsReload;
			break;
		case SpAbil_QuantumShield:
			AbilDelegate = SA_QuantumShield;
			break;
		default:
			break;
	}
}

reliable server function ServerConsumeAbilityPoints(int Amount = 1)
{
	ActivePerkManager.CurrentPerk.PerkConsumeAbilityPoints(Amount);
}

function bool ConsumeAbilityPoints(int Amount = 1)
{
	EHP = ExtHumanPawn(Pawn);
	if (EHP == None || EHP.AbilityCount <= 0) return false;
	
	if (EHP.AbilityCount - Amount < 0)
		return false;
	
	EHP.AbilityCount -= Amount;
	ServerConsumeAbilityPoints(Amount);
	
	return true;
}

/********************
	Commando
 */
function int SA_MGRsReload()
{
	EHP = ExtHumanPawn(Pawn);
	if (EHP != None)
		EHP.MGRs_Reload();

	return 1;
}
/*
	Commando
 ********************/

/********************
	Zerker
 */
function int SA_RocketJump()
{
	if (Role < ROLE_Authority)
	{
		ServerRocketJump();
	}
	
	if (ConsumeAbilityPoints(1))
	{
		Pawn.SetPhysics(PHYS_Falling);
		Pawn.Velocity += vect(0.0f, 0.0f, 10000.0f);
	}
	return 1;
}


reliable server function Server_Activate_MysticEyes()
{
	SA_MysticEyes();
}

function int SA_MysticEyes()
{
	local Ext_PerkBerserker BerserkerPerk;
	local KFPawn KFP;
	local Inventory inv;
	local ExtWeap_Knife_Berserker_Mystic mysticKnife;

	if (!ConsumeAbilityPoints())
		return 0;
	
	if (Role < ROLE_Authority)
	{
		Server_Activate_MysticEyes();
	}

	// `log("SA_MysticEyes() executed on " @ Role);

	BerserkerPerk = Ext_PerkBerserker(ActivePerkManager.CurrentPerk);
	if (BerserkerPerk == None) return 0;
	if (!BerserkerPerk.bHasMysticEyes)
		return 0;

	KFP = KFPawn(Pawn);
	if (KFP == None) return 0;
	for (Inv = KFP.InvManager.InventoryChain; Inv != None; Inv = Inv.Inventory)
	{
		mysticKnife = ExtWeap_Knife_Berserker_Mystic(Inv);
		if (mysticKnife != None)
		{
			mysticKnife.ActivateMysticEyes(
				BerserkerPerk.MysticEyesDuration, BerserkerPerk.MysticEyesDmgMultiplier);
			// EHP.SetAbilityDuration(BerserkerPerk.MysticEyesDuration);
			return 1;
		}
	}

	return 0;
}

reliable server function ServerRocketJump()
{
	SA_RocketJump();
}
/*
	Zerker
 ********************/

/********************
	Medic
 */
simulated function PrepareHemoStrike()
{
	local Ext_PerkFieldMedic MedicPerk;
	local int Count;
	local vector RandomLoc;
	local vector StrikeCenter;
	local int TotalShots;
	local float Dist, Angle, RandX, RandY;


	MedicPerk = Ext_PerkFieldMedic(ActivePerkManager.CurrentPerk);
	if (MedicPerk == None)
	{
		`log("SA_HemoStrike: Perk is not medic!");
		return;
	}
	HemoStrikeMissilePerShot = MedicPerk.MisslesPerShot;

	StrikeCenter = Pawn.Location;
	StrikeCenter.Z += MedicPerk.default.HemoStrikeHeight;
	// StrikeCenter.Z += 10.0;

	TotalShots = MedicPerk.HemoStrikeRadius / 500.0;
	TotalShots = TotalShots * TotalShots * HemoStrikeMissilePerShot;

	HemoStrikeLocs.Length = 0;
	HemoStrikeIdx = 0;
	for (Count = 0; Count < TotalShots; Count++)
	{
		Angle = FRand() * 2.0 * Pi;
		Dist = FRand() * MedicPerk.HemoStrikeRadius;
		RandX = Dist * Cos(Angle);
		RandY = Dist * Sin(Angle);

		RandomLoc.x = StrikeCenter.X + RandX;
		RandomLoc.y = StrikeCenter.Y + RandY;
		RandomLoc.z = StrikeCenter.Z;

		HemoStrikeLocs.AddItem(RandomLoc);
	}

	`log("PrepareHemoStrike: HemoStrikeLocs.Length = " @ HemoStrikeLocs.Length);
}

simulated function FireHemoStrikeMissle(Vector Loc)
{
	local KFProj_Rocket_HRG_MedicMissile Missile;
	local Vector Dir;
	// `log("FireHemoStrikeMissle: Loc=" @ Loc @ " Role=" @ Role);

	Dir = Vect(0.0, 0.0, -1.0);

	Missile = Spawn(class'KFProj_Rocket_HRG_MedicMissile', Pawn.Weapon != None ? Pawn.Weapon : Pawn, , loc, rotator(Dir),, true);
	if (Missile != none)
	{
		Missile.Instigator = Pawn;
		Missile.bSyncToThirdPersonMuzzleLocation = false; // Prevent snapping to weapon muzzle on other clients
		// Missile.bBlockedByInstigator = true;
		Missile.OriginalLocation = Loc;
		Missile.Init(Dir);
		// Missile.SyncOriginalLocation();
	}
}

reliable server function Timer_FireHemoStrikeMissles()
{
	local int firecount;

	for (firecount = 0; firecount < HemoStrikeMissilePerShot && HemoStrikeIdx < HemoStrikeLocs.Length; firecount++)
	{
		FireHemoStrikeMissle(HemoStrikeLocs[HemoStrikeIdx]);
		HemoStrikeIdx++;
	}
	`log("Timer_FireHemoStrikeMissles() HemoStrikeIdx=" @ HemoStrikeIdx @ "interval=" @ HemoStrikeInterval);

	if (HemoStrikeIdx < HemoStrikeLocs.Length)
	{
		SetTimer(0.3, false, 'Timer_FireHemoStrikeMissles');
	}
	else
	{
		bIsFiringHemoStrike = false;
	}
}

reliable server function int LaunchHemoStrike()
{
	if (bIsFiringHemoStrike)
	{
		`log("LaunchHemoStrike: already firing HemoStrike");
		return 0;
	}

	PrepareHemoStrike();
	SetTimer(0.1, false, 'Timer_FireHemoStrikeMissles');
	`log("LaunchHemoStrike: firing HemoStrike");
	bIsFiringHemoStrike = true;
	return 1;
}

function int SA_HemoStrike()
{
return LaunchHemoStrike();
}

function int SA_QuantumShield()
{
	EHP = ExtHumanPawn(Pawn);
	if (EHP == None || EHP.ArmorInt <= 0) return 0;
	if (EHP.bOwnsQuantumShield) return 0;

	GiveQuantumShields(EHP.QuantumShieldDuration, EHP.QuantumShieldDmgMultiplier);

	return 1;
}

reliable server function GiveQuantumShields(float Duration, int Mult)
{
	local ExtHumanPawn TeamPawn;
	local ExtPlayerController TeammatePC;

	EHP = ExtHumanPawn(Pawn);
	if (EHP == None || EHP.ArmorInt <= 0) return;

	EHP.bOwnsQuantumShield = true;
	EHP.QuantumShieldMultiplier = Mult;
	EHP.QuantumShieldArmorConsumed = 0;

	foreach WorldInfo.AllControllers(class'ExtPlayerController', TeammatePC)
	{
		TeamPawn = ExtHumanPawn(TeammatePC.Pawn);
		if (TeamPawn != None && TeamPawn.IsAliveAndWell() && TeamPawn.GetTeamNum() == 0)
		{
			TeamPawn.ReceiveQuantumShield(EHP, Duration, Mult);
		}
	}

	SetTimer(Duration, false, 'OnQuantumShieldExpired');
}

function OnQuantumShieldExpired()
{
	DetonateAllQuantumShields();
}

function OnQuantumShieldDstroyed()
{
	// `log("OnQuantumShieldDstroyed(): detonate all quantum shields!");
	ClearTimer('OnQuantumShieldExpired');
	DetonateAllQuantumShields();
}

reliable server function DetonateAllQuantumShields()
{
	local ExtHumanPawn ShieldRecipient;
	local ExtHumanPawn ShieldOwner;

	if (Role < ROLE_Authority) return;

	ShieldOwner = ExtHumanPawn(Pawn);
	if (ShieldOwner == None || !ShieldOwner.bOwnsQuantumShield) return;

	ShieldOwner.bOwnsQuantumShield = false;

	foreach WorldInfo.AllPawns(class'ExtHumanPawn', ShieldRecipient)
	{
		if (ShieldRecipient.IsAliveAndWell() && ShieldRecipient.QuantumShieldOwner == ShieldOwner)
		{
			DetonateQuantumShield(ShieldRecipient, ShieldRecipient.QuantumShieldArmorConsumed, ShieldRecipient.QuantumShieldMultiplier);
			ShieldRecipient.DeactivateQuantumShield();
		}
	}
	
	ShieldOwner.QuantumShieldArmorConsumed = 0;
}

simulated function DetonateQuantumShield(Actor Target, int ArmorConsumed, int Mult)
{
	local vector HitLocation;
	local KFExplosionActorReplicated ExploActor;

	if (Role == ROLE_Authority)
	{
		HitLocation = Target.Location;

		QuantumShieldExploTemplate.Damage = Max(ArmorConsumed * Mult, 1);

		ExploActor = Spawn(class'KFExplosionActorReplicated', self,, HitLocation, rotator(vect(0,0,1)),, true);
		if (ExploActor != None)
		{
			ExploActor.InstigatorController = self;
			ExploActor.Instigator = Pawn;
			ExploActor.bIgnoreInstigator = true;
			ExploActor.Explode(QuantumShieldExploTemplate);
		}
	}
}

/*
	Medic
 ********************/

reliable client function ClientAddSpecialAbility(SpecialAbilities Ability)
{
	if (SpecialAbil.Find(Ability) == INDEX_NONE)
	{
		SpecialAbil.AddItem(Ability);
	}
}

reliable client function ClientRemoveSpecialAbility(SpecialAbilities Ability)
{
	SpecialAbil.RemoveItem(Ability);
}
/*
	Special Abilities
 ****************************************/

// The player wants to fire.
// Setup bFire/bAltFire so that Auto-Fire trait will work.
exec function StartFire(optional byte FireModeNum)
{
	if (FireModeNum==0)
		bFire = 1;
	else if (FireModeNum==1)
		bAltFire = 1;
	else if (FireModeNum==4)
	{
		
		if (Pawn != None && CurrentSpecialAbility != SpAbil_PerkGrenade)
		{	
			UseAbility();
			return;
		}
	}

	Super.StartFire(FireModeNum);
}

exec function StopFire(optional byte FireModeNum)
{
	if (FireModeNum==0)
		bFire = 0;
	else if (FireModeNum==1)
		bAltFire = 0;
	Super.StopFire(FireModeNum);
}

state Spectating
{
	function BeginState(Name PreviousStateName)
	{
		Super.BeginState(PreviousStateName);
		bCollideWorld = false;
	}
	function ProcessMove(float DeltaTime, vector NewAccel, eDoubleClickDir DoubleClickMove, rotator DeltaRot)
	{
		Acceleration = Normal(NewAccel) * SpectatorCameraSpeed;
		Velocity = Acceleration;
		MoveSmooth(Acceleration * DeltaTime);
	}
	function PlayerMove(float DeltaTime)
	{
		local vector X,Y,Z;
		local rotator OldRotation;

		OldRotation = Rotation;
		GetAxes(Rotation,X,Y,Z);
		Acceleration = (Normal(PlayerInput.aForward*X + PlayerInput.aStrafe*Y + PlayerInput.aUp*vect(0,0,1)) - bDuck*vect(0,0,1))*100.f;
		UpdateRotation(DeltaTime);

		if (Role < ROLE_Authority) // then save this move and replicate it
		{
			ReplicateMove(DeltaTime, Acceleration, DCLICK_None, rot(0,0,0));

			// only done for clients, as LastActiveTime only affects idle kicking
			if ((!IsZero(Acceleration) || OldRotation != Rotation) && LastUpdateSpectatorActiveTime<WorldInfo.TimeSeconds)
			{
				LastUpdateSpectatorActiveTime = WorldInfo.TimeSeconds+UpdateSpectatorActiveInterval;
				ServerSetSpectatorActive();
			}
		}
		else
		{
			ProcessMove(DeltaTime, Acceleration, DCLICK_None, rot(0,0,0));
		}
	}
	exec function SpectateNextPlayer()
	{
		SpectateRoaming();
	}
	exec function SpectatePreviousPlayer()
	{
		ServerViewNextPlayer();
		if (Role == ROLE_Authority)
		{
			NotifyChangeSpectateViewTarget();
		}
	}
	unreliable server function ServerViewNextPlayer()
	{
		if (CurrentSpectateMode==SMODE_Roaming)
		{
			CurrentSpectateMode = SMODE_PawnFreeCam;
			SetCameraMode('FreeCam');
		}
		Global.ServerViewNextPlayer();
	}
	reliable client function ClientSetCameraMode(name NewCamMode)
	{
		Global.ClientSetCameraMode(NewCamMode);
		if (NewCamMode=='FirstPerson' && ViewTarget==Self && MyGFxHUD!=None)
			MyGFxHUD.SpectatorInfoWidget.SetSpectatedKFPRI(None); // Possibly went to first person, hide player info.
	}
}

// Feign death:
function EnterRagdollMode(bool bEnable)
{
	if (bEnable)
		GoToState('RagdollMove');
	else if (Pawn==None)
		GotoState('Dead');
	else if (Pawn.PhysicsVolume.bWaterVolume)
		GotoState(Pawn.WaterMovementState);
	else GotoState(Pawn.LandMovementState);
}

// Optional dramatic end-game camera!
simulated function EndGameCamFocus(vector Pos)
{
	local vector CamPos;
	local rotator CamRot;

	GetPlayerViewPoint(CamPos,CamRot);
	bEndGameCamFocus = true;
	EndGameCamFocusPos[0] = Pos;
	EndGameCamFocusPos[1] = CamPos;
	EndGameCamRot = CamRot;
	EndGameCamTimer = WorldInfo.RealTimeSeconds;

	if (LocalPlayer(Player)==None)
		ClientFocusView(Pos);
	else if (KFPawn(ViewTarget)!=None)
		KFPawn(ViewTarget).SetMeshVisibility(true);
}

reliable client function ClientFocusView(vector Pos)
{
	if (WorldInfo.NetMode==NM_Client)
		EndGameCamFocus(Pos);
}

final function bool CalcEndGameCam()
{
	local float T,RT;
	local vector HL,HN;

	if (LastPlayerCalcView==WorldInfo.TimeSeconds)
		return true;

	T = WorldInfo.RealTimeSeconds-EndGameCamTimer;

	if (T>=20.f) // Finished view.
	{
		bEndGameCamFocus = false;
		if (LocalPlayer(Player)!=None && KFPawn(ViewTarget)!=None)
			KFPawn(ViewTarget).SetMeshVisibility(!Global.UsingFirstPersonCamera());
		return false;
	}
	// Setup other cache params.
	LastPlayerCalcView	= WorldInfo.TimeSeconds;

	CalcViewLocation.Z = 1.f;
	RT = WorldInfo.RealTimeSeconds;
	if (T<4.f)
		RT += (4.f-T);
	CalcViewLocation.X = Sin(RT*0.08f);
	CalcViewLocation.Y = Cos(RT*0.08f);
	CalcViewLocation = EndGameCamFocusPos[0] + Normal(CalcViewLocation)*350.f;
	if (Trace(HL,HN,CalcViewLocation,EndGameCamFocusPos[0],false,vect(16,16,16))!=None)
		CalcViewLocation = HL;

	CalcViewRotation = rotator(EndGameCamFocusPos[0]-CalcViewLocation);

	if (T<4.f && LocalPlayer(Player)!=None) // Zoom in to epic death.
	{
		T*=0.25;
		CalcViewLocation = CalcViewLocation*T + EndGameCamFocusPos[1]*(1.f-T);
		CalcViewRotation = RLerp(EndGameCamRot,CalcViewRotation,T,true);
	}
	return true;
}

simulated event GetPlayerViewPoint(out vector out_Location, out Rotator out_Rotation)
{
	if (bEndGameCamFocus && CalcEndGameCam())
	{
		out_Location = CalcViewLocation;
		out_Rotation = CalcViewRotation;
		return;
	}
	Super.GetPlayerViewPoint(out_Location,out_Rotation);
}

exec function DebugRenderMode()
{
	if (WorldInfo.NetMode!=NM_Client)
	{
		bRenderModes = !bRenderModes;
		SaveConfig();
		ClientMessage(bRenderModes);
	}
}

// Stats traffic.
reliable server function ServerRequestStats(byte ListNum)
{
	if (ListNum<3)
	{
		TransitListNum = ListNum;
		TransitIndex = 0;
		SetTimer(0.001,true,'SendNextList');
	}
}

function SendNextList()
{
	if (!OnClientGetStat(Self,TransitListNum,TransitIndex++))
	{
		ClientGetStat(TransitListNum,true);
		ClearTimer('SendNextList');
	}
}

simulated reliable client function ClientGetStat(byte ListNum, bool bFinal, optional string N, optional UniqueNetId ID, optional int V)
{
	OnClientReceiveStat(ListNum,bFinal,N,ID,V);
}

Delegate OnClientReceiveStat(byte ListNum, bool bFinal, string N, UniqueNetId ID, int V);
Delegate bool OnClientGetStat(ExtPlayerController PC, byte ListNum, int StatIndex);

reliable server function ChangeSpectateMode(bool bSpectator)
{
	OnSpectateChange(Self,bSpectator);
}

simulated reliable client function ClientSpectateMode(bool bSpectator)
{
	UpdateURL("SpectatorOnly",(bSpectator ? "1" : "0"),false);
}

Delegate OnSpectateChange(ExtPlayerController PC, bool bSpectator);

state RagdollMove extends PlayerWalking
{
Ignores NotifyPhysicsVolumeChange,ServerCamera,ResetCameraMode;

	event BeginState(Name PreviousStateName)
	{
		FOVAngle = DesiredFOV;

		if (WorldInfo.NetMode!=NM_Client)
			SetCameraMode('ThirdPerson');
	}
	event EndState(Name NewState)
	{
		FOVAngle = DesiredFOV;

		if (Pawn!=none && NewState!='Dead')
			Global.SetCameraMode('FirstPerson');
	}
	function PlayerMove(float DeltaTime)
	{
		local rotator			OldRotation;

		if (Pawn == None)
			GotoState('Dead');
		else
		{
			// Update rotation.
			OldRotation = Rotation;
			UpdateRotation(DeltaTime);
			bDoubleJump = false;
			bPressedJump = false;

			if (Role < ROLE_Authority) // then save this move and replicate it
				ReplicateMove(DeltaTime, vect(0,0,0), DCLICK_None, OldRotation - Rotation);
			else ProcessMove(DeltaTime, vect(0,0,0), DCLICK_None, OldRotation - Rotation);
		}
	}
	simulated event GetPlayerViewPoint(out vector out_Location, out Rotator out_Rotation)
	{
		local Actor TheViewTarget;
		local vector HL,HN,EndOffset;

		if (bEndGameCamFocus && CalcEndGameCam())
		{
			out_Location = CalcViewLocation;
			out_Rotation = CalcViewRotation;
			return;
		}
		if (Global.UsingFirstPersonCamera())
			Global.GetPlayerViewPoint(out_Location,out_Rotation);
		else
		{
			out_Rotation = Rotation;
			TheViewTarget = GetViewTarget();
			if (TheViewTarget==None)
				TheViewTarget = Self;
			out_Location = TheViewTarget.Location;
			EndOffset = out_Location-vector(Rotation)*250.f;

			if (TheViewTarget.Trace(HL,HN,EndOffset,out_Location,false,vect(16,16,16))!=None)
				out_Location = HL;
			else out_Location = EndOffset;
		}
	}
}

state PlayerWalking
{
ignores SeePlayer, HearNoise, Bump;

	function PlayerMove(float DeltaTime)
	{
		local vector			X,Y,Z, NewAccel;
		local eDoubleClickDir	DoubleClickMove;
		local rotator			OldRotation;
		local bool				bSaveJump;

		if (Pawn == None)
		{
			GotoState('Dead');
		}
		else
		{
			GetAxes(Pawn.Rotation,X,Y,Z);
			if (VSZombie(Pawn)!=None)
				VSZombie(Pawn).ModifyPlayerInput(Self,DeltaTime);

			// Update acceleration.
			NewAccel = PlayerInput.aForward*X + PlayerInput.aStrafe*Y;
			NewAccel.Z	= 0;
			NewAccel = Pawn.AccelRate * Normal(NewAccel);

			if (IsLocalPlayerController())
			{
				AdjustPlayerWalkingMoveAccel(NewAccel);
			}

			DoubleClickMove = PlayerInput.CheckForDoubleClickMove(DeltaTime/WorldInfo.TimeDilation);

			// Update rotation.
			OldRotation = Rotation;
			UpdateRotation(DeltaTime);
			bDoubleJump = false;

			if (bPressedJump && Pawn.CannotJumpNow())
			{
				bSaveJump = true;
				bPressedJump = false;
			}
			else
			{
				bSaveJump = false;
			}

			if (Role < ROLE_Authority) // then save this move and replicate it
			{
				ReplicateMove(DeltaTime, NewAccel, DoubleClickMove, OldRotation - Rotation);
			}
			else
			{
				ProcessMove(DeltaTime, NewAccel, DoubleClickMove, OldRotation - Rotation);
			}
			bPressedJump = bSaveJump;
		}
	}
}

state Dead
{
	event BeginState(Name PreviousStateName)
	{
		local KFPlayerInput KFPI;

		SetTimer(5.f, false, nameof(StartSpectate));
		if ((Pawn != None) && (Pawn.Controller == self))
			Pawn.Controller = None;
		Pawn = None;
		FOVAngle = DesiredFOV;
		Enemy = None;
		bPressedJump = false;
		FindGoodView();
		CleanOutSavedMoves();

		if (KFPawn(ViewTarget)!=none)
		{
			KFPawn(ViewTarget).SetMeshVisibility(true);
		}

		// Deactivate any post process effects when we die
		ResetGameplayPostProcessFX();

		if (CurrentPerk != none)
			CurrentPerk.PlayerDied();

		KFPI = KFPlayerInput(PlayerInput);
		if (KFPI != none)
			KFPI.HideVoiceComms();

		if (MyGFxManager != none)
			MyGFxManager.CloseMenus();

		if (MyGFxHUD != none)
			MyGFxHUD.ClearBuffIcons();
	}
	simulated event GetPlayerViewPoint(out vector out_Location, out Rotator out_Rotation)
	{
		local Actor TheViewTarget;
		local vector HL,HN,EndOffset;

		if (bEndGameCamFocus && CalcEndGameCam())
		{
			out_Location = CalcViewLocation;
			out_Rotation = CalcViewRotation;
			return;
		}
		out_Rotation = Rotation;
		TheViewTarget = GetViewTarget();
		if (TheViewTarget==None)
			TheViewTarget = Self;
		out_Location = TheViewTarget.Location;
		EndOffset = out_Location-vector(Rotation)*400.f;

		if (TheViewTarget.Trace(HL,HN,EndOffset,out_Location,false,vect(16,16,16))!=None)
			out_Location = HL;
		else out_Location = EndOffset;
	}
}

function bool FindWeaponProperties(class<KFWeapon> WPC, out int WeaponIdx)
{

	for (WeaponIdx = 0; WeaponIdx < InvProperties.Length; WeaponIdx++)
	{
		if (InvProperties[WeaponIdx].WeaponClass == WPC) return true;
	}

	return false;
}

function bool HasWeapon(class<KFWeapon> WPC)
{
	local Inventory Inv;

	for (Inv = EIM.InventoryChain; Inv != None; Inv = Inv.Inventory)
	{
		if (Inv.Class == WPC) return true;
	}

	return false;
}

function InitWeaponProperties()
{
	local Inventory Inv;
	local KFWeapon KFW;
	for (Inv = Pawn.InvManager.InventoryChain; Inv != None; Inv = Inv.Inventory)
	{
		KFW = KFWeapon(Inv);
		if (KFW != None)
		{
			CreateWeapProp(KFW);
		}
	}
}

reliable server function ServerSetWeaponMaxLevels()
{
	SetWeaponMaxLevels();
}

simulated function SetWeaponMaxLevels()
{
	`log("ExtPlayerController.SetWeaponMaxLevels called on " @ Role);
	if (PlayerReplicationInfo != None)
	{
		class'Ext_WeaponProperties'.static.SetMaxLvs(PlayerReplicationInfo);
		`log("ExtPlayerController.SetWeaponMaxLevels called");
	}
}

reliable server function ServerClearUpgradeStates()
{
	local int idx;
	for (idx = 0; idx < 15; idx++)
	{
		WeaponUpgradeStates[idx].bHasData = false;
	}
}

reliable server function ServerAddUpgradeState(class<KFWeapon> WPC)
{
	local int idx;

	for (idx = 0; idx < 15; idx++)
	{
		if (!WeaponUpgradeStates[idx].bHasData) break;
	}
	if (idx < 15)
	{
		WeaponUpgradeStates[idx].bHasData = true;
		WeaponUpgradeStates[idx].WeaponClass = WPC;
		WeaponUpgradeStates[idx].DamageLv = 0;
		WeaponUpgradeStates[idx].AoELv = 0;
		WeaponUpgradeStates[idx].PenetrationLv = 0;
		WeaponUpgradeStates[idx].DotLv = 0;
	}
	else
	{
		`log("ExtPlayerController.AddUpgradeState: No more upgrade slots available");
	}
}

// reliable server function ServerCreateWeapProp(KFWeapon NewWeapon)
// {
// 	CreateWeapProp(NewWeapon);
// }

function CreateWeapProp(KFWeapon NewWeapon)
{
	local int idx;
	local Ext_WeaponProperties WPP;

	WPP = new class'Ext_WeaponProperties';

	WPP.PCInit(self, NewWeapon);
	InvProperties.AddItem(WPP);
	`log("ExtPlayerController.CreateWeapProp: Created new weapon properties for " @ NewWeapon.Class @ " MaxDmgLv=" @ WPP.default.MaxDmgLv);

	if (Role == ROLE_Authority)
		WeaponUpgradeStates[InvProperties.Length] = WPP.GetUpgradeState();
}

/***
 * wrapper for Pawn.InvManager.CreateInventory()
 * add a weapon to the pawn and create an associated weapon properties
 * return true if the weapon is added, otherwise false
 */ 
// reliable client function bool AddWeapon(class<KFWeapon> WPC)
// {
// 	local KFWeapon SpawnedWeapon;

// 	if (HasWeapon(WPC)) return false;

// 	SpawnedWeapon = ServerAddWeapon(WPC);
// 	if (SpawnedWeapon == None) return false;

// 	CreateWeapProp(SpawnedWeapon);

// 	return true;
// }

reliable server function KFWeapon ServerAddWeapon(class<KFWeapon> WPC)
{
    local KFWeapon SpawnedWeapon;

    if (EHP == None || EIM == None) return none;

    if (HasWeapon(WPC)) return none;

    SpawnedWeapon = KFWeapon(EIM.CreateInventory(WPC));
    
    // Create weapon properties on server side as well
    if (SpawnedWeapon != None)
    {
        CreateWeapProp(SpawnedWeapon);
		ServerAddUpgradeState(WPC);
        `log("ExtPlayerController.ServerAddWeapon: Created weapon properties for " @ WPC @ " on server. InvProperties.Length=" @ InvProperties.Length);
    }
    
    return SpawnedWeapon;
}

// Server function to purchase weapon and deduct dosh atomically
reliable server function ServerPurchaseWeapon(class<KFWeapon> WPC, int Price)
{
    local KFWeapon SpawnedWeapon;
    local ExtPlayerReplicationInfo ExtPRI;
    
    ExtPRI = ExtPlayerReplicationInfo(PlayerReplicationInfo);
    if (ExtPRI == None)
    {
        // `log("ExtPlayerController.ServerPurchaseWeapon: Failed - No PRI");
        return;
    }
    
    // Check if player can afford it
    if (ExtPRI.Score < Price)
    {
        // `log("ExtPlayerController.ServerPurchaseWeapon: Failed - Not enough dosh. Have: " @ ExtPRI.Score @ " Need: " @ Price);
        return;
    }
    
    // Add weapon
    SpawnedWeapon = ServerAddWeapon(WPC);
    if (SpawnedWeapon == None)
    {
        // `log("ExtPlayerController.ServerPurchaseWeapon: Failed - Could not add weapon");
        return;
    }
    
    // Deduct dosh on server (AddDosh has built-in Max(0, ...) to prevent negative)
    ExtPRI.AddDosh(-Price);
    `log("ExtPlayerController.ServerPurchaseWeapon: Success - Purchased " @ WPC @ " for " @ Price @ " dosh. Remaining: " @ ExtPRI.Score);
}

function DropWeapon(KFWeapon Weapon)
{
	local int Idx;

	return;

	for (Idx = 0; Idx < InvProperties.Length; Idx++)
	{
		if (InvProperties[Idx].WeaponInstance == Weapon)
		{	
			`log("ExtPlayerController.DropWeapon: Dropped weapon at index " @ Idx);
			RemoveWeaponIdx(Idx, false);
		}
	}
}

simulated function RemoveUpgradeState(int PropIdx)
{
	local int idx;

	for (idx = PropIdx; idx < 14; idx++)
	{
		WeaponUpgradeStates[idx] = WeaponUpgradeStates[idx + 1];
	}
}

simulated function RemoveWeaponIdx(int PropIdx, bool bDestroyWeapon = true)
{
	local KFInventoryManager KFIM;
	KFIM = KFInventoryManager(Pawn.InvManager);

	if (KFIM == None) return;
	
	KFIM.ServerRemoveFromInventory(InvProperties[PropIdx].WeaponInstance);

	if (bDestroyWeapon)
		InvProperties[PropIdx].WeaponInstance.Destroy();

	InvProperties.Remove(PropIdx, 1);
	RemoveUpgradeState(PropIdx);

	CheckPropAndUpgrades();

	// if (Role == ROLE_Authority)
	// 	ServerRecreateUpgradeStates();
}

// Server function to sell weapon and add dosh atomically
reliable server function ServerSellWeapon(int PropIdx)
{
    local ExtPlayerReplicationInfo ExtPRI;
    local int SellPrice;
    local int ScoreBefore;
    
    ExtPRI = ExtPlayerReplicationInfo(PlayerReplicationInfo);
    if (ExtPRI == None)
    {
        return;
    }
    
    // Validate the weapon property index
    if (PropIdx < 0 || PropIdx >= InvProperties.Length)
    {
        `log("ExtPlayerController.ServerSellWeapon: Failed - Invalid PropIdx=" @ PropIdx @ " Length=" @ InvProperties.Length);
        return;
    }
    
    if (InvProperties[PropIdx] == None)
    {
        `log("ExtPlayerController.ServerSellWeapon: Failed - InvProperties[" @ PropIdx @ "] is None");
        return;
    }
    
    // Get sell price before removing
    SellPrice = InvProperties[PropIdx].GetSellPrice();
    ScoreBefore = ExtPRI.Score;
    // `log("ExtPlayerController.ServerSellWeapon: Before sell - Score=" @ ScoreBefore @ " SellPrice=" @ SellPrice);
    
    // Add dosh on server
    ExtPRI.AddDosh(SellPrice);
    `log("ExtPlayerController.ServerSellWeapon: After AddDosh - Score=" @ ExtPRI.Score @ " Expected: " @ (ScoreBefore + SellPrice));

	RemoveWeaponIdx(PropIdx, true);
}

function HandlePickup(Inventory Inv)
{
	local KFWeapon KFW;

	super.HandlePickup(Inv);
	KFW = KFWeapon(Inv);
	if (KFW != none)
		CreateWeapProp(KFW);
}

function NotifyAddInventory(Inventory NewItem)
{
	local KFWeapon KFW;

	super.NotifyAddInventory(NewItem);

	KFW = KFWeapon(NewItem);
	if (KFW != none)
		CreateWeapProp(KFW);
}

function OpenTraderMenu( optional bool bForce=false )
{
	local ExtInventoryManager InvMng;
    if (Pawn == none) return;
    InvMng = ExtInventoryManager(Pawn.InvManager);
	if (InvMng == None) return;
		
	InvMng.ThrowMoney();
}

exec function RequestSwitchTeam()
{
	ConsoleCommand("disconnect");
}

exec function SwitchTeam()
{
	ConsoleCommand("disconnect");
}

defaultproperties
{
	SpecialAbil.Add(SpAbil_PerkGrenade)
	AbilityGaugePerKill=0
	
	bCanRocketJump=false
	InputClass=Class'ExtPlayerInput'
	PurchaseHelperClass=class'ExtAutoPurchaseHelper'
	bIgnoreEncroachers=true
	SpectatorCameraSpeed=900
	MidGameMenuClass=class'UI_MidGameMenu'
	PerkList.Empty()
	PerkList.Add((PerkClass=Class'ExtPerkManager'))

	bIsFiringHemoStrike=false

	Begin Object Class=PointLightComponent Name=QuantumShieldExploPointLight
		LightColor=(R=252,G=218,B=171,A=255)
		Brightness=4.f
		Radius=2000.f
		FalloffExponent=10.f
		CastShadows=False
		CastStaticShadows=FALSE
		CastDynamicShadows=False
		bEnabled=FALSE
		LightingChannels=(Indoor=TRUE,Outdoor=TRUE,bInitialized=TRUE)
	End Object

	Begin Object Class=KFGameExplosion Name=QuantumShieldExploTemplate0
		Damage=125
		DamageRadius=700
		DamageFalloffExponent=2.f
		DamageDelay=0.f

		// Damage Effects
		MyDamageType=class'KFDT_Explosive_FlashBangGrenade'
		KnockDownStrength=0
		FractureMeshRadius=200.0
		FracturePartVel=500.0
		ExplosionEffects=KFImpactEffectInfo'WEP_M84_ARCH.M84_Explosion'
		ExplosionSound=AkEvent'WW_WEP_EXP_Grenade_Frag.Play_WEP_Flashbang'

		// Dynamic Light
		ExploLight=QuantumShieldExploPointLight
		ExploLightStartFadeOutTime=0.0
		ExploLightFadeOutTime=0.2

		// Camera Shake
		CamShake=CameraShake'FX_CameraShake_Arch.Grenades.Default_Grenade'
		CamShakeInnerRadius=200
		CamShakeOuterRadius=900
		CamShakeFalloff=1.5f
		bOrientCameraShakeTowardsEpicenter=true

		bIgnoreInstigator=true
		ActorClassToIgnoreForDamage=class'KFPawn_Human'
	End Object
	QuantumShieldExploTemplate=QuantumShieldExploTemplate0

	NVG_DOF_FocalDistance=3800.0
	NVG_DOF_SharpRadius=2500.0
	NVG_DOF_FocalRadius=3500.0
	NVG_DOF_MaxNearBlurSize=0.25
}