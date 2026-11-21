// botcams: give every bot the camera of the pro it is named after.
//
// Watching a career match, the player view and the goal replays use the watched
// car's own camera settings, and a bot has the game's defaults. This reads
// %APPDATA%\rl-career-hub\botswap\cameras.txt (written by cameras.py, which the plugin
// starts by itself when the list is missing or a week old) and sets
// them on every player of the match, every two seconds while a match is on:
//
//     * 110 100 -3.0 270 0.35 4.00 1.40        everyone not listed
//     atow 110 100 -3.0 270 0.40 4.20 1.40     name, lower case, letters and digits only
//
// Console: botcams_apply (apply now), botcams_enabled 0|1, botcams_ballcam 0|1 (bots in ball cam),
// botcams_tactic_keys 0|1, botcams_tactic_down_key N, botcams_tactic_up_key M (hub tactics off 1 and 2).
// Build: build.bat beside this file.

#include "bakkesmod/plugin/bakkesmodplugin.h"
#include "bakkesmod/wrappers/GameObject/CameraSettingsActorWrapper.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cctype>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <sstream>
#include <string>

class BotCams : public BakkesMod::Plugin::BakkesModPlugin
{
public:
    void onLoad() override;
    void apply(bool reload, bool log);
    void tick();
    void moveTacticKeys();

private:
    std::map<std::string, ProfileCameraSettings> cameras;
};

BAKKESMOD_PLUGIN(BotCams, "Pro cameras for bots", "1.0", PLUGINTYPE_FREEPLAY)

static std::string slug(const std::string& name)
{
    std::string out;
    for (unsigned char c : name)
        if (std::isalnum(c)) out += static_cast<char>(std::tolower(c));
    return out;
}

static std::map<std::string, ProfileCameraSettings> readCameras()
{
    std::map<std::string, ProfileCameraSettings> cameras;
    const char* appdata = std::getenv("APPDATA");
    if (!appdata) return cameras;
    std::ifstream file(std::string(appdata) + "\\rl-career-hub\\botswap\\cameras.txt");
    std::string line;
    while (std::getline(file, line))
    {
        std::istringstream in(line);
        std::string key;
        ProfileCameraSettings c{};
        if (in >> key >> c.FOV >> c.Height >> c.Pitch >> c.Distance >> c.Stiffness >> c.SwivelSpeed >> c.TransitionSpeed)
            cameras[key] = c;
    }
    return cameras;
}

// Keeps cameras.txt current without the player doing anything: when it is missing or a
// week old, run cameras.py with the Python the hub ships, hidden, in the background.
// cameras.py itself refuses a broken download and keeps the old list.
static void refreshCameraList()
{
    namespace fs = std::filesystem;
    const char* appdata = std::getenv("APPDATA");
    const char* local = std::getenv("LOCALAPPDATA");
    if (!appdata || !local) return;
    fs::path folder = fs::path(appdata) / "rl-career-hub" / "botswap";
    fs::path list = folder / "cameras.txt";
    fs::path script = folder / "cameras.py";
    fs::path python = fs::path(local) / "Programs" / "RL Career Hub" / "resources" / "python" / "python.exe";
    std::error_code ec;
    if (!fs::exists(script, ec) || !fs::exists(python, ec)) return;
    if (fs::exists(list, ec) && fs::file_time_type::clock::now() - fs::last_write_time(list, ec) < std::chrono::hours(24 * 7)) return;
    std::wstring cmd = L"\"" + python.wstring() + L"\" \"" + script.wstring() + L"\" --refresh";
    STARTUPINFOW si{ sizeof(si) };
    PROCESS_INFORMATION pi{};
    if (CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW | DETACHED_PROCESS,
                       nullptr, folder.wstring().c_str(), &si, &pi)) {
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
    }
}

// A bind string without its "rlcareer_tactic ..." commands ("default_down; rlcareer_tactic up" -> "default_down").
static std::string withoutTactic(const std::string& bind)
{
    std::string out, part;
    std::istringstream in(bind);
    while (std::getline(in, part, ';')) {
        part.erase(0, part.find_first_not_of(' '));
        part.erase(part.find_last_not_of(' ') + 1);
        if (part.empty() || part.rfind("rlcareer_tactic", 0) == 0) continue;
        out += (out.empty() ? "" : "; ") + part;
    }
    return out;
}

