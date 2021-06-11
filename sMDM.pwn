

/*
    Mega DeathMatch
    LuisSAMP, Kapex
*/

#include <a_samp>
#include <streamer>
#include <a_mysql>
#include <a_mysql_yinline>
#include <sscanf2>
#include <Pawn.CMD>
#include <Pawn.Regex>

#define SERVER_VERSION      "1.10"
#define BUILD_VERSION       "17/04/2020"

#undef MAX_PLAYERS
#define MAX_PLAYERS     50

#define VIRTUAL_WORLD_OF_CHEATS    100
#define MAX_PARTICIPANTS_CAREER     8 // Máximos corredores

#define SERVER_NAME         "Mega DeathMatch"
#define SERVER_HOSTNAME     "     « Mega DeathMatch "SERVER_VERSION" (Español 0.3.7) »"
#define SERVER_GAMEMODE     "Deathmatch en español"
#define SERVER_LANGUAGE     "Español / Spanish"
#define SERVER_WEBURL       "discord.gg/CA9U4z"

#define MAX_PING    1500
#define MAX_TIMERS_PER_PLAYER       50

#define MYSQL_HOST      "localhost"
#define MYSQL_DATABASE  "megadm"
#define MYSQL_PASS      ""
#define MYSQL_USER      "root"

/* Colores */
#define COLOR_GREY      0x999999AA

new Duel_Count;

forward CheckPlayerPause(playerid);

main()
{
    print("-- > "SERVER_NAME" < --");
}

new Random_Weapons[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 13, 14, 15, 16, 17, 18, 19, 20, 21, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34};

new Float:Random_Spawn_Pos[][] =
{
    {2489.9841, -1672.0533, 13.3359}, // LS
    {-1747.9178, -580.0380, 16.3359}, // SF
    {1712.0676, 1472.0187, 10.8203} // LV
};

// Contraseña
#define MIN_PASS_LENGTH 6
#define MAX_PASS_LENGTH 18

new TOTAL_PLAYERS, create_labels;
new MySQL:Database;

enum enum_PI
{
    pi_ID,
    pi_NAME[24],
    pi_IP[16],
    pi_EMAIL[32],
    pi_KILLS,
    pi_DEATHS,
    pi_COINS,
    pi_CASH,
    bool:pi_USER_EXIT,
    bool:pi_USER_LOGGED,
    pi_SALT[16],
    pi_PASS[64 + 1],
    pi_BAD_LOGIN_ATTEMPS,
    pi_ADMIN_LEVEL,
    pi_TIMERS[MAX_TIMERS_PER_PLAYER],
    pi_DUEL_SENDERID,
    pi_DUEL_SENDER,
    bool:pi_IN_DUEL,
    pi_VIP,
    pi_PLAYER_SHOTTING,
    bool:pi_BLOCK_TELE,
    pi_SKIN,
    pi_SELECT_SKIN,
    bool:pi_STATE_DEATH,
    pi_DOUBT_MESSAGE[190],
    pi_PLAYERID_DOUBT_RESPONDED,
    bool:pi_DOUBT_RESPONDE,
    pi_PM_SENDERID,
    pi_PM,
    Float:pi_OLD_HEALTH,
    bool:pi_GODMODE,
    pi_CHECK_AFK,
    bool:pi_AUTORIZED_AFK,
    pi_DOUBT_CHANNEL_TIME,
    pi_DOUBT_CHANNEL,
    pi_KKILLS,
    pi_DOUBT_MUTE,
    pi_PARTICIPATING
};
new PI[MAX_PLAYERS][enum_PI];

public OnPlayerConnect(playerid)
{
    TOTAL_PLAYERS ++;

    GetPlayerName(playerid, PI[playerid][pi_NAME], 24);
    GetPlayerIp(playerid, PI[playerid][pi_IP], 16);

    new string[120];
    format(string, sizeof string, "{fc0303}%s (ID: %d) ha entrado al servidor.", PI[playerid][pi_NAME], playerid);
    SendClientMessageToAll(-1, string);

    inline CheckPlayerRegister()
    {
        new rows;
        if(cache_get_row_count(rows))
        {
            if(rows)
            {
                cache_get_value_name_int(0, "id", PI[playerid][pi_ID]);
                cache_get_value_name(0, "name", PI[playerid][pi_NAME], 24);
                cache_get_value_name(0, "ip", PI[playerid][pi_IP], 16);
                cache_get_value_name(0, "salt", PI[playerid][pi_SALT], 16);
                cache_get_value_name(0, "pass", PI[playerid][pi_PASS], 64 + 1);

                PI[playerid][pi_USER_EXIT] = true;
            }
            else PI[playerid][pi_USER_EXIT] = false;
        }
    }

    PI[playerid][pi_USER_LOGGED] = false;

    new DB_Query[120];
    mysql_format(Database, DB_Query, sizeof DB_Query, "SELECT id, name, ip, salt, pass FROM player WHERE name = '%e';", PI[playerid][pi_NAME]);
    mysql_tquery_inline(Database, DB_Query, using inline CheckPlayerRegister);

    return 1;
}

public OnGameModeInit()
{
    SetGameModeText(SERVER_GAMEMODE);
    SendRconCommand("hostname       "SERVER_HOSTNAME"");
    SendRconCommand("language       "SERVER_LANGUAGE"");
    SendRconCommand("weburl         "SERVER_WEBURL"");

    UsePlayerPedAnims();
    //ConnectDatabase();
    DisableInteriorEnterExits();

    mysql_log(ERROR | WARNING);

    //LoadServerLabels();

    return 1;
}

enum
{
    CMD_USER,
    CMD_HELPER,
    CMD_MODERATOR,
    CMD_ADMIN
};

public OnPlayerDisconnect(playerid, reason)
{
    TOTAL_PLAYERS --;
    if(PI[playerid][pi_USER_EXIT]) SavePlayerData(playerid);

    new string[120];
    format(string, sizeof string, "{fc0303}%s (%d) ha salido del servidor.", PI[playerid][pi_NAME], playerid);
    SendClientMessageToAll(-1, string);

    return 1;
}

public OnGameModeExit()
{
    mysql_close(Database);
    print("n\n---> Saliendo...");

    return 1;
}

public OnPlayerSpawn(playerid)
{
    SetPlayerHealth(playerid, 100.0);
    SetPlayerArmour(playerid, 100.0);

    if(!PI[playerid][pi_SKIN]) SetPlayerSkin(playerid, random(311));
    else SetPlayerSkin(playerid, PI[playerid][pi_SKIN]);

    for(new i = 0; i != 10; i++) GivePlayerWeapon(playerid, Random_Weapons[random(sizeof(Random_Weapons))], 10000);

    PI[playerid][pi_USER_LOGGED] = true;
    PI[playerid][pi_STATE_DEATH] = false;

    return 1;
}

forward OnPlayerRegister(playerid);
forward OnPlayerLogin(playerid);

enum
{
    DIALOG_INFO,
    DIALOG_REGISTER,
    DIALOG_REGISTER_EMAIL,
    DIALOG_LOGIN,
    DIALOG_SELECT_WEAPONS,
    DIALOG_SELECT_VEHICLES,
    DIALOG_FAST_VEHICLES,
    DIALOG_SLOW_VEHICLES,
    DIALOG_BIKES,
    DIALOG_BICYCLE,
    DIALOG_SLOW_WEAPONS,
    DIALOG_FAST_WEAPONS,
    DIALOG_OTHER_WEAPONS,
    DIALOG_PLAYER_DUEL,
    DIALOG_PLAYER_DUEL_ACCEPT,
    DIALOG_VIP_BUY,
    DIALOG_HELP,
    DIALOG_GENERAL_HELP,
    DIALOG_SHOP,
    DIALOG_WEAPONS_BUY,
    DIALOG_BUY_ARMOUR,
    DIALOG_CHANGE_SKIN,
    DIALOG_BUY_FAST_WEAPONS,
    DIALOG_BUY_SLOW_WEAPONS,
    DIALOG_FSKIN_CONFIRM,
    DIALOG_CHANGE_PASSWORD,
    DIALOG_CHANGE_PASSWORD_PASS
};

