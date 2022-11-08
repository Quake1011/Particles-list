#pragma tabsize 0

#include <sourcemod>
#include <sdktools>
//#include "exy/exs.sp"

ArrayList ParticleArray;
ArrayList Array[MAXPLAYERS+1];

int iParticle[MAXPLAYERS+1];

public Plugin myinfo = 
{ 
    name = "GenParticleList", 
    author = "Quake1011", 
    description = "Allow see at particles and generate personal particle list", 
    version = "1.0.0.1", 
    url = "https://github.com/Quake1011/"
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_plist", ParticleList, _, ADMFLAG_ROOT);
    RegConsoleCmd("sm_getlist", GetListSelectedParticles, _, ADMFLAG_ROOT);
    HookEvent("round_end", EventRoundStart, EventHookMode_Pre);
    char sPath[256];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/particles.txt");
    if(FileExists(sPath))
    {
        File hFile = OpenFile(sPath, "a+");
        char bufferParticle[256];
        ParticleArray = CreateArray(256);
        int b = 0;
        do
        {
            ReadFileLine(hFile, bufferParticle, sizeof(bufferParticle));
            TrimString(bufferParticle);
            //LogMessage("%s", bufferParticle);
            //LogMessage("%i", b);
            ParticleArray.PushString(bufferParticle);
            b++;
        }
        while(!IsEndOfFile(hFile))
        //LogMessage("List of particles is created, count: %i", b);
        delete hFile;
    }

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i)) Array[i] = view_as<ArrayList>(ParticleArray.Clone());
    }
}

public Action GetListSelectedParticles(int client, int args)
{
    char buffer[256];
    BuildPath(Path_SM, buffer, sizeof(buffer), "configs/generatedlist.txt");
    if(FileExists(buffer)) DeleteFile(buffer);

    File GenFile = OpenFile(buffer, "a+");
    for(int i = 0; i < Array[client].Length; i++)
    {
        Array[client].GetString(i, buffer, sizeof(buffer));
        GenFile.WriteLine(buffer);
    }
    //LogMessage("POSITIONS SAVED: %i", Array[client].Length);
    delete GenFile;

    return Plugin_Handled;
}

public Action ParticleList(int client, int args)
{
    OpenPartMenu(client);
    return Plugin_Handled;
}

void OpenPartMenu(int client)
{
    Menu ParticleMenu = CreateMenu(MenuHandlerParts);
    ParticleMenu.SetTitle("Список партиклей");
    for(int i = 0; i < ParticleArray.Length; i++)
    {
        char buffer[256], display[256]; 
		//char limit[10];
        ParticleArray.GetString(i, buffer, sizeof(buffer));
        //strcopy(limit,sizeof(limit), buffer)
        //Format(display, sizeof(display), "%s [%s]", limit, Array[client].FindString(buffer) != -1 ? "+" : "-");
		Format(display, sizeof(display), "%s [%s]", buffer, Array[client].FindString(buffer) != -1 ? "+" : "-");
        ParticleMenu.AddItem(buffer, display);
    }
    ParticleMenu.ExitBackButton = true;
    ParticleMenu.ExitButton = true;
    ParticleMenu.Display(client, MENU_TIME_FOREVER);    
}

public int MenuHandlerParts(Menu menu, MenuAction action, int client, int item)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[256], display[256];
            menu.GetItem(item, info, sizeof(info), _, display, sizeof(display));
            //PrintToChatAll(display);
            if(display[strlen(display)-2] == '-') OpenAddToListMenu(info, client);
            else if(display[strlen(display)-2] == '+') OpenRemoveFromListMenu(info, client);
        }
        case MenuAction_End: delete menu;
    }
    return 0;
}

void OpenAddToListMenu(const char[] sInfo, int client)
{
    Menu hMenu = CreateMenu(AddToList);
    hMenu.SetTitle(sInfo);
    hMenu.AddItem(sInfo, "Добавить партикл");
    hMenu.AddItem(sInfo, "Посмотреть партикл");
    hMenu.ExitBackButton = true;
    hMenu.ExitButton = true;
    hMenu.Display(client, MENU_TIME_FOREVER);
}

void OpenRemoveFromListMenu(const char[] sInfo, int client)
{
    Menu hMenu = CreateMenu(RemoveFromList);
    hMenu.SetTitle(sInfo);
    hMenu.AddItem(sInfo, "Удалить партикл");
    hMenu.AddItem(sInfo, "Посмотреть партикл");
    hMenu.ExitBackButton = true;
    hMenu.ExitButton = true;
    hMenu.Display(client, MENU_TIME_FOREVER);
}

