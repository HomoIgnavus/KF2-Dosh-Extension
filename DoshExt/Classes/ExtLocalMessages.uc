class ExtLocalMessages extends KFLocalMessage;

enum EExtMessageType
{
    EMT_Medic_Resurrection_Team,
    EMT_Medic_Resurrection_Player,
    EMT_Undefined,
};

var localized string ResurrectedMessageTeam; // Will be "%1 resurrected %2"
var localized string ResurrectedMessagePlayer; // Will be "%1 resurrected %2"

static function string GetString(
    optional int Switch,
    optional bool bPRI1HUD,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
    )
{
    local string S;
    
    switch (Switch)
    {
        case EMT_Medic_Resurrection_Team:
            if (RelatedPRI_1 == None)
                return "";
            S = Default.ResurrectedMessageTeam;
            S = Repl(S, "%1", RelatedPRI_1.PlayerName);
            break;
        case EMT_Medic_Resurrection_Player:
            if (RelatedPRI_1 == None || RelatedPRI_2 == None)
                return "";
            S = Default.ResurrectedMessagePlayer;
            S = Repl(S, "%1", RelatedPRI_1.PlayerName);
            S = Repl(S, "%2", RelatedPRI_2.PlayerName);
            break;
        default:
            S = "";
            break;
    }

    return S;
}
defaultproperties
{
    bIsSpecial=false
    bIsUnique=false
    Lifetime=3.0
    bBeep=false
}