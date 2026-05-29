class Ext_WeaponProperties extends Object
    config(DoshExtWeapons);

enum UpgradeTypes
{
    DamageUp,
    PenetrationUp,
    AoEUp,
    DoTUp,
};

struct WeaponUpgradeState
{
    var bool bHasData;
    var class<KFWeapon> WeaponClass;
    var int DamageLv;
    var int PenetrationLv;
    var int AoELv;
    var int DoTLv;
};

var ExtPlayerReplicationInfo ExtPRI;

var public class<KFWeaponDefinition> WeaponDef;
var public class<KFWeapon> WeaponClass;
var public array< class<KFProj_BallisticExplosive> > ExpProjs;
var public string Remark;
var public KFWeapon WeaponInstance;
var public int DamageLv;
var public array<float> BaseDamage;
var public int AoELv;
var public array<float> BaseAoE;
var public int DoTLv;
var public float BaseDoT;
var public int PenetrationLv;
var public array<float> BasePenetrations;
var public int ListedPrice;

var public bool bCanUpgradeDamage;
var public bool bCanUpgradeAoE;
var public bool bCanUpgradeDoT;
var public bool bCanUpgradePenetration;

var config int MinLevel;

var config int MaxDmgLv;
var config int MaxAoELv;
var config int MaxDoTLv;
var config int MaxPenetrationLv;

var config float DmgPerLv;
var config float DmgCost;
var config float AoEPerLv;
var config float AoECost;
var config float DoTPerLv;
var config float DoTCost;
var config float PenetrationPerLv;
var config float PenetrationCost;

var public int BasePrice;
var public int NextDmgCost;
var public int NextAoECost;
var public int NextDoTCost;
var public int NextPenetrationCost;
var public int TotalValue;
var public bool bCanBeSold;

// called when the weapon is added to the player's inventory
public function PCInit(ExtPlayerController PCParam, KFWeapon WeaponParam)
{
    local WeaponInfo WPI;
    
    ExtPRI = ExtPlayerReplicationInfo(PCParam.PlayerReplicationInfo);
    if (ExtPRI == none)
    {
        `log("Failed to initialize Ext_WeaponProperties for " @ WeaponParam);
        return;
    }

    WeaponInstance = WeaponParam;

    if (PCParam.WeaponList == None)
    {
        PCParam.WeaponList = new class'Ext_WeaponList';
        PCParam.WeaponList.LoadWeapons();
    }

    if (PCParam.WeaponList == None)
    {
        `log("Failed to initialize Ext_WeaponProperties: WeaponList is None");
        return;
    }

    if (!PCParam.WeaponList.GetWeaponInfo(WeaponParam.Class, WPI))
    {
        `log("Failed to get weapon info for " @ WeaponParam.class);
        return;
    }

    if (WPI.WeaponDef == None)
    {
        `log("Failed to resolve weapon definition for " @ WeaponParam.Class);
        return;
    }

    DefInit(WPI.WeaponDef, WPI.Remark);
    ApplyModifiers();
}