// The hub binds its tactics to 1 and 2, which also switch the spectator's view to a
// player: each press moved both. Its plugin puts them back on 1/2, so this runs at load
// and every kickoff: tactics leave 1 and 2 (their other commands stay) for two keys of
// the player's choice, N and M by default.
void BotCams::moveTacticKeys()
{
    if (!cvarManager->getCvar("botcams_tactic_keys").getBoolValue()) return;
    for (const char* key : { "One", "Two" }) {
        std::string bind = cvarManager->getBindStringForKey(key);
        if (bind.find("rlcareer_tactic") == std::string::npos) continue;
        std::string rest = withoutTactic(bind);
        if (rest.empty()) cvarManager->removeBind(key);
        else cvarManager->setBind(key, rest);
    }
    std::string down = cvarManager->getCvar("botcams_tactic_down_key").getStringValue();
    std::string up = cvarManager->getCvar("botcams_tactic_up_key").getStringValue();
    if (!down.empty() && cvarManager->getBindStringForKey(down) != "rlcareer_tactic down")
        cvarManager->setBind(down, "rlcareer_tactic down");
    if (!up.empty() && cvarManager->getBindStringForKey(up) != "rlcareer_tactic up")
        cvarManager->setBind(up, "rlcareer_tactic up");
}

void BotCams::onLoad()
{
    refreshCameraList();  // the new list is read at the next kickoff
    cvarManager->registerCvar("botcams_tactic_keys", "1", "Move the hub's tactic keys off 1 and 2 (spectator views)", true, true, 0, true, 1);
    cvarManager->registerCvar("botcams_tactic_down_key", "N", "Key for a more defensive tactic", true);
    cvarManager->registerCvar("botcams_tactic_up_key", "M", "Key for a more attacking tactic", true);
    // After the hub's plugin has set its own binds at load.
    gameWrapper->SetTimeout([this](GameWrapper*) { moveTacticKeys(); }, 5.0f);
    cvarManager->registerCvar("botcams_enabled", "1", "Give bots the camera of the pro they are named after", true, true, 0, true, 1);
    cvarManager->registerCvar("botcams_ballcam", "1", "Bots play in ball cam (seen when spectating their view)", true, true, 0, true, 1);
    cvarManager->registerNotifier("botcams_apply", [this](std::vector<std::string>) { apply(true, true); },
                                  "Apply the pro cameras to the players of this match now", PERMISSION_ALL);
    // Each kickoff: read the file again, it may have been refreshed since the game started.
    gameWrapper->HookEvent("Function GameEvent_Soccar_TA.Countdown.BeginState", [this](std::string) {
        gameWrapper->SetTimeout([this](GameWrapper*) { apply(true, true); moveTacticKeys(); }, 1.0f);
    });
    tick();
}

// The kickoff alone comes too late: the cars are on screen well before the first
// countdown, and a car that respawns or joins must not fall back to the defaults.
void BotCams::tick()
{
    apply(false, false);
    gameWrapper->SetTimeout([this](GameWrapper*) { tick(); }, 2.0f);
}

void BotCams::apply(bool reload, bool log)
{
    if (!cvarManager->getCvar("botcams_enabled").getBoolValue()) return;
    if (gameWrapper->IsInOnlineGame()) return;  // real players online keep their own cameras
    ServerWrapper game = gameWrapper->GetCurrentGameState();
    if (!game) return;
    if (reload || cameras.empty()) cameras = readCameras();
    if (cameras.empty()) return;

    int set = 0;
    auto pris = game.GetPRIs();
    for (int i = 0; i < pris.Count(); i++)
    {
        PriWrapper pri = pris.Get(i);
        // The person at the keyboard keeps their own camera, playing or watching.
        if (!pri || pri.IsLocalPlayerPRI() || pri.IsSpectator()) continue;
        auto found = cameras.find(slug(pri.GetPlayerName().ToString()));
        if (found == cameras.end()) found = cameras.find("*");
        if (found == cameras.end()) continue;
        pri.SetCameraSettings(found->second);
        // The game reads the settings off this actor where a player has one.
        CameraSettingsActorWrapper actor = pri.GetPersistentCamera();
        if (actor) {
            actor.SetProfileSettings(found->second);
            // Ball cam on, as pros play: what a spectator sees in this player's view.
            // The spectator's own camera (free, RLCS view...) is never touched.
            if (cvarManager->getCvar("botcams_ballcam").getBoolValue()) actor.SetUsingSecondaryCamera(true);
        }
        set++;
    }
    if (log) cvarManager->log("botcams: camera set on " + std::to_string(set) + " players");
}