ShowDialog(playerid, dialogid)
{
    switch(dialogid)
    {
        case DIALOG_REGISTER:
        {
            new dialog[140];
            format(dialog, sizeof dialog, "Introduce una contraseña para ingresar\nLa contraseña debe tener mínimo de %d caracteres a %d.", MIN_PASS_LENGTH, MAX_PASS_LENGTH);
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_PASSWORD, "Registrarse", dialog, "Aceptar", "Cancelar");
        }
        case DIALOG_REGISTER_EMAIL: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_INPUT, "E-Mail", "Ahora necesitamos que ingreses un correo electrónico, tranquilo\nno sufrirás SPAM o suscripciones", "Aceptar", "Cancelar");
        case DIALOG_LOGIN:
        {
            new dialog[120];
            format(dialog, sizeof dialog, "Bienvenido de nuevo %s, ingresa tu contraseña para\ningresar", PI[playerid][pi_NAME]);
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_PASSWORD, "Ingresar", dialog, "Aceptar", "Salir");
        }
        case DIALOG_SELECT_WEAPONS:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Armas",
            "\
                Armas lentas\n\
                Armas pesadas\n\
                Armas rápidas\n\
                Otras\n\
            ", "Seleccionar", "Salir");
        }
        case DIALOG_SELECT_VEHICLES:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Vehículos",
            "\
                Autos rápidos\n\
                Autos lentos\n\
                Motos\n\
                Bicicletas\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_FAST_VEHICLES:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Vehículos rápidos",
            "\
                Infernus\n\
                Sultan\n\
                Bullet\n\
                ZR-350\n\
                Uranus\n\
                Euros\n\
                Super GT\n\
                Buffalo\n\
            ", "Seleccionar", "Salir");
        }
        case DIALOG_SLOW_VEHICLES:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Vehículos lentos",
            "\
                Primo\n\
                Emperor\n\
                Tornado\n\
                Glendale\n\
                Burrito\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_BIKES:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Motos",
            "\
                PCJ-600\n\
                NRG-500\n\
                Faggio\n\
                Wayfarer\n\
                FCR-900\n\
                Sánchez\n\
                Freeway\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_BICYCLE:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Bicicletas", "BMX", "Aceptar", "Cancelar");
            return 1;
        }
        case DIALOG_SLOW_WEAPONS:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Armas lentas",
            "\
                Desert Eagle\n\
                Escopeta de combate\n\
                Sniper\n\
                Rifle\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_FAST_WEAPONS:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Armas rápidas",
            "\
                M4\n\
                Ak-47\n\
                MP5\n\
                Tec-9\n\
                9mm\n\
                9mm silenciada\n\
                Escopeta recortada\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_PLAYER_DUEL: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_INPUT, "Duelos", "Elije la ID de la persona que quieras invitar.", "Aceptar", "Salir");
        case DIALOG_PLAYER_DUEL_ACCEPT:
        {
            new dialog[120];
            format(dialog, sizeof dialog, "%s te ha invitado a participar en duelo, ¿quieres aceptarlo?", PI[ PI[playerid][pi_DUEL_SENDERID] ][pi_NAME]);
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_MSGBOX, "Duelos", dialog, "Si", "No");
        }
        case DIALOG_VIP_BUY: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_MSGBOX, "VIP", "¿Estás seguro de que quieres comprar el VIP?, cuesta 20 coins", "Aceptar", "Cancelar");
        case DIALOG_HELP:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_MSGBOX, "Ayuda general",
            "\
                Bueno, vamos a empezar explicándote algunos aspectos que\n\
                tienes que tener en cuenta si quieres mantenerte bien\n\
                en el servidor, son conseptos básicos y que casi todos\n\
                tienen, pero no dejan de ser importantes:\n\
                \n\
                Debes respetar a todos los ususarios en el servidor.\n\
                No utilizar hacks o mejor conocididos como chetos, igualmente\n\
                el servidor tiene un AntiCheat que detecta todo tipo de hacks.\n\
                Puedes cambiarte el nombre dentro del servidor, pero no puedes abusar\n\
                o algo así por el estilo de esta función.\n\
                \n\
                Si has llegado hasta acá, puedes presionar el botón 'Ayuda' para ir\n\
                a la ayuda general del servidor y algunas indicaciones para un juego más\n\
                comodo.\n\
            ", "Ayuda", "Cerrar");
        }
        case DIALOG_GENERAL_HELP:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_MSGBOX, "Ayuda general",
            "\
                Para spawnear un vehículo utiliza el comando /v\n\
                Para obtener un arma utiliza el comando /armas\n\
                Para obtener una membresia VIP utiliza el comando /comprarvip (Cuesta 20 coins)\n\
                Pronto estarán aclaradas las ventajas de esta membresía VIP\n\
                Al comprar un skin fijo, será el skin con el que spawnearás todas las veces que loguees.\n\
            ", "Salir", "");
        }
        case DIALOG_SHOP:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Tienda",
            "\
                Comprar armas\n\
                Comprar chaleco\n\
                Cambiar skin\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_BUY_ARMOUR: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_MSGBOX, "Comprar chaleco antibalas", "¿Estás seguro de que quieres comprar chaleco antibalas?, cuesta 200$", "Aceptar", "Cancelar");
        case DIALOG_WEAPONS_BUY:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Comprar armas",
            "\
                Armas lentas\n\
                Armas rápidas\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_BUY_SLOW_WEAPONS:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Armas lentas",
            "\
                Desert eagle (500$)\n\
                Escopeta de combate (1000$)\n\
                Rifle (1500$)\n\
                Sniper (2000$)\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_BUY_FAST_WEAPONS:
        {
            ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Armas rápidas",
            "\
                M4 (1300$)\n\
                MP5 (1250$)\n\
            ", "Seleccionar", "Cancelar");
        }
        case DIALOG_CHANGE_SKIN: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_INPUT, "Cambiar skin", "Introduce el ID del skin al que quieras cambiar\nPor ahora no tenemos disponible la\nselección de skin, esperamos que en futuras actualizaciones podamos implementarlo.", "Aceptar", "Cancelar");
        case DIALOG_FSKIN_CONFIRM: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_MSGBOX, "SKin fijo", "¿Estás seguro de que quieres comprar este skin?, el precio sería 5 coins.", "Aceptar", "Cancelar");
        case DIALOG_CHANGE_PASSWORD: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_PASSWORD, "Cambiar contraseña", "Ingresa tu contraseña actual para poder cambiar tu\ncontraseña", ">>", "-");
        case DIALOG_CHANGE_PASSWORD_PASS: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_PASSWORD, "Cambiar contraseña", "Ahora ingresa la nueva contraseña", ">>", "-");
        case DIALOG_OTHER_WEAPONS: return ShowPlayerDialog(playerid, dialogid, DIALOG_STYLE_LIST, "Otras", "Cocktail Molotov", ">>", "-");
    }

    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    if(killerid != INVALID_PLAYER_ID)
    {
        PI[playerid][pi_DEATHS] ++;
        PI[killerid][pi_KILLS] ++;

        PI[killerid][pi_KKILLS] ++;
        if(PI[playerid][pi_KKILLS] > 3)
        {
            new string[120];
            format(string, sizeof string, "{f2de05}%s (%d) lleva una buena racha de {e30909}%d {f2de05}kills sin morir.", PI[killerid][pi_NAME], killerid, PI[killerid][pi_KKILLS]);
            SendClientMessageToAll(-1, string);
        }

        if(PI[playerid][pi_KKILLS] > 6)
        {
            GivePlayerCash(playerid, 5000);
            new string[120]; format(string, sizeof string, "{d4b90d}%s {920dd4}ha logrado 6 kills o más sin morir y ha obtenido recompensa.", PI[playerid][pi_NAME]);
            SendClientMessageToAll(-1, string);
        }

        if(PI[playerid][pi_KKILLS] >= 3)
        {
            new losed_string[140]; format(losed_string, sizeof losed_string, "{ff0022}%s (%d) ha acabado con la racha de {77009e}%s (%d) {ff0022}de {77009e}%d {ff0022}kills sin morir.", PI[killerid][pi_NAME], killerid, PI[playerid][pi_NAME], playerid, PI[playerid][pi_KKILLS]);
            PI[playerid][pi_KKILLS] = 0;
            SendClientMessageToAll(-1, losed_string);
        }

        if(PI[killerid][pi_IN_DUEL] && PI[playerid][pi_IN_DUEL])
        {
            if(PI[killerid][pi_VIP]) PI[killerid][pi_KILLS] += 2;
            else PI[playerid][pi_KILLS] ++;

            new string[120];
            format(string, sizeof string, "---> {ff0022}%s (%d) {9906d4}le ha ganado el duelo a {ff0022}%s (%d).", PI[killerid][pi_NAME], killerid, PI[playerid][pi_NAME], playerid);
            SendClientMessageToAll(-1, string);

            PI[playerid][pi_IN_DUEL] = false;
            PI[killerid][pi_IN_DUEL] = false;
        }
    }
    else
    {
        PI[playerid][pi_DEATHS] ++;
        if(PI[playerid][pi_IN_DUEL])
        {
            new string[120];
            format(string, sizeof string, "---> {ff0022}%s (%d) {9906d4}ha muerto en medio del duelo.", PI[playerid][pi_NAME], playerid);
            SendClientMessageToAll(-1, string);

            PI[playerid][pi_IN_DUEL] = false;
            PI[ PI[playerid][pi_DUEL_SENDER] ][pi_IN_DUEL] = false;
        }
    }

    PI[playerid][pi_STATE_DEATH] = true;
    SendDeathMessage(killerid, playerid, reason);
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    inline CheckPlayerBan()
    {
        new rows;
        if(cache_get_row_count(rows))
        {
            if(rows)
            {
                new name[24], ip[16], id, reason[128], days, banner;
                cache_get_value_name_int(0, "id_player", id);
                cache_get_value_name(0, "name", name, 24);
                cache_get_value_name(0, "ip", ip, 16);
                cache_get_value_name_int(0, "by", banner);
                cache_get_value_name(0, "reason", reason, 128);
                cache_get_value_name_int(0, "date", days);

                if(!days)
                {
                    new dialog[145];
                    format(dialog, sizeof dialog,
                    "\
                        ID: %d\n\
                        Tu nombre: %s\n\
                        Tu IP: %s\n\
                        Tu ID:\n\
                        Razón: %s\n\
                        \n\
                        Baneo permanente.\n\
                    ", banner, name, ip, id, reason);
                    ShowPlayerDialog(playerid, DIALOG_INFO, DIALOG_STYLE_MSGBOX, "Aviso", dialog, "Entiendo", "");
                    KickEx(playerid, 500);
                }
            }
        }
    }

    new DB_Query[120];
    mysql_format(Database, DB_Query, sizeof DB_Query, "SELECT * FROM bans WHERE id_player = %d;", PI[playerid][pi_ID]);
    mysql_tquery_inline(Database, DB_Query, using inline CheckPlayerBan);

    ClearPlayerChat(playerid);

    if(PI[playerid][pi_USER_EXIT]) ShowDialog(playerid, DIALOG_LOGIN);
    else ShowDialog(playerid, DIALOG_REGISTER);

    return 1;
}

public OnPlayerWeaponShot(playerid, weaponid, hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
    /*new weapon_name[32];
    GetWeaponName(weaponid, weapon_name, 32);
    printf("---> %s (%d) has shot with the gun %s.", PI[playerid][pi_NAME], playerid, weapon_name);*/

    return 1;
}

stock KickEx(playerid, time = 0)
{
    if(!time) Kick(playerid);
    else
    {
        KillTimer(PI[playerid][pi_TIMERS][0]);
        PI[playerid][pi_TIMERS][0] = SetTimerEx("KickPlayer", time, false, "i", playerid);
    }

    return 1;
}

forward KickPlayer(playerid);
public KickPlayer(playerid)
{
    return Kick(playerid);
}

stock SetPlayerSkillsLevel(playerid)
{
    SetPlayerSkillLevel(playerid, WEAPON_M4, 999);
    SetPlayerSkillLevel(playerid, WEAPON_AK47, 999);
    SetPlayerSkillLevel(playerid, WEAPON_SHOTGSPA, 999);

    /* AÑADIR MÁS */

    return 1;
}

