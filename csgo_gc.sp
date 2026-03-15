#include <sourcemod>
#include <steamworks>

#pragma semicolon 1
#pragma newdecls required

#define WEBHOOK_URL "YOUR_LINK_ON_WEBHOOK"

ConVar g_cvApiToken;
ConVar g_cvServerPass;
ConVar g_cvServerName;

public Plugin myinfo = {
    name = "CS:GO_GS Monitoring",
    author = "NE MAZHIK/LESHA",
    version = "1.3"
};

public void OnPluginStart() {
    g_cvApiToken   = CreateConVar("sm_monitor_token", "", "API Token (ОБЯЗАТЕЛЬНО)", FCVAR_PROTECTED);
    g_cvServerPass = CreateConVar("sm_monitor_password", "", "Пароль от сервера", FCVAR_PROTECTED);
    g_cvServerName = CreateConVar("sm_monitor_name", "My CS:GO Server", "Название сервера для мониторинга");

    AutoExecConfig(true, "csgo_gc_monitor");
}

public void OnConfigsExecuted() {
    SendStatusToWebhook("server_start");
}

public void OnClientPutInServer(int client) {
    if (!IsFakeClient(client)) {
        SendStatusToWebhook("player_connect");
    }
}


public void OnClientDisconnect(int client) {
    if (IsClientInGame(client) && !IsFakeClient(client)) {
        SendStatusToWebhook("player_disconnect", client);
    }
}


void SendStatusToWebhook(const char[] eventType, int clientExclude = -1) {
    
    char sToken[256];
    g_cvApiToken.GetString(sToken, sizeof(sToken));
    
    if (sToken[0] == '\0') {
        PrintToServer("[Monitor] ОШИБКА: API Token пуст.");
        return;
    }

    
    char sIP[32];
    ConVar cvIp = FindConVar("net_public_adr");
    if (cvIp != null) {
        cvIp.GetString(sIP, sizeof(sIP));
    }

    if (sIP[0] == '\0' || StrEqual(sIP, "0.0.0.0")) return;

    
    int onlineCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        
        if (IsClientInGame(i) && !IsFakeClient(i) && i != clientExclude) {
            onlineCount++;
        }
    }

    int port = GetConVarInt(FindConVar("hostport"));
    int maxPlayers = MaxClients;

    char sPass[64], sName[128], jsonData[1536]; 
    g_cvServerPass.GetString(sPass, sizeof(sPass));
    g_cvServerName.GetString(sName, sizeof(sName));

    Format(jsonData, sizeof(jsonData), 
        "{\"event\":\"%s\", \"name\":\"%s\", \"ip\":\"%s\", \"port\":%d, \"players\":%d, \"max_players\":%d, \"token\":\"%s\", \"password\":\"%s\"}", 
        eventType, sName, sIP, port, onlineCount, maxPlayers, sToken, sPass);

    Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, WEBHOOK_URL);
    if (hRequest != INVALID_HANDLE) {
        SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", jsonData, strlen(jsonData));
        SteamWorks_SetHTTPCallbacks(hRequest, OnTransferComplete);
        SteamWorks_SendHTTPRequest(hRequest);
    }
}

public int OnTransferComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode) {
    if (bFailure || eStatusCode != k_EHTTPStatusCode200OK) {
        LogError("[Monitor] Webhook failed. HTTP Code: %d", eStatusCode);
    }
    delete hRequest; 
    return 0; 
}
