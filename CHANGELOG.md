0.16.5:
- fix: bots no longer catch or carry corpses (every enemy corpse has its own carry id, a thrown guard was caught and vanished); applies to catching and monkeepers_mode

0.16.4:
- fix: bots in stealth (still cool) have their weapon hidden again, only downed or alerted bots keep it visible

0.16.3:
- fix: crash on quit to desktop (HUD updates on destroyed bot panels)

0.16.2:
- defaults: bots throw grenades, wait mode 4

0.16.1:
- the spring mine (betty) is back as bot throwable, last in the list

0.16.0:
- Bot weapons: Geco and Kar98k as primary, secondary choice (Luger/M1911), class based defaults, M1911 hand offset
- downed bots keep their weapon visible
- Monkeepers: a thrown bag that lands in a secure area still makes a route, pickup objective split out, collecting bots count as carrying

0.15.1:
- guard carry unit removal against a destroyed carrier

0.15.0:
- bots keep their bag for short jobs (flare, flee, pickup, revive)
- flares preempt bag jobs
- wait mode survives jobless state

0.14.1:
- Comm wheel: human peers are ignored as shout target
- reset restores the defaults
- the bot mode is always resynced
- uses blt.pcall

0.14.0:
- Monkeepers: bots go back to following, carry job icon
- limited bot grenades with pickups

0.13.3:
- spring mine removed from the bot grenades, saved selections are migrated
- added icon

0.13.2:
- bots release secured bags they still carry

0.13.1:
- bots do not catch thrown flak shell pallets and tank shells

0.13.0:
- bots carry bags along the routes players throw them (monkeepers_mode)
- bots drop carried bags at mission end (replaces bots_secure_carried)
- bots put out spotter flares, 5% of the time by pissing on them
- bots are slowed down while carrying (option bots_slowed_by_carry)
- bots catch every thrown bag, except corpses, ladder, parachute and turret

0.12.1:
- auto updates will be pulled directly from git, instead of mws

0.12.0
- Follow icon: bots show who they are following on their teammate panel and name label.
  The icon uses the colour of the followed character (WolfgangHUD's colorize mode is
  respected if installed, otherwise the game's player colours)
- The icon hides while a bot is down and comes back once it is revived

0.11.1:
- Respawn timer: dead bots show a countdown to their respawn next to their name on the teammate panel
  ("..." while the respawn is on hold, e.g. in stealth)
- "No unnecessary revives" is now enabled by default
- A bot that goes down or dies loses its wait mode and its icons, a revived bot starts over with the normal follow behaviour
- Taking over a revive from a bot: the bot stopped for a moment and then resumed right away.
  It now stays away as long as you are reviving
- Bot wait mode / revive icons stayed on the HUD after the bot went down or died
- Bots that were stepping out of a grenade and got downed in the process had their old order restored
- Bots no longer run away from their own thrown grenade right after throwing it
- Respawn timer could error on non-integer values

0.11.0:
- Wait modes: bots can now wait in two ways when loud
  - Stationary: holds the spot, never takes cover, returns to it after a fight
  - Use cover: takes cover near the spot, returns to it once healthy (50%+)
- New option "Wait modes": stationary > cover, cover > stationary, only stationary or only cover
  - comm wheel "wait" and the quick shout toggle cycle through them
    (quick shout: follow > first mode > second mode > follow)
  - bots waiting stationary from stealth switch to the first loud mode on alarm
  - host setting, applies to all players
- Wait mode icon (stationary / use cover) on the bot's teammate panel and name label
- Wait mode no longer lets bots drift away when taking cover
- Revive icon on bots on their way to revive someone: white = somebody else, red = you
- Bots avoid grenades: they step out of the blast radius of live grenades
  (yours, your team's and the enemy's) and out of fires, and return to what they
  were doing afterwards. New option "Bots avoid grenades" (default on)
- Grenades (opt-in): bots now only throw at groups of enemies and never when a
  teammate, a player or the bot itself would be inside the blast radius.
  The throwable is selectable per bot (Concrete Grenade, Spring Mine, 343d, Mills, M24)
- "No unnecessary revives": reworked. Bots no longer take a revive on someone who
  is already being revived (also when a client revives) and stop when you start,
  without instantly retrying. Moved out of the experimental block
- Options menu: removed the "Experimental" header, "Grenades" now sits in the new
  "Bot Grenades" block

0.10.2:
- netcode hotfix

0.10.1
- crashfix when shouted target is gone
- fixed grenade kills ownership

0.10.0
- improved network code
- added german translation

0.9.0
- added option for bot primary weapons

0.8.0
- improved handshake, fixed announce_player_uses_mod as server
- implemented bot carry update routine with air/ground-ray check, instead of a timeout

0.7.0
- updated for blt2.0

0.6.4
- crashfix when shouting at teammates

0.6.3
- fixed locale: Bots cry out loud, at 20% health
- added blt 1.3 menu icon

v0.6.2
- slightly improved options texts
- double_bot_health option is now synced, to fix bot health bars on clients (cant fix unmodded clients remotely tho)
- added option to 'Announce players using the mod' locally

v0.6.1
- fixed long dist revive calls when downed
- improved logging when bot shouts get skipped

v0.6
- reworked shout commands system, listening for spoken sounds, therefore now also works with comm wheels of un-modded clients.
- added chat messages (optional) when shouting using long range Interact/F, just as in the comm wheel by default.
- added options for controls shift+F and the follow/wait F-toggle.
- added bot defend_area mode for loud (call wait).
- bots do now crouch in stealth
- general code improvements

0.5.1:
- added strong back option
- added missing loot to be carryable (cigar crates etc)

0.5:
- added full compat to 'competent bots': when it's installed, it gets higher prio for offline mode and still applies it's reduced falloff damage.
- the carry system for bots is now entirely rewritten, including stacking and netcode.
(when clients have the mod too, they can even use shout functions and get ui elements for the carry amounts.
everything else works for unmodded clients as well.)
- added hud elements for carry weight
- added shout commands for follow/wait in stealth
- complete netcode for the carry/wait systems

0.4:
- fixed ai dropping bags when being replaced by a player

0.3:
- U25 crash fix 

0.2:
- fixed grenade throwing option (by thetrashmanns)

0.1:
- fixed xp screen
- removed obsolete codes (bots respawning, bullet-mask changes)
- added menu
- disabled some of the rather wonky features by default
