#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <clientprefs>
#include <chat-processor>
#include <colorvariables>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.00"
#define g_sPrefix "[{green}Rules{default}]"

char g_sFile[PLATFORM_MAX_PATH];
char g_sShowFlag[32];
Handle AcceptedRules, rules_kv, AlertTimer[MAXPLAYERS+1];

bool g_bAccepted[MAXPLAYERS + 1];
bool g_bJoined[MAXPLAYERS + 1];

float g_fTimer[MAXPLAYERS + 1];
ConVar sm_accept_time, sm_showrules_flag, sm_kick_msg;

//Handle MainMenu;
Menu RulesMenu;
Menu RulesAltMenus[66];

public Plugin myinfo = 
{
	name = "Advanced Rules",
	author = "Levi2288",
	description = "Brief description of plugin functionality here!",
	version = PLUGIN_VERSION,
	url = "github.com/Levi2288"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// No need for the old GetGameFolderName setup.
	EngineVersion g_engineversion = GetEngineVersion();
	if (g_engineversion != Engine_CSGO)
	{
		SetFailState("This plugin was made for use with Counter-Strike: Global Offensive only.");
	}
} 

public void OnPluginStart()
{
	RegConsoleCmd("sm_rules", RulesAction);
	RegConsoleCmd("sm_showrules", ShowRulesAction);
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	BuildPath(Path_SM, g_sFile, sizeof(g_sFile), "configs/Levi2288/rules.cfg");
	
	sm_showrules_flag = CreateConVar("sm_showrules_flag", "b", "show rules command access flag (empty for all players)");
	sm_accept_time = CreateConVar("sm_accept_time", "120", "How many time does the player gets to accept the rules before kicking him");
	sm_kick_msg = CreateConVar("sm_kick_msg", "1", "Print an alert message in chat if player get kicked because declining the rules");
	
	AcceptedRules = RegClientCookie("rules_accepted", "rules_accepted", CookieAccess_Private);
	
	LoadTranslations("common.phrases");
	LoadTranslations("levi2288_rules.phrases");
	
	AutoExecConfig(true, "levi2288_AdvancedRules");
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i) && IsValidClient(i))
		{
			//OnClientPutInServer(i);
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached( int client )
{
	char strCookie[8];

	GetClientCookie(client, AcceptedRules, strCookie, sizeof(strCookie));
	g_bAccepted[client] = (strCookie[0] != '\0' && StringToInt(strCookie));
	
}

public void OnClientPostAdminCheck(int client)
{
	g_bJoined[client] = true;
	g_fTimer[client] = 0.0;
	
	
}

public void OnMapStart()
{
	LoadRulesConfig();
	GetConVarString(sm_showrules_flag, g_sShowFlag, sizeof(g_sShowFlag));
}
///////////////////////////////////
////////////////Actions////////////
///////////////////////////////////

public Action RulesAction(int client, int args)
{
	char TargetName[128];
		
	GetCmdArg(1, TargetName, sizeof(TargetName));
	

	if(args == 0)
	{
		if(g_bAccepted[client])
		{
			RulesMenu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			MainMenu(client);
		}
	}
	else if(args == 1)
	{
		if(CheckAdminFlags(client, ReadFlagString(g_sShowFlag)))
		{
			int target = FindTarget(client, TargetName, true, false);
			MainMenu(target);
		}
		else
		{
			
			CPrintToChat(client, "[SM] No command access");
		}
	}
	else if(CheckAdminFlags(client, ReadFlagString(g_sShowFlag)))
	{
		
		ReplyToCommand(client, "[SM] Usage: sm_rules <player> or sm_showrules <player>");
		
	}
}

public Action ShowRulesAction(int client, int args)
{
	if(CheckAdminFlags(client, ReadFlagString(g_sShowFlag)))
	{
		char TargetName[128];
		
		GetCmdArg(1, TargetName, sizeof(TargetName));
		
		if(args == 1)
		{
			char buffer[256];
			char sTargetName[MAX_NAME_LENGTH];
			
			int target = FindTarget(client, TargetName, true, false);
			
			GetClientName(target, sTargetName, sizeof(sTargetName));
			Format(buffer, sizeof(buffer), "%T", "Menu sent", LANG_SERVER, sTargetName);
			CPrintToChat(client, "%s %s", g_sPrefix, buffer);
			MainMenu(target);
		}
		else
		{
		
			ReplyToCommand(client, "[SM] Usage: sm_rules <player> or sm_showrules <player>");
		
		}
	}
	
}

public void KickPlayer(int client)
{
	char buffer[256];
	char PlayerName[MAX_NAME_LENGTH];
	
	GetClientName(client, PlayerName, sizeof(PlayerName));
	if(sm_kick_msg)
	{
		Format(buffer, sizeof(buffer), "%T", "Player Kick Alert", LANG_SERVER, PlayerName);
		CPrintToChatAll("%s %s", g_sPrefix, buffer);
		
	}
	
	
	FormatEx(buffer, sizeof(buffer), "%T", "Kick Reason", client);
	KickClientEx(client, buffer);
	
	
}


///////////////////////////////////
////////////////Menus//////////////
///////////////////////////////////
public void MainMenu(int target)
{
	char buffer[128];
	Menu menu = new Menu(Menu_Main);
	
	Format(buffer, sizeof(buffer), "%T", "Menu Title", LANG_SERVER);
	menu.SetTitle(buffer);
	Format(buffer, sizeof(buffer), "%T", "Rules", LANG_SERVER);
	menu.AddItem("rules", buffer);
	
	menu.AddItem("", "", 8);
	
	Format(buffer, sizeof(buffer), "%T", "Accept", LANG_SERVER);
	menu.AddItem("accept", buffer);
	Format(buffer, sizeof(buffer), "%T", "Decline", LANG_SERVER);
	menu.AddItem("decline", buffer);
	
	SetMenuExitButton(menu, false);
	DisplayMenu(menu, target, MENU_TIME_FOREVER);
	
	
}

public int Menu_Main(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		char items[32];
		char buffer[256];
		menu.GetItem(param2, items, sizeof(items));
		
		if (StrEqual(items, "rules")) 
		{
			RulesMenu.Display(client, MENU_TIME_FOREVER);
		}
		
		if (StrEqual(items, "accept")) 
		{
			delete AlertTimer[client];
			FormatEx(buffer, sizeof(buffer), "%T", "Rules Accepted", client);
			CPrintToChat(client, "%s %s", g_sPrefix, buffer);
			SetClientCookie(client, AcceptedRules, "1"); // save to cookie
		}
		
		if (StrEqual(items, "decline")) 
		{
			KickPlayer(client);
		}
	}
}


