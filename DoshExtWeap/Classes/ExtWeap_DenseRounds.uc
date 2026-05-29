class ExtWeap_DenseRounds extends KFWeapon;

simulated function SetDamage(float InDamage)
{
    InstantHitDamage[0] = InDamage;
    InstantHitDamage[1] = InDamage;
}

simulated function SetPenetration(float InPenetration)
{
    PenetrationPower[0] = InPenetration;
    PenetrationPower[1] = InPenetration;
}

simulated function SetDamageType(class<DamageType> InDT)
{
    InstantHitDamageTypes[0] = InDT;
    InstantHitDamageTypes[1] = InDT;
}

simulated function int GetModifiedDamage(byte FireModeNum, optional vector RayDir)
{
    return InstantHitDamage[FireModeNum];
}

defaultproperties
{
    InventorySize=0
}