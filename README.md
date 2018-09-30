### tf2-default

It's a helper tool to reset tf2 to it's default settings... ( https://github.com/mastercoms/mastercomfig#clean-up )

list of actions:
  1. finds tf2's dir automatically
  2. moves `cfg` & `custom` dir to a backup dir at `/tf/backup_before_default/`
  3. verify tf2's files
  4. disable current steam user's steam cloud for tf2 by cleaning the files at `STEAM_FOLDER/userdata/USER_ID/440/remote/cfg`
  5. runs the game with `-novid -default -autoconfig +host_writeconfig +mat_savechanges +quit`
  6. done


download at [releases](https://github.com/UnnoTed/tf2-default/releases/latest)
