#pragma semicolon 1
#include <shop>

public Plugin myinfo = 
{
	name		= "[Shop] Shower of Armor",
	version		= "1.0",
	description	= "",
	author		= "ღ λŌK0ЌЭŦ ღ ™",
	url			= "https://github.com/IL0co"
}

#define CATEGORY	"shower"
#define ITEM	"shower_armor"

static const char SPACE[][][] = {{"", "", "", "", "", "", ""},
						  		{"", " ", "  ", "   ", "    ", "     ", "      "},
								{"", "  ", "    ", "      ", "        ", "          ", "            "}, 
								{"", "   ", "      ", "         ", "            ", "               ", "                  "},
								{"", "    ", "        ", "            ", "                ", "                    ", "                        "},
								{"", "     ", "          ", "               ", "                    ", "                         ", "                              "},
								{"", "      ", "            ", "                  ", "                        ", "                              ", "                                    "},
								{"", "       ", "              ", "                     ", "                            ", "                                   ", "                                         "}};

char oldValue[MAXPLAYERS+1][5][16];
int	iArmorNow[MAXPLAYERS+1];
float iTime[MAXPLAYERS+1];
	
bool iEnable[MAXPLAYERS+1];
	
Handle iHud, iTimer[MAXPLAYERS+1];

ConVar cvar_cCount, 
	   cvar_cType,
	   cvar_cTimeClean, 
	   cvar_cTimeUpdate, 
	   cvar_cTypePoss, 
	   cvar_cHudColor, 
	   cvar_cHudPoss, 
	   cvar_cTimeHide,
	   cvar_Price, 
	   cvar_SellPrice, 
	   cvar_Duration,
	   cvar_cEnable;

int cCount, cType, cTypePoss, cHudColor[4], cSellPrice, cDuration, cPrice;
float cTimeClean, cTimeUpdate, cHudPoss[2], cTimeHide;
bool cEnable;
ItemId iId;

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnPluginStart()
{
	iHud = CreateHudSynchronizer();

	(cvar_cEnable = CreateConVar("sm_shower_armor_enable", "1", "RU: Включен ли плагин?\nEN: Enabled plugin?", _, true, 0.0, true, 1.0)).AddChangeHook(CVarChanged);
	cEnable = cvar_cEnable.BoolValue;

	(cvar_cCount = CreateConVar("sm_shower_armor_count", "5", "RU: Количество столбиков\nEN: Number of posts", _, true, 1.0, true, 5.0)).AddChangeHook(CVarChanged);
	cCount = cvar_cCount.IntValue;

	(cvar_cType = CreateConVar("sm_shower_armor_type", "2", "RU: На сколько смещать каждую новую строчку? (в пробелах)\nEN: How much to shift each new line? (in spaces)", _, true, 0.0, true, 7.0)).AddChangeHook(CVarChanged);
	cType = cvar_cType.IntValue;

	(cvar_cTypePoss = CreateConVar("sm_shower_armor_type_poss", "0", "RU: Куда уходит лесенка начиная от прицела?, 0 - в левый низ, 1 - в правый вверх, 2 - в правый низ, 3 - в левый вверх\nEN: Where does the ladder go from the sight ?, 0 - to the left bottom, 1 - to the right up, 2 - to the right bottom, 3 - to the left up", _, true, 0.0, true, 3.0)).AddChangeHook(CVarChanged);
	cTypePoss = cvar_cTypePoss.IntValue;

	(cvar_cTimeClean = CreateConVar("sm_shower_armor_clean_time", "2.0", "RU: Время очищения истории\nEN: History Cleansing Time", _, true, 0.1)).AddChangeHook(CVarChanged);
	cTimeClean = cvar_cTimeClean.FloatValue;

	(cvar_cTimeUpdate = CreateConVar("sm_shower_armor_update_time", "0.5", "RU: Время проверки изменения брони. Требуется рестарт плагина!\nEN: Check time changes armor. Restart plugin required!", _, true, 0.1)).AddChangeHook(CVarChanged);
	cTimeUpdate = cvar_cTimeUpdate.FloatValue;

	(cvar_cHudColor = CreateConVar("sm_shower_armor_rgba", "153 153 153 255", "RU: RGBA цвет худа\nEN: RGBA color hud")).AddChangeHook(CVarChanged);
	SetHUDColor(cvar_cHudColor);

	(cvar_cHudPoss = CreateConVar("sm_shower_armor_poss", "0.32 0.5", "RU: XY позиция худа\nEN: XY hud position")).AddChangeHook(CVarChanged);
	SetHUDPosition(cvar_cHudPoss);

	(cvar_cTimeHide = CreateConVar("sm_shower_armor_hide_time", "2.0", "RU: Время скрытия худа\nEN: Hud hiding time", _, true, 0.1)).AddChangeHook(CVarChanged);
	cTimeHide = cvar_cTimeHide.FloatValue;
	
	(cvar_Price = CreateConVar("sm_shop_shower_armor_price", "500", "RU: Цена предмета \nEN: Item price")).AddChangeHook(CVarChanged);
	cPrice = cvar_Price.IntValue;

	(cvar_SellPrice = CreateConVar("sm_shop_shower_armor_sellprice", "250", "RU: Цена продажи предмета \nEN: Item selling price")).AddChangeHook(CVarChanged);
	cSellPrice = cvar_SellPrice.IntValue;

	(cvar_Duration = CreateConVar("sm_shop_shower_armor_duration", "86400", "RU: Длительность предмета \nEN: Item Duration")).AddChangeHook(CVarChanged);
	cDuration = cvar_Duration.IntValue;

	AutoExecConfig(true, "shop_shower_armor", "shop");

	CreateTimer(cTimeUpdate, timerarmorOut, _, TIMER_REPEAT);
	LoadTranslations("shop_shower_base.phrases");
}

