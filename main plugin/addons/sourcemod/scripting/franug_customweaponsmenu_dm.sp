/*  SM Franug Custom Weapons DM
 *
 *  Copyright (C) 2021 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <autoexecconfig>

#define VERSION "0.1"

#pragma newdecls required

// Grenade Defines
#define NADE_FLASHBANG    0
#define NADE_MOLOTOV      1
#define NADE_SMOKE        2
#define NADE_HE           3
#define NADE_DECOY        4
#define NADE_INCENDIARY   5

Handle g_hTimer[MAXPLAYERS + 1] = INVALID_HANDLE;

bool g_bNewWeaponsSelected[MAXPLAYERS + 1];
bool g_bRememberChoice[MAXPLAYERS + 1];
bool g_awpChance[MAXPLAYERS + 1];
bool g_bWeaponsGivenThisRound[MAXPLAYERS + 1] = { false, ... };
bool g_bHasFlag[MAXPLAYERS + 1] = { false, ... };
bool g_awpSelected[MAXPLAYERS + 1];

// Menus
Menu g_mOptionsMenu1 = null;
Menu g_mOptionsMenu2 = null;
Menu g_mOptionsMenu3[MAXPLAYERS + 1] = null;
Menu g_mOptionsMenu4 = null;

char g_sPrimaryWeapon[MAXPLAYERS + 1][24];
char g_sSecondaryWeapon[MAXPLAYERS + 1][24];


ConVar g_cFlags;


enum Weapons
{
	String:number[64], 
	String:desc[64]
}

ArrayList g_aPrimary;
ArrayList g_aSecoundary;

Handle g_hWeapons1 = INVALID_HANDLE;
Handle g_hWeapons2 = INVALID_HANDLE;
Handle remember = INVALID_HANDLE;

ConVar cv_popup;
ConVar cv_awpSpots;
ConVar cv_awpSpotsTimer;
ConVar cv_defaultWeaponCT_primary;
ConVar cv_defaultWeaponCT_secondary;
ConVar cv_defaultWeaponT_primary;
ConVar cv_defaultWeaponT_secondary;

public Plugin myinfo = 
{
	name = "SM Franug Custom Weapons DM", 
	author = "Franc1sco franug", 
	description = "", 
	version = VERSION, 
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	g_aPrimary = new ArrayList(128);
	g_aSecoundary = new ArrayList(128);
	ListWeapons();
	
	// Create menus
	g_mOptionsMenu1 = BuildOptionsMenu(true);
	g_mOptionsMenu2 = BuildOptionsMenu(false);
	g_mOptionsMenu4 = BuildOptionsMenuWeapons(false, 0);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	AddCommandListener(Event_Say, "say");
	AddCommandListener(Event_Say, "say_team");
	AddCommandListener(Event_Guns, "drop");
	
	g_hWeapons1 = RegClientCookie("Primary Weapons", "", CookieAccess_Private);
	g_hWeapons2 = RegClientCookie("Secondary Weapons", "", CookieAccess_Private);
	remember = RegClientCookie("Remember Weapons", "", CookieAccess_Private);
	
	AutoExecConfig_SetFile("franug_customweaponsmenu_dm");
	
	cv_popup = AutoExecConfig_CreateConVar("sm_weaponsmenu_popup", "1", "2 = auto popup / 1 = no popup when someone has picked guns already / 0 = no popup at all");
	cv_awpSpots = AutoExecConfig_CreateConVar("sm_weaponsmenu_awpspots", "1", "Spots for awp to non vips");
	cv_awpSpotsTimer = AutoExecConfig_CreateConVar("sm_weaponsmenu_awpspotstimer", "120.0", "Seconds to rotate awp");
	g_cFlags = AutoExecConfig_CreateConVar("sm_weaponsmenu_vipflags", "a", "flag needed to be marked as VIP");
	cv_defaultWeaponCT_primary = AutoExecConfig_CreateConVar("sm_weaponsmenu_defaultweaponct_primary", "weapon_m4a1", "Default primary weapon for CT");
	cv_defaultWeaponCT_secondary = AutoExecConfig_CreateConVar("sm_weaponsmenu_defaultweaponct_secondary", "weapon_hkp2000", "Default secondary weapon for CT");
	cv_defaultWeaponT_primary = AutoExecConfig_CreateConVar("sm_weaponsmenu_defaultweapont_primary", "weapon_ak47", "Default primary weapon for T");
	cv_defaultWeaponT_secondary = AutoExecConfig_CreateConVar("sm_weaponsmenu_defaultweapont_secondary", "weapon_glock", "Default secondary weapon for T");
	LoadTranslations("franug_customweaponsmenu_dm.phrases");
	
	AutoExecConfig_ExecuteFile();
	
	AutoExecConfig_CleanFile();
	
}

Menu BuildOptionsMenu(bool sameWeaponsEnabled)
{
	int sameWeaponsStyle = (sameWeaponsEnabled) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Menu menu3 = new Menu(Menu_Options, MENU_ACTIONS_DEFAULT | MenuAction_DisplayItem);
	menu3.SetTitle("Weapon Menu:");
	menu3.ExitBackButton = true;
	menu3.AddItem("New", "New weapons");
	menu3.AddItem("Same 1", "Same weapons", sameWeaponsStyle);
	menu3.AddItem("Same All", "Same weapons every round", sameWeaponsStyle);
	menu3.AddItem("Random 1", "Random weapons");
	menu3.AddItem("Random All", "Random weapons every round");
	return menu3;
}

void DisplayOptionsMenu(int client)
{
	if (strcmp(g_sPrimaryWeapon[client], "") == 0 || strcmp(g_sSecondaryWeapon[client], "") == 0)
		g_mOptionsMenu2.Display(client, MENU_TIME_FOREVER);
	else
		g_mOptionsMenu1.Display(client, MENU_TIME_FOREVER);
}

Menu BuildOptionsMenuWeapons(bool primary, int client)
{
	Menu menu;
	int Items[Weapons];
	if (primary)
	{
		menu = new Menu(Menu_Primary);
		menu.SetTitle("Primary Weapon:");
		menu.ExitBackButton = true;
		for (int i = 0; i < g_aPrimary.Length; ++i)
		{
			g_aPrimary.GetArray(i, Items[0]);
			if(!g_bHasFlag[client] && StrEqual(Items[number], "weapon_awp"))
			{
				char menudesc[128];
				Format(menudesc, 128, "Allow chance of an AWP ?! -> %s", g_awpChance[client] ? "Yes":"No");
				menu.AddItem(Items[number], menudesc);
			}
			else
				menu.AddItem(Items[number], Items[desc]);
		}
	}
	else
	{
		menu = new Menu(Menu_Secoundary);
		menu.SetTitle("Secundary Weapon:");
		menu.ExitBackButton = true;
		for (int i = 0; i < g_aSecoundary.Length; ++i)
		{
			g_aSecoundary.GetArray(i, Items[0]);
			menu.AddItem(Items[number], Items[desc]);
		}
	}
	
	return menu;
}


public int Menu_Options(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[24];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "New"))
		{
			if (g_bWeaponsGivenThisRound[param1])
				g_bNewWeaponsSelected[param1] = true;
				
			delete g_mOptionsMenu3[param1];
			g_mOptionsMenu3[param1] = BuildOptionsMenuWeapons(true, param1);
			
			g_mOptionsMenu3[param1].Display(param1, MENU_TIME_FOREVER);
			
			g_bRememberChoice[param1] = false;
		}
		else if (StrEqual(info, "Same 1"))
		{
			if (g_bWeaponsGivenThisRound[param1])
			{
				g_bNewWeaponsSelected[param1] = true;
				PrintToChat(param1, "[\x04GUNS\x01] %t.", "Same");
			}
			GiveSavedWeapons(param1);
			g_bRememberChoice[param1] = false;
		}
		else if (StrEqual(info, "Same All"))
		{
			if (g_bWeaponsGivenThisRound[param1])
				PrintToChat(param1, "[\x04GUNS\x01] %t.", "Same_All");
			GiveSavedWeapons(param1);
			g_bRememberChoice[param1] = true;
		}
		else if (StrEqual(info, "Random 1"))
		{
			if (g_bWeaponsGivenThisRound[param1])
			{
				g_bNewWeaponsSelected[param1] = true;
				PrintToChat(param1, "[\x04GUNS\x01] %t.", "Random");
			}
			g_sPrimaryWeapon[param1] = "random";
			g_sSecondaryWeapon[param1] = "random";
			GiveSavedWeapons(param1);
			g_bRememberChoice[param1] = false;
		}
		else if (StrEqual(info, "Random All"))
		{
			if (g_bWeaponsGivenThisRound[param1])
				PrintToChat(param1, "[\x04GUNS\x01] %t.", "Random_All");
			g_sPrimaryWeapon[param1] = "random";
			g_sSecondaryWeapon[param1] = "random";
			GiveSavedWeapons(param1);
			g_bRememberChoice[param1] = true;
		}
	}
	else if (action == MenuAction_DisplayItem)
	{
		char Display[128];
		switch (param2)
		{
			case 0:FormatEx(Display, sizeof(Display), "%T", "Menu_NewWeapons", param1);
			case 1:FormatEx(Display, sizeof(Display), "%T", "Menu_SameWeapons", param1);
			case 2:FormatEx(Display, sizeof(Display), "%T", "Menu_SameWeapons_all", param1);
			case 3:FormatEx(Display, sizeof(Display), "%T", "Menu_Random", param1);
			case 4:FormatEx(Display, sizeof(Display), "%T", "Menu_Random_All", param1);
		}
		return RedrawMenuItem(Display);
	}
	return 0;
}

public int Menu_Primary(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[24];
		menu.GetItem(param2, info, sizeof(info));
		
		if(!g_bHasFlag[param1] && StrEqual(info, "weapon_awp"))
		{
			g_awpChance[param1] = !g_awpChance[param1];
			delete g_mOptionsMenu3[param1];
			g_mOptionsMenu3[param1] = BuildOptionsMenuWeapons(true, param1);
			
			g_mOptionsMenu3[param1].Display(param1, MENU_TIME_FOREVER);
			PrintToChat(param1, "[\x04GUNS\x01] %t %s.", "awpChance", g_awpChance[param1]?"Yes":"No");
			return;
		}
		
		g_sPrimaryWeapon[param1] = info;
		g_mOptionsMenu4.Display(param1, MENU_TIME_FOREVER);
		delete g_mOptionsMenu3[param1];
	}
}

public int Menu_Secoundary(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[24];
		menu.GetItem(param2, info, sizeof(info));
		g_sSecondaryWeapon[param1] = info;
		GiveSavedWeapons(param1);
		if (!IsPlayerAlive(param1))
			g_bNewWeaponsSelected[param1] = true;
		if (g_bNewWeaponsSelected[param1])
			PrintToChat(param1, "[\x04GUNS\x01] %t.", "New_weapons");
	}
}

public void OnMapStart()
{
	
	CreateTimer(cv_awpSpotsTimer.FloatValue, Timer_Awp, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Awp(Handle timer)
{
	setAwpSpots();
	CreateTimer(cv_awpSpotsTimer.FloatValue, Timer_Awp, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	//CancelClientMenu(client);
	CloseTimer(client);
	g_hTimer[client] = CreateTimer(0.2, GiveWeapons, client);
}

public Action GiveWeapons(Handle timer, any client)
{
	g_hTimer[client] = INVALID_HANDLE;
	if (GetClientTeam(client) > 1 && IsPlayerAlive(client))
	{
		giveDefaultWeapons(client);
		// Give weapons or display menu.
		g_bWeaponsGivenThisRound[client] = false;
		if (g_bNewWeaponsSelected[client])
		{
			//PrintToConsole(client, "camino 1");
			GiveSavedWeapons(client);
			g_bNewWeaponsSelected[client] = false;
		}
		else if (g_bRememberChoice[client])
		{
			//PrintToConsole(client, "camino 2");
			GiveSavedWeapons(client);
		}
		else
		{
			//PrintToConsole(client, "camino 3");
			if(g_awpSelected[client] && g_awpChance[client])
			{
				int weaponindex = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
				if (weaponindex != -1)
				{
					RemovePlayerItem(client, weaponindex);
					AcceptEntityInput(weaponindex, "Kill");
				}
				GivePlayerItem(client, "weapon_awp");
			}
			switch(cv_popup.IntValue)
			{
				case 2:DisplayOptionsMenu(client);
				case 1:{
					if (strcmp(g_sPrimaryWeapon[client], "") == 0 || strcmp(g_sSecondaryWeapon[client], "") == 0)
					{
						DisplayOptionsMenu(client);
					}
				}
			}
		}
	}
}

public Action Event_Say(int client, const char[] command, int arg)
{
	static char menuTriggers[][] =  { "gun", "!gun", "/gun", "guns", "!guns", "/guns", "menu", "!menu", "/menu", "weapon", "!weapon", "/weapon", "weapons", "!weapons", "/weapons" };
	
	if (client > 0 && IsClientInGame(client))
	{
		// Retrieve and clean up text.
		char text[24];
		GetCmdArgString(text, sizeof(text));
		StripQuotes(text);
		TrimString(text);
		
		for (int i = 0; i < sizeof(menuTriggers); i++)
		{
			if (StrEqual(text, menuTriggers[i], false))
			{
				g_bRememberChoice[client] = false;
				DisplayOptionsMenu(client);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_Guns(int client, const char[] command, int arg)
{
	g_bRememberChoice[client] = false;
	DisplayOptionsMenu(client);
	return Plugin_Stop;
}

void GiveSavedWeapons(int client)
{
	//PrintToConsole(client, "armas dadas");
	char weapons[128];
	int weaponindex;
	if (!g_bWeaponsGivenThisRound[client] && IsPlayerAlive(client))
	{
		//StripAllWeapons(client);
		weaponindex = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
		if(g_awpSelected[client] && g_awpChance[client])
		{
			if (weaponindex != -1)
			{
				RemovePlayerItem(client, weaponindex);
				AcceptEntityInput(weaponindex, "Kill");
			}
			GivePlayerItem(client, "weapon_awp");
		}
		else{
			if (StrEqual(g_sPrimaryWeapon[client], "random"))
			{
				if (weaponindex != -1)
				{
					RemovePlayerItem(client, weaponindex);
					AcceptEntityInput(weaponindex, "Kill");
				}
				// Select random menu item (excluding "Random" option)
				int random = GetRandomInt(0, g_aPrimary.Length - 1);
				int Items[Weapons];
				g_aPrimary.GetArray(random, Items[0]);
				GivePlayerItem(client, Items[number]);
			}
			else
			{
				if (weaponindex != -1)
				{
					GetEdictClassname(weaponindex, weapons, 128);
					if (!StrEqual(weapons, g_sPrimaryWeapon[client]))
					{
						RemovePlayerItem(client, weaponindex);
						AcceptEntityInput(weaponindex, "Kill");
						
						GivePlayerItem(client, g_sPrimaryWeapon[client]);
					}
				}
				else
				{
					
					GivePlayerItem(client, g_sPrimaryWeapon[client]);
				}
			}
		}
		
		// next
		
		weaponindex = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		if (StrEqual(g_sSecondaryWeapon[client], "random"))
		{
			if (weaponindex != -1)
			{
				RemovePlayerItem(client, weaponindex);
				AcceptEntityInput(weaponindex, "Kill");
			}
			// Select random menu item (excluding "Random" option)
			int random = GetRandomInt(0, g_aSecoundary.Length - 1);
			int Items[Weapons];
			g_aSecoundary.GetArray(random, Items[0]);
			GivePlayerItem(client, Items[number]);
		}
		else
		{
			if (weaponindex != -1)
			{
				GetEdictClassname(weaponindex, weapons, 128);
				if (!StrEqual(weapons, g_sSecondaryWeapon[client]))
				{
					RemovePlayerItem(client, weaponindex);
					AcceptEntityInput(weaponindex, "Kill");
					
					GivePlayerItem(client, g_sSecondaryWeapon[client]);
				}
			}
			else
			{
				
				GivePlayerItem(client, g_sSecondaryWeapon[client]);
			}
		}
		g_bWeaponsGivenThisRound[client] = true;
		
		if (GetPlayerWeaponSlot(client, 2) == -1)GivePlayerItem(client, "weapon_knife");
		FakeClientCommand(client, "use weapon_knife");
		PrintToChat(client, "[\x04GUNS\x01] %t.", "Change_Weapons");
		//PrintToChat(client, "Primary weapons is %s secondary weapons is %s y valor primary es %i",g_sPrimaryWeapon[client], g_sSecondaryWeapon[client], strcmp(g_sPrimaryWeapon[client], ""));
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client))
	{
		g_bHasFlag[client] = false;
		char buffer[16];
		g_cFlags.GetString(buffer, sizeof(buffer));
		if (strlen(buffer) > 0)
		{
			char sFlags[16];
			AdminFlag aFlags[16];
			
			Format(sFlags, sizeof(sFlags), buffer);
			FlagBitsToArray(ReadFlagString(sFlags), aFlags, sizeof(aFlags));
			
			if (HasFlags(client, aFlags))
			{
				g_bHasFlag[client] = true;
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	ResetClientSettings(client);
}

public void OnClientCookiesCached(int client)
{
	GetClientCookie(client, g_hWeapons1, g_sPrimaryWeapon[client], 24);
	GetClientCookie(client, g_hWeapons2, g_sSecondaryWeapon[client], 24);
	g_bRememberChoice[client] = GetCookie(client);
	g_awpChance[client] = false;
}

void ResetClientSettings(int client)
{
	g_bWeaponsGivenThisRound[client] = false;
	g_bNewWeaponsSelected[client] = false;
}

public void OnClientDisconnect(int client)
{
	CloseTimer(client);
	
	delete g_mOptionsMenu3[client];
	g_awpSelected[client] = false;
	SetClientCookie(client, g_hWeapons1, g_sPrimaryWeapon[client]);
	SetClientCookie(client, g_hWeapons2, g_sSecondaryWeapon[client]);
}

public void CloseTimer(int client)
{
	if (g_hTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hTimer[client]);
		g_hTimer[client] = INVALID_HANDLE;
	}
}


void ListWeapons()
{
	g_aPrimary.Clear();
	g_aSecoundary.Clear();
	
	int Items[Weapons];
	
	Format(Items[number], 64, "weapon_negev");
	Format(Items[desc], 64, "Negev");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_m249");
	Format(Items[desc], 64, "M249");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_bizon");
	Format(Items[desc], 64, "PP-Bizon");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_p90");
	Format(Items[desc], 64, "P90");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_scar20");
	Format(Items[desc], 64, "SCAR-20");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_g3sg1");
	Format(Items[desc], 64, "G3SG1");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_m4a1");
	Format(Items[desc], 64, "M4A1");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_m4a1_silencer");
	Format(Items[desc], 64, "M4A1-S");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_ak47");
	Format(Items[desc], 64, "AK-47");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_aug");
	Format(Items[desc], 64, "AUG");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_galilar");
	Format(Items[desc], 64, "Galil AR");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_sg556");
	Format(Items[desc], 64, "SG 553");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_ump45");
	Format(Items[desc], 64, "UMP-45");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_mp7");
	Format(Items[desc], 64, "MP7");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_famas");
	Format(Items[desc], 64, "FAMAS");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_mp9");
	Format(Items[desc], 64, "MP9");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_mac10");
	Format(Items[desc], 64, "MAC-10");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_ssg08");
	Format(Items[desc], 64, "SSG 08");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_nova");
	Format(Items[desc], 64, "Nova");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_xm1014");
	Format(Items[desc], 64, "XM1014");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_sawedoff");
	Format(Items[desc], 64, "Sawed-Off");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_mag7");
	Format(Items[desc], 64, "MAG-7");
	g_aPrimary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_awp");
	Format(Items[desc], 64, "AWP");
	g_aPrimary.PushArray(Items[0]);
	
	
	
	// Secondary weapons
	Format(Items[number], 64, "weapon_elite");
	Format(Items[desc], 64, "Dual Berettas");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_deagle");
	Format(Items[desc], 64, "Desert Eagle");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_tec9");
	Format(Items[desc], 64, "Tec-9");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_fiveseven");
	Format(Items[desc], 64, "Five-SeveN");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_cz75a");
	Format(Items[desc], 64, "CZ75-Auto");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_glock");
	Format(Items[desc], 64, "Glock-18");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_usp_silencer");
	Format(Items[desc], 64, "USP-S");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_p250");
	Format(Items[desc], 64, "P250");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_hkp2000");
	Format(Items[desc], 64, "P2000");
	g_aSecoundary.PushArray(Items[0]);
	
	Format(Items[number], 64, "weapon_revolver");
	Format(Items[desc], 64, "Revolver");
	g_aSecoundary.PushArray(Items[0]);
}

bool GetCookie(int client)
{
	char buffer[10];
	GetClientCookie(client, remember, buffer, sizeof(buffer));
	
	return StrEqual(buffer, "On");
}

void giveDefaultWeapons(int client)
{
	int weaponindex = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
	if (weaponindex != -1)
	{
		RemovePlayerItem(client, weaponindex);
		AcceptEntityInput(weaponindex, "Kill");
	}
	weaponindex = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
	if (weaponindex != -1)
	{
		RemovePlayerItem(client, weaponindex);
		AcceptEntityInput(weaponindex, "Kill");
	}
	
	int team = GetClientTeam(client);
	if(team == CS_TEAM_CT) {
		char weapon[128];
		GetConVarString(cv_defaultWeaponCT_primary, weapon, 128);
		GivePlayerItem(client, weapon);
		GetConVarString(cv_defaultWeaponCT_secondary, weapon, 128);
		GivePlayerItem(client, weapon);
		
	} else {
		char weapon[128];
		GetConVarString(cv_defaultWeaponT_primary, weapon, 128);
		GivePlayerItem(client, weapon);
		GetConVarString(cv_defaultWeaponT_secondary, weapon, 128);
		GivePlayerItem(client, weapon);
		
	}
}

void setAwpSpots()
{
	//PrintToConsoleAll("camino awps");
	Handle array_players = CreateArray();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{	
			if(g_awpSelected[i])
			{
				PrintToChat(i, "[\x04GUNS\x01] %t.", "awpChanceEnded");
			}
			if(GetClientTeam(i) > 1 && g_awpChance[i] && !g_bHasFlag[i])
			{
				//PrintToConsoleAll("camino awps metido %i", i);
				PushArrayCell(array_players, i);
			}
		}
		g_awpSelected[i] = false;
	}
	
	if(GetArraySize(array_players) == 0) 
	{
		delete array_players;
		return;
	}
	int needed = cv_awpSpots.IntValue;
	
	while(GetArraySize(array_players) > 0 && needed > 0)
	{
		//PrintToConsoleAll("camino awps vuelta");
		int index = GetArrayCell(array_players, GetRandomInt(0, GetArraySize(array_players) - 1));
		g_awpSelected[index] = true;
		PrintToChat(index, "[\x04GUNS\x01] %t.", "AwpSelectedForYou");
		RemoveFromArray(array_players, index-1);
	}
	
	delete array_players;
}

stock void RemoveNades(int iClient)
{
	while (RemoveWeaponBySlot(iClient, 3)) {  }
}

stock bool RemoveWeaponBySlot(int iClient, int iSlot)
{
	int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
	if (IsValidEdict(iEntity)) {
		RemovePlayerItem(iClient, iEntity);
		AcceptEntityInput(iEntity, "Kill");
		return true;
	}
	return false;
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return false;
	
	return true;
}


stock bool HasFlags(int client, AdminFlag flags[16])
{
	int iFlags = GetUserFlagBits(client);
	
	if (iFlags & ADMFLAG_ROOT)
		return true;
	
	for (int i = 0; i < sizeof(flags); i++)
	if (iFlags & FlagToBit(flags[i]))
		return true;
	
	return false;
}
