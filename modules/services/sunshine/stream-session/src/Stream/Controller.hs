{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Stream.Controller (main) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (concurrently_)
import Control.Concurrent.MVar
import Control.Exception
import Control.Monad
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import qualified Data.ByteString.Lazy.Char8 as B
import Data.List (find, isInfixOf, isPrefixOf, sortOn)
import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Network.Socket hiding (close)
import qualified Network.Socket as N
import Stream.Model
import System.Directory
import System.Environment
import System.Exit
import System.FilePath
import System.IO
import System.Posix.Files (setFileMode)
import System.Posix.IO (openFd, closeFd, defaultFileFlags, OpenFileFlags(creat), OpenMode(ReadWrite), setLock, LockRequest(WriteLock))
import System.Process
import System.Timeout (timeout)
import Text.Read (readMaybe)

output, streamWorkspace :: String
output = "STREAM"
streamWorkspace = "streaming"

data Monitor = Monitor { monName :: String, monId :: Int, monFocus :: Bool, monWorkspace :: String
                       , monX :: Int, monY :: Int, monWidth :: Int, monHeight :: Int, monRate :: Double }

data Runtime = Runtime { stateFile :: FilePath, saved :: Maybe Snapshot, history :: [String] }

dieIO :: String -> IO a
dieIO = ioError . userError

run :: String -> [String] -> IO String
run executable args = do
  result <- timeout 15000000 (readProcessWithExitCode executable args "")
  case result of
    Just (ExitSuccess, out, _) -> pure out
    Just (_, _, err) -> dieIO (executable ++ " failed: " ++ take 1000 err)
    Nothing -> dieIO (executable ++ " timed out")

ctl :: [String] -> IO ()
ctl args = do
  response <- run "hyprctl" args
  unless (response == "ok\n" || response == "ok") $ dieIO ("hyprctl: " ++ response)

dispatch :: String -> String -> IO ()
dispatch action arg = ctl ["dispatch", action, arg]

query :: String -> (Value -> Parser a) -> IO a
query endpoint parser = do
  response <- run "hyprctl" ["-j", endpoint]
  value <- either dieIO pure (eitherDecode (B.pack response))
  either dieIO pure (parseEither parser value)

monitors :: IO [Monitor]
monitors = query "monitors" $ \v -> parseJSON v >>= mapM (withObject "monitor" $ \o ->
  Monitor <$> o .: "name" <*> o .: "id" <*> o .: "focused"
    <*> (o .: "activeWorkspace" >>= (.: "name")) <*> o .: "x" <*> o .: "y"
    <*> o .: "width" <*> o .: "height" <*> o .: "refreshRate")

windows :: IO [Window]
windows = query "clients" $ \v -> parseJSON v >>= mapM (withObject "window" $ \o ->
  Window <$> o .: "address" <*> o .: "pid" <*> o .: "class" <*> o .: "title"
    <*> (o .: "workspace" >>= (.: "name")) <*> o .: "fullscreen")

workspaces :: IO [(Int, String, String)]
workspaces = query "workspaces" $ \v -> parseJSON v >>= mapM (withObject "workspace" $ \o ->
  (,,) <$> o .: "id" <*> o .: "name" <*> o .: "monitor")

cursor :: IO (Int, Int)
cursor = query "cursorpos" (withObject "cursor" $ \o -> (,) <$> o .: "x" <*> o .: "y")

physical :: [Monitor] -> [Monitor]
physical = sortOn monId . filter ((/= output) . monName)

firstPhysical :: [Monitor] -> IO Monitor
firstPhysical ms = case physical ms of
  [] -> dieIO "No physical monitor available; refusing to guess a restoration target"
  m:_ -> pure m

streamMonitor :: IO Monitor
streamMonitor = monitors >>= maybe (dieIO "STREAM output missing") pure . find ((== output) . monName)

setMode :: Mode -> IO ()
setMode (Mode w h f) = do
  ctl ["keyword", "monitor", output ++ "," ++ show w ++ "x" ++ show h ++ "@" ++ show f ++ ",10000x10000,1"]
  m <- streamMonitor
  unless (monWidth m == w && monHeight m == h && abs (monRate m - fromIntegral f) < 1) $
    dieIO "Hyprland did not apply requested mode"

focusStream :: IO ()
focusStream = do
  dispatch "focusmonitor" output
  dispatch "workspace" ("name:" ++ streamWorkspace)
  m <- streamMonitor
  dispatch "movecursor" (show (monX m + monWidth m `div` 2) ++ " " ++ show (monY m + monHeight m `div` 2))

ensureOutput :: Maybe Snapshot -> IO ()
ensureOutput session = do
  ms <- monitors
  fallback <- firstPhysical ms
  let previous = fromMaybe fallback (find monFocus ms)
  ctl ["keyword", "workspace", "name:streaming,monitor:STREAM,default:true,persistent:true"]
  case find ((== output) . monName) ms of
    Nothing | isJust session -> dieIO "Active session lost its output; refusing to recreate/reset it"
    Nothing -> ctl ["output", "create", "headless", output] >> setMode idleMode
    Just _ -> pure ()  -- Existing output may contain a game, even without controller state.
  m <- streamMonitor
  when (monWorkspace m /= streamWorkspace) $ do
    focusStream
    dispatch "focusmonitor" (monName previous)

persist :: Runtime -> IO ()
persist rt = do
  let tmp = stateFile rt ++ ".tmp"
  B.writeFile tmp (encode (saved rt))
  setFileMode tmp 0o600
  renameFile tmp (stateFile rt)

-- Save before external effects: a failure leaves an explicit recovery state,
-- never an apparently Idle session with forgotten windows.
store :: MVar Runtime -> (Runtime -> IO Runtime) -> IO ()
store variable operation = modifyMVar_ variable $ \rt -> operation rt

putSnapshot :: Runtime -> Maybe Snapshot -> IO Runtime
putSnapshot rt snapshot = do
  let new = rt { saved = snapshot }
  persist new
  pure new

prepare :: MVar Runtime -> Mode -> Bool -> IO ()
prepare variable requested steam = do
  snapshot <- modifyMVar variable $ \rt -> do
    when (isJust (saved rt)) $ dieIO "Session already active/recovering; resume or run stream-session stop"
    ensureOutput Nothing
    existing <- windows
    when (any ((== streamWorkspace) . workspace) existing) $
      dieIO "Unowned windows exist on STREAM; move/close them before starting a new session"
    ms <- monitors
    fallback <- firstPhysical ms
    let previous = fromMaybe fallback (find monFocus (physical ms))
    point <- cursor
    baselinePids <- mapMaybe readMaybe <$> listDirectory "/proc"
    let s = Snapshot (monName previous) (monWorkspace previous) point existing baselinePids [] steam requested Preparing
    rt' <- putSnapshot rt (Just s)
    pure (rt', s)
  setMode requested
  focusStream
  store variable $ \rt -> putSnapshot rt (Just snapshot { phase = Active })

place :: Window -> IO ()
place w = do
  when (workspace w /= streamWorkspace) $
    dispatch "movetoworkspacesilent" ("name:streaming,address:" ++ address w)
  when (fullscreen w /= 2) $ do
    dispatch "focuswindow" ("address:" ++ address w)
    dispatch "fullscreenstate" "2 2"

restoreFocus :: Snapshot -> IO ()
restoreFocus s = do
  ms <- monitors
  fallback <- firstPhysical ms
  let target = fromMaybe fallback (find ((== returnMonitor s) . monName) (physical ms))
  dispatch "focusmonitor" (monName target)
  when (monName target == returnMonitor s) $ do
    dispatch "workspace" ("name:" ++ returnWorkspace s)
    let (x,y) = returnCursor s
    dispatch "movecursor" (show x ++ " " ++ show y)

-- Steam must not be a child in the controller/Sunshine service cgroup: a
-- controller restart must never kill a running game or Steam.
steamUri :: String -> IO ()
steamUri uri = do
  executable <- findExecutable "steam" >>= maybe (dieIO "steam executable missing") pure
  void $ run "systemd-run" ["--user", "--collect", "--quiet", "--property=PartOf=graphical-session.target", "--", executable, uri]

stopSession :: MVar Runtime -> IO ()
stopSession variable = do
  session <- saved <$> readMVar variable
  forM_ session $ \s -> do
    store variable $ \rt -> putSnapshot rt (Just s { phase = Closing })
    current <- windows
    -- Never infer game ownership from a recovery scan. Unknown games block cleanup.
    let unknown = filter (\w -> isGame w && workspace w == streamWorkspace
                   && not (any (sameWindow w) (ownedGames s))) current
    unless (null unknown) $ dieIO "Unowned game on STREAM; close it manually before retrying stop"
    forM_ (ownedGames s) $ \owned ->
      forM_ (find (sameWindow owned) current) $ \w -> dispatch "closewindow" ("address:" ++ address w)
    let waitGames 0 = dieIO "Game did not close gracefully; output preserved. Save/close it and retry stop."
        waitGames n = do
          remaining <- windows
          if any (\w -> any (sameWindow w) (ownedGames s)) remaining
            then threadDelay 500000 >> waitGames (n-1 :: Int)
            else pure ()
    waitGames 30
    when (wantsSteam s && not (any isBigPicture (originalWindows s))) $
      steamUri "steam://close/bigpicture"
    -- Allow Steam's asynchronous close-Big-Picture request to settle.
    when (wantsSteam s) $ threadDelay 1000000
    remaining <- windows
    forM_ (filter ((== streamWorkspace) . workspace) remaining) $ \w -> do
      let original = find (sameWindow w) (originalWindows s)
          destination = maybe (returnWorkspace s) workspace original
          full = maybe 0 fullscreen original
      dispatch "movetoworkspacesilent" ("name:" ++ destination ++ ",address:" ++ address w)
      dispatch "focuswindow" ("address:" ++ address w)
      dispatch "fullscreenstate" (show full ++ " " ++ show full)
    restoreFocus s
    setMode idleMode
    store variable $ \rt -> putSnapshot rt Nothing

observe :: MVar Runtime -> Maybe String -> IO ()
observe variable opened = do
  ms <- monitors
  fallback <- firstPhysical ms
  ws <- workspaces
  -- No other workspace may remain bound to the virtual monitor.
  forM_ ws $ \(_,name,monitor) -> when (monitor == output && name /= streamWorkspace) $
    dispatch "moveworkspacetomonitor" ("name:" ++ name ++ " " ++ monName fallback)
  stream <- streamMonitor
  when (monWorkspace stream /= streamWorkspace) $ do
    point <- cursor
    dispatch "focusmonitor" output
    dispatch "workspace" "name:streaming"
    dispatch "focusmonitor" (monName (fromMaybe fallback (find monFocus ms)))
    dispatch "movecursor" (show (fst point) ++ " " ++ show (snd point))
  active <- query "activeworkspace" (withObject "workspace" (.: "name"))
  store variable $ \rt -> pure $ if active /= streamWorkspace && not ("special" `isPrefixOf` active)
    then rt { history = take 32 (active : filter (/= active) (history rt)) } else rt
  session <- saved <$> readMVar variable
  forM_ session $ \s -> when (phase s == Active && wantsSteam s) $ do
    current <- windows
    let newlyOpened = maybe [] (\a -> filter ((== a) . address) current) opened
        claimed = foldl claimGame s newlyOpened
    when (claimed /= s) $ store variable $ \rt -> putSnapshot rt (Just claimed)
    forM_ current $ \w -> when (isBigPicture w || any (sameWindow w) (ownedGames claimed)) $ place w

navigate :: MVar Runtime -> String -> IO ()
navigate variable action | action `elem` ["steam", "steam-pull"] = do
  session <- saved <$> readMVar variable
  if isJust session then focusStream else
    void $ run "hyprland_show_app" (["-a", "steam", "-c", "steam", "-w", "Steam"] ++ ["-p" | action == "steam-pull"])
navigate _ "window-previous" = do
  clients <- query "clients" $ \v -> parseJSON v >>= mapM (withObject "window" $ \o ->
    (,,) <$> o .: "address" <*> (o .: "workspace" >>= (.: "name")) <*> (o .:? "focusHistoryID" .!= (-1 :: Int)))
  active <- query "activewindow" (withObject "window" $ \o -> o .:? "address" .!= "")
  case sortOn (\(_,_,i) -> i) (filter (\(a,w,i) -> a /= active && w /= streamWorkspace && i >= 0) clients) of
    (a,_,_):_ -> dispatch "focuswindow" ("address:" ++ a)
    [] -> pure ()
navigate variable action = do
  ms <- monitors
  fallback <- firstPhysical ms
  let targets = physical ms
      focused = fromMaybe fallback (find monFocus ms)
      next = case dropWhile ((/= monName focused) . monName) targets of
        _:m:_ -> m
        _ -> fallback
  if action `elem` ["monitor", "window", "workspace-monitor"]
    then case action of
      "monitor" -> dispatch "focusmonitor" (monName next)
      "window" -> when (monName focused /= output) $ dispatch "movewindow" ("mon:" ++ monName next)
      _ -> when (monName focused /= output) $ dispatch "moveworkspacetomonitor" ("name:" ++ monWorkspace focused ++ " " ++ monName next)
    else do
      ws <- filter (\(_,name,m) -> m /= output && name /= streamWorkspace && not ("special" `isPrefixOf` name)) <$> workspaces
      past <- history <$> readMVar variable
      let current = monWorkspace focused
          available = [name | (_,name,_) <- ws]
          local = [name | (_,name,m) <- sortOn (\(i,_,_) -> i) ws, m == monName focused]
          cycleTarget = case dropWhile (/= current) (local ++ take 1 local) of
            _:n:_ -> Just n
            _ -> Nothing
          target = if action == "previous" then find (\n -> n /= current && n `elem` available) past else cycleTarget
      unless (action `elem` ["previous", "cycle"]) $ dieIO "Unknown navigation action"
      forM_ target $ \name -> dispatch "workspace" ("name:" ++ name)

handleRequest :: MVar Runtime -> Request -> IO String
handleRequest rt command = do
  case command of
    Prepare m steam -> do
      either dieIO (const $ pure ()) (validateMode (map show [width m,height m,fps m]))
      prepare rt m steam
    Launch -> do
      s <- saved <$> readMVar rt
      case s of
        Just session | phase session == Active && wantsSteam session -> do
          focusStream
          steamUri "steam://open/bigpicture"
        _ -> dieIO "No active Steam session"
    Stop -> stopSession rt
    Connected -> do
      s <- saved <$> readMVar rt
      when (maybe False ((== Active) . phase) s) focusStream
    Disconnected -> pure ()
    Navigate action -> navigate rt action
    Observe opened -> observe rt opened
    Status -> pure ()
  snapshot <- saved <$> readMVar rt
  pure $ case snapshot of
    Nothing -> "Idle"
    Just s -> show (phase s) ++ " " ++ show (mode s) ++ "; owned game windows=" ++ show (length (ownedGames s))

-- Only synchronous operational failures are contained. Cancellation still works.
safely :: IO a -> IO (Either String a)
safely action = catches (Right <$> action)
  [ Handler $ \(e :: IOException) -> pure (Left (displayException e)) ]

withUnix :: FilePath -> (Handle -> IO a) -> IO a
withUnix path action = bracket (socket AF_UNIX Stream defaultProtocol) N.close $ \s -> do
  connect s (SockAddrUnix path)
  bracket (socketToHandle s ReadWriteMode) hClose action

request :: FilePath -> Request -> IO String
request path command = do
  response <- timeout 90000000 $ withUnix path $ \h -> do
    B.hPutStrLn h (encode command)
    hFlush h
    hGetLine h
  case response of
    Nothing -> dieIO "Controller request timed out; session state retained"
    Just line | "OK " `isPrefixOf` line -> pure (drop 3 line)
    Just line -> dieIO line

-- Journal is deliberately a version-specific adapter, not authoritative cleanup.
-- Do/undo hooks own lifetime; journal connection messages can only restore focus.
journal :: (Request -> IO ()) -> IO ()
journal send = bracket
  (createProcess (proc "journalctl" ["--user", "-u", "sunshine.service", "-f", "-n", "0", "-o", "cat", "--no-pager"]) { std_out = CreatePipe })
  cleanupProcess $ \(_, out, _, _) -> case out of
    Nothing -> dieIO "No journal pipe"
    Just h -> forever $ do
      line <- hGetLine h
      when ("]: Info: CLIENT CONNECTED" `isInfixOf` line) (send Connected)
      -- Disconnect intentionally produces no command or state mutation.

hyprEvents :: FilePath -> (Request -> IO ()) -> IO ()
hyprEvents path send = withUnix path $ \h -> forever $ do
  line <- hGetLine h
  if "openwindow>>" `isPrefixOf` line
    then send (Observe (Just ("0x" ++ takeWhile (/= ',') (drop 12 line))))
    else when (any (`isPrefixOf` line) ["workspace>>", "focusedmon>>", "movewindow>>", "windowtitle>>"]) $
      send (Observe Nothing)

daemon :: FilePath -> FilePath -> IO ()
daemon directory hyprSocket = do
  let path = directory </> "control.sock"
      file = directory </> "session.json"
  exists <- doesFileExist file
  session <- if exists then B.readFile file >>= either (dieIO . ("Invalid recovery state: " ++)) pure . eitherDecode else pure Nothing
  rt <- newMVar (Runtime file session [])
  serial <- newMVar ()
  -- Preparing/Closing snapshots are not silently promoted. Explicit stop retries cleanup.
  ensureOutput session
  let execute command = withMVar serial $ \_ -> safely (handleRequest rt command)
      send command = execute command >>= either (hPutStrLn stderr) (const $ pure ())
  oldSocket <- doesPathExist path
  when oldSocket (removeFile path)
  bracket (socket AF_UNIX Stream defaultProtocol) N.close $ \server -> do
    bind server (SockAddrUnix path)
    setFileMode path 0o600
    listen server 8
    void $ run "systemd-notify" ["--ready"]
    let serve = forever $ do
          result <- safely $ bracket (fst <$> accept server) N.close $ \client ->
            bracket (socketToHandle client ReadWriteMode) hClose $ \h -> do
              line <- timeout 5000000 (hGetLine h)
              response <- case line of
                Nothing -> pure (Left "Request read timeout")
                Just text -> case eitherDecode (B.pack text) of
                  Left err -> pure (Left err)
                  Right command -> execute command
              hPutStrLn h (either ("ERROR " ++) ("OK " ++) response)
              hFlush h
          either (hPutStrLn stderr) (const $ pure ()) result
    concurrently_ serve (concurrently_ (journal send) (hyprEvents hyprSocket send))

main :: IO ()
main = do
  args <- getArgs
  runtime <- getEnv "XDG_RUNTIME_DIR"
  signature <- getEnv "HYPRLAND_INSTANCE_SIGNATURE"
  when (null signature || any (`elem` ("/\\" :: String)) signature) $ dieIO "Invalid Hyprland instance"
  let directory = runtime </> "stream-session" </> signature
      path = directory </> "control.sock"
      hyprSocket = runtime </> "hypr" </> signature </> ".socket2.sock"
  createDirectoryIfMissing True directory
  setFileMode directory 0o700
  case args of
    ["daemon"] -> bracket (openFd (directory </> "daemon.lock") ReadWrite defaultFileFlags { creat = Just 0o600 }) closeFd $ \fd -> do
      setLock fd (WriteLock, AbsoluteSeek, 0, 0)
      daemon directory hyprSocket
    _ -> do
      command <- case args of
        "prepare":rest -> do
          values <- mapM getEnv ["SUNSHINE_CLIENT_WIDTH", "SUNSHINE_CLIENT_HEIGHT", "SUNSHINE_CLIENT_FPS"]
          m <- either dieIO pure (validateMode values)
          unless (rest `elem` [[], ["--steam"]]) $ dieIO "Invalid prepare arguments"
          pure (Prepare m (rest == ["--steam"]))
        ["launch"] -> pure Launch
        ["stop"] -> pure Stop
        ["status"] -> pure Status
        ["nav", action] -> pure (Navigate action)
        _ -> dieIO "Usage: stream-session daemon|prepare [--steam]|launch|stop|status|nav ACTION"
      request path command >>= putStrLn
