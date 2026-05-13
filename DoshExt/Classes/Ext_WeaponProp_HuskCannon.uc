class Ext_WeaponProp_HuskCannon extends Ext_WeaponProperties;

var KFWeap_HuskCannon CannonInstance;
var float BaseMaxChargeTime;
var float BaseValueIncreaseTime;

var class<KFProjectile> Projectile;
var float BaseAoE;
var float BaseProjDmg;


public function PCInit(ExtPlayerController PCParam, KFWeapon WeaponParam)
{
    CannonInstance = KFWeap_HuskCannon(WeaponParam);
    if (CannonInstance == none) 
    {
        `log("Ext_WeaponProp_HuskCannon: CannonInstance is none");
        return;
    }
    super.PCInit(PCParam, WeaponParam);
}

public function DefInit(class<KFWeaponDefinition> WeaponDefParam, string RemarkParam)
{
    super.DefInit(WeaponDefParam, RemarkParam);
    
    Projectile = class<KFProjectile>(WeaponClass.default.WeaponProjectiles[0]);
    BaseAoE = Projectile.default.ExplosionTemplate.DamageRadius;
    BaseProjDmg = Projectile.default.ExplosionTemplate.Damage;
    BaseMaxChargeTime = CannonInstance.default.MaxChargeTime;
    BaseValueIncreaseTime = CannonInstance.default.ValueIncreaseTime;
    bCanUpgradeAoE = true;

    `log("Ext_WeaponProp_HuskCannon: MaxDmgLv=" @ MaxDmgLv);
}


public function ApplyModifiers()
{
    local int Idx;
    local float DmgMod;
    local float MagMod;

    if (WeaponInstance == none) 
    {
        `log("ApplyModifiers: WeaponInstance is none");
        return;
    }

    if (DamageLv > 0)
    {
        DmgMod = 1.0 + default.DmgPerLv * DamageLv;
        // for (Idx = 0; Idx < WeaponInstance.InstantHitDamage.Length; Idx++)
        // {
        //     WeaponInstance.InstantHitDamage[Idx] = Round(BaseDamage[Idx] * DmgMod);
        // }
        Projectile.default.ExplosionTemplate.Damage = Round(BaseProjDmg * DmgMod);
    }

    if (PenetrationLv > 0)
    {
        for (Idx = 0; Idx < WeaponInstance.PenetrationPower.Length; Idx++)
        {
            WeaponInstance.PenetrationPower[Idx] = BasePenetration[idx] * (1.0 + default.PenetrationPerLv * PenetrationLv);
        }
    }

    // if (FireRateLv > 0)
    // {
    //     // increased firerate = reduced charge time
    //     CannonInstance.MaxChargeTime = BaseMaxChargeTime * ((1.0 - default.FireRatePerLv) ** FireRateLv);
    //     CannonInstance.ValueIncreaseTime = BaseValueIncreaseTime * ((1.0 - default.FireRatePerLv) ** FireRateLv);
    // }

    // apply AoE
    Projectile.default.ExplosionTemplate.DamageRadius = BaseAoE * (1.0 + default.AoEPerLv * AoELv);

}

public function Bool CanAddPenetration()
{
    return false;
}

public function string GetAoEInfo()
{
    if (AoELv == 0) return "(Lv 0)";
    return "(Lv" $ AoELv @ "+" $ Round(AoEPerLv * AoELv * 100) $ "%)"; 
}

public function string GetFireRateInfo()
{
    local float Modified;

    // Modified = BaseMaxChargeTime * ((1.0 - default.FireRatePerLv) ** FireRateLv);

    // return Round(1.0/Modified) $ "s (Lv" $ FireRateLv @ "+" $ Round(FireRatePerLv * FireRateLv * 100) $ "%)";
    return "";
}

defaultproperties
{
    bCanUpgradeAoE = true
}