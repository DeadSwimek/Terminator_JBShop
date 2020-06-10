/*
 * MyJailShop - Freeday Item Module.
 * by: shanapu
 * https://github.com/shanapu/MyJailShop/
 *
 * This file is part of the MyJailShop SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http:// www.gnu.org/licenses/>.
 */


// Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <emitsoundany>
#include <colors>
#include <mystocks>
#include <myjailshop>
#include <myjbwarden>
#include <fpvm_interface>
#include <autoexecconfig>  // add new cvars to existing .cfg file
#include <warden>

// Compiler Options
#pragma semicolon 1
#pragma newdecls required


// ConVars shop specific
ConVar gc_iItemPrice;
ConVar gc_iItemPrice2;
ConVar gc_sItemFlag;
ConVar gc_sItemFlag2;


int iVyp;


// Strings shop specific
char g_sItemFlag[64];
char g_sItemFlag2[64];
char g_sPurchaseLogFile[PLATFORM_MAX_PATH];

bool remove[MAXPLAYERS+1];

// Handels shop specific
Handle gF_hOnPlayerBuyItem;


// Start
public Plugin myinfo =
{
	name = "Freeday for MyJailShop",
	author = "shanapu",
	description = "Buy a MyJB warden Freeday item for next round",
	version = "1.0",
	url = "https://github.com/shanapu"
};


public void OnPluginStart()
{
	// Translation
	LoadTranslations("MyJailShop.phrases");


	// Add new Convars to existing Items.cfg
	AutoExecConfig_SetFile("Items", "MyJailShop");
	AutoExecConfig_SetCreateFile(true);

	// Register ConVars
	gc_iItemPrice = AutoExecConfig_CreateConVar("sm_jailshop_noze_price", "4500", "Price of a Freeday");
	gc_iItemPrice2 = AutoExecConfig_CreateConVar("sm_jailshop_noze_price2", "5500", "Price of a Freeday");
	gc_sItemFlag = AutoExecConfig_CreateConVar("sm_jailshop_noze_flag", "", "Set flag for admin/vip must have to get access to freeday. No flag = is available for all players!");
	gc_sItemFlag2 = AutoExecConfig_CreateConVar("sm_jailshop_noze_flag2", "t", "Set flag for admin/vip must have to get access to freeday. No flag = is available for all players!");

	// Add new Convars to existing Items.cfg
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	// Set file for Logs
	SetLogFile(g_sPurchaseLogFile, "purchase", "MyJailShop");
}

public void OnMapStart()
{

    AddFileToDownloadsTable("sound/madgames/jailbreak/buy.mp3");
    PrecacheSoundAny("madgames/jailbreak/buy.mp3");

	iVyp = PrecacheModel("models/weapons/eminem/wooden_jutte/v_wooden_jutte.mdl");

}


public void OnConfigsExecuted()
{
	gc_sItemFlag.GetString(g_sItemFlag, sizeof(g_sItemFlag));
	gc_sItemFlag2.GetString(g_sItemFlag2, sizeof(g_sItemFlag2));
}


// Here we add an new item to shop menu
public void MyJailShop_OnShopMenu(int client, Menu menu)
{
	if (GetClientTeam(client) == CS_TEAM_CT)
	{
		char info[64];
		Format(info, sizeof(info), "%t", "shop_menu_terminator", gc_iItemPrice2.IntValue);

		if (MyJailShop_GetCredits(client) >= gc_iItemPrice2.IntValue && MyJailShop_IsBuyTime() && IsPlayerAlive(client) && CheckVipFlag(client, g_sItemFlag2)) 
			AddMenuItem(menu, "VYP1", info);
		else if (CheckVipFlag(client, g_sItemFlag2)) 
			AddMenuItem(menu, "VYP1", info, ITEMDRAW_DISABLED);
	}
}


// What should we do when new item was picked?
public void MyJailShop_OnShopMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if (!IsValidClient(client, false, false))
	{
		return;
	}

	if (action == MenuAction_Select)
	{
		if (MyJailShop_IsBuyTime())
		{
			char info[64];
			menu.GetItem(itemNum, info, sizeof(info));
			
			if (StrEqual(info, "VYP1"))
			{
				Item_VYP1(client, info);
			}
		}
	}

	return;
}


void Item_VYP1(int client, char[] name)
{
	if (!warden_iswarden(client))
	{
	// has player enough credits?
	if (MyJailShop_GetCredits(client) < gc_iItemPrice2.IntValue)
	{
		CPrintToChat(client, "%t %t", "shop_tag", "shop_missingcredits", MyJailShop_GetCredits(client), gc_iItemPrice2.IntValue);
		return;
	}
    EmitSoundToAllAny("madgames/jailbreak/buy.mp3", _, _, _, _, 0.8); 

	FPVMI_AddViewModelToClient(client, "weapon_knife", iVyp);

	SetEntityRenderColor(client, 0, 255, 0, 255);

	int health = GetEntProp(client, Prop_Send, "m_iHealth");
	int nowhealth = health + 150;
	SetEntityHealth(client, nowhealth);
	
    SetEntProp( client, Prop_Send, "m_ArmorValue", 200, 1 ); 

    float speed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
    float nowspeed = speed + 1.2;
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", nowspeed);

	// now we take his money & push the forward
	MyJailShop_SetCredits(client,(MyJailShop_GetCredits(client) - gc_iItemPrice2.IntValue));
	Forward_OnPlayerBuyItem(client, name);



	// announce it
	CPrintToChat(client, "%t %t", "shop_tag", "shop_terminator");
	CPrintToChat(client, "%t %t", "shop_tag", "shop_costs", MyJailShop_GetCredits(client), gc_iItemPrice2.IntValue);

	// log it
	ConVar c_bLogging = FindConVar("sm_jailshop_log");
	if (c_bLogging.BoolValue)
	{
		LogToFileEx(g_sPurchaseLogFile, "Player %L bought: Terminátora", client);
	}
	}else{
	PrintToChat(client, " \x02---- \x04Tento předmět si jako warden nemůžeš koupit \x02----");
	PrintToChat(client, " \x02---- \x04Tento předmět si jako warden nemůžeš koupit \x02----");
	PrintToChat(client, " \x02---- \x04Tento předmět si jako warden nemůžeš koupit \x02----");
	PrintToChat(client, " \x02---- \x04Tento předmět si jako warden nemůžeš koupit \x02----");
	}
}

// Forward MyJailShop_OnPlayerBuyItem
void Forward_OnPlayerBuyItem(int client, char[] item)
{
	Call_StartForward(gF_hOnPlayerBuyItem);
	Call_PushCell(client);
	Call_PushString(item);
	Call_Finish();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gF_hOnPlayerBuyItem = CreateGlobalForward("MyJailShop_OnPlayerBuyItem", ET_Ignore, Param_Cell, Param_String);

	return APLRes_Success;
}