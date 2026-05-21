// ExtMeleeHelper_Mystic.uc
class ExtMeleeHelper_Mystic extends KFMeleeHelperWeapon;

var bool bForceHeadHit;

simulated function SetHeadHitOnly(bool bValue)
{
    bForceHeadHit = bValue;
}

simulated function EPawnOctant ChooseAttackDir()
{
    if (Instigator == None)
    {
        return DIR_None;
    }

    return super.ChooseAttackDir();
}

simulated function PawnTakeDamage(ImpactInfo Impact, byte FiringMode, vector Momentum)
{
    // Force the BoneName to 'head' before the engine processes it
    // Most ZEDs use 'head', but you can also look it up from the victim's HitZones
    if ( bForceHeadHit == true )
    {
        Impact.HitInfo.BoneName = 'head';
        `log("ExtMeleeHelper_Mystic: forcing head hit");
    }

    // Call the original TakeDamage with our modified Impact
    if ( Instigator != None )
    {
        Impact.HitActor.TakeDamage(
            GetMeleeDamage(FiringMode, Impact.RayDir), 
            Instigator.Controller,
            Impact.HitLocation, 
            Momentum,
            GetDamageType(FiringMode), 
            Impact.HitInfo, 
            Outer 
        );
    }
}

defaultproperties
{
    bForceHeadHit=false
}