public void CVarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	if(cvar == cvar_cCount)				cCount = cvar.IntValue;
	else if(cvar == cvar_cType)			cType = cvar.IntValue;
	else if(cvar == cvar_cTypePoss)		cTypePoss = cvar.IntValue;
	else if(cvar == cvar_cTimeClean)	cTimeClean = cvar.FloatValue;
	else if(cvar == cvar_cTimeHide)		cTimeHide = cvar.FloatValue;
	else if(cvar == cvar_cEnable)		cEnable = cvar.BoolValue;
	else if(cvar == cvar_cHudColor)		SetHUDColor(cvar);
	else if(cvar == cvar_cHudPoss)		SetHUDPosition(cvar);
	
	else if (cvar == cvar_Price) 		cPrice = cvar.IntValue, Shop_SetItemPrice(iId, cPrice);
	else if (cvar == cvar_SellPrice) 	cSellPrice = cvar.IntValue, Shop_SetItemSellPrice(iId, cSellPrice);
	else if (cvar == cvar_Duration) 	cDuration = cvar.IntValue, Shop_SetItemValue(iId, cDuration);
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, CATEGORY, "", OnCategoryDisplay);
	if (Shop_StartItem(category_id, ITEM))
	{
		Shop_SetInfo("shower_armor", "", cPrice, cSellPrice, Item_Togglable, cDuration);
		Shop_SetCallbacks(OnItemRegistered, OnItemUsed, _, OnDisplay, OnDescription);
		Shop_EndItem();
	}
}

public bool OnCategoryDisplay(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "display", client);
	return true;
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	iId = item_id;
}

public bool OnDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "shower_armor", client);
	return true;
}

public bool OnDescription(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, const char[] description, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "shower_armor_description", client);
	return true;
}

