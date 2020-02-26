#pragma semicolon 1
#include <clientprefs>

public Plugin myinfo = 
{
	name		= "Shower of Health",
	version		= "1.0",
	description	= "Shower of your hp",
	author		= "ღ λŌK0ЌЭŦ ღ ™",
	url			= "https://github.com/IL0co"
}

static const char SPACE[][][] = {{"", "", "", "", "", "", ""},
						  		{"", " ", "  ", "   ", "    ", "     ", "      "},
								{"", "  ", "    ", "      ", "        ", "          ", "            "}, 
								{"", "   ", "      ", "         ", "            ", "               ", "                  "},
								{"", "    ", "        ", "            ", "                ", "                    ", "                        "},
								{"", "     ", "          ", "               ", "                    ", "                         ", "                              "},
								{"", "      ", "            ", "                  ", "                        ", "                              ", "                                    "},
								{"", "       ", "              ", "                     ", "                            ", "                                   ", "                                         "}};

char oldValue[MAXPLAYERS+1][5][16];
int	iHealthNow[MAXPLAYERS+1];
float iTime[MAXPLAYERS+1];
	
bool g_bHUD[MAXPLAYERS+1];
	
Handle g_hCookie, iHud, iTimer[MAXPLAYERS+1];

ConVar cvar_cCount, 
	   cvar_cType,
	   cvar_cTimeClean, 
	   cvar_cTimeUpdate, 
	   cvar_cTypePoss, 
	   cvar_cHudColor, 
	   cvar_cHudPoss, 
	   cvar_cTimeHide, 
	   cvar_cEnable;

int cCount, cType, cTypePoss, cHudColor[4];
float cTimeClean, cTimeUpdate, cHudPoss[2], cTimeHide;
bool cEnable;

public void OnPluginStart()
{
	iHud = CreateHudSynchronizer();
	g_hCookie = RegClientCookie("shower_health", "shower_health", CookieAccess_Private);
	SetCookieMenuItem(CreditsCookieHandler, 0, "shower_health");
	for(int i = 1; i <= MaxClients; i++)	if(IsClientInGame(i) && IsClientAuthorized(i))
		OnClientCookiesCached(i);

	(cvar_cEnable = CreateConVar("sm_shower_health_enable", "1", "RU: Включен ли плагин?\nEN: Enabled plugin?", _, true, 0.0, true, 1.0)).AddChangeHook(CVarChanged);
	cEnable = cvar_cEnable.BoolValue;

	(cvar_cCount = CreateConVar("sm_shower_health_count", "5", "RU: Количество столбиков\nEN: Number of posts", _, true, 1.0, true, 5.0)).AddChangeHook(CVarChanged);
	cCount = cvar_cCount.IntValue;

	(cvar_cType = CreateConVar("sm_shower_health_type", "2", "RU: На сколько смещать каждую новую строчку? (в пробелах)\nEN: How much to shift each new line? (in spaces)", _, true, 0.0, true, 7.0)).AddChangeHook(CVarChanged);
	cType = cvar_cType.IntValue;

	(cvar_cTypePoss = CreateConVar("sm_shower_health_type_poss", "0", "RU: Куда уходит лесенка начиная от прицела?, 0 - в левый низ, 1 - в правый вверх, 2 - в правый низ, 3 - в левый вверх\nEN: Where does the ladder go from the sight ?, 0 - to the left bottom, 1 - to the right up, 2 - to the right bottom, 3 - to the left up", _, true, 0.0, true, 3.0)).AddChangeHook(CVarChanged);
	cTypePoss = cvar_cTypePoss.IntValue;

	(cvar_cTimeClean = CreateConVar("sm_shower_health_clean_time", "2.0", "RU: Время очищения истории\nEN: History Cleansing Time", _, true, 0.1)).AddChangeHook(CVarChanged);
	cTimeClean = cvar_cTimeClean.FloatValue;

	(cvar_cTimeUpdate = CreateConVar("sm_shower_health_update_time", "0.5", "Время проверки изменения хп. Требуется рестарт плагина!\nEN: Check time changes hp. Restart plugin required!", _, true, 0.1)).AddChangeHook(CVarChanged);
	cTimeUpdate = cvar_cTimeUpdate.FloatValue;

	(cvar_cHudColor = CreateConVar("sm_shower_health_rgba", "255 0 255 255", "RU: RGBA цвет худа\nEN: RGBA color hud")).AddChangeHook(CVarChanged);
	SetHUDColor(cvar_cHudColor);

	(cvar_cHudPoss = CreateConVar("sm_shower_health_poss", "0.38 0.5", "RU: XY позиция худа\nEN: XY hud position")).AddChangeHook(CVarChanged);
	SetHUDPosition(cvar_cHudPoss);

	(cvar_cTimeHide = CreateConVar("sm_shower_health_hide_time", "2.0", "RU: Время скрытия худа\nEN: Hud hiding time", _, true, 0.1)).AddChangeHook(CVarChanged);
	cTimeHide = cvar_cTimeHide.FloatValue;

	AutoExecConfig(true, "shower_health");

	CreateTimer(cTimeUpdate, timerhealthOut, _, TIMER_REPEAT);
	LoadTranslations("shower_base.phrases");
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
}

public Action timerhealthOut(Handle timer)
{
	if(!cEnable) return;
	for(int client = 1; client <= MaxClients; client++) if(IsClientInGame(client) && g_bHUD[client])
	{
		char textBuff[256];
		int currHealth, health;

		health = GetEntProp(client, Prop_Send, "m_iHealth");
		currHealth = health-iHealthNow[client];

		if(iHealthNow[client] != health || health != 100 && currHealth != 0)
		{
			iTime[client] = cTimeClean;
			iTimer[client] = CreateTimer(0.1, TimerDamege_Clean, GetClientUserId(client), TIMER_REPEAT);

			if(health > iHealthNow[client]) Format(oldValue[client][0], sizeof(oldValue[][]), "+%i", currHealth);
			else Format(oldValue[client][0], sizeof(oldValue[][]), "%i", currHealth);

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

			iHealthNow[client] = health;
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

public void OnClientCookiesCached(int client)
{
    char szValue[4];
    GetClientCookie(client, g_hCookie, szValue, sizeof(szValue));
    if(!szValue[0]) g_bHUD[client] = true;
    else g_bHUD[client] = view_as<bool>(StringToInt(szValue));
}

public void CreditsCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(!cEnable) return;
	switch (action)
    {
		case CookieMenuAction_DisplayOption:
		{
			SetGlobalTransTarget(client);
			FormatEx(buffer, maxlen, "%t%t", g_bHUD[client] ? "Plus" : "Minus", "Health");
		}
		case CookieMenuAction_SelectOption:
		{
			if(g_bHUD[client]) 	SetClientCookie(client, g_hCookie, "0");
			else 				SetClientCookie(client, g_hCookie, "1");

			g_bHUD[client] = !g_bHUD[client];
			
			ShowCookieMenu(client);
		}
    }
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