public int RemoveFromList(Menu menu, MenuAction action, int client, int item)
{
    switch(action)
    {
        case MenuAction_End: delete menu; 
        case MenuAction_Select:
        {
            char sInfo[2][256];
            menu.GetItem(item, sInfo[0], 256, _, sInfo[1], 256);
            if(item == 0) 
            {
                Array[client].Erase(Array[client].FindString(sInfo[0]));
                OpenAddToListMenu(sInfo[0], client);
            }
            if(item == 1) 
            {
                OpenRemoveFromListMenu(sInfo[0], client);
                CreateParticle(sInfo[0], client, GetAimPosition(client), 5.0);
            }
        }
        case MenuAction_Cancel: if(item == MenuCancel_ExitBack) OpenPartMenu(client);
    }
    return 0;
}

public int AddToList(Menu menu, MenuAction action, int client, int item)
{
    switch(action)
    {
        case MenuAction_End: delete menu; 
        case MenuAction_Select:
        {
            char sInfo[2][256];
            menu.GetItem(item, sInfo[0], 256, _, sInfo[1], 256);
            if(item == 0) 
            {
                Array[client].PushString(sInfo[0]);
                OpenRemoveFromListMenu(sInfo[0], client);
            }
            if(item == 1) 
            {
                OpenAddToListMenu(sInfo[0], client);
                CreateParticle(sInfo[0], client, GetAimPosition(client), 5.0);
            }
        }
        case MenuAction_Cancel: if(item == MenuCancel_ExitBack) OpenPartMenu(client);
    }
    return 0;
}

public void EventRoundStart(Event hEvent, const char[] sEvent, bool bdb)
{
    for(int i = 1; i <= MaxClients; i++) 
        if(iParticle[i] != -1) DeleteParticle(iParticle[i], i);
}

public void OnClientPostAdminCheck(int client)
{
    Array[client] = ParticleArray.Clone();
}

public void OnClientDisconnect(int client)
{
    if(iParticle[client] != -1) DeleteParticle(iParticle[client], client);

    Array[client].Clear();
}

// public void OnMapStart()
// {
//     for(int i = 0; i < sizeof(DownloadAndPrecacheParticles); i++) AddFileToDownloadsTable(DownloadAndPrecacheParticles[i]);

//     for(int i = 0; i < sizeof(precache); i++) 
//         PrecacheGeneric(precache[i], true);	
// }

bool Filter(int i, int mask) 
{ 
	return i ? false : true;
}

stock void CreateParticle(char[] particleName, int client, float pos[3], float time = 0.0)
{
    int particle = CreateEntityByName("info_particle_system");
    char name[64];
    if(IsValidEdict(particle))
    {
		pos[2]+=20.0;
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
        GetEntPropString(client, Prop_Data, "m_iName", name, sizeof(name));
        DispatchKeyValue(particle, "targetname", "tf2particle");
        DispatchKeyValue(particle, "parentname", name);
        DispatchKeyValue(particle, "effect_name", particleName);
        DispatchSpawn(particle);
        SetVariantString(name);
        AcceptEntityInput(particle, "SetParent", particle, particle, 0);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        //PrintToChat(client, "%s", particleName);
        iParticle[client] = particle;
        if(time > 0.0) CreateTimer(time, DeleteTimer, client);
    }
}

public Action DeleteTimer(Handle hTimer, int client)
{
    DeleteParticle(iParticle[client], client);
    return Plugin_Continue;
}

stock void DeleteParticle(any particle, i)
{
    if(IsValidEntity(particle))
    {
        char classN[64];
        GetEdictClassname(particle, classN, sizeof(classN));
        if (StrEqual(classN, "info_particle_system", false)) 
        {
            RemoveEdict(particle);
            iParticle[i] = -1;
        }
    }
}

float[] GetAimPosition(int client)
{
    float ang[3], org[3], end[3];
    GetClientEyeAngles(client, ang);
    GetClientEyePosition(client, org);
    Handle hTrace = TR_TraceRayFilterEx(org, ang, MASK_SOLID, RayType_Infinite, Filter, client);
    if(TR_DidHit(hTrace) && hTrace != INVALID_HANDLE) TR_GetEndPosition(end, hTrace);
    delete hTrace;
    return end;
}