#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#define DEBUG false


Handle g_afkTimer = null;
ConVar g_cvarEnabled;
ConVar g_cvarTime;

char g_tag[] = "[AFK Timer]";

float g_clientOldPos[MAXPLAYERS+1][3];
float g_lastMoveTime[MAXPLAYERS+1];
float g_afkDuration;

bool g_enabled;

public Plugin myinfo = {
	name = "Dys AFK Spec",
	description = "Move AFK players to Spectator team",
	author = "bauxite",
	version = "0.1.3",
	url = "https://github.com/bauxiteDYS/SM-DYS-AFK-Spec",
};

public void OnPluginStart()
{
	g_cvarEnabled = CreateConVar("sm_afk_move_spec", "1", "Whether to automatically move AFK players to spectator", _, true, 0.0, true, 1.0);
	
	#if !DEBUG
	g_cvarTime = CreateConVar("sm_afk_duration", "170", "How much time a player needs to be AFK before being moved to spectator", _, true, 60.0, true, 600.0);
	#else
	g_cvarTime = CreateConVar("sm_afk_duration", "10", "How much time a player needs to be AFK before being moved to spectator", _, true, 10.0, true, 600.0);
	#endif
		
	HookConVarChange(g_cvarEnabled, Cvar_Changed);
	HookConVarChange(g_cvarTime, Cvar_Changed);
	
	AutoExecConfig();
}

public void OnMapEnd()
{
	// handles are closed on map end but still contain old handle values, we have to set them to null on map end
	g_afkTimer = null;
}

public void OnConfigsExecuted()
{
	GetCvars();
}

public void Cvar_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_enabled = g_cvarEnabled.BoolValue;
	g_afkDuration = g_cvarTime.FloatValue;
	
	CreateAFKTimer();
}

void CreateAFKTimer()
{
	if(g_afkTimer != null)
	{
		delete g_afkTimer;
	}
	
	if(g_enabled)
	{
		g_afkTimer = CreateTimer(5.0, CheckAFK, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

public Action CheckAFK(Handle timer)
{
	// we need to check if the player is also not doing something even if they are standing still, counts as moving if moving in cyber
	// so then if they are not moving at all either in cyber or meat for 3 minutes its probably safe to assume afk
	
	if(!g_enabled) // probably don't need to do this but just for dunno
	{
		g_afkTimer = null;
		return Plugin_Stop;
	}
	
	float currentPos[3];
	float curTime = GetGameTime();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == 1 || GetClientTeam(i) == 0)
		{
			g_lastMoveTime[i] = 0.0;
			g_clientOldPos[i] = {0.0, 0.0, 0.0};
			continue;
		}
		
		GetClientAbsOrigin(i, currentPos);
		
		if(!(currentPos[0] == g_clientOldPos[i][0] && currentPos[1] == g_clientOldPos[i][1] && currentPos[2] == g_clientOldPos[i][2]))
		{
			#if DEBUG
			PrintToChatAll("playing is moving");
			#endif
			
			g_lastMoveTime[i] = curTime;
			
			for(int f = 0; f < 3; f++)
			{
				g_clientOldPos[i][f] = currentPos[f];
			}
			
			#if !DEBUG
			return Plugin_Continue; // no point going further?
			#endif
		}
		#if DEBUG
		else
		{
			PrintToChatAll("player is not moving");
		}
		#endif
		
		if(g_lastMoveTime[i] > 0.0 && curTime >= g_lastMoveTime[i] + g_afkDuration)
		{
			PrintToChatAll("\x08ffdd00%s \x03%N \x0800ccffhas been afk for %.2f minutes and has been moved to spectator.", g_tag, i, (g_afkDuration/60.0));
			ClientCommand(i, "jointeam 1");
			g_lastMoveTime[i] = 0.0;
			g_clientOldPos[i] = {0.0, 0.0, 0.0};
		}
		
	}
	
	return Plugin_Continue;
}
