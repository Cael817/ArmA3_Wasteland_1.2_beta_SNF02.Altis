// ******************************************************************************************
// * This project is licensed under the GNU Affero GPL v3. Copyright © 2014 A3Wasteland.com *
// ******************************************************************************************
//@file Version: 1.1
//@file Name: init.sqf
//@file Author: [404] Deadbeat, [GoT] JoSchaap, AgentRev, [KoS] Bewilderbeest
//@file Created: 20/11/2012 05:19
//@file Description: The client init.

if (isDedicated) exitWith {};

if (!isServer) then
{
	waitUntil {!isNil "A3W_network_compileFuncs"};
};

waitUntil {!isNil "A3W_serverSetupComplete"};

[] execVM "client\functions\bannedNames.sqf";

showPlayerIcons = true;
mutexScriptInProgress = false;
respawnDialogActive = false;
groupManagmentActive = false;
pvar_PlayerTeamKiller = objNull;
doCancelAction = false;

pvar_PlayerTeamKilled = objNull; //Cael817, Bounty from GoT
pvar_PlayerTKPrevBounty = 0; //Cael817, Bounty from GoT
firstspawn = 1; //Cael817, From GoT
//player setVariable ["respawnDialogActive", false, true]; //Cael817, Dont remember what this (fix) was for
player setVariable ["tempVehicleSpawn", 1, true]; //Cael817, Allow the player to spawn a quad or boat

//Initialization Variables
playerCompiledScripts = false;
playerSetupComplete = false;

waitUntil {!isNull player};
waitUntil {time > 0.1};

removeAllWeapons player;
player switchMove "";

// initialize actions and inventory
"client\actions" call mf_init;
"client\inventory" call mf_init;
"client\items" call mf_init;

//Call client compile list.
call compile preprocessFileLineNumbers "client\functions\clientCompile.sqf";

//Stop people being civ's.
if !(playerSide in [BLUFOR,OPFOR,INDEPENDENT]) exitWith
{
	endMission "LOSER";
};

//Setup player events.
if (!isNil "client_initEH") then { player removeEventHandler ["Respawn", client_initEH] };
player addEventHandler ["Respawn", { _this spawn onRespawn }];
player addEventHandler ["Killed", { _this spawn onKilled }];

A3W_scriptThreads pushBack execVM "client\functions\evalManagedActions.sqf";

pvar_playerRespawn = [player, objNull];
publicVariableServer "pvar_playerRespawn";

//Player setup
player call playerSetupStart;

// Deal with money here
_baseMoney = ["A3W_startingMoney", 100] call getPublicVar;
player setVariable ["cmoney", _baseMoney, true];

//Cael817, Set initial bounty
_baseBounty = ["A3W_startingBounty", 150] call getPublicVar;
player setVariable ["cbounty", _baseBounty, true];
//Cael817,End

// Player saving - load data
if (["A3W_playerSaving"] call isConfigOn) then
{
	call compile preprocessFileLineNumbers "persistence\client\players\setupPlayerDB.sqf";
	call fn_requestPlayerData;

	waitUntil {!isNil "playerData_loaded"};

	A3W_scriptThreads pushBack ([] spawn
	{
		scriptName "savePlayerLoop";

		// Save player every 60s
		while {true} do
		{
			sleep 60;
			call fn_savePlayerData;
		};
	});
};

if (isNil "playerData_alive") then
{
	player call playerSetupGear;
};

player call playerSetupEnd;

diag_log format ["Player starting with $%1", (player getVariable ["cmoney", 0]) call fn_numToStr];

[] execVM "territory\client\hideDisabledTerritories.sqf";

// Territory system enabled?
if (count (["config_territory_markers", []] call getPublicVar) > 0) then
{
	A3W_fnc_territoryActivityHandler = "territory\client\territoryActivityHandler.sqf" call mf_compile;
	[] execVM "territory\client\setupCaptureTriggers.sqf";
};

//Setup player menu scroll action.
//[] execVM "client\clientEvents\onMouseWheel.sqf";

//Setup Key Handler
waitUntil {!isNull findDisplay 46};
(findDisplay 46) displayAddEventHandler ["KeyDown", onKeyPress];
(findDisplay 46) displayAddEventHandler ["KeyUp", onKeyRelease];

call compile preprocessFileLineNumbers "client\functions\setupClientPVars.sqf";

//client Executes
A3W_scriptThreads pushBack execVM "client\systems\hud\playerHud.sqf";

if (["A3W_survivalSystem"] call isConfigOn) then
{
	execVM "client\functions\initSurvival.sqf";
};

[] spawn
{
	[] execVM "client\functions\createGunStoreMarkers.sqf";
	[] execVM "client\functions\createGeneralStoreMarkers.sqf";
	[] execVM "client\functions\createVehicleStoreMarkers.sqf";
};

[] spawn playerSpawn;

A3W_scriptThreads pushBack execVM "addons\fpsFix\vehicleManager.sqf";
A3W_scriptThreads pushBack execVM "addons\Lootspawner\LSclientScan.sqf";
[] execVM "client\functions\drawPlayerIcons.sqf";
[] execVM "addons\far_revive\FAR_revive_init.sqf";
[] execVM "addons\camera\functions.sqf";
[] execVM "addons\UAV_Control\functions.sqf";

[] execVM "addons\water_edge\functions.sqf"; //Cael817, water_edge addon from micovery, maybe not needed any more?
[] execVM "addons\AUXOPS\init.sqf"; //Cael817, Init AUXOPS

call compile preprocessFileLineNumbers "client\functions\generateAtmArray.sqf";
[] execVM "client\functions\drawPlayerMarkers.sqf";

// update player's spawn beacon
{
	if (_x getVariable ["ownerUID",""] == getPlayerUID player) then
	{
		_x setVariable ["ownerName", name player, true];
		_x setVariable ["side", playerSide, true];
	};
} forEach pvar_spawn_beacons;

{ _x call A3W_fnc_setupAntiExplode } forEach allMissionObjects "Air";
{ _x call A3W_fnc_setupAntiExplode } forEach allMissionObjects "LandVehicle"; //Cael817, Changed "UGV_01_base_F" to "LandVehicle"
{ _x call A3W_fnc_setupAntiExplode } forEach allMissionObjects "Ship"; //Cael817, Added ships too

{
	{
		if (!isPlayer _x) then
		{
			_x setName ["AI","",""];
		};
	} forEach crew _x;
} forEach allUnitsUAV;
