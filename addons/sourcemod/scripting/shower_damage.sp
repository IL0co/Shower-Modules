#include <clientprefs>
#include <sourcemod>

#undef REQUIRE_PLUGIN
#tryinclude <vip_core>
#undef REQUIRE_PLUGIN
#tryinclude <shop>

public Plugin myinfo = 
{
	name		= "[VIP/SHOP/ANY] Shower of Damage",
	version		= "1.0.1",
	description	= "Shower of your damage",
	author		= "iLoco",
	url			= "https://github.com/IL0co"
}

#pragma semicolon 1
#pragma newdecls required

static const char SPACE[][][] = {{"", "", "", "", "", "", ""},
						  		{"", " ", "  ", "   ", "	", "	 ", "	  "},
								{"", "  ", "	", "	  ", "		", "		  ", "			"}, 
								{"", "   ", "	  ", "		 ", "			", "			   ", "				  "},
								{"", "	", "		", "			", "				", "					", "						"},
								{"", "	 ", "		  ", "			   ", "					", "						 ", "							  "},
								{"", "	  ", "			", "				  ", "						", "							  ", "									"},
								{"", "	   ", "			  ", "					 ", "							", "								   ", "										 "}};

enum ShowerEnable
{
	NONE = 0,
	ANY = 1,
	VIP = 2,
	SHOP = 4
};

char gPath[256];
KeyValues kv;
Cookie gCookie;
ShowerEnable gEnable;

char iOldValues[MAXPLAYERS+1][5][16];
Handle gHud, iTimer[MAXPLAYERS+1];
ShowerEnable iEnable[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int max)
{
	__pl_vip_core_SetNTVOptional();
	__pl_shop_SetNTVOptional();

	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "vip_core", false) == 0)
		gEnable |= VIP;

	if(strcmp(name, "shop", false) == 0)
		gEnable |= SHOP;
}

public void OnLibraryRemoved(const char[] name)
{
	if(strcmp(name, "vip_core", false) == 0)
		gEnable &= ~VIP;

	if(strcmp(name, "shop", false) == 0)
		gEnable &= ~SHOP;
}

public void OnPluginEnd()
{
	if(gEnable & VIP)
		VIP_UnregisterMe();

	if(gEnable & SHOP)
		Shop_UnregisterMe();
}

public void OnPluginStart()
{
	BuildPath(Path_SM, gPath, sizeof(gPath), "configs/shower_damage.cfg");
	LoadCfg();

	if(LibraryExists("vip_core"))
	{
		gEnable |= VIP;

		if(VIP_IsVIPLoaded())
			VIP_OnVIPLoaded();
	}

	if(LibraryExists("shop"))
	{
		gEnable |= SHOP;

		if(Shop_IsStarted())	
			Shop_Started();
	}

	gHud = CreateHudSynchronizer();

	if(gEnable & ANY)
	{
		gCookie = new Cookie("shower_damage", "shower_damage", CookieAccess_Private);
		SetCookieMenuItem(CreditsCookieHandler, 0, "shower_damage");
	}

	for(int i = 1; i <= MaxClients; i++)	if(IsClientAuthorized(i) && IsClientInGame(i))
	{
		OnClientCookiesCached(i);
		OnClientPostAdminCheck(i);
	}

	HookEvent("player_hurt", Event_PlayerHurt);

	LoadTranslations("shower_base.phrases");
}

public void VIP_OnVIPLoaded()
{
	if(gEnable & VIP && JumpTo(0, "vip"))
	{
		char feature[64];
		kv.GetString("vip feature name", feature, sizeof(feature), "shower_damage");
		VIP_RegisterFeature(feature, BOOL, _, CallBack_VIP_OnItemToggled, CallBack_VIP_OnItemDisplay);
	}
}

public Action CallBack_VIP_OnItemToggled(int client, const char[] sFeatureName, VIP_ToggleState OldStatus, VIP_ToggleState &NewStatus)
{
	if(NewStatus == ENABLED)
		iEnable[client] |= VIP;
	else
		iEnable[client] &= ~VIP;

	return Plugin_Continue;
}

public bool CallBack_VIP_OnItemDisplay(int client, const char[] feature, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "Menu. VIP. Damage", client);
	VIP_AddStringToggleStatus(buffer, buffer, maxlen, feature, client);

	return true;
}

public void Shop_Started()
{
	if(!(gEnable & SHOP) || !JumpTo(0, "shop"))
		return;

	char item[64];
	kv.GetString("vip feature name", item, sizeof(item), "shower_damage");

	CategoryId category_id = Shop_RegisterCategory("stuff", "stuff", "");
	if(Shop_StartItem(category_id, item))
	{
		Shop_SetInfo(item, "", kv.GetNum("shop item price"), kv.GetNum("shop item sell price"), Item_Togglable, kv.GetNum("shop item duration"));
		Shop_SetCallbacks(_, CallBack_Shop_OnItemUsed, _, CallBack_Shop_OnDisplay);
		Shop_EndItem();
	}
}

public bool CallBack_Shop_OnDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "Menu. SHOP. Damage", client);
	return true;
}