///////////////////////////////////
////////////////ETC////////////////
///////////////////////////////////

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(g_bJoined[client] && IsValidClient(client))
	{
		if(g_bAccepted[client] == false)
		{
			AlertTimer[client] = CreateTimer(4.0, TimerReminder, client, TIMER_REPEAT);
			MainMenu(client);
			g_fTimer[client] = GetGameTime() + GetConVarInt(sm_accept_time);
		}
		g_bJoined[client] = false;
		
		
	}
	
}

bool CheckAdminFlags(int client, int iFlag)
{
	int iUserFlags = GetUserFlagBits(client);
	return (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag);
}


public Action OnPlayerRunCmd( int client, int& buttons, int& impulse, float vel[3], float angles[3] , int& weapon)
{
	if(IsValidClient(client))
	{
		
		if(g_fTimer[client] <= GetGameTime() && g_bAccepted[client] == false)
		{
			CloseHandle(AlertTimer[client]);
			AlertTimer[client] = INVALID_HANDLE;
			KickPlayer(client);
		}
		
	}
}
public void LoadRulesConfig()
{
	
	char sIndex[526];
	char sSectionName[64];
	char buffer[64];
	
	rules_kv = CreateKeyValues("Rules");
	FileToKeyValues(rules_kv, g_sFile);
	
	if (!KvGotoFirstSubKey(rules_kv))
	{
		SetFailState("CFG File not found: %s", g_sFile);
		CloseHandle(rules_kv);
	} 
	
	Format(buffer, sizeof(buffer), "%T", "Menu Title", LANG_SERVER);
	RulesMenu = new Menu(RulesMainMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	RulesMenu.SetTitle(buffer);
	RulesMenu.ExitBackButton = true;
	
	
	int counter = 1;
	do
	{
		KvGetSectionName(rules_kv, sSectionName, sizeof(sSectionName));
		if(StrEqual(sSectionName, NULL_STRING, false)) continue;
		
		IntToString(counter, buffer, sizeof(buffer));
		RulesMenu.AddItem(buffer, sSectionName);
		if(RulesAltMenus[counter] != null)
		{
			delete RulesAltMenus[counter];
		}
		
		KvGotoFirstSubKey(rules_kv);
		
		
		RulesAltMenus[counter] = new Menu(RulesMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
		RulesAltMenus[counter].SetTitle(sSectionName);
		RulesAltMenus[counter].ExitBackButton = true;


		KvGetString(rules_kv, "info", sIndex, sizeof(sIndex));
		if(StrEqual(sIndex, NULL_STRING, false)) continue;
			
		RulesAltMenus[counter].AddItem("", sIndex, ITEMDRAW_DISABLED);
			
	
		counter++;
	}while (KvGotoNextKey(rules_kv, false));
	
	CloseHandle(rules_kv);
	
}


stock bool IsValidClient(int client)
{
	
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	if(IsFakeClient(client)) return false;
	if(!IsClientInGame(client))return false;
	return true;
}

public Action TimerReminder(Handle timer, int client)
{
	char buffer[256];
	FormatEx(buffer, sizeof(buffer), "%T", "Accept Rules Reminder", client);
	CPrintToChat(client, buffer);
	
}

public int RulesMainMenuHandler(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		char sChoice[8];
		menu.GetItem(choice, sChoice, sizeof(sChoice));
		int index = StringToInt(sChoice);
		RulesAltMenus[index].Display(client, MENU_TIME_FOREVER);
		
	}
	if(action == MenuAction_Cancel)
	{
	    if(choice == MenuCancel_ExitBack) 
		{
    		MainMenu(client);
    	}
    }
}

public int RulesMenuHandler(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		char sChoice[64];
		
		GetMenuItem(menu, choice, sChoice, sizeof(sChoice));
		
	}
	
	if(action == MenuAction_Cancel)
	{
	    if(choice == MenuCancel_ExitBack) 
		{
    		RulesMenu.Display(client, MENU_TIME_FOREVER);
    	}
    }
}