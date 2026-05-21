class Ext_WeaponList extends Object
    config(DoshExtWeapons);

struct WeaponGroup
{
    var string Package;
    var string Remark;
};

struct WeaponInfo
{
    var class<KFWeaponDefinition> WeaponDef;
    var class<KFWeapon> WeaponClass;
    var string Remark;
};

struct ColorInfo
{
    var string Remark;
    var int R;
    var int G;
    var int B;
};

var array< class<KFWeaponDefinition> > BuiltInWeapons;

var config array<WeaponGroup> Group;
var config array<ColorInfo> RemarkColor;
var config array<string> WeapDef;

var public array<WeaponInfo> WeapInfos;

function LoadWeapons()
{
    local string WPDStr;
    local class<KFWeaponDefinition> WPD;
    local class<KFWeapon> WPC;
    local WeaponGroup WPG;
    local WeaponInfo WPI;
    local string Remark;

    foreach default.BuiltInWeapons(WPD)
    {
        WPC = class<KFWeapon>(DynamicLoadObject(WPD.Default.WeaponClassPath, class'Class'));
        if (WPC == none)
        {
            `log("Failed to load built-in weapon class: " $ WPD.Default.WeaponClassPath);
            continue;
        }

        WPI.WeaponDef = WPD;
        WPI.WeaponClass = WPC;
        WPI.Remark = "Ext";
        WeapInfos.AddItem(WPI);
    }

    foreach default.WeapDef(WPDStr)
    {
        Remark = "";
        WPD = class<KFWeaponDefinition>(DynamicLoadObject(WPDStr, class'Class'));
        if (WPD == none)
        {
            `log("Failed to load weapon definition: " $ WPDStr);
            continue;
        }

        WPC = class<KFWeapon>(DynamicLoadObject(WPD.Default.WeaponClassPath, class'Class'));
        if (WPC == none)
        {
            `log("Failed to load weapon class: " $ WPDStr);
            continue;
        }

        foreach default.Group(WPG)
        {
            if (Left(WPDStr, Len(WPG.Package)) == WPG.Package)
            {    
                Remark = WPG.Remark;
                break;
            }
        }

        // WPI = new Struct'WeaponInfo';
        WPI.WeaponDef = WPD;
        WPI.WeaponClass = WPC;
        WPI.Remark = Remark;
        WeapInfos.AddItem(WPI);
        `log("Ext_WeaponList: Loaded weapon: " $ WPDStr);
    }
}

function bool GetWeaponInfo(class<KFWeapon> WPC, out WeaponInfo WPI)
{
    local int i;
    for (i = 0; i < WeapInfos.Length; i++)
    {
        if (WeapInfos[i].WeaponClass == WPC)
        {
            WPI = WeapInfos[i];
            return true;
        }
    }
    return false; // Changed from return None; to return None;
}

// function class<KFWeaponDefinition> GetWeaponDef(class<KFWeapon> WPC)
// {
//     local int i;
//     for (i = 0; i < WeapInfos.Length; i++)
//     {
//         if (WeapInfos[i].WeaponClass == WPC)
//             return WeapInfos[i].WeaponDef;
//     }
//     return None;
// }
defaultproperties
{
    BuiltInWeapons.Add(class'ExtWeapDef_Knife_MedicRapid')
    BuiltInWeapons.Add(class'ExtWeapDef_Knife_Berserker_Mystic')
}