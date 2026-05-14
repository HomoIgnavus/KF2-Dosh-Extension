// ExtMeleeHelper_Mystic.uc
class ExtMeleeHelper_Mystic extends KFMeleeHelperWeapon;

simulated function PawnTakeDamage(ImpactInfo Impact, byte FiringMode, vector Momentum)
{
    // Force the BoneName to 'head' before the engine processes it
    // Most ZEDs use 'head', but you can also look it up from the victim's HitZones
    if ( KFPawn(Impact.HitActor) != None )
    {
        Impact.HitInfo.BoneName = 'head';
    }

    // Call the original TakeDamage with our modified Impact
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

