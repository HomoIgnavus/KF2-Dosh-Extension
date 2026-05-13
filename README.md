## Description
A fork of GenZmeY's KF2-Server-Extension(https://github.com/GenZmeY/KF2-Server-Extension)
Steamworkshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3711253158

## Changes
- Removed 255 limit of Magazine size
- Max Armor can now be greater than 255
- Removed map rating popup
- HP healing rate changed from 10HP/s to 5%HP/s

## New stuffs
- new URL options: XpScale and ExtraXpPerWave. 
    - Usage example: start the game with ?XpScale=2.0?ExtraXpPerWave=0.1, then in the first wave you get 2x Xp and 2.2x in the second wave 
- When you prestige, the level after you prestige is now the difference between your current level and the minimum prestige level
    - E.g. when minimum prestige level is 200, your prestige at level 240, then you will be level 40 after prestige
- You can no longer throw dosh (see below for details)
- Stock trader menu is replaced by a custom trader menu:
    - The menu can be opened by pressing throw money button
    - It uses a custom upgrade mechanism. You can upgrade your weapons damage, penetration, AoE (Rocket launchers), DoT (Fire weapons)
    - The maximum upgrade level increases with your perk prestige
    - Note: the upgrade system assumes that each player carries at most 15 weapons. If a player carries over 15 weapons it will cause errors.

## New Traits
- All: Airbag Armor
    - Armor now protects you from falling damage
- Berserker: Parry Master
    - Some stuffs that are triggered when you successfully parry
## Special Abilities
- Grenande can be replaced with the current perk's special abilities. You can set it in the trader menu's ability tab
    - Berserker: Rocket Jump


## Planned
### System
- Dosh transfer
    - Transfer any amount of dosh to another player
### Stat
- Initial dosh
    - Add this when you have too much star points!
### Traits
- Sharpshooter: Icebreaker
    - Killing zeds can cause a freeze explosion
- Gunslinger: Phantom reload
    - Consuming n% of the magazine your current weapon reloads other weapons in your inventory
- Survivalist: Scavanger
    - Randomly get ammo/HP/armor/Dosh by killing zeds
- Medic: Ext_TraitRapidSurgery

### Abilities
- Commando: Military Grade Rounds
    - Reminds you of Metro 2033
- Demolitionist
    - Suicide Bomb: Blow yourself up and deal n% of your HP as damage to all zeds alive
    - Explosive Dosh: Throw doshes and make them explode on impact
- Firebug:
    - Blackhole grenade
- Support:
    - BFS (Big Fucking Shield)
        - Create a spherical shield around you that block all projectiles