/*ConnectDatabase()
{
	new MySQLOpt:options = mysql_init_options();
	mysql_set_option(options, AUTO_RECONNECT, true);
	mysql_set_option(options, MULTI_STATEMENTS, true);
	Database = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATABASE, options);
	if(mysql_errno(Database) == 0)
	{
		print("\n----------------------------------------");
		print("La conexión con la base de datos funciona.");
		print("----------------------------------------\n");
		mysql_query(Database, "SET FOREIGN_KEY_CHECKS=1;", false);
	}
	else
	{
		print("\n----------------------------------");
		print("      Conexión con DB fallida!      ");
		print("----------------------------------\n");
     	SendRconCommand("exit");
	}
	return 1;
}*/

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_REGISTER:
        {
            if(response)
            {
                if(strlen(inputtext) < MIN_PASS_LENGTH || strlen(inputtext) > MAX_PASS_LENGTH) return ShowDialog(playerid, dialogid);

                new salt[16];
                getRandomSalt(salt);
                format(PI[playerid][pi_SALT], 16, "%s", salt);
                SHA256_PassHash(inputtext, PI[playerid][pi_SALT], PI[playerid][pi_PASS], 64 + 1);

                ShowDialog(playerid, DIALOG_REGISTER_EMAIL);
                return 1;
            }
            else Kick(playerid);
        }
        case DIALOG_REGISTER_EMAIL:
        {
            if(!response) return Kick(playerid);
            if(strlen(inputtext) < 5)  return ShowDialog(playerid, dialogid);

            if(strfind(inputtext, "@", true) == -1) return ShowDialog(playerid, dialogid);
            if(strfind(inputtext, ".", true) == -1) return ShowDialog(playerid, dialogid);

            inline CheckExistingEmail()
            {
                new rows;
                if(cache_get_row_count(rows))
                {
                    if(rows)
                    {
                        SendClientMessage(playerid, -1, "{999999}Este correo electrónico ya está en uso, prueba otro distinto.");
                        ShowDialog(playerid, dialogid);
                    }
                    else
                    {
                        format(PI[playerid][pi_EMAIL], 32, "%s", inputtext);
                        RegisterNewPlayer(playerid);
                    }
                }
            }

            new DB_Query[120];
            mysql_format(Database, DB_Query, sizeof DB_Query, "SELECT * FROM player WHERE email = '%e';", inputtext);
            mysql_tquery_inline(Database, DB_Query, using inline CheckExistingEmail);

            return 1;
        }
        case DIALOG_LOGIN:
        {
            if(!response) return Kick(playerid); // Kickea sin pensarlo 2 veces xD
            if(!strlen(inputtext)) return ShowDialog(playerid, dialogid);

            new password[64 + 1];
            SHA256_PassHash(inputtext, PI[playerid][pi_SALT], password, sizeof password);
            if(!strcmp(password, PI[playerid][pi_PASS], false))
            {
                inline OnPlayerDataLoad()
                {
                    new rows;
                    if(cache_get_row_count(rows))
                    {
                        if(rows)
                        {
                            cache_get_value_name(0, "name", PI[playerid][pi_NAME], 24);
                            cache_get_value_name(0, "ip", PI[playerid][pi_IP], 16);
                            cache_get_value_name_int(0, "cash", PI[playerid][pi_CASH]);
                            cache_get_value_name_int(0, "kills", PI[playerid][pi_KILLS]);
                            cache_get_value_name_int(0, "deaths", PI[playerid][pi_DEATHS]);
                            cache_get_value_name_int(0, "admin_level", PI[playerid][pi_ADMIN_LEVEL]);
                            cache_get_value_name_int(0, "skin", PI[playerid][pi_SKIN]);
                            cache_get_value_name_int(0, "coins", PI[playerid][pi_COINS]);
                            cache_get_value_name_int(0, "vip", PI[playerid][pi_VIP]);

                            OnPlayerLogin(playerid);
                        }
                        else Kick(playerid);
                    }
                    else Kick(playerid);
                }

                new DB_Query[120];
                mysql_format(Database, DB_Query, sizeof DB_Query, "SELECT * FROM player WHERE id = %d;", PI[playerid][pi_ID]);
                mysql_tquery_inline(Database, DB_Query, using inline OnPlayerDataLoad);
            }
            else
            {
                PI[playerid][pi_BAD_LOGIN_ATTEMPS] ++;
                if(PI[playerid][pi_BAD_LOGIN_ATTEMPS] > 3) return Kick(playerid);
                ShowDialog(playerid, dialogid);
            }
        }
        case DIALOG_SELECT_WEAPONS:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: ShowDialog(playerid, DIALOG_SLOW_WEAPONS);
                    case 1: return SendClientMessage(playerid, -1, "Temporalmente deshabilitado.");
                    case 2: ShowDialog(playerid, DIALOG_FAST_WEAPONS);
                    case 3: ShowDialog(playerid, DIALOG_OTHER_WEAPONS);
                }
            }
        }
        case DIALOG_SELECT_VEHICLES:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: ShowDialog(playerid, DIALOG_FAST_VEHICLES);
                    case 1: ShowDialog(playerid, DIALOG_SLOW_VEHICLES);
                    case 2: ShowDialog(playerid, DIALOG_BIKES);
                    case 3: ShowDialog(playerid, DIALOG_BICYCLE);
                }
            }
        }

        case DIALOG_FAST_WEAPONS:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: GivePlayerWeapon(playerid, WEAPON_M4, 10000);
                    case 1: GivePlayerWeapon(playerid, WEAPON_AK47, 10000);
                    case 2: GivePlayerWeapon(playerid, WEAPON_MP5, 10000);
                    case 3: GivePlayerWeapon(playerid, WEAPON_TEC9, 10000);
                    case 4: GivePlayerWeapon(playerid, WEAPON_COLT45, 10000);
                    case 5: GivePlayerWeapon(playerid, WEAPON_SILENCED, 10000);
                    case 6: GivePlayerWeapon(playerid, WEAPON_SAWEDOFF, 10000);
                }
            }
        }
        case DIALOG_SLOW_WEAPONS:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: GivePlayerWeapon(playerid, WEAPON_DEAGLE, 10000);
                    case 1: GivePlayerWeapon(playerid, WEAPON_SHOTGSPA, 10000);
                    case 2: GivePlayerWeapon(playerid, WEAPON_SNIPER, 10000);
                    case 3: GivePlayerWeapon(playerid, WEAPON_RIFLE, 10000);
                }
            }
        }
        case DIALOG_OTHER_WEAPONS:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: GivePlayerWeapon(playerid, WEAPON_MOLTOV, 10000);
                }
            }
        }

        case DIALOG_FAST_VEHICLES:
        {
            new Float:pos[4];
            GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
            GetPlayerFacingAngle(playerid, pos[3]);

            switch(listitem)
            {
                case 0: // Infernus
                {
                    new vehicleid = CreateVehicle(411, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
                case 1: // Sultan
                {
                    new vehicleid = CreateVehicle(560, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
                case 2: // Bullet
                {
                    new vehicleid = CreateVehicle(541, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
                case 3: // ZR-350
                {
                    new vehicleid = CreateVehicle(477, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
                case 4:
                {
                    new vehicleid = CreateVehicle(558, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
                case 5:
                {
                    new vehicleid = CreateVehicle(587, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
                case 6:
                {
                    new vehicleid = CreateVehicle(506, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
                case 7:
                {
                    new vehicleid = CreateVehicle(402, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                    PutPlayerInVehicle(playerid, vehicleid, 0);
                }
            }
        }
        case DIALOG_SLOW_VEHICLES:
        {
        	new Float:pos[4];
            GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
            GetPlayerFacingAngle(playerid, pos[3]);

            if(response)
            {
                switch(listitem)
                {
                    case 0: //Primo
                    {
                        new vehicleid = CreateVehicle(457, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 1: // Emperor
                    {
                        new vehicleid = CreateVehicle(508, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 2: // Tornado
                    {
                        new vehicleid = CreateVehicle(576, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 3: // ADRIANCHITO
                    {
                        new vehicleid = CreateVehicle(466, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 4: // Burrito
                    {
                        new vehicleid = CreateVehicle(482, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                }
            }
        }
        case DIALOG_BIKES:
        {
            new Float:pos[4];
            GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
            GetPlayerFacingAngle(playerid, pos[3]);

            if(response)
            {
                switch(listitem)
                {
                    case 0: // PCJ-600
                    {
                        new vehicleid = CreateVehicle(461, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 1: // NRG-500
                    {
                        new vehicleid = CreateVehicle(522, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 2: // Faggio
                    {
                        new vehicleid = CreateVehicle(462, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 3: // Wayfarer
                    {
                        new vehicleid = CreateVehicle(586, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 4:
                    {
                        new vehicleid = CreateVehicle(521, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 5:
                    {
                        new vehicleid = CreateVehicle(468, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                    case 6:
                    {
                        new vehicleid = CreateVehicle(463, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                        PutPlayerInVehicle(playerid, vehicleid, 0);
                    }
                }
            }
        }
        case DIALOG_BICYCLE:
        {
        	new Float:pos[4];
            GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
            GetPlayerFacingAngle(playerid, pos[3]);

            if(response)
            {
                new vehicleid = CreateVehicle(481, pos[0], pos[1], pos[2], pos[3], 0, 0, 300);
                PutPlayerInVehicle(playerid, vehicleid, 0);
            }
        }
        case DIALOG_PLAYER_DUEL:
        {
            if(response)
            {
                if(sscanf(inputtext, "u", inputtext[0])) return ShowDialog(playerid, dialogid);
                if(!IsPlayerConnected(inputtext[0]))
                {
                    SendClientMessage(playerid, -1, "{999999}El jugador no está conectado.");
                    ShowDialog(playerid, dialogid);
                    return 1;
                }
                if(PI[inputtext[0]][pi_IN_DUEL])
                {
                    SendClientMessage(playerid, -1, "Este jugador ya está en un duelo.");
                    ShowDialog(playerid, dialogid);
                    return 1;
                }

                if(PI[ inputtext[0] ][pi_KILLS] < 3) return SendClientMessage(playerid, -1, "{999999}Este jugador necesita al menos 3 kills para hacer duelos.");
                else
                {
                    PI[inputtext[0]][pi_DUEL_SENDERID] = playerid;
                    PI[playerid][pi_DUEL_SENDER] = inputtext[0];

                    SendClientMessageEx(playerid, -1, "{CCCCCC}Has invitado a %s (%d) a hacer un duelo entre tu y el.", PI[ PI[playerid][pi_DUEL_SENDER] ][pi_NAME], PI[playerid][pi_DUEL_SENDER]);
                    ShowDialog(PI[playerid][pi_DUEL_SENDER], DIALOG_PLAYER_DUEL_ACCEPT);
                }

                return 1;
            }
        }
        case DIALOG_PLAYER_DUEL_ACCEPT:
        {
            if(response)
            {
                SendClientMessageEx(PI[playerid][pi_DUEL_SENDERID], -1, "{CCCCCC}%s ha aceptado el duelo, espera a que termine la cuenta regresiva.", PI[playerid][pi_NAME]);
                SendClientMessage(playerid, -1, "{CCCCCC}Has aceptado, ahora espera...");

                SetTimerEx("RegresiveCount", 6000, false, "ii", PI[playerid][pi_DUEL_SENDERID], playerid);
                return 1;
            }
            else
            {
                SendClientMessageEx(PI[playerid][pi_DUEL_SENDERID], -1, "{CCCCCC}%s no ha aceptado el duelo.", PI[playerid][pi_NAME]);
                PI[ PI[playerid][pi_DUEL_SENDERID] ][pi_DUEL_SENDER] = INVALID_PLAYER_ID;
                PI[playerid][pi_DUEL_SENDERID] = INVALID_PLAYER_ID;
            }
        }
        case DIALOG_VIP_BUY:
        {
            if(response)
            {
                if(PI[playerid][pi_COINS] < 20) return SendClientMessageEx(playerid, -1, "{999999}Necesitas 20 coins para poder comprar VIP, te faltan %d coins.", 20 - PI[playerid][pi_COINS]);
                else
                {
                    PI[playerid][pi_COINS] -= 20;
                    PI[playerid][pi_VIP] = true;

                    SendClientMessage(playerid, -1, "¡Felicidades! Has comprado el VIP por 20 coins.");

                    new DB_Query[120];
                    mysql_format(Database, DB_Query, sizeof DB_Query, "UPDATE player SET vip = 1 WHERE id = %d;", PI[playerid][pi_ID]);
                    mysql_tquery(Database, DB_Query);
                }
            }
        }
        case DIALOG_HELP:
        {
            if(response) ShowDialog(playerid, DIALOG_GENERAL_HELP);
        }
        case DIALOG_SHOP:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: ShowDialog(playerid, DIALOG_WEAPONS_BUY);
                    case 1: ShowDialog(playerid, DIALOG_BUY_ARMOUR);
                    case 2: ShowDialog(playerid, DIALOG_CHANGE_SKIN);
                }
            }
        }
        case DIALOG_BUY_ARMOUR:
        {
            if(response)
            {
                if(PI[playerid][pi_CASH] < 200) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder comprar chaleco.");
                SetPlayerArmour(playerid, 100.0);
                GivePlayerCash(playerid, -200);
            }
        }
        case DIALOG_WEAPONS_BUY:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0: ShowDialog(playerid, DIALOG_BUY_SLOW_WEAPONS);
                    case 1: ShowDialog(playerid, DIALOG_BUY_FAST_WEAPONS);
                }
            }
        }
        case DIALOG_BUY_SLOW_WEAPONS:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0:
                    {
                        if(PI[playerid][pi_CASH] < 500) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder comprar esta arma.");
                        GivePlayerWeapon(playerid, WEAPON_DEAGLE, 10000);
                        GivePlayerCash(playerid, -500);
                    }
                    case 1:
                    {
                        if(PI[playerid][pi_CASH] < 1000) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder comprar esta arma.");
                        GivePlayerWeapon(playerid, WEAPON_SHOTGSPA, 10000);
                        GivePlayerCash(playerid, -1000);
                    }
                    case 2:
                    {
                        if(PI[playerid][pi_CASH] < 1500) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder comprar esta arma.");
                        GivePlayerWeapon(playerid, WEAPON_RIFLE, 10000);
                        GivePlayerCash(playerid, -1500);
                    }
                    case 3:
                    {
                        if(PI[playerid][pi_CASH] < 2000) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder comprar esta arma.");
                        GivePlayerWeapon(playerid, WEAPON_SNIPER, 10000);
                        GivePlayerCash(playerid, -2000);
                    }
                }
            }
        }
        case DIALOG_BUY_FAST_WEAPONS:
        {
            if(response)
            {
                switch(listitem)
                {
                    case 0:
                    {
                        if(PI[playerid][pi_CASH] < 1500) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder comprar esta arma.");
                        GivePlayerWeapon(playerid, WEAPON_M4, 10000);
                        GivePlayerCash(playerid, -1500);
                    }
                    case 1:
                    {
                        if(PI[playerid][pi_CASH] < 1250) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder comprar esta arma.");
                        GivePlayerWeapon(playerid, WEAPON_MP5, 10000);
                        GivePlayerCash(playerid, -1250);
                    }
                }
            }
        }
        case DIALOG_CHANGE_SKIN:
        {
            if(response)
            {
                if(PI[playerid][pi_CASH] < 200) return SendClientMessage(playerid, -1, "{999999}No tienes dinero suficiente para poder cambiarte de skin.");
                if(sscanf(inputtext, "d", inputtext[0]))
                {
                    SendClientMessage(playerid, -1, "Introduce el ID del skin al que quieras cambiar.");
                    ShowDialog(playerid, dialogid);
                    return 1;
                }
                if(inputtext[0] > 311)
                {
                    SendClientMessage(playerid, -1, "El ID del skin no es válido.");
                    ShowDialog(playerid, dialogid);
                    return 1;
                }

                if(inputtext[0] <= 0) SetPlayerSkin(playerid, 0);
                else SetPlayerSkin(playerid, inputtext[0]);

                GivePlayerCash(playerid, -200);

                SendClientMessageEx(playerid, -1, "Cambiaste al skin %d.", inputtext[0]);
                return 1;
            }
        }
        case DIALOG_FSKIN_CONFIRM:
        {
            if(response)
            {
                PI[playerid][pi_COINS] -= 5;
                SetPlayerSkin(playerid, PI[playerid][pi_SELECT_SKIN]);
                PI[playerid][pi_SKIN] = PI[playerid][pi_SELECT_SKIN];

                new DB_Query_Coins[120];
                mysql_format(Database, DB_Query_Coins, sizeof DB_Query_Coins, "UPDATE player SET coins = %d WHERE id = %d;", PI[playerid][pi_COINS], PI[playerid][pi_ID]);
                mysql_tquery(Database, DB_Query_Coins);

                new DB_Query[120];
                format(DB_Query, sizeof DB_Query, "UPDATE player SET skin = %d WHERE id = %d;", PI[playerid][pi_SKIN], PI[playerid][pi_ID]);
                mysql_tquery(Database, DB_Query);

                SendClientMessageEx(playerid, -1, "Ahora tu skin fijo es el %d.", PI[playerid][pi_SELECT_SKIN]);
                return 1;
            }
        }
        case DIALOG_CHANGE_PASSWORD:
        {
            if(response)
            {
                new password[64 + 1];
                SHA256_PassHash(inputtext, PI[playerid][pi_SALT], password, sizeof password);

                if(!strcmp(password, PI[playerid][pi_PASS], false))
                {
                    PI[playerid][pi_BAD_LOGIN_ATTEMPS] = 0;
                    ShowDialog(playerid, DIALOG_CHANGE_PASSWORD_PASS);
                }
                else
                {
                    PI[playerid][pi_BAD_LOGIN_ATTEMPS] ++;
                    if(PI[playerid][pi_BAD_LOGIN_ATTEMPS] > 3) return Kick(playerid);

                    ShowDialog(playerid, dialogid);
                    SendClientMessageEx(playerid, 0x999999AA, "Contraseña incorrecta, aviso %d/3.", PI[playerid][pi_BAD_LOGIN_ATTEMPS]);
                }
            }
        }
        case DIALOG_CHANGE_PASSWORD_PASS:
        {
            if(response)
            {
                if(strlen(inputtext) < MIN_PASS_LENGTH || strlen(inputtext) > MAX_PASS_LENGTH) return ShowDialog(playerid, dialogid);

                new salt[16];
                getRandomSalt(salt);
                format(PI[playerid][pi_SALT], 16, "%s", salt);

                SHA256_PassHash(inputtext, PI[playerid][pi_SALT], PI[playerid][pi_PASS], 64 + 1);

                new DB_Query[120];
                mysql_format(Database, DB_Query, sizeof DB_Query, "UPDATE player SET salt = '%e', pass = '%e' WHERE id = %d;", PI[playerid][pi_SALT], PI[playerid][pi_PASS], PI[playerid][pi_ID]);
                mysql_tquery(Database, DB_Query);

                SendClientMessage(playerid, -1, "{0af70a}Contraseña cambiada.");
                return 1;
            }
        }
    }

    return 1;
}

getRandomSalt(salt[], length = sizeof salt)
{
    for(new i = 0; i != length; i ++)
	{
		salt[i] = random(2) ? (random(26) + (random(2) ? 'a' : 'A')) : (random(10) + '0');
	}
	return true;
}

CMD:v(playerid, params[])
{
    ShowDialog(playerid, DIALOG_SELECT_VEHICLES);
    return 1;
}

CMD:armas(playerid, params[])
{
    if(PI[playerid][pi_GODMODE]) return SendClientMessage(playerid, -1, "No puedes pedir armas estando en god mode.");
    ShowDialog(playerid, DIALOG_SELECT_WEAPONS);
    return 1;
}

CMD:est(playerid, params[])
{
    ShowPlayerStats(playerid);
    return 1;
}

ShowPlayerStats(playerid)
{
    new dialog[240];
    format(dialog, sizeof dialog,
    "\
        ID: %d\n\
        Nombre: %s\n\
        Dinero: %d$\n\
        Kills: %d\n\
        Muertes: %d\n\
    ", PI[playerid][pi_ID], PI[playerid][pi_NAME], PI[playerid][pi_CASH],
    PI[playerid][pi_KILLS], PI[playerid][pi_DEATHS]);

    ShowPlayerDialog(playerid, DIALOG_INFO, DIALOG_STYLE_MSGBOX, "Estadísticas", dialog, "Cerrar", "");
    return 1;
}

GivePlayerCash(playerid, ammount)
{
    PI[playerid][pi_CASH] += ammount;
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, PI[playerid][pi_CASH]);

    new DB_Query[120];
    mysql_format(Database, DB_Query, sizeof DB_Query, "UPDATE player SET cash = %d WHERE id = %d;", PI[playerid][pi_CASH], PI[playerid][pi_ID]);
    mysql_tquery(Database, DB_Query);

    return 1;
}

CMD:ls(playerid, params[])
{
    SetPlayerPos(playerid, 2489.9841, -1672.0533, 13.3359);
    return 1;
}

CMD:sf(playerid, params[])
{
    SetPlayerPos(playerid, -1747.9178, -580.0380, 16.3359);
    return 1;
}

CMD:lv(playerid, params[])
{
    SetPlayerPos(playerid, 1712.0676, 1472.0187, 10.8203);
    return 1;
}

CMD:players(playerid, params[])
{
    SendClientMessageEx(playerid, -1, "Hay %d jugadores conectados.", TOTAL_PLAYERS);
    return 1;
}

SendClientMessageEx(playerid, color, form[], {Float, _}: ...)
{
    #pragma unused form

    static
        tmp[145]
    ;
    new
        t1 = playerid,
        t2 = color
    ;
    const
        n4 = -4,
        n16 = -16,
        size = sizeof tmp
    ;
    #emit stack 28
    #emit push.c size
    #emit push.c tmp
    #emit stack n4
    #emit sysreq.c format
    #emit stack n16

    return (t1 == -1 ? (SendClientMessageToAll(t2, tmp)) : (SendClientMessage(t1, t2, tmp)) );
}

SavePlayerData(playerid)
{
    if(!PI[playerid][pi_USER_EXIT]) return 0;

    new DB_Query[900];
    mysql_format(Database, DB_Query, sizeof DB_Query,
    "\
        UPDATE player SET \
        name = '%e',\
        ip = '%e',\
        salt = '%e',\
        pass = '%e',\
        cash = %d,\
        kills = %d,\
        deaths = %d,\
        admin_level = %d,\
        coins = %d,\
        skin = %d \
        WHERE id = %d;\
    ", PI[playerid][pi_NAME], PI[playerid][pi_IP], PI[playerid][pi_SALT], PI[playerid][pi_PASS], PI[playerid][pi_CASH], PI[playerid][pi_KILLS],
    PI[playerid][pi_DEATHS], PI[playerid][pi_ADMIN_LEVEL], PI[playerid][pi_COINS], PI[playerid][pi_SKIN], PI[playerid][pi_ID]);

    mysql_tquery(Database, DB_Query);
    return 1;
}

stock RegisterNewPlayer(playerid)
{
    inline OnPlayerInserted()
    {
        PI[playerid][pi_ID] = cache_insert_id();
        OnPlayerRegister(playerid);
    }

    new DB_Query[800];
    mysql_format(Database, DB_Query, sizeof DB_Query,
    "\
        INSERT INTO `player`(`name`, `email`, `ip`, `salt`, `pass`, `admin_level`, `kills`, `deaths`, `cash`, `vip`, `coins`, `skin`) VALUES ('%e', '%e', '%e', '%e', '%e', %d, %d, %d, %d, %d, %d, %d)",
    PI[playerid][pi_NAME], PI[playerid][pi_EMAIL], PI[playerid][pi_IP], PI[playerid][pi_SALT], PI[playerid][pi_PASS], PI[playerid][pi_ADMIN_LEVEL], PI[playerid][pi_KILLS],
    PI[playerid][pi_DEATHS], PI[playerid][pi_CASH], PI[playerid][pi_VIP], PI[playerid][pi_COINS], PI[playerid][pi_SKIN]);

    mysql_tquery_inline(Database, DB_Query, using inline OnPlayerInserted);
    return 1;
}

public OnPlayerRegister(playerid)
{
    SendClientMessageEx(playerid, -1, "{03fc28}¡Bienvenido a "SERVER_NAME" %s!{ffffff}, esperemos que disfrutes de esta gran comunidad.", PI[playerid][pi_NAME]);
    SendClientMessage(playerid, -1, "Estamos en constante desarrollo, puedes dejar tus sugerencias por ahora en el Discord, usa {03fc28}/web");

    new r = random(sizeof(Random_Spawn_Pos));
    if(!PI[playerid][pi_SKIN]) SetSpawnInfo(playerid, NO_TEAM, random(311), Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);
    else SetSpawnInfo(playerid, NO_TEAM, PI[playerid][pi_SKIN], Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);

    SpawnPlayer(playerid);
    PI[playerid][pi_USER_EXIT] = true;

    return 1;
}

CMD:kick(playerid, params[])
{
    new to_player, reason[128];
    if(sscanf(params, "us[128]", to_player, reason)) return SendClientMessage(playerid, -1, "Syntax: /kick <player_id <razón>");
    if(!IsPlayerConnected(to_player)) return SendClientMessageEx(playerid, -1, "Jugador (%d) desconectado.", to_player);
    if(PI[playerid][pi_ADMIN_LEVEL] < PI[to_player][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "El rango administrativo de este jugador es superior al tuyo.");

    KickEx(to_player, 500);
    SendClientMessageEx(playerid, -1, "Jugador (nick: '%s' player_id: '%d' DB-ID '%d') expulsado.", PI[to_player][pi_NAME], to_player, PI[to_player][pi_ID]);

    new string[120];
    format(string, sizeof string, "{ff952b}[ADMIN] {ffffff}%s (%d) expulsó a %s (%d): %s.", PI[playerid][pi_NAME], playerid, PI[to_player][pi_NAME], to_player, reason);
    SendClientMessageToAll(-1, string);

    return 1;
}
flags:kick(CMD_MODERATOR);

CMD:setskin(playerid, params[])
{
    new to_player, skin;
    if(sscanf(params, "ud", to_player, skin)) return SendClientMessage(playerid, -1, "Syntax: /setskin <player_id> <skin>");
    if(!IsPlayerConnected(to_player)) return SendClientMessageEx(playerid, -1, "Jugador (%d) desconectado.", to_player);
    if(PI[playerid][pi_ADMIN_LEVEL] < PI[to_player][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "El rango administrativo de este jugador es superior al tuyo.");

    if(skin > 311) return SendClientMessage(playerid, -1, "Skin no válido.");

    SetPlayerSkin(to_player, skin);
    SendClientMessageEx(playerid, -1, "Ahora el jugador %s tiene la skin %d.", PI[playerid][pi_NAME], skin);

    return 1;
}
flags:setskin(CMD_ADMIN);

CMD:darscore(playerid, params[])
{
    new to_player, score;
    if(sscanf(params, "ud", to_player, score)) return SendClientMessage(playerid, -1, "Syntax: /setscore <player_id> <score>");
    if(!IsPlayerConnected(to_player)) return SendClientMessageEx(playerid, -1, "Jugador (%d) desconectado.", to_player);
    if(PI[playerid][pi_ADMIN_LEVEL] < PI[to_player][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "El rango administrativo de este jugador es superior al tuyo.");

    PI[to_player][pi_KILLS] += score;
    SetPlayerScore(to_player, PI[to_player][pi_KILLS]);

    SendClientMessageEx(playerid, -1, "Ahora el score de %s (%d) es de %d.", PI[to_player][pi_NAME], to_player, PI[to_player][pi_KILLS]);
    return 1;
}
flags:darscore(CMD_ADMIN);

public OnPlayerCommandPerformed(playerid, cmd[], params[], result, flags)
{
    if(result == -1)
    {
		SendClientMessage(playerid, -1, "Comando incorrecto, usa {C4FF66}/ayuda {FFFFFF}si necesitas ayuda.");
        return 0;
    }
    return 1;
}

public OnPlayerCommandReceived(playerid, cmd[], params[], flags)
{
    if(flags)
	{
		if(flags > PI[playerid][pi_ADMIN_LEVEL])
		{
			SendClientMessage(playerid, -1, "Comando incorrecto, usa {C4FF66}/ayuda {FFFFFF}si necesitas ayuda.");
			return 0;
		}
	}

    printf("[CMD] %s (%d): /%s %s", PI[playerid][pi_NAME], playerid, cmd, params); // <--- Log de comandos
    return 1;
}

CMD:dameadmin(playerid, params[])
{
    if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, -1, "SERVER: Unknown command.");

    PI[playerid][pi_ADMIN_LEVEL] = 5;
    new DB_Query[120];

    mysql_format(Database, DB_Query, sizeof DB_Query, "UPDATE player SET admin_level = 5 WHERE id = %d;", PI[playerid][pi_ID]);
    mysql_tquery(Database, DB_Query);

    SendClientMessage(playerid, -1, "{ffd000}Ahora eres administrador nivel 5 por haber logueado con RCON.");
    return 1;
}

CMD:givemod(playerid, params[])
{
    new to_player, level;
    if(sscanf(params, "ud", to_player, level)) return SendClientMessage(playerid, -1, "Syntax: /givemod <player_id> <level>");
    if(!IsPlayerConnected(to_player)) return SendClientMessageEx(playerid, -1, "Jugador (%d) desconectado.", to_player);

    if(PI[playerid][pi_ADMIN_LEVEL] < PI[to_player][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "{ff0000}Este usuario tiene un rango administrativo superior al tuyo.");
    if(level > PI[playerid][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "No puedes cambiar el rango a este jugador porque el rango es superior al tuyo.");

    PI[to_player][pi_ADMIN_LEVEL] = level;
    SendClientMessageEx(to_player, -1, "Ahora tu nivel de admin es %d.", level);

    new DB_Query[120];
    mysql_format(Database, DB_Query, sizeof DB_Query, "UPDATE player SET admin_level = %d WHERE id = %d;", level, PI[to_player][pi_ID]);
    mysql_tquery(Database, DB_Query);

    return 1;
}
flags:givemod(CMD_ADMIN);

CMD:duelo(playerid, params[])
{
    if(PI[playerid][pi_KILLS] < 3) return SendClientMessage(playerid, -1, "Necesitas al menos 3 kills para poder invitar a alguien a hacer duelos.");

    PI[playerid][pi_DUEL_SENDERID] = playerid;

    ShowDialog(playerid, DIALOG_PLAYER_DUEL);
    return 1;
}

forward RegresiveCount(playerid, pid);
public RegresiveCount(playerid, pid)
{
    PI[playerid][pi_IN_DUEL] = true;
    PI[pid][pi_IN_DUEL] = true;

    SetPlayerPos(playerid, 1712.0676, 1472.0187, 10.8203);
    SetPlayerPos(pid, 1712.0676, 1472.0187, 10.8203);

    SetPlayerFacingAngle(playerid, 270.0);
    SetPlayerFacingAngle(pid, 270.0);

    TogglePlayerControllable(playerid, false);
    Duel_Count ++;

    SetTimerEx("RegresiveCount1", 1000, false, "ii", playerid, pid);
    return 1;
}

forward RegresiveCount1(playerid, pid);
public RegresiveCount1(playerid, pid)
{
    if(Duel_Count >= 3)
    {
        TogglePlayerControllable(playerid, true);
        TogglePlayerControllable(pid, true);

        SendClientMessage(pid, -1, "{CCCCCC}El duelo ha comenzado.");
        SendClientMessage(playerid, -1, "{CCCCCC}El duelo ha comenzado.");

        for(new i = 0; i != 10; i++)
        {
            GivePlayerWeapon(playerid, Random_Weapons[random(sizeof(Random_Weapons))], 10000);
            GivePlayerWeapon(pid, Random_Weapons[random(sizeof(Random_Weapons))], 10000);
        }

        SetPlayerHealthAndArmourEx(playerid, 100.0);
        SetPlayerHealthAndArmourEx(pid, 100.0);

        Duel_Count = 0;
        return 1;
    }

    Duel_Count ++;
    SetTimerEx("RegresiveCount1", 1000, false, "ii", playerid, pid);

    return 1;
}

stock SetPlayerHealthAndArmourEx(playerid, Float:value)
{
    SetPlayerHealth(playerid, value);
    SetPlayerArmour(playerid, value);

    return 1;
}

public OnPlayerLogin(playerid)
{
    SetPlayerScore(playerid, PI[playerid][pi_KILLS]);
    ResetPlayerMoney(playerid);

    GivePlayerMoney(playerid, PI[playerid][pi_CASH]);

    if(PI[playerid][pi_SKIN]) SetPlayerSkin(playerid, PI[playerid][pi_SKIN]);
    else SetPlayerSkin(playerid, random(311));

    new r = random(sizeof(Random_Spawn_Pos));
    if(!PI[playerid][pi_SKIN]) SetSpawnInfo(playerid, NO_TEAM, random(311), Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);
    else SetSpawnInfo(playerid, NO_TEAM, PI[playerid][pi_SKIN], Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);

    SpawnPlayer(playerid);

    SendClientMessageEx(playerid, -1, "Bienvenido de nuevo {03fc28}%s!, {ffffff}esperemos que sigas disfrutando de nuestro servidor.", PI[playerid][pi_NAME]);
    printf("Datos de %s (%d) cargados.", PI[playerid][pi_NAME], playerid);

    return 1;
}

CMD:cls(playerid, params[])
{
    for(new i = 0; i != 50; i ++) SendClientMessageToAll(-1, " ");
    SendCmdLogToAdmins(playerid, "cls", params);

    return 1;
}
flags:cls(CMD_MODERATOR);

CMD:kill(playerid, params[])
{
    SetPlayerHealth(playerid, 0.0);
    return 1;
}

CMD:adv(playerid, params[])
{
    new to_player, reason[128];
    if(sscanf(params, "us[128]", to_player, reason)) return SendClientMessage(playerid, -1, "Error: Utiliza /adv [PlayerID/Nombre]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    new dialog[90 + MAX_PLAYER_NAME];
    format(dialog, sizeof dialog,
    "\
        Has recibido una advertencia por parte de un administrador\n\
        Razón: %s\n\
    ", reason);
    ShowPlayerDialog(to_player, DIALOG_INFO, DIALOG_STYLE_MSGBOX, "Aviso", dialog, "Entiendo", "");

    new message[120];
    format(message, 120, "{ff9e03}[ADMIN] {ffffff}%s (%d) advirtió a %s (%d): %s", PI[playerid][pi_NAME], playerid, PI[to_player][pi_NAME], to_player, reason);
    SendClientMessageToAll(-1, message);

    SendClientMessageEx(playerid, -1, "Jugador (nick '%s' DB-ID: '%d' PlayerID: '%d') advertido.", PI[to_player][pi_NAME], PI[to_player][pi_ID], to_player);
    return 1;
}
flags:adv(CMD_MODERATOR);

public OnPlayerText(playerid, text[])
{
    if(!PI[playerid][pi_USER_LOGGED]) { SendClientMessage(playerid, -1, "{fffb00}Ahora no puedes hablar."); return 0; }
    if(PI[playerid][pi_STATE_DEATH])
    {
        SendClientMessage(playerid, -1, "No puedes decir nada estando muerto.");
        return 0;
    }

    if(StringContainsIP(text)) return Kick(playerid); // ANTI SPAM
    if(text[0] == '#' && PI[playerid][pi_ADMIN_LEVEL]) // CHAT ADMIN
    {
        new string[200 + MAX_PLAYER_NAME];
        format(string, 200, "{7eeb63}[ADMIN CHAT] {ffffff}%s (%d): %s", PI[playerid][pi_NAME], playerid, text[1]);
        SendMessageToAdmins(-1, string);

        return 0;
    }
    else if(text[0] == '$' && PI[playerid][pi_VIP]) // CHAT VIP
    {
        new str[200];
        format(str, 200, "{ff9900}[VIP] {ffffff}%s (%d): %s", PI[playerid][pi_NAME], playerid, text[1]);
        SendMessageToVIPMembers(-1, str);

        return 0;
    }
    else
    {
        new global_str[300];
        format(global_str, 300, "{5eeb00}%s (%d): {ffffff}%s", PI[playerid][pi_NAME], playerid, text);
        SendClientMessageToAll(-1, global_str);
    }

    return 0;
}

SendMessageToAdmins(color, string[])
{
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i))
        {
            if(PI[i][pi_ADMIN_LEVEL])
            {
                SendClientMessage(i, color, string);
            }
        }
    }

    return 1;
}

SendMessageToVIPMembers(color, string[])
{
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i))
        {
            if(PI[i][pi_VIP])
            {
                SendClientMessage(i, color, string);
            }
        }
    }

    return 1;
}

CMD:comprarvip(playerid, params[])
{
    if(PI[playerid][pi_VIP]) return SendClientMessage(playerid, -1, "{999999}Ya eres VIP.");
    else ShowDialog(playerid, DIALOG_VIP_BUY);

    return 1;
}

CMD:setcoins(playerid, params[])
{
    new to_player, coins;
    if(sscanf(params, "ud", to_player, coins)) return SendClientMessage(playerid, -1, "Error: Utiliza /setcoins [PlayerID/Nombre] [Cantidad]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    PI[to_player][pi_COINS] = coins;
    SendClientMessageEx(playerid, -1, "Ahora la cantidad de coins de %s es de %d.", PI[to_player][pi_NAME], coins);

    return 1;
}
flags:setcoins(CMD_ADMIN);

public OnPlayerUpdate(playerid)
{
    PI[playerid][pi_CHECK_AFK] = gettime() + 120;

    new player_weapon = GetPlayerWeapon(playerid);
    if(player_weapon == 38 || player_weapon == 35 || player_weapon == 36 || player_weapon == 37)
    {
        SendClientMessage(playerid, -1, "En este servidor no puedes usar estas armas.");
        TogglePlayerControllable(playerid, false);
    }

    return 1;
}

public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid, bodypart)
{
    new Float:player_health;
    GetPlayerHealth(playerid, player_health);

    if(issuerid != INVALID_PLAYER_ID)
    {
        if(IsPlayerConnected(playerid) && PI[playerid][pi_PLAYER_SHOTTING] > 5 && PI[playerid][pi_ADMIN_LEVEL] < 3 && player_health > 100.0)
        {
            SetPlayerVirtualWorld(playerid, VIRTUAL_WORLD_OF_CHEATS);
            PI[playerid][pi_PLAYER_SHOTTING] = 0;

            return 1;
        }

        PlayerPlaySound(issuerid, 17802, 0.0, 0.0, 0.0); // campana
        PlayerPlaySound(playerid, 17802, 0.0, 0.0, 0.0); // campana
        PI[playerid][pi_PLAYER_SHOTTING] ++;
    }

    if(!PI[playerid][pi_USER_LOGGED]) return ShowPlayerDialog(issuerid, DIALOG_INFO, DIALOG_STYLE_MSGBOX, "Aviso", "El jugador no ha spawneado, por favor espera.", "Cerrar", "");
    return 1;
}

CMD:ventajas(playerid, params[])
{
    ShowPlayerDialog(playerid, DIALOG_INFO, DIALOG_STYLE_MSGBOX, "Ventajas VIP",
    "\
        Por ahora no son muchas las ventajas, pero las hay:\n\
        Si le ganas un duelo a alguien te ganas 2 puntos extras.\n\
        Puedes comprar más coins para renovar tu membresía\n\
    ",
    "Cerrar", "");

    return 1;
}
alias:ventajas("vent");

CMD:ayuda(playerid, params[])
{
    ShowDialog(playerid, DIALOG_HELP);
    return 1;
}

CMD:campana(playerid, params[])
{
    PlayerPlaySound(playerid, 17802, 0.0, 0.0, 0.0);
    return 1;
}

CMD:csave(playerid, params[])
{
    SavePlayerData(playerid);

    SendClientMessage(playerid, -1, "Los datos de tu cuenta han sido guardados.");
    return 1;
}

CMD:chaleco(playerid, params[])
{
    if(PI[playerid][pi_CASH] < 200) return SendClientMessage(playerid, -1, "No tienes dinero suficiente para comprar el chaleco, intenta más tarde.");
    else
    {
        SetPlayerArmour(playerid, 100.0);
        GivePlayerCash(playerid, -200);

        SendClientMessage(playerid, -1, "Compraste chaleco por 200$");
    }

    return 1;
}

CMD:shop(playerid, params[])
{
    ShowDialog(playerid, DIALOG_SHOP);
    return 1;
}

CMD:cambiarskin(playerid, params[])
{
    ShowDialog(playerid, DIALOG_CHANGE_SKIN);
    return 1;
}

CMD:givecash(playerid, params[])
{
    new to_player, value;
    if(sscanf(params, "ud", to_player, value)) return SendClientMessage(playerid, -1, "Syntax: /givecash <player_id> <value>");
    if(!IsPlayerConnected(to_player)) return SendClientMessageEx(playerid, -1, "Jugador (%d) desconectado.", to_player);

    GivePlayerCash(to_player, value);
    SendClientMessageEx(playerid, -1, "Ahora la cantidad de dinero de %s es de %d$.", PI[playerid][pi_NAME], value);

    return 1;
}
flags:givecash(CMD_ADMIN);

CMD:getskin(playerid, params[])
{
    new to_player;
    if(sscanf(params, "u", to_player)) return SendClientMessage(playerid, -1, "Syntax: /getskin <playerid>");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    SendClientMessageEx(playerid, -1, "El ID skin de %s es %d.", PI[to_player][pi_NAME], GetPlayerSkin(to_player));
    return 1;
}
flags:getskin(CMD_ADMIN);

CMD:spec(playerid, params[])
{
    new to_player;
    if(sscanf(params, "u", to_player)) return SendClientMessage(playerid, -1, "Syntax: /spec <playerid>");
    if(!IsPlayerConnected(to_player)) return SendClientMessageEx(playerid, -1, "Jugador (%d) desconectado.", to_player);
    if(PI[to_player][pi_ADMIN_LEVEL] > PI[playerid][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "El rango administrativo de este jugador es superior al tuyo.");

    TogglePlayerSpectating(playerid, true);
    if(IsPlayerInAnyVehicle(to_player)) PlayerSpectateVehicle(playerid, GetPlayerVehicleID(to_player));
    else PlayerSpectatePlayer(playerid, to_player);
    SendClientMessage(playerid, -1, "Utiliza /specoff para terminar este modo.");

    return 1;
}
flags:spec(CMD_ADMIN);

CMD:specoff(playerid, params[])
{
    TogglePlayerSpectating(playerid, false);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);

    for(new i = 0; i != 10; i++) GivePlayerWeapon(playerid, Random_Weapons[random(sizeof(Random_Weapons))], 10000);

    new r = random(sizeof(Random_Spawn_Pos));
    if(!PI[playerid][pi_SKIN]) SetSpawnInfo(playerid, NO_TEAM, random(311), Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);
    else SetSpawnInfo(playerid, NO_TEAM, PI[playerid][pi_SKIN], Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);

    SpawnPlayer(playerid);
    return 1;
}
flags:specoff(CMD_ADMIN);

CMD:ir(playerid, params[])
{
    if(sscanf(params, "u", params[0])) return SendClientMessage(playerid, -1, "Error: Usa /ir [PlayerID/Nombre]");
    if(!IsPlayerConnected(params[0])) return SendClientMessage(playerid, -1, "Jugador desconectado.");
    if(PI[params[0]][pi_BLOCK_TELE]) return SendClientMessage(playerid, -1, "Este jugador tiene la teletransportación bloqueada.");
    if(PI[playerid][pi_BLOCK_TELE]) return SendClientMessage(playerid, -1, "No puedes ir a donde está este jugador porque tienes la teletransportación bloqueada.");

    new Float:pos[4];
    GetPlayerPos(params[0], pos[0], pos[1], pos[2]);
    GetPlayerFacingAngle(params[0], pos[3]);

    SetPlayerPos(playerid, pos[0], pos[1], pos[2]);
    SetPlayerFacingAngle(playerid, pos[3] + 180);

    SendClientMessageEx(playerid, -1, "Fuiste a la ubicación de %s.", PI[params[0]][pi_NAME]);
    return 1;
}

CMD:tele(playerid, params[])
{
    if(PI[playerid][pi_BLOCK_TELE])
    {
        SendClientMessage(playerid, -1, "Teletransportación desbloqueada.");
        PI[playerid][pi_BLOCK_TELE] = false;
    }
    else
    {
        SendClientMessage(playerid, -1, "Teletransportación bloqueada.");
        PI[playerid][pi_BLOCK_TELE] = true;
    }

    return 1;
}

CMD:fskin(playerid, params[])
{
    if(sscanf(params, "d", params[0])) return SendClientMessage(playerid, -1, "Error: Usa /fskin [ID del skin]");
    if(params[0] > 311) return SendClientMessage(playerid, -1, "El ID del skin no es válido.");

    if(PI[playerid][pi_COINS] < 5) return SendClientMessage(playerid, -1, "Necesitas 5 coins para poder comprar un skin fijo.");
    else
    {
        PI[playerid][pi_SELECT_SKIN] = params[0];
        ShowDialog(playerid, DIALOG_FSKIN_CONFIRM);
    }

    return 1;
}

stock SetPlayerSkinEx(playerid, skinid)
{
    PI[playerid][pi_SKIN] = skinid;
    SetPlayerSkin(playerid, PI[playerid][pi_SKIN]);

    return 1;
}

stock SendCmdLogToAdmins(playerid, cmd[], params[])
{
    new message[190];
    if(isnull(params)) format(message, 190, "[ADMIN] %s (%d): /%s %s", PI[playerid][pi_NAME], playerid, cmd, params);
    else format(message, 190, "[ADMIN] %s (%d): /%s", PI[playerid][pi_NAME], playerid, cmd);

    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i))
        {
            if(PI[playerid][pi_ADMIN_LEVEL]) SendClientMessage(i, -1, message);
        }
    }

    return 1;
}

CMD:label(playerid, params[])
{
    new label_text[90];
    if(sscanf(params, "s[90]", label_text)) return SendClientMessage(playerid, -1, "Error, usa /label [Texto]");
    if(StringContainsIP(label_text)) return Kick(playerid);

    if(strlen(label_text) > 90) return SendClientMessage(playerid, -1, "Tu texto es demasiado largo, prueba con otro.");
    else
    {
        new current_int = GetPlayerInterior(playerid), current_vw = GetPlayerVirtualWorld(playerid);
        new Float:pos[3]; GetPlayerPos(playerid, pos[0], pos[1], pos[2]);

        create_labels ++;
        CreateDynamic3DTextLabel(label_text, 0xFFFFFFFF, pos[0], pos[1], pos[2], 10.0, .testlos = true, .worldid = current_vw, .interiorid = current_int);

        Streamer_Update(playerid);
        SendClientMessageEx(playerid, -1, "Label #%d creado.", create_labels);
    }

    return 1;
}

forward EndSpec(playerid);
public EndSpec(playerid)
{
    new r = random(sizeof(Random_Spawn_Pos));
    if(!PI[playerid][pi_SKIN]) SetSpawnInfo(playerid, NO_TEAM, random(311), Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);
    else SetSpawnInfo(playerid, NO_TEAM, PI[playerid][pi_SKIN], Random_Spawn_Pos[r][0], Random_Spawn_Pos[r][1], Random_Spawn_Pos[r][2], 270.0, 0, 0, 0, 0, 0, 0);

    SpawnPlayer(playerid);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);

    return 1;
}

CMD:ban(playerid, params[])
{
    new to_player, reason[128];
    if(sscanf(params, "u", to_player)) return SendClientMessage(playerid, -1, "Syntax: /ban <playerid> <razón>");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    if(PI[to_player][pi_ADMIN_LEVEL] > PI[playerid][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "El rango administrativo de este jugador es superior al tuyo.");
    AddPlayerBan(PI[to_player][pi_ID], PI[to_player][pi_NAME], PI[to_player][pi_IP], PI[playerid][pi_ID], reason, -1);

    new str[140];
    format(str, 140, "[ADMIN] %s (%d) baneó permanentemente a %s (%d): %s.", PI[playerid][pi_NAME], playerid, PI[to_player][pi_NAME], to_player, reason);
    SendClientMessageToAll(-1, str);

    KickEx(playerid, 500);

    SendClientMessageEx(playerid, -1, "Jugador (nick: '%s', player_id: '%d', DB-ID: '%d') baneado permanentemente.", PI[to_player][pi_NAME], to_player, PI[to_player][pi_ID]);
    return 1;
}
flags:ban(CMD_ADMIN);

AddPlayerBan(to_account, name[], ip[], by_account, reason[], days = 0)
{
    new DB_Query[150];
    mysql_format(Database, DB_Query, sizeof DB_Query,
    "\
        INSERT INTO `bans`\
        (\
            `id_player`, `name`, `ip`, `by`, `date`, `reason`, `days`\
        )\
        VALUES \
        (\
            %d, '%e', '%e', '%e', %d, '%e', %d\
        )\
    ", to_account, name, ip, by_account, reason, days);
    mysql_tquery(Database, DB_Query);

    return 1;
}

CMD:comprarcoins(playerid, params[])
{
    if(!PI[playerid][pi_VIP]) return SendClientMessage(playerid, -1, "{999999}No eres VIP.");
    if(sscanf(params, "d", params[0])) return SendClientMessage(playerid, -1, "{999999}Error: Usa /comprarcoins [Cantidad]");
    if(params[0] > 10) return SendClientMessage(playerid, -1, "{999999}No puedes comprar más de 10 coins.");

    new price = params[0] * 20000;
    if(PI[playerid][pi_CASH] < price) return SendClientMessage(playerid, -1, "{999999}No tienes suficiente dinero para comprar esta cantidad.");

    PI[playerid][pi_COINS] += params[0];
    GivePlayerCash(playerid, -price);

    SendClientMessageEx(playerid, -1, "Compraste %d coins por %d$.", params[0], price);
    return 1;
}

CMD:web(playerid, params[])
{
    SendClientMessage(playerid, -1, ""SERVER_WEBURL"");
    return 1;
}

CMD:duda(playerid, params[])
{
    if(isnull(params)) return SendClientMessage(playerid, -1, "Error, utiliza /duda [Tu duda]");

    format(PI[playerid][pi_DOUBT_MESSAGE], 190, "%s", params);
    SendDoubtMessageToAdmins(playerid, PI[playerid][pi_DOUBT_MESSAGE]);

    return 1;
}

SendDoubtMessageToAdmins(playerid, message[])
{
    for(new i = 0, j = GetMaxPlayers(); i < j; i++)
    {
        if(IsPlayerConnected(i))
        {
            if(PI[i][pi_ADMIN_LEVEL])
            {
                SendClientMessageEx(i, -1, "%s (%d) ha enviado una duda: %s.", PI[playerid][pi_NAME], playerid, message);
                PI[i][pi_PLAYERID_DOUBT_RESPONDED] = playerid;
                PI[i][pi_DOUBT_RESPONDE] = true;
            }
        }
    }

    return 1;
}

CMD:responder(playerid, params[])
{
    if(isnull(params)) return SendClientMessage(playerid, -1, "Error, utiliza /responder [Texto]");
    if(!IsPlayerConnected(PI[playerid][pi_PLAYERID_DOUBT_RESPONDED])) return SendClientMessage(playerid, -1, "El jugador que envió la duda se ha desconectado.");

    new string[200];
    format(string, 200, "Respuesta del administrador %s: %s.", PI[playerid][pi_NAME], params);
    SendClientMessage(PI[playerid][pi_PLAYERID_DOUBT_RESPONDED], -1, string);

    SendClientMessageEx(playerid, -1, "Respondiste la duda de %s.", PI[ PI[playerid][pi_PLAYERID_DOUBT_RESPONDED] ][pi_NAME]);
    return 1;
}
flags:responder(CMD_ADMIN);

CMD:mp(playerid, params[])
{
    new to_player, message[120];
    if(sscanf(params, "us[120]", to_player, message)) return SendClientMessage(playerid, -1, "Error, utiliza /mp [PlayerID/Nombre] [Mensaje]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    if(StringContainsIP(message)) return Kick(playerid);

    new string[120 * 2];
    format(string, sizeof string, "Mensaje privado de %s: %s.", PI[playerid][pi_NAME], message);
    SendClientMessage(to_player, -1, string);

    PI[to_player][pi_PM_SENDERID] = playerid;
    PI[playerid][pi_PM] = true;

    SendClientMessageEx(playerid, -1, "Enviaste un mensaje privado a %s.", PI[to_player][pi_NAME]);
    return 1;
}

CMD:r(playerid, params[])
{
    if(!PI[playerid][pi_PM]) return SendClientMessage(playerid, -1, "Nadie te ha mandado un mensaje privado.");
    if(!IsPlayerConnected(PI[playerid][pi_PM_SENDERID])) return SendClientMessage(playerid, -1, "El jugador que envió el mensaje se ha desconectado.");

    new message[200];
    if(sscanf(params, "s[200]", message)) return SendClientMessage(playerid, -1, "Error, utiliza /r [Respuesta]");

    if(StringContainsIP(message)) return Kick(playerid);

    new string[200 * 2];
    format(string, sizeof string, "Respuesta de %s: %s", PI[playerid][pi_NAME], message);
    SendClientMessage(PI[playerid][pi_PM_SENDERID], -1, string);

    SendClientMessageEx(playerid, -1, "Le has respondido a %s.", PI[ PI[playerid][pi_PM_SENDERID] ][pi_NAME]);
    return 1;
}

StringContainsIP(const string[])
{
    new regex:reg_exp = regex_new("([0-9]{1,3}[\\.]){3}[0-9]{1,3}"), match_results:results, pos;
    new result = regex_search(string, reg_exp, results, pos);
    regex_delete(reg_exp);
    return result;
}

CMD:sethealth(playerid, params[])
{
    new to_player, Float:value;
    if(sscanf(params, "uf", to_player, value)) return SendClientMessage(playerid, -1, "Error, usa /sethealth [ID] [Cantidad]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    if(value > 100.0) return SendClientMessage(playerid, -1, "Cantidad no válida.");

    SetPlayerHealth(to_player, value);
    SendClientMessageEx(playerid, -1, "Ahora la vida de %s (%d) es de %.1f.", PI[to_player][pi_NAME], to_player, value);

    return 1;
}
flags:sethealth(CMD_ADMIN);

CMD:a(playerid, params[])
{
    if(isnull(params)) return SendClientMessage(playerid, -1, "Error, utiliza /a [Mensaje]");

    new str[190];
    format(str, 190, "* [ADMIN]: %s", params);
    SendClientMessageToAll(-1, str);

    return 1;
}
flags:a(CMD_MODERATOR);

CMD:godmode(playerid, params[])
{
    if(PI[playerid][pi_GODMODE]) DesactivePlayerGodMode(playerid);
    else ActivePlayerGodMode(playerid);

    return 1;
}

ActivePlayerGodMode(playerid)
{
    GetPlayerHealth(playerid, PI[playerid][pi_OLD_HEALTH]);
    if(!PI[playerid][pi_GODMODE])
    {
        SetPlayerHealth(playerid, 9999999.0);
        PI[playerid][pi_GODMODE] = true;

        ResetPlayerWeapons(playerid);
        return 1;
    }

    return 1;
}

DesactivePlayerGodMode(playerid)
{
    if(PI[playerid][pi_GODMODE])
    {
        SetPlayerHealth(playerid, PI[playerid][pi_OLD_HEALTH]);
        PI[playerid][pi_GODMODE] = false;
        ResetPlayerWeapons(playerid);

        for(new i = 0; i != 10; i++) GivePlayerWeapon(playerid, Random_Weapons[random(sizeof(Random_Weapons))], 10000);
        return 1;
    }

    return 1;
}

CMD:setname(playerid, params[])
{
    new to_player, name[24];
    if(sscanf(params, "us[24]", to_player, name)) return SendClientMessage(playerid, -1, "Error, utiliza /setname [PlayerID/Nombre] [Nuevo nombre]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    if(PI[to_player][pi_ADMIN_LEVEL] > PI[playerid][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "El rango administrativo de este jugador es superior al tuyo.");

    inline CheckNameExist()
    {
        new rows;
        if(cache_get_row_count(rows))
        {
            if(rows) SendClientMessageEx(playerid, -1, "El nombre '%s' ya está en uso, prueba otro distinto.", name);
        }
    }

    SendClientMessageEx(playerid, -1, "Ahora el nombre del jugador '%s (%d)' es %s.", PI[to_player][pi_NAME], to_player, name);
    SetPlayerName(to_player, name);

    new DB_Query[180];
    format(DB_Query, sizeof DB_Query, "UPDATE player SET name = '%e' WHERE id = %d;", name, PI[to_player][pi_NAME]);
    mysql_tquery(Database, DB_Query);

    format(DB_Query, sizeof DB_Query, "SELECT id FROM player WHERE name = '%e';", name);
    mysql_tquery_inline(Database, DB_Query, using inline CheckNameExist);

    return 1;
}
flags:setname(CMD_ADMIN);

CMD:ww(playerid, params[])
{
    if(PI[playerid][pi_GODMODE]) return SendClientMessage(playerid, 0x999999AA, "Ahora no puedes usar este comando.");

    for(new i = 0; i != 10; i++) GivePlayerWeapon(playerid, minrand(30, 35), 10000);
    PlayerPlaySound(playerid, 1058, 0.0, 0.0, 0.0);
    return 1;
}

stock minrand(min, max) // By Alex "Y_Less" Cole
{
    return random(max - min) + min;
}

public CheckPlayerPause(playerid)
{
    if(!PI[playerid][pi_USER_LOGGED] || PI[playerid][pi_STATE_DEATH] == true || PI[playerid][pi_AUTORIZED_AFK] == true || PI[playerid][pi_ADMIN_LEVEL]) return 1;
    if(gettime() >= PI[playerid][pi_CHECK_AFK] + 120)
    {
        KickEx(playerid, 500);

        new string[120];
        format(string, sizeof string, "{f50535}%s (%d) fue expulsado, razón: Inactivo.", PI[playerid][pi_NAME], playerid);
        SendClientMessageToAll(-1, string);

        return 1;
    }

    return 1;
}

CMD:afk(playerid, params[])
{
    if(PI[playerid][pi_AUTORIZED_AFK])
    {
        PI[playerid][pi_AUTORIZED_AFK] = false;
        SendClientMessage(playerid, -1, "Has salido del modo AFK.");
    }
    else
    {
        PI[playerid][pi_AUTORIZED_AFK] = true;
        SendClientMessage(playerid, -1, "Has entrado en modo AFK, ahora no serás expulsado por el sistema.");
    }

    return 1;
}

CMD:pass(playerid, params[])
{
    ShowDialog(playerid, DIALOG_CHANGE_PASSWORD);
    return 1;
}

stock SetPlayerPosEx(playerid, Float:x, Float:y, Float:angle, interior, worldid)
{
    SetPlayerPos(playerid, x, y, z);
    SetPlayerFacingAngle(playerid, angle);

    SetPlayerInterior(playerid, interior);
    SetPlayerVirtualWorld(playerid, worldid);

    if(IsPlayerInAnyVehicle(playerid))
    {
        new vehicleid = GetPlayerVehicleID(vehicleid);

        SetVehiclePos(vehicleid, x, y, z);
        SetVehicleZAngle(vehicleid, angle);

        PutPlayerInVehicle(playerid, vehicleid, 0);
    }
    return 1;
}

CMD:creditos(playerid, params[])
{
    ShowPlayerDialog(playerid, DIALOG_INFO, DIALOG_STYLE_MSGBOX, ""SERVER_NAME" - Créditos",
    "\
        Nombre del servidor: "SERVER_NAME"\n\
        Fecha de actualización: "BUILD_VERSION"\n\
        \n\
        Mega DeathMatch es un servidor con una GameMode desde\n\
        0, por lo que puede contener varios fallos. Cualquier\n\
        fallo que encuentres dentro del servidor, te pedimos que\n\
        lo reportes lo antes posible para que el problema sea\n\
        solucionado con mayor rápidez.\n\
        \n\
        Programación:\n\
        LuisSAMP\n\
        KapeX\n\
        \n\
        Includes:\n\
        Incognito por streamer\n\
        Y_Less por sscanf2 y librería YSI\n\
        YourShadow por Pawn.CMD y Pawn.RakNet\n\
        BlueG por MySQL\n\
        \n\
        Mapeos:\n\
        Algunos mapeos están descargados de internet, otros\n\
        hechos por KapeX\n\
        \n\
        Agradecimientos:\n\
        KapeX - Discord, SA-MP Wiki, TDEditor por adri1\n\
    ",
    "Cerrar", "");
    return 1;
}

CMD:rv(playerid, params[])
{
    new to_car, color1, color2;
    if(sscanf(params, "ddd", to_car, color1, color2)) return SendClientMessage(playerid, -1, "Syntax: /rv <vehicleid> <color 1> <color 2>");

    new Float:pos[4];
    GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
    GetPlayerFacingAngle(playerid, pos[3]);

    new vehicleid = CreateVehicle(to_car, pos[0], pos[1], pos[2], pos[3], color1, color2, 300);
    PutPlayerInVehicle(playerid, vehicleid, 0);

    return 1;
}
flags:rv(CMD_MODERATOR);

CMD:repararveh(playerid, params[])
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if(!vehicleid) return SendClientMessage(playerid, -1, "No estás conduciendo.");

    RepairVehicle(vehicleid);
    SendClientMessageEx(playerid, -1, "Vehículo (%d) reparado.", vehicleid);

    return 1;
}
flags:repararveh(CMD_HELPER);

CMD:nitro(playerid, params[])
{
    if(PI[playerid][pi_GODMODE]) return SendClientMessage(playerid, COLOR_GREY, "Ahora no puedes usar este comando.");
    if(!IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, -1, "No estás en un vehículo.");

    AddVehicleComponent(GetPlayerVehicleID(playerid), 1010);
    SendClientMessage(playerid, -1, "Nitro x10 añadido al vehículo.");

    return 1;
}

ClearPlayerChat(playerid)
{
    for(new i = 0; i != 50; i ++) SendClientMessage(playerid, -1, " ");
    return 1;
}

stock ClearChatAllPlayers()
{
    for(new i = 0; i != 50; i++) SendClientMessageToAll(-1, " ");
    return 1;
}

CMD:vida(playerid, params[])
{
    if(PI[playerid][pi_GODMODE]) return SendClientMessage(playerid, COLOR_GREY, "Ahora no puedes usar este comando.");

    SetPlayerHealth(playerid, 100.0);
    SendClientMessage(playerid, -1, "Vida recuperada.");

    return 1;
}

CMD:reportar(playerid, params[])
{
    new admins = CountPlayerAdmins();
    if(admins <= 0) return SendClientMessage(playerid, -1, "Actualmente no puedes reportar porque no hay adminstradores conectados.");

    new to_player, reason[128];
    if(sscanf(params, "us[128]", to_player, reason)) return SendClientMessage(playerid, -1, "Error: Usa /reportar [ID] [Razón]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");
    if(to_player == playerid) return SendClientMessage(playerid, -1, "Para autoreportate usa el comando /bug [Razón]");

    SendClientMessage(playerid, -1, "{CCCCCC}Tu reporte ha sido enviado a los administradores en línea.");

    new str[145]; format(str, 145, "{ff6403}[REPORTE] {ffffff}%s (%d) está reportando a %s (%d) por %s.", PI[playerid][pi_NAME], playerid, PI[to_player][pi_NAME], to_player, reason);
    SendMessageToAdmins(-1, str);
    return 1;
}

CMD:bug(playerid, params[])
{
    new admins = CountPlayerAdmins();
    if(admins <= 0) return SendClientMessage(playerid, -1, "Actualmente no puedes reportar porque no hay adminstradores conectados.");

    new reason[128];
    if(sscanf(params, "s[128]", reason)) return SendClientMessage(playerid, -1, "{ff0000}ERROR: {ffffff}Usa /bug [Razón]");
    if(strlen(reason) > 256) return SendClientMessage(playerid, -1, "El mensaje es demasiado largo y no llega a los administradores.");

    new string[256];
    format(string, sizeof string, "{ff6403}[REPORTE BUG] {ffffff}%s (%d) - %s.", PI[playerid][pi_NAME], playerid, reason);
    SendMessageToAdmins(-1, string);

    SendClientMessage(playerid, -1, "{CCCCCC}Tu reporte ha sido enviado a los administradores en línea.");
    return 1;
}

CountPlayerAdmins()
{
    new count;
    for(new i = 0, j = GetMaxPlayers(); i < j; i++)
    {
        if(IsPlayerConnected(i))
        {
            if(PI[i][pi_ADMIN_LEVEL]) count ++;
        }
    }

    return count;
}

stock GivePlayerHealthEx(playerid, Float:health)
{
    new Float:phealth;
    GetPlayerHealth(playerid, phealth);

    if(health < 0.0) phealth -= health;
    else phealth += health;

    SetPlayerHealth(playerid, phealth);
    return 1;
}

stock GivePlayerArmour(playerid, Float:ammour)
{
    new Float:parmour;
    GetPlayerArmour(playerid, parmour);

    if(armour < 0.0) parmour -= armour;
    else parmour += armour;

    SetPlayerHealth(playerid, parmour);
    return 1;
}

CMD:health(playerid, params[])
{
    GivePlayerHealthEx(playerid, 50.0);
    return 1;
}

CMD:nohealth(playerid, params[])
{
    GivePlayerHealthEx(playerid, -10.0);
    return 1;
}

CMD:n(playerid, params[])
{
    new message[145];
    if(!sscanf(params, "s[145]", message)){
        if(PI[playerid][pi_DOUBT_CHANNEL_TIME]){
            if(PI[playerid][pi_DOUBT_CHANNEL_TIME] > 60) SendClientMessageEx(playerid, -1, "Ahora no puedes hablar por este canal, tienes que esperar {33eb00}%dm {ffffff}y {33eb00}%ds.", PI[playerid][pi_DOUBT_CHANNEL_TIME] / 60, PI[playerid][pi_DOUBT_CHANNEL_TIME] % (60));
            else if(PI[playerid][pi_DOUBT_CHANNEL_TIME] <= 60) SendClientMessageEx(playerid, -1, "Ahora no puedes hablar por este canal, tienes que esperar {33eb00}%ds.", PI[playerid][pi_DOUBT_CHANNEL_TIME]);
        }
        else if(PI[playerid][pi_DOUBT_MUTE]){
            if(PI[playerid][pi_DOUBT_MUTE] <= 60) SendClientMessageEx(playerid, -1, "No puedes enviar dudas durante {33eb00}%ds.", PI[playerid][pi_DOUBT_MUTE]);
            else if(PI[playerid][pi_DOUBT_MUTE] > 60) SendClientMessageEx(playerid, -1, "No puedes enviar dudas durante {33eb00}%dm %ds.", PI[playerid][pi_DOUBT_MUTE] / 60, PI[playerid][pi_DOUBT_MUTE] % (60));
        }
        else{
            new string[170]; format(string, sizeof string, "{02a7b0}[Dudas] {00b5eb}%s (%d) [Nivel %d]: %s", PI[playerid][pi_NAME], playerid, PI[playerid][pi_KILLS], message);
            SendClientMessageToAll(-1, string);
            PI[playerid][pi_DOUBT_CHANNEL_TIME] = 60;
            PI[playerid][pi_TIMERS][3] = SetTimerEx("LosingSecondsDoubt", 1000, false, "i", playerid);
        }
    }
    else SendClientMessage(playerid, -1, "Error: Usa {47eb00}/n {ffffff}[Tu duda]");
    return 1;
}

forward LosingSecondsDoubt(playerid);
public LosingSecondsDoubt(playerid)
{
    PI[playerid][pi_DOUBT_CHANNEL_TIME] --;
    if(PI[playerid][pi_DOUBT_CHANNEL_TIME] < 0) PI[playerid][pi_DOUBT_CHANNEL_TIME] = 0;
    PI[playerid][pi_TIMERS][3] = SetTimerEx("LosingSecondsDoubt", 1000, false, "i", playerid);
    return 1;
}

stock SendMessageDoubtChannel(playerid, message[])
{
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++){
        if(IsPlayerConnected(i)){
            if(PI[playerid][pi_DOUBT_CHANNEL]) SendClientMessage(playerid, -1, message);
        }
    }
    return 1;
}

CMD:dudas(playerid, params[])
{
    if(PI[playerid][pi_DOUBT_CHANNEL])
    {
        PI[playerid][pi_DOUBT_CHANNEL] = false;
        SendClientMessage(playerid, -1, "Canal de dudas {b0bdae}desactivado.");
    }
    else
    {
        PI[playerid][pi_DOUBT_CHANNEL] = true;
        SendClientMessage(playerid, -1, "Canal de dudas {23eb00}activado.");
    }

    return 1;
}

CMD:silenciar(playerid, params[])
{
    new to_player, time;
    if(sscanf(params, "ud", to_player, time)) return SendClientMessage(playerid, -1, "Error: Usa /silenciar [PlayerID/Nombre] [Cantidad de minutos]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "El jugador no está conectado.");
    if(PI[to_player][pi_ADMIN_LEVEL] > PI[playerid][pi_ADMIN_LEVEL]) return SendClientMessage(playerid, -1, "El rango administrativo de este jugador es superior al tuyo.");
    if(PI[playerid][pi_DOUBT_MUTE]) return SendClientMessage(playerid, -1, "Este jugador ya está silenciado.");

    if(time > 3000) return SendClientMessage(playerid, -1, "No puedes añadir tanto tiempo.");
    else
    {
        new string[140]; format(string, sizeof string, "{a10202}%s ha silenciado a %s del canal de dudas durante %d %s.", PI[playerid][pi_NAME], PI[to_player][pi_NAME], time, (time == 1) ? ("minuto") : ("minutos"));
        SendClientMessageToAll(-1, string);

        SendClientMessageEx(to_player, -1, "Fuiste silenciado durante {ed0000}%d %s.", time, (time == 1) ? ("minuto") : ("minutos"));
        PI[playerid][pi_DOUBT_MUTE] = time * 60;
        PI[playerid][pi_TIMERS][4] = SetTimerEx("LosedMutedDoubtTime", 1000, false, "i", playerid);
    }

    return 1;
}
flags:silenciar(CMD_HELPER);

forward LosedMutedDoubtTime(playerid);
public LosedMutedDoubtTime(playerid)
{
    PI[playerid][pi_DOUBT_MUTE] --;
    if(PI[playerid][pi_DOUBT_MUTE] <= 0)
    {
        SendClientMessage(playerid, -1, "Ya puedes volver a enviar dudas, no hagas que te vuelvan a silenciar.");
        PI[playerid][pi_DOUBT_MUTE] = 0;
        return 1;
    }
    PI[playerid][pi_TIMERS][4] = SetTimerEx("LosedMutedDoubtTime", 1000, false, "i", playerid);
    return 1;
}

CMD:id(playerid, params[])
{
    new to_player;
    if(sscanf(params, "u", to_player)) return SendClientMessage(playerid, -1, "Error: Usa /id [PlayerID/Nombre]");
    if(!IsPlayerConnected(to_player)) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    SendClientMessageEx(playerid, -1, "Nombre {00ed3b}'%s' {ffffff}PlayerID: {00ed3b}%d {ffffff}DB-ID {00ed3b}'%d' {ffffff}Ping {00ed3b}'%d'", PI[to_player][pi_NAME], to_player, PI[to_player][pi_ID], GetPlayerPing(to_player));
    return 1;
}

CMD:dardinero(playerid, params[])
{
    if(sscanf(params, "ud", params[0], params[1])) return SendClientMessage(playerid, -1, "ERROR: /dardinero [PlayerID/Nombre] [Cantidad]");
    if(!IsPlayerConnected(params[0])) return SendClientMessage(playerid, -1, "Jugador desconectado.");

    if(PI[playerid][pi_CASH] < params[1]) return SendClientMessage(playerid, -1, "{e60202}No tienes esa cantidad.");
    else
    {
        GivePlayerCash(playerid, -params[1]);
        GivePlayerCash(params[0], params[1]);

        SendClientMessageEx(playerid, -1, "Le has dado {00ff26}%d$ a {02dee6}%s.", params[1], PI[params[0]][pi_NAME]);
        SendClientMessageEx(params[0], -1, "{02dee6}%s te ha dado {00ff26}%d$.", PI[playerid][pi_NAME], params[1]);
    }

    return 1;
}

CMD:registrarse(playerid, params[])
{
    if(PI[playerid][pi_USER_EXIT]) return SendClientMessage(playerid, -1, "Ya estás registrado.");

    ShowDialog(playerid, DIALOG_REGISTER);
    return 1;
}