public ShopAction CallBack_Shop_OnItemUsed(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if(!isOn)
		iEnable[client] |= SHOP;
	else
		iEnable[client] &= ~SHOP;

	if (isOn || elapsed)
		return Shop_UseOff;

	return Shop_UseOn;
}

public Action Event_PlayerHurt(Event hEvent, const char[] name, bool dontBroadcast)
{
	static char textBuff[256];
	static int client, victim, damage, rgba[4];
	static float pos[3];

	client = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if(!client || !IsClientInGame(client) || !JumpTo(client)) 
		return Plugin_Continue;

	victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client != victim)
	{
		damage = GetEventInt(hEvent, "dmg_health");
		
		if(iTimer[client]) 
			delete iTimer[client];
		iTimer[client] = CreateTimer(kv.GetFloat("clean time", 1.0), TimerDamege_Clean, GetClientUserId(client), TIMER_REPEAT);

		if(damage == -1) 
			Format(iOldValues[client][0], sizeof(iOldValues[][]), "%T", "Killed", client);
		else 
			Format(iOldValues[client][0], sizeof(iOldValues[][]), "-%i", damage);
		
		SetTextAlign(client, kv.GetNum("number of offsets", 1), kv.GetNum("align"), textBuff, sizeof(textBuff));
		
		for(int poss = kv.GetNum("number of columns") - 1; poss > 0; poss--)	
			iOldValues[client][poss] = iOldValues[client][poss-1];

		kv.GetColor4("hud color", rgba);
		kv.GetVector("hud position", pos);

		SetHudTextParams(pos[0], pos[1], kv.GetFloat("hide time", 3.0), rgba[0], rgba[1], rgba[2], rgba[3], 0, 0.0, 0.1, 0.1);
		ShowSyncHudText(client, gHud, textBuff);

	}

	return Plugin_Continue;
}

public Action TimerDamege_Clean(Handle timer, any client)
{
	client = GetClientOfUserId(client);

	for(int poss = 0; poss < 5; poss++)
		iOldValues[client][poss][0] = '\0';

	iTimer[client] = null;
			
	return Plugin_Stop;
}

public void OnClientPostAdminCheck(int client)
{
	iEnable[client] = NONE;
	iTimer[client] = null;
}

public void OnClientCookiesCached(int client)
{
	if(!(gEnable & ANY)) 
		return;

	char buff[4];
	gCookie.Get(client, buff, sizeof(buff));

	if(!buff[0] || buff[0] == '1') 
		iEnable[client] |= ANY;
}

public void CreditsCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_DisplayOption)
	{
		SetGlobalTransTarget(client);
		FormatEx(buffer, maxlen, "%t%t", iEnable[client] & ANY ? "Plus" : "Minus", "Menu. Any. Damage");
	}
	else if(action == CookieMenuAction_SelectOption)
	{	
		if(iEnable[client] & ANY)
			iEnable[client] &= ~ANY;
		else
			iEnable[client] |=ANY;

		gCookie.Set(client, iEnable[client] & ANY ? "1" : "0");

		ShowCookieMenu(client);
	}
}

stock void SetTextAlign(int client, int offset, int position, char[] textBuff, int size = 256)
{
	if(textBuff[0])
		textBuff[0] = '\0';

	if(position == 0)
	{
		for(int poss = 0, poss2 = 5; poss < 5; poss++, poss2--)	if(iOldValues[client][poss][0])
		{
			Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[offset][poss2], iOldValues[client][poss]);
		}
	}
	else if(position == 1)
	{
		for(int poss = 5; poss > 0; poss--)
		{
			if(iOldValues[client][poss-1][0])
				Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[offset][poss], iOldValues[client][poss-1]);
			else
				Format(textBuff, size, "%s\n%s", textBuff, SPACE[offset][poss]);
		}
	}
	else if(position == 2)
	{
		for(int poss = 0, poss2 = 5; poss < 5; poss++, poss2--)	if(iOldValues[client][poss][0])
		{
			Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[offset][poss], iOldValues[client][poss]);
		}
	}
	else if(position == 3)
	{
		for(int poss = 0, poss2 = 5; poss < 5; poss++, poss2--)
		{
			if(iOldValues[client][poss2-1][0])
				Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[offset][poss], iOldValues[client][poss2-1]);
			else
				Format(textBuff, size, "%s\n%s", textBuff, SPACE[offset][poss]);
		}
	}
}

stock void LoadCfg()
{
	if(kv)
		delete kv;
	
	kv = new KeyValues("Shower Damage");
	if(!kv.ImportFromFile(gPath))
		SetFailState("Does not find file '%s'", gPath);

	if(JumpTo(0, "any"))
		gEnable |= ANY;
}

stock bool JumpTo(int client = 0, char[] key = "")
{
	kv.Rewind();

	if(key[0] && kv.JumpToKey(key) && kv.GetNum("enable"))
		return true;
	else if(client && iEnable[client] != NONE)
		return ((gEnable & VIP && iEnable[client] & VIP && JumpTo(0, "vip")) || (gEnable & SHOP && iEnable[client] & SHOP && JumpTo(0, "shop")) || (gEnable & ANY && iEnable[client] & ANY && JumpTo(0, "any")));

	return false;
}