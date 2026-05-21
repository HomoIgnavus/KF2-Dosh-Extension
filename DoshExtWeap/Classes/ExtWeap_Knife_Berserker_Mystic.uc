//=============================================================================
// KFWeap_Knife_Berserker
//=============================================================================
// Class Description
//=============================================================================
// thinking about making a knife for Ext_TraitSA_MysticEyes, with additional visual effects
//=============================================================================

class ExtWeap_Knife_Berserker_Mystic extends KFWeap_Knife_Berserker;

var private array<float> DamageNormal;
var private ExtMeleeHelper_Mystic HelperMystic;

var private bool bIsMysticEyesActive;

simulated function PostBeginPlay()
{
	super.PostBeginPlay();
	HelperMystic = ExtMeleeHelper_Mystic(MeleeAttackHelper);
	if (HelperMystic == None) 
	{
		`log("HelperMystic is None");
	}
}

simulated event SetWeapon()
{
	if ( WorldInfo.NetMode != NM_DedicatedServer )
	{
		// Forcefully apply custom materials to the mesh slots
		// We do this before super.SetWeapon() so the blood MICs use these as parents
		Mesh.SetMaterial(0, MaterialInstanceConstant'WEP_3P_MysticBlade_MAT.WEP_3P_BerserkerKnife_MIC');
		Mesh.SetMaterial(1, MaterialInstanceConstant'WEP_3P_MysticBlade_MAT.WEP_3P_BerserkerKnife_MIC');
	}

	super.SetWeapon();
}

function ActivateMysticEyes(float Duration, float DmgMultiplier)
{
	local int idx;

	if (bIsMysticEyesActive) return;

	for (idx = 0; idx < InstantHitDamage.Length; idx++)
	{
		DamageNormal[idx] = InstantHitDamage[idx];
		InstantHitDamage[idx] *= DmgMultiplier;
	}
	HelperMystic.SetHeadHitOnly(True);
	bIsMysticEyesActive = true;

	SetTimer(Duration, false, 'DeactivateMysticEyes');
	// `log("Mystic Eyes activated!");
}

function DeactivateMysticEyes()
{
	local int idx;

	for (idx = 0; idx < InstantHitDamage.Length; idx++)
	{
		InstantHitDamage[idx] = DamageNormal[idx];
	}
	HelperMystic.SetHeadHitOnly(false);
	bIsMysticEyesActive = false;
	// `log("Mystic Eyes deactivated!");
}

defaultproperties
{
	Begin Object Class=ExtMeleeHelper_Mystic Name=MeleeHelper_0
		bUseDirectionalMelee=true
		bHasChainAttacks=true
		MaxHitRange=220
		WorldImpactEffects=KFImpactEffectInfo'FX_Impacts_ARCH.Bladed_melee_impact'
		// Override automatic hitbox creation (advanced)
		HitboxChain.Add((BoneOffset=(Y=+3,Z=125)))
		HitboxChain.Add((BoneOffset=(Y=-3,Z=100)))
		HitboxChain.Add((BoneOffset=(Y=+3,Z=75)))
		HitboxChain.Add((BoneOffset=(Y=-3,Z=50)))
		HitboxChain.Add((BoneOffset=(Y=+3,Z=25)))
		HitboxChain.Add((BoneOffset=(Y=-3,Z=0)))
		HitboxChain.Add((BoneOffset=(Z=-25)))
		MeleeImpactCamShakeScale=0.03f //0.2
		// modified combo sequences
		ChainSequence_F=(DIR_ForwardRight, DIR_ForwardLeft, DIR_ForwardRight, DIR_ForwardLeft)
		ChainSequence_B=(DIR_BackwardLeft, DIR_BackwardRight, DIR_BackwardLeft, DIR_ForwardRight)
		ChainSequence_L=(DIR_Right, DIR_ForwardLeft, DIR_ForwardRight, DIR_Left, DIR_Right)
		ChainSequence_R=(DIR_Left, DIR_ForwardRight, DIR_ForwardLeft, DIR_Right, DIR_Left)
	End Object
	MeleeAttackHelper=MeleeHelper_0
	
	// NumBloodMapMaterials=2

	Begin Object Name=FirstPersonMesh
        Materials(0)=MaterialInstanceConstant'WEP_1P_MysticBlade_MAT.Wep_1stP_BerserkerKnife_MIC'
        Materials(1)=MaterialInstanceConstant'WEP_1P_MysticBlade_MAT.Wep_1stP_BerserkerKnife_MIC'
    End Object
}
