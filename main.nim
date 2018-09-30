import os, osproc, winim, strutils, nre, times

const VERSION = "v1"

echo "tf2-default " & VERSION & " - https://github.com/UnnoTed/tf2-default"

const gamePath: string = "steamapps/common/team fortress 2/tf/"
const gameFiles: seq[string] = @[
  "\\steamapps\\common\\team fortress 2\\hl2.exe",
  "\\steamapps\\common\\team fortress 2\\tf\\",
  "\\steamapps\\common\\team fortress 2\\tf\\bin\\",
  "\\steamapps\\common\\team fortress 2\\tf\\bin\\client.dll",
]

var backupDir: string

proc findSteamPath(): string =
  echo "\n\nFinding steam path..."
  var hProcessSnap: HANDLE = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
  var steamProcID: DWORD
  var entry: PROCESSENTRY32

  if hProcessSnap != INVALID_HANDLE_VALUE:
    entry.dwSize = DWORD(sizeof(PROCESSENTRY32))
    while Process32Next(hProcessSnap, addr entry):
      if startsWith(toLowerAscii($entry.szExeFile), "steam.exe"):
        echo "found steam.exe's process id -> ", entry.th32ProcessID, " = ", $entry.szExeFile
        steamProcID = entry.th32ProcessID
        break

  else:
    quit(0)

  CloseHandle(hProcessSnap)

  var p: Handle = OpenProcess(PROCESS_QUERY_INFORMATION, WINBOOL(false), steamProcID)
  var buf = newWideCString("", 4096)

  GetProcessImageFileNameW(p, cast[LPWSTR](addr buf[0]), DWORD(4096))
  echo "steamExePath: ", $buf

  CloseHandle(p)

  var steamExePath = toLowerAscii($buf)
  var path: string

  if startsWith(steamExePath, "\\device\\"):
    var list: seq[string] = split(steamExePath, "\\")
    list = list[3..(list.len-2)]
    var path = join(list, "\\")
    echo "exe path: ", path

    for device in 'A'..'Z':
      let path: string = device & ":\\" & path
      echo "testing dir: ", path
      if existsDir(path):
        echo "found! ", path
        return path

proc findSteamLibraries(steamPath: string): seq[string] = 
  echo "\n\nFinding steam libraries..."
  var list: seq[string]

  var steamConfig = $readFile(steamPath & "\\config\\config.vdf")

  echo "matching steam libraries..."
  list.add(steamPath)

  var canFind = true
  var start = 0

  while(canFind):
    var m = steamConfig.find(re("\"BaseInstallFolder_[\\d+]\"[\\s]+\"(.*)\""), start)
    if isSome[RegexMatch](m):
      let theMatch = get[RegexMatch](m)
      let dir = theMatch.captures[0]
      let pos = theMatch.captureBounds[0].get().a
      echo "checking if steam library exists ", dir

      if existsDir(dir):
        echo "steam library is valid: ", dir
        list.add(dir)

      start = pos+1
    else:
      canFind = false

  echo "done"
  return list

proc findGameDir(libraries: seq[string]): string =
  echo "\n\nFinding tf2's dir in libraries: ", libraries
  for lib in libraries:
    var found = true
    for gf in gameFiles:
      if contains(lib & gf, ".exe") or contains(lib & gf, ".dll"):
        found = existsFile(lib & gf)
      else:
        found = existsDir(lib & gf)
    if found:
      var gd = lib & "\\steamapps\\common\\team fortress 2\\tf\\"
      echo "found tf2's dir: ", gd
      return gd
  
  return ""

proc backupUserConfig(gameDir: string) =
  echo "\n\nBacking up user's config and custom..."
  if not existsDir(gameDir):
    echo "tf2's dir not found", gameDir
    return

  let date = format(now(), "HH-mm-ss dd-MM-yyyy")
  backupDir = gameDir & "backup_before_default\\" & date

  echo "backup dir is: ", backupDir

  if not existsDir(backupDir):
    createDir(backupDir)

  if existsDir(gameDir & "cfg"):
    moveDir(gameDir & "cfg", backupDir & "\\cfg")

  if existsDir(gameDir & "custom"):
    moveDir(gameDir & "custom", backupDir & "\\custom")
  
  echo "done"

proc disableSteamCloud(steamPath: string) =
  echo "\n\nDisabling steam cloud for TF2"
  var loginUsers = $readFile(steamPath & "\\config\\loginusers.vdf")
  var recentPos = 0

  var m = loginUsers.find(re("\"mostrecent\"[\\s]+\"(1)\""), recentPos)
  if isSome[RegexMatch](m):
    recentPos = get[RegexMatch](m).captureBounds[0].get().a
    loginUsers = loginUsers[0..recentPos]

    var lookForQuote = false
    var closePos = 0
    var openPos = 0
    var open = false

    var steamID: string
    while steamID == "":
      recentPos -= 1
      if loginUsers[recentPos] == '{':
        lookForQuote = true
      elif lookForQuote:
        if loginUsers[recentPos] == '"':
          if open:
            openPos = recentPos+1
            steamID = loginUsers[openPos..closePos]
          elif not open:
            closePos = recentPos-1
            open = true
    
    var id32 = parseInt(steamID) - 76561197960265728
    var userdata = steamPath & "\\userdata\\"
    if not existsDir(userdata & $id32):
      id32 -= 1

    echo "TF2's steam cloud dir: ", userdata & $id32 & "\\440\\remote"
    for f in walkFiles(userdata & $id32 & "\\440\\remote\\*.*"):
      echo "cleaning file: ", f
      writeFile(f, "")
  
  echo "done"


proc validateGameFiles(gameDir: string) =
  var vURL: string = """start "" "steam://validate/440""""
  discard execShellCmd(vURL)

  while true:
    sleep(5000)
    if existsDir(gameDir & "cfg") and existsDir(gameDir & "custom") and existsDir(gameDir & "custom\\workshop") and
      existsFile(gameDir & "cfg\\config_default.cfg") and existsFile(gameDir & "custom\\readme.txt"):
      echo "Found the default config files"
      break
    else:
      echo "Waiting for config files to finish verification and download..."

proc runGame() =
  echo "\n\nLaunching tf2 with \"-novid -default -autoconfig +host_writeconfig +mat_savechanges +quit\""
  echo "Expect tf2 to close as soon as it loads!"
  var vURL: string = """start "" "steam://rungameid/440//-novid -default -autoconfig +host_writeconfig +mat_savechanges +quit""""

  sleep(5000)
  discard execShellCmd(vURL)

##############
##############

var steamPath: string = findSteamPath()
var list: seq[string] = findSteamLibraries(steamPath)
var gameDir: string = findGameDir(list)
backupUserConfig(gameDir)
validateGameFiles(gameDir)
disableSteamCloud(steamPath)
runGame()

echo "\n\nYour old files are at \"", backupDir, "\""
echo "\nif you found any bug please report at https://github.com/UnnoTed/tf2-default or UnnoTed#1497 @ discord."
echo "\n\nPress ENTER to close."

# closes on enter
while true:
  discard readChar(stdin)
  break
