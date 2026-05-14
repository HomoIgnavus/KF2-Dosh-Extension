//=============================================================================
// KFWeap_Knife_Berserker
//=============================================================================
// Class Description
//=============================================================================
// thinking about making a knife for Ext_TraitSA_MysticEyes, with additional visual effects
//=============================================================================

class ExtWeap_Knife_Berserker_Mystic extends KFWeap_Knife_Berserker;

var private ExtMeleeHelper_Mystic HelperMystic;

simulated function ActivateMysticEyes()
{
	MeleeAttackHelper = HelperMystic;
}

defaultproperties
{
	// Content
	PackageKey="BerserkerKnife"
	FirstPersonMeshName="WEP_1P_BerserkerKnife_MESH.Wep_1stP_BerserkerKnife_Rig"
	AttachmentArchetypeName="WEP_BerserkerKnife_ARCH.Wep_Knife_3P"

	Begin Object Name=FirstPersonMesh
		AnimSets(0)=AnimSet'WEP_1P_CommandoKnife_ANIM.Wep_1stP_CommKnife_Anim'
	End Object
	
	// Inventory
	AssociatedPerkClasses(0)=class'KFPerk_Berserker'
	WeaponSelectTexture=Texture2D'ui_weaponselect_tex.UI_WeaponSelect_BerserkerKnife'

	InstantHitDamageTypes(DEFAULT_FIREMODE)=class'KFDT_Slashing_Knife_Berserker'
	InstantHitDamageTypes(HEAVY_ATK_FIREMODE)=class'KFDT_Slashing_KnifeHeavy_Berserker'
	InstantHitDamageTypes(BASH_FIREMODE)=class'KFDT_Piercing_KnifeStab_Berserker'

	Begin Object Name=MeleeHelper_Mystic
		class=ExtMeleeHelper_Mystic
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
	HelperMystic=MeleeHelper_Mystic
}