public function DefInit(class<KFWeaponDefinition> WeaponDefParam, string RemarkParam)
{
    local int Idx;
    WeaponDef = WeaponDefParam;
    Remark = RemarkParam;

    if (WeaponDefParam == None)
    {
        `log("Failed to initialize Ext_WeaponProperties: WeaponDefParam is none");
        return;
    }

    WeaponClass = class<KFWeapon>(DynamicLoadObject(WeaponDefParam.Default.WeaponClassPath, class'Class'));
    if (WeaponClass == None)
    {
        `log("Failed to load weapon instance: " @ WeaponDefParam.Default.WeaponClassPath);
        return;
    }

    if (WeaponClass == class'ExtWeap_Knife_FieldMedicRapid')
        bCanBeSold = false;
    
    DamageLv=0;
    BaseDamage=WeaponClass.default.InstantHitDamage;
    PenetrationLv=0;
    BasePenetrations=WeaponClass.default.PenetrationPower;

    ListedPrice=WeaponDefParam.Default.BuyPrice;

    if (WeaponClass.default.InstantHitDamage[0] > 0)
        bCanUpgradeDamage = true;
    else
        bCanUpgradeDamage = false;

    bCanUpgradePenetration = false;
    for (Idx = 0; Idx < BasePenetrations.Length; Idx++)
    {
        BasePenetrations[Idx] = WeaponClass.default.PenetrationPower[Idx];
        if (BasePenetrations[Idx] > 0)
            bCanUpgradePenetration = true;
    }

    bCanUpgradeAoE = false;
    for (Idx = 0; Idx < WeaponClass.default.WeaponProjectiles.Length; Idx++)
    {
        ExpProjs[Idx] = Class<KFProj_BallisticExplosive>(WeaponClass.default.WeaponProjectiles[Idx]);
        if (ExpProjs[Idx] != none)
        {
            bCanUpgradeAoE = true;
            BaseAoE[Idx] = ExpProjs[Idx].default.ExplosionTemplate.DamageRadius;
        }
    }

    if (ClassIsChildOf(WeaponClass, class'KFWeap_FlameBase'))
        bCanUpgradeDot = true;
    else
        bCanUpgradeDot = false;

    BasePrice = WeaponDef.Default.BuyPrice;
    NextDmgCost = DmgCost * BasePrice;
    NextAoECost = AoECost * BasePrice;
    NextPenetrationCost = PenetrationCost * BasePrice;
    TotalValue = WeaponDef.Default.BuyPrice;
}

public static function SetMaxLvs(PlayerReplicationInfo PRIParam)
{
    local ExtPlayerReplicationInfo LocalPRI;
    local Ext_PerkBase CurrentPerk;
    local int MaxLv;

    LocalPRI = ExtPlayerReplicationInfo(PRIParam);
    if (LocalPRI == none)
    {
        `log("Ext_WeaponProperties.SetMaxLvs: LocalPRI is None");
        return;
    }

    MaxLv = LocalPRI.ECurrentPerkPrestige + default.MinLevel;
    `log("Ext_WeaponProperties.SetMaxLvs: MinLevel=" @ default.MinLevel @ " MaxLv=" @ MaxLv);

    // if (MaxLv > 0)
    // {
    //     MaxLv = LocalPRI.ECurrentPerkPrestige;
    // }
    // else
    // {
    //     // Fallback to FCurrentPerk if available
    //     // CurrentPerk = LocalPRI.FCurrentPerk;
    //     `log("Ext_WeaponProperties.SetMaxLvs: FCurrentPerk is None and ECurrentPerkPrestige=0, using default max level 10");
    //     MaxLv = MinLevel;
    //     // else
    //     // {
    //     //     MaxLv = CurrentPerk.CurrentPrestige;
    //     //     `log("Ext_WeaponProperties.SetMaxLvs: Using FCurrentPerk.CurrentPrestige=" @ MaxLv);
    //     // }
    // }

    default.MaxDmgLv = MaxLv;
    default.MaxAoELv = MaxLv;
    default.MaxDotLv = MaxLv;
    default.MaxPenetrationLv = MaxLv;

    `log("Ext_WeaponProperties.SetMaxLvs: MaxDmgLv=" @ default.MaxDmgLv @ " MaxAoELv=" @ default.MaxAoELv @ " MaxDotLv=" @ default.MaxDotLv @ " MaxPenetrationLv=" @ default.MaxPenetrationLv);
}

public function SyncUpgradeState(WeaponUpgradeState UpgradeStat)
{
    local bool bLvModified;

    if (UpgradeStat.WeaponClass != WeaponClass) return;
        
    if (DamageLv != UpgradeStat.DamageLv)
    { 
        bLvModified = true;
        DamageLv = UpgradeStat.DamageLv;
    }
    if (PenetrationLv != UpgradeStat.PenetrationLv)
    { 
        bLvModified = true;
        PenetrationLv = UpgradeStat.PenetrationLv;
    }
    if (AoELv != UpgradeStat.AoELv)
    { 
        bLvModified = true;
        AoELv = UpgradeStat.AoELv;
    }
    if (DoTLv != UpgradeStat.DoTLv)
    { 
        bLvModified = true;
        DoTLv = UpgradeStat.DoTLv;
    }

    if (bLvModified) 
        ApplyModifiers();
}

public function ApplyModifiers()
{
    local int Idx;
    local float DmgMod;
    local class<KFProj_BallisticExplosive> ExpProj;

    if (WeaponInstance == none) 
    {
        `log("ApplyModifiers: WeaponInstance is none");
        return;
    }

    if (DamageLv > 0)
    {
        DmgMod = 1.0 + default.DmgPerLv * DamageLv;
        for (Idx = 0; Idx < WeaponInstance.InstantHitDamage.Length; Idx++)
        {
            WeaponInstance.InstantHitDamage[Idx] = Round(BaseDamage[Idx] * DmgMod);
        }
    }

    if (PenetrationLv > 0)
    {
        for (Idx = 0; Idx < WeaponInstance.PenetrationPower.Length; Idx++)
        {
            WeaponInstance.PenetrationPower[Idx] = BasePenetrations[idx] * (1.0 + default.PenetrationPerLv * PenetrationLv);
        }
    }

    if (AoELv > 0)
    {
        for (Idx = 0; Idx < ExpProjs.Length; idx++)
        {
            ExpProj = ExpProjs[Idx];
            if (ExpProj != none)
            {
                ExpProj.default.ExplosionTemplate.DamageRadius = BaseAoE[Idx] * (1.0 + default.AoEPerLv * AoELv);
            }
        }
    }
    // `log("ApplyModifiers: Weapon=" @ WeaponInstance.Class.Name @ " Dmg=" @ WeaponInstance.InstantHitDamage[0] @ " Penetration=" @ WeaponInstance.PenetrationPower[0]);
}