public ShopAction OnItemUsed(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	iEnable[client] = !isOn;
	if (isOn || elapsed)
	{
		return Shop_UseOff;
	}
	return Shop_UseOn;
}
public Action timerarmorOut(Handle timer)
{
	if(!cEnable) return;
	for(int client = 1; client <= MaxClients; client++) if(IsClientInGame(client) && iEnable[client])
	{
		char textBuff[256];
		int currArmor, armor;

		armor = GetEntProp(client, Prop_Send, "m_ArmorValue");
		currArmor = armor-iArmorNow[client];

		if(iArmorNow[client] != armor || armor != 100 && currArmor != 0)
		{
			iTime[client] = cTimeClean;
			iTimer[client] = CreateTimer(0.1, TimerDamege_Clean, GetClientUserId(client), TIMER_REPEAT);

			if(armor > iArmorNow[client]) Format(oldValue[client][0], sizeof(oldValue[][]), "+%i", currArmor);
			else Format(oldValue[client][0], sizeof(oldValue[][]), "%i", currArmor);

			switch(cTypePoss)
			{
				case 0: Procc_Left_Down(client, textBuff, sizeof(textBuff));
				case 1: Procc_Right_Up(client, textBuff, sizeof(textBuff));
				case 2: Procc_Right_Down(client, textBuff, sizeof(textBuff));
				case 3: Procc_Left_Up(client, textBuff, sizeof(textBuff));
			}
			
			for(int poss = cCount-1; poss > 0; poss--)	
				oldValue[client][poss] = oldValue[client][poss-1];

			SetHudTextParams(cHudPoss[0], cHudPoss[1], cTimeHide, cHudColor[0], cHudColor[1], cHudColor[2], cHudColor[3], 0, 0.0, 0.1, 0.1);
			ShowSyncHudText(client, iHud, textBuff);

			iArmorNow[client] = armor;
		}
	}
}

public Action TimerDamege_Clean(Handle timer, any client)
{
	client = GetClientOfUserId(client);

	if(!client || !IsClientInGame(client) || iTimer[client] != timer)
		return Plugin_Stop;

	if((iTime[client] -= 0.1) <= 0.0)
	{
		for(int poss = 0; poss < cCount; poss++)
			oldValue[client][poss][0] = '\0';
			
		return Plugin_Stop;
	}

	return Plugin_Continue;
}


stock void Procc_Right_Up(int client, char[] textBuff, int size = 256)
{
	for(int poss = cCount; poss > 0; poss--)
	{
		if(oldValue[client][poss-1][0])
			Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[cType][poss], oldValue[client][poss-1]);
		else
			Format(textBuff, size, "%s\n%s", textBuff, SPACE[cType][poss]);
	}
}

stock void Procc_Left_Down(int client, char[] textBuff, int size = 256)
{
	for(int poss = 0, poss2 = cCount; poss < cCount; poss++, poss2--)	if(oldValue[client][poss][0])
	{
		Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[cType][poss2], oldValue[client][poss]);
	}
}
stock void Procc_Right_Down(int client, char[] textBuff, int size = 256)
{
	for(int poss = 0, poss2 = cCount; poss < cCount; poss++, poss2--)	if(oldValue[client][poss][0])
	{
		Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[cType][poss], oldValue[client][poss]);
	}
}

stock void Procc_Left_Up(int client, char[] textBuff, int size = 256)
{
	for(int poss = 0, poss2 = cCount; poss < cCount; poss++, poss2--)
	{
		if(oldValue[client][poss2-1][0])
			Format(textBuff, size, "%s\n%s%s", textBuff, SPACE[cType][poss], oldValue[client][poss2-1]);
		else
			Format(textBuff, size, "%s\n%s", textBuff, SPACE[cType][poss]);
	}
}

stock void SetHUDColor(ConVar cvar)
{
	char buffer[16], clr[4][4];
	cvar.GetString(buffer, sizeof(buffer));
	ExplodeString(buffer, " ", clr, 4, 4);
	for(int i; i <= 3; i++) cHudColor[i] = StringToInt(clr[i]);
}

stock void SetHUDPosition(ConVar cvar)
{
	char buffer[16], pos[2][8];
	cvar.GetString(buffer, sizeof(buffer));
	ExplodeString(buffer, " ", pos, 2, 8);
	cHudPoss[0] = StringToFloat(pos[0]);
	cHudPoss[1] = StringToFloat(pos[1]);
}
