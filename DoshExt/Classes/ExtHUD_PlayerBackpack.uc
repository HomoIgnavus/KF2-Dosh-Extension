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

class ExtHUD_PlayerBackpack extends KFGFxHUD_PlayerBackpack;

var class<Ext_PerkBase> EPerkClass;
var ExtPlayerController EPC;
var ExtHumanPawn EHP;
var int LastAbilityGauge;
var int LastAbilityCount;

function InitializeHUD()
{
    Super.InitializeHUD();
    
    EPC = ExtPlayerController(MyKFPC);
}

// overriden to use it for displaying the current ability gauge
function UpdateFlashlight()
{
    local int CurrentAbilityGauge;
    if(MyKFPC != none &&  MyKFPC.Pawn != none)
    {
        CurrentAbilityGauge = EPC.GetAbilityGauge();
        if ( CurrentAbilityGauge != LastAbilityGauge )
        {
            SetFlashlightBattery(CurrentAbilityGauge, false);
            LastAbilityGauge = CurrentAbilityGauge;
        }
    }
}

function UpdateGrenades()
{
	local int CurrentAbilityCount;
	local ExtPerkManager PM;

	//Update the icon the for grenade type.
    EPC = ExtPlayerController(MyKFPC);
	if (EPC!=None)
	{
		PM = EPC.ActivePerkManager;

		if (PM!=None && PM.CurrentPerk!=None && EPerkClass!=PM.CurrentPerk.Class)
		{
			SetString("backpackGrenadeType", "img://"$PM.CurrentPerk.GrenadeWeaponDef.Static.GetImagePath());
			EPerkClass = PM.CurrentPerk.Class;
		}
	}
	// Update the ability count value
    CurrentAbilityCount = EPC.GetGrenadeCount();
	if (CurrentAbilityCount != LastAbilityCount)
	{
		SetInt("backpackGrenades" , Min(CurrentAbilityCount,9));
		LastAbilityCount = CurrentAbilityCount;
	}
}

function UpdateWeapon()
{
	local int CurrentSpareAmmo;
	local int CurrentMagazineAmmo;
    local byte CurrentSecondaryAmmo;
    local int CurrentSecondarySpareAmmo;
	local string CurrentSpecialAmmo;
    local KFWeapon CurrentWeapon;
    local ASColorTransform ColorChange;
    local name StateName;
	local bool ForceSecondaryWeaponIconUpdate;

    if(MyKFPC != none && MyKFPC.Pawn != none && MyKFPC.Pawn.Weapon != none )
    {
        CurrentWeapon = KFWeapon(MyKFPC.Pawn.Weapon);
        if(CurrentWeapon != none)
        {
            // If we changed weapons
            if( LastWeapon == none || LastWeapon != CurrentWeapon )
            {
                LastWeapon = CurrentWeapon;
                RefreshWeapon(CurrentWeapon);
				ForceSecondaryWeaponIconUpdate = true;
            }
            else if( bWasUsingAltFireMode != CurrentWeapon.bUseAltFireMode )
            {
                UpdateFireModeIcon(CurrentWeapon);
            }

            if (bUsesAmmo)
            {
                // Update the ammo in the weapon's magazine
                CurrentMagazineAmmo = CurrentWeapon.AmmoCount[0];

                if ( CurrentMagazineAmmo != LastMagazineAmmo )
            	{
                    SetInt("weaponMagazineAmmo" , CurrentMagazineAmmo);
                    LastMagazineAmmo  = CurrentMagazineAmmo;
					
            	}

                // Update the spare ammo (whatever is not in the magazine)
                CurrentSpareAmmo = CurrentWeapon.GetSpareAmmoForHUD();
                if ( CurrentSpareAmmo != LastSpareAmmo )
            	{
                    SetInt("backpackStoredAmmo" , CurrentSpareAmmo);
                    LastSpareAmmo  = CurrentSpareAmmo;
            	}

                /**
                    Reusing this variable for showing the dosh icon for doshinegun.
                    Only FAMAS uses bUsesSecondaryAmmoAltHUD and for it bUsesSecondaryAmmo is true
                 */
                if (!bUsesSecondaryAmmo && CurrentWeapon.bUsesSecondaryAmmoAltHUD)
                {
                    SetBool("doshAmmoIcon", true);
                }
            }
			else
			{
				// if the weapon doesn't use ammo, let them display a special string in that section
				CurrentSpecialAmmo = CurrentWeapon.GetSpecialAmmoForHUD();
				if (CurrentSpecialAmmo != LastSpecialAmmo)
				{
					SetString("specialAmmoString", CurrentSpecialAmmo);
				}
			}

			// always reset the last special ammo since setting a new string turns the default "---" off
			LastSpecialAmmo = CurrentSpecialAmmo;
            StateName = CurrentWeapon.GetStateName();
            if (bUsesSecondaryAmmo)
            {
                CurrentSecondaryAmmo = CurrentWeapon.GetSecondaryAmmoForHUD();

				// Update the amount of ammo
                if (!bUsesSecondaryAmmoAltHUD)
                {
                    if (CurrentSecondaryAmmo != LastSecondaryAmmo)
                    {
                        SetInt("secondaryAmmo" , CurrentSecondaryAmmo);
                        LastSecondaryAmmo = CurrentSecondaryAmmo;
                    }
                }
				else
                {
                    if (CurrentSecondaryAmmo != LastSecondaryAmmo)
                    {
                        SetInt("secondaryAltAmmo" , CurrentSecondaryAmmo);
                        LastSecondaryAmmo = CurrentSecondaryAmmo;
                    }

                    CurrentSecondarySpareAmmo = CurrentWeapon.GetSecondarySpareAmmoForHUD();
                    if (CurrentSecondarySpareAmmo != LastSecondarySpareAmmo)
                    {
                        SetInt("secondaryAltSpareAmmo", CurrentSecondarySpareAmmo);
                        LastSecondarySpareAmmo = CurrentSecondarySpareAmmo;
                    }
                }

				// Force the color of the background if we detect a weapon change and the weapon doesn't use secondary ammo
				if( !bUsesGrenadesAsSecondaryAmmo && ForceSecondaryWeaponIconUpdate )
				{
					GetObject("secondaryAmmoContainer").SetColorTransform(DefaultColor);
				}

				// Update the aspect of the icon
                if ( bUsesGrenadesAsSecondaryAmmo && StateName != OldState)
                {
                    OldState = StateName;
                    if(CurrentWeapon.HasToReloadSecondaryAmmoForHUD())
                    {
                        ColorChange.Add = MakeLinearColor(0.65f,0.23f,0.00f,0.2f);
                        GetObject("secondaryAmmoContainer").SetColorTransform(ColorChange);
                        SetString("secondaryIcon", "img://"$CurrentWeapon.SecondaryAmmoTexture.GetPackageName()$".UI_FireModeSelect_BulletSingleProhibited");

                    }
                    else
                    {
                        SetString("secondaryIcon", "img://"$CurrentWeapon.SecondaryAmmoTexture.GetPackageName()$"."$CurrentWeapon.SecondaryAmmoTexture);
                        GetObject("secondaryAmmoContainer").SetColorTransform(DefaultColor);
                    }
                }
            }
        }
    }
}

defaultproperties
{

}