public function Bool CanAddDamage()
{
    local bool bResult;
    local int ScoreValue;

    if (ExtPRI != None)
        ScoreValue = ExtPRI.Score;
    else
        ScoreValue = -1;

    bResult = ExtPRI != None && DamageLv < default.MaxDmgLv && ExtPRI.Score > NextDmgCost;
    `log("Ext_WeaponProperties.CanAddDamage: ExtPRI=" @ ExtPRI @ " DamageLv=" @ DamageLv @ " MaxDmgLv=" @ default.MaxDmgLv @ " Score=" @ ScoreValue @ " NextDmgCost=" @ NextDmgCost @ " Result=" @ bResult);
    return bResult;
}

public function Bool CanAddAoE()
{
    return ExtPRI != None && bCanUpgradeAoE && AoELv < default.MaxAoELv && ExtPRI.Score > NextAoECost;
}

public function Bool CanAddDot()
{
    return ExtPRI != None && bCanUpgradeDot && DotLv < default.MaxDotLv && ExtPRI.Score > NextDotCost;
}

public function Bool CanAddPenetration()
{
    return ExtPRI != None && PenetrationLv < default.MaxPenetrationLv && ExtPRI.Score > NextPenetrationCost;
}


public function int AddDamage()
{
    local int AmountCharged;
    
    if (!CanAddDamage())
        return 0;

    AmountCharged = NextDmgCost;
    DamageLv++;
    TotalValue += NextDmgCost;

    if (DamageLv < default.MaxDmgLv)
        NextDmgCost = Round(BasePrice * DmgCost * (1 + DamageLv));
    else
        NextDmgCost = 0;
    return AmountCharged;
}

public function int AddPenetration()
{
    local int AmountCharged;
    if (!CanAddPenetration())
        return 0;

    AmountCharged = NextPenetrationCost;
    PenetrationLv++;
    TotalValue += NextPenetrationCost;

    if (PenetrationLv < default.MaxPenetrationLv)
        NextPenetrationCost = Round(BasePrice *  PenetrationCost * (1 + PenetrationLv));
    else
        NextPenetrationCost = 0;
    return AmountCharged;
}

public function int AddAoE()
{
    local int AmountCharged;
    `log("AddAoE() executed");
    if (!CanAddAoE())
        return 0;

    AmountCharged = NextAoECost;
    AoELv++;
    TotalValue += NextAoECost;

    if (AoELv < default.MaxAoELv)
        NextAoECost = Round(BasePrice * AoECost * (1 + AoELv));
    else
        NextAoECost = 0;

    `log("AddAoE() lv=" $ AoELv);
    return AmountCharged;
}

public function int AddDot()
{
    local int AmountCharged;

    if (!CanAddDot())
        return 0;

    AmountCharged = NextDoTCost;
    DoTLv++;
    TotalValue += NextDoTCost;

    if (DoTLv < default.MaxDotLv)
        NextDoTCost = Round(BasePrice * DoTCost * (1 + DoTLv));
    else
        NextDoTCost = 0;
    return AmountCharged;
}

public function string GetItemName()
{
    return WeaponDef.static.GetItemName();
}

public function int GetSellPrice()
{
    return TotalValue * 0.75;
}

public function int GetCostDmg()
{
    return NextDmgCost;
}

public function int GetCostAoE()
{
    return NextAoECost;
}

public function int GetCostPenetration()
{
    return NextPenetrationCost;
}

public function Array<UpgradeTypes> GetUpgradables()
{
    local Array<UpgradeTypes> upgradables;
    
    upgradables.Length = 0;

    if (bCanUpgradeDamage)
        upgradables.AddItem(UpgradeTypes.DamageUp);
    if (bCanUpgradeDoT)
        upgradables.AddItem(UpgradeTypes.DoTUp);
    if (bCanUpgradeAoE)
        upgradables.AddItem(UpgradeTypes.AoEUp);
    if (bCanUpgradePenetration)
        upgradables.AddItem(UpgradeTypes.PenetrationUp);

    return upgradables;
}


public function string GetUpgradeInfo(UpgradeTypes Type)
{
    local float Modified;
    
    switch (Type)
    {
        case DamageUp:
            if (BaseDamage.Length == 0) return "0 (Lv 0)";
            Modified = BaseDamage[0] * (1.0 + DmgPerLv * DamageLv);
            // if (DamageLv == 0) return Round(Modified) @ "(Lv 0)";
            return Round(Modified) @ "(Lv" $ DamageLv @ "/" @ default.MaxDmgLv @ "+" $ Round(DmgPerLv * DamageLv * 100) $ "%)";
            break;
            
        case AoEUp:
            `log("GetUpgradeInfo(): AoELv="$AoELv);
            if (AoELv == 0) return "(Lv 0/" @ default.MaxAoELv @ ")";
            return "(Lv" $ AoELv @ "/" @ default.MaxAoELv @ "+" $ Round(AoEPerLv * AoELv * 100) $ "%)";
            break;
            
        case DoTUp:
            if (DoTLv == 0) return "(Lv 0/" @ default.MaxDotLv @ ")";
            return "(Lv" $ DoTLv @ "/" @ default.MaxDotLv @ "+" $ Round(DoTPerLv * DoTLv * 100) $ "%)";
            break;
            
        case PenetrationUp:
            if (BasePenetrations.Length == 0) return "0 (Lv 0)";
            Modified = BasePenetrations[0] * (1.0 + PenetrationPerLv * PenetrationLv);
            // if (PenetrationLv == 0) return Round(Modified) @ "(Lv 0/" @ default.MaxPenetrationLv @ ")";
            return Round(Modified) @ "(Lv" $ PenetrationLv @ "/" @ default.MaxPenetrationLv @ "+" $ Round(PenetrationPerLv * PenetrationLv * 100) $ "%)";
            break;
            
        default:
            return "(Lv 0)";
            break;
    }
}

public function WeaponUpgradeState GetUpgradeState()
{
    local WeaponUpgradeState UpgradeState;
    UpgradeState.bHasData = true;
    UpgradeState.WeaponClass = WeaponClass;
    UpgradeState.DamageLv = DamageLv;
    UpgradeState.PenetrationLv = PenetrationLv;
    UpgradeState.AoELv = AoELv;
    UpgradeState.DoTLv = DoTLv;
    return UpgradeState;
}

static final operator(24) bool == ( Ext_WeaponProperties A, Ext_WeaponProperties B )
{
    return A.WeaponClass == B.WeaponClass;
}

static final operator(26) bool != ( Ext_WeaponProperties A, Ext_WeaponProperties B )
{
    return A.WeaponClass != B.WeaponClass;
}

defaultproperties
{
    DamageLv=0
    PenetrationLv=0
    AoELv=0
    DoTLv = 0
    bCanBeSold = true
    
    BasePenetrations.Add(0)
    BasePenetrations.Add(0)

    BaseAoE.Add(0)
    BaseAoE.Add(0)

    ExpProjs.Add(none)
    ExpProjs.Add(none)
}