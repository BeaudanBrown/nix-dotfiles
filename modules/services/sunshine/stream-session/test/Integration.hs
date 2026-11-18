{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- Black-box acceptance tests. This executable doubles as fake OS commands via
-- symlinks; requests and fixtures deliberately do not use production model types.
module Main where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async
import Control.Concurrent.MVar
import Control.Exception
import Control.Monad
import Data.Aeson
import qualified Data.ByteString.Lazy.Char8 as B
import Data.List (find, isInfixOf, isPrefixOf)
import Data.Maybe (fromMaybe)
import GHC.Generics (Generic)
import Network.Socket hiding (close)
import qualified Network.Socket as N
import System.Directory
import System.Environment
import System.FilePath
import System.IO
import System.Posix.IO
import System.Posix.Signals
import System.Process
import System.Timeout

-- Fixture state is independent of the controller's JSON representation.
data Screen = Screen { screen :: String, ident :: Int, focused :: Bool, size :: (Int,Int,Int), desk :: String }
  deriving (Eq, Show, Generic, ToJSON, FromJSON)
data Client = Client { addr :: String, processId :: Int, klass :: String, caption :: String, space :: String, full :: Int }
  deriving (Eq, Show, Generic, ToJSON, FromJSON)
data World = World { screens :: [Screen], clients :: [Client], pointer :: (Int,Int), active :: String
                   , refuseClose :: Bool, failMode :: Bool }
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

assertThat :: String -> Bool -> IO ()
assertThat message condition = unless condition (ioError (userError message))

readWorld :: FilePath -> IO World
readWorld root = B.readFile (root </> "world") >>= either (ioError . userError) pure . eitherDecode

worldLock :: FilePath -> IO a -> IO a
worldLock root action = bracket
  (openFd (root </> "lock") ReadWrite defaultFileFlags { creat = Just 0o600 }) closeFd $ \fd -> do
    waitToSetLock fd (WriteLock, AbsoluteSeek, 0, 0)
    action

updateWorld :: FilePath -> (World -> World) -> IO ()
updateWorld root change = worldLock root $ readWorld root >>= writeWorld root . change

writeWorld :: FilePath -> World -> IO ()
writeWorld root value = do
  B.writeFile (root </> "world.tmp") (encode value)
  renameFile (root </> "world.tmp") (root </> "world")

screenJSON :: Screen -> Value
screenJSON s = let (w,h,f) = size s in object
  ["name" .= screen s, "id" .= ident s, "focused" .= focused s,
   "width" .= w, "height" .= h, "refreshRate" .= f,
   "x" .= (if screen s == "STREAM" then 10000 else 0 :: Int),
   "y" .= (if screen s == "STREAM" then 10000 else 0 :: Int),
   "activeWorkspace" .= object ["id" .= ident s, "name" .= desk s]]

clientJSON :: Client -> Value
clientJSON c = object ["address" .= addr c, "pid" .= processId c, "class" .= klass c,
  "title" .= caption c, "workspace" .= object ["name" .= space c], "fullscreen" .= full c,
  "focusHistoryID" .= (1 :: Int)]

focus :: String -> World -> World
focus name w = w { screens = map (\s -> s { focused = screen s == name }) (screens w) }

changeClient :: String -> (Client -> Client) -> World -> World
changeClient address change w = w { clients = map (\c -> if addr c == address then change c else c) (clients w) }

queryWorld :: World -> String -> Value
queryWorld w endpoint = case endpoint of
  "monitors" -> toJSON (map screenJSON (screens w))
  "clients" -> toJSON (map clientJSON (clients w))
  "cursorpos" -> object ["x" .= fst (pointer w), "y" .= snd (pointer w)]
  "activeworkspace" -> object ["name" .= maybe "work" desk (find focused (screens w))]
  "activewindow" -> maybe (object []) clientJSON (find ((== active w) . addr) (clients w))
  "workspaces" -> toJSON [object ["id" .= ident s, "name" .= desk s, "monitor" .= screen s] | s <- screens w]
  _ -> error ("Unexpected fixture query: " ++ endpoint)

split :: Char -> String -> [String]
split delimiter text = case break (== delimiter) text of
  (a,[]) -> [a]
  (a,_:rest) -> a : split delimiter rest

mutate :: World -> [String] -> (World, String)
mutate w ["keyword", "monitor", value]
  | failMode w = (w, "mode rejected")
  | otherwise = case split ',' value of
      _:dimensions:_ -> case split '@' dimensions of
        [xy,rate] -> case split 'x' xy of
          [x,y] -> (w { screens = map (\s -> if screen s == "STREAM" then s { size = (read x,read y,read rate) } else s) (screens w) }, "ok")
          _ -> error "bad dimensions"
        _ -> error "bad mode"
      _ -> error "bad monitor specification"
mutate w ["keyword", "workspace", _] = (w,"ok")
mutate w ["output", "create", "headless", "STREAM"] =
  (w { screens = screens w ++ [Screen "STREAM" 2 False (640,360,10) "streaming"] }, "ok")
mutate w ["dispatch", operation, argument] = (change, "ok") where
  change = case operation of
    "focusmonitor" -> focus argument w
    "movecursor" -> case words argument of
      [x,y] -> w { pointer = (read x,read y) }
      _ -> error "bad cursor"
    "workspace" -> w { screens = map (\s -> if focused s then s { desk = drop 5 argument } else s) (screens w) }
    "focuswindow" -> let a = drop 8 argument
                         c = fromMaybe (error "missing fixture window") (find ((== a) . addr) (clients w))
                     in (focus (if space c == "streaming" then "STREAM" else "DP-1") w) { active = a }
    "fullscreenstate" -> case words argument of
      value:_ -> changeClient (active w) (\c -> c { full = read value }) w
      [] -> error "missing fullscreen mode"
    "movetoworkspacesilent" -> case split ',' argument of
      [destination,a] -> changeClient (drop 8 a) (\c -> c { space = drop 5 destination }) w
      _ -> error "bad move"
    "closewindow" -> if refuseClose w then w else w { clients = filter ((/= drop 8 argument) . addr) (clients w) }
    "movewindow" -> w
    "moveworkspacetomonitor" -> w
    _ -> error ("Unexpected fixture dispatcher: " ++ operation)
mutate _ args = error ("Unexpected fixture mutation: " ++ show args)

fixture :: String -> [String] -> IO ()
fixture name args = do
  root <- getEnv "STREAM_FIXTURE"
  if name == "journalctl"
    then withFile (root </> "journal") ReadMode $ \h -> do
      hSetBuffering stdout LineBuffering
      forever $ do
        eof <- hIsEOF h
        if eof then threadDelay 20000 else hGetLine h >>= putStrLn
    else worldLock root $ do
      appendFile (root </> "commands") (show (name:args) ++ "\n")
      w <- readWorld root
      case (name,args) of
        ("hyprctl", ["-j",endpoint]) -> B.putStrLn (encode (queryWorld w endpoint))
        ("hyprctl", _) -> do
          let (changed,response) = mutate w args
          writeWorld root changed
          putStrLn response
        _ -> pure ()

withTemp :: (FilePath -> IO a) -> IO a
withTemp action = bracket acquire removePathForcibly action where
  acquire = do
    base <- getTemporaryDirectory
    (path,h) <- openTempFile base "stream-test"
    hClose h
    removeFile path
    createDirectory path
    pure path

waitFor :: String -> IO Bool -> IO ()
waitFor label check = do
  result <- timeout 15000000 (let loop = check >>= \ok -> unless ok (threadDelay 20000 >> loop) in loop)
  assertThat ("Timed out: " ++ label) (result == Just ())

rpc :: FilePath -> Value -> IO String
rpc path message = bracket (socket AF_UNIX Stream defaultProtocol) N.close $ \s -> do
  connect s (SockAddrUnix path)
  bracket (socketToHandle s ReadWriteMode) hClose $ \h -> do
    B.hPutStrLn h (encode message)
    hFlush h
    response <- timeout 45000000 (hGetLine h)
    maybe (ioError (userError "RPC timeout")) pure response

command :: String -> Value
command tag = object ["tag" .= tag]
withContents :: String -> Value -> Value
withContents tag contents = object ["tag" .= tag, "contents" .= contents]

terminateGroup :: ProcessHandle -> IO ()
terminateGroup process = do
  pid <- getPid process
  forM_ pid $ \p -> signalProcessGroup sigTERM p `catch` \(_ :: IOException) -> pure ()
  void (waitForProcess process)

acceptance :: IO ()
acceptance = withTemp $ \root -> do
  executable <- getExecutablePath
  override <- lookupEnv "STREAM_SESSION_TEST_EXE"
  let sibling = takeDirectory (takeDirectory executable) </> "stream-session" </> "stream-session"
  siblingExists <- doesFileExist sibling
  -- Setup.hs test builds internal build-tools but does not add them to PATH.
  -- Cabal v2 provides a build-tool PATH; prefer the known sibling in v1/Nix.
  controller <- case override of
    Just path -> makeAbsolute path
    Nothing | siblingExists -> pure sibling
    Nothing -> findExecutable "stream-session" >>= maybe (ioError (userError "stream-session test executable not found")) pure
  let bin = root </> "bin"
      signature = "fixture"
      control = root </> "stream-session" </> signature </> "control.sock"
      snapshot = root </> "stream-session" </> signature </> "session.json"
      hypr = root </> "hypr" </> signature </> ".socket2.sock"
      initial = World [Screen "DP-1" 0 True (2560,1440,144) "work", Screen "DP-2" 1 False (2560,1440,144) "other"] [] (100,200) "" False False
  createDirectory bin
  forM_ ["hyprctl", "journalctl", "systemd-notify", "systemd-run", "steam", "hyprland_show_app"] $ \name ->
    createFileLink executable (bin </> name)
  createDirectoryIfMissing True (takeDirectory hypr)
  B.writeFile (root </> "world") (encode initial)
  writeFile (root </> "commands") ""
  writeFile (root </> "journal") ""
  inherited <- getEnvironment
  let additions = [("PATH",bin),("XDG_RUNTIME_DIR",root),("HYPRLAND_INSTANCE_SIGNATURE",signature),("STREAM_FIXTURE",root)]
      environment = additions ++ filter (\(key,_) -> key `notElem` map fst additions) inherited
  handles <- newMVar []
  processes <- newMVar []
  let start = do
        exists <- doesPathExist control
        when exists (removeFile control)
        (_,_,_,p) <- createProcess (proc controller ["daemon"]) { env = Just environment, create_group = True }
        modifyMVar_ processes (pure . (p:))
        waitFor "controller socket" (doesPathExist control)
        waitFor "Hyprland subscription" (not . null <$> readMVar handles)
        pure p
      ok request = rpc control request >>= \response -> assertThat response ("OK " `isPrefixOf` response)
      failure request = rpc control request >>= \response -> assertThat response ("ERROR " `isPrefixOf` response)
      emit line = readMVar handles >>= \hs -> case hs of
        h:_ -> hPutStrLn h line >> hFlush h
        [] -> error "missing Hyprland subscription"
      mode = object ["width" .= (3840::Int),"height" .= (2160::Int),"fps" .= (60::Int)]
      prepare = withContents "Prepare" (toJSON [mode, Bool True])
      game = Client "0x123" 2147483000 "steam_app_42" "game" "streaming" 2
      streamSize w = size <$> find ((== "STREAM") . screen) (screens w)
      cleanup = do
        ps <- readMVar processes
        forM_ ps $ \p -> getProcessExitCode p >>= \status -> when (status == Nothing) (terminateGroup p)
        readMVar handles >>= mapM_ (\h -> hClose h `catch` \(_ :: IOException) -> pure ())
  bracket (socket AF_UNIX Stream defaultProtocol) N.close $ \listener -> do
    bind listener (SockAddrUnix hypr)
    listen listener 8
    withAsync (forever $ do
      (connection,_) <- accept listener
      h <- socketToHandle connection ReadWriteMode
      modifyMVar_ handles (pure . (h:))) $ \_ -> flip finally cleanup $ do
        p <- start
        ok prepare
        failure prepare
        updateWorld root (\w -> w { clients = [game] })
        emit "openwindow>>123,streaming,steam_app_42,game"
        waitFor "claim from actual Hyprland event" (isInfixOf "0x123" <$> readFile snapshot)
        before <- B.readFile snapshot
        original <- readWorld root
        appendFile (root </> "journal") "[test]: Info: CLIENT DISCONNECTED\n"
        threadDelay 100000
        ok (command "Disconnected")
        assertThat "disconnect changed desktop" . (== original) =<< readWorld root
        assertThat "disconnect changed session" . (== before) =<< B.readFile snapshot
        updateWorld root (focus "DP-1" . (\w -> w { pointer = (20,30) }))
        appendFile (root </> "journal") "[test]: Info: CLIENT CONNECTED\n"
        waitFor "journal reconnect refocus" ((== (11920,11080)) . pointer <$> readWorld root)
        assertThat "reconnect changed session mode/ownership" . (== before) =<< B.readFile snapshot
        ok (command "Launch")
        assertThat "Steam must launch outside controller cgroup" . isInfixOf "systemd-run" =<< readFile (root </> "commands")
        terminateGroup p
        beforeRestart <- readWorld root
        void start
        assertThat "restart changed desktop" . (== beforeRestart) =<< readWorld root
        assertThat "restart changed ownership" . (== before) =<< B.readFile snapshot
        updateWorld root (\w -> w { refuseClose = True })
        failure (command "Stop")
        blocked <- readWorld root
        assertThat "failed graceful quit closed game or resized" (clients blocked == [game] && streamSize blocked == Just (3840,2160,60))
        updateWorld root (\w -> w { refuseClose = False })
        ok (command "Stop")
        finished <- readWorld root
        assertThat "idle mode" (streamSize finished == Just (640,360,10))
        assertThat "physical monitors untouched" (all ((== (2560,1440,144)) . size) (filter ((/= "STREAM") . screen) (screens finished)))
        assertThat "pointer restored" (pointer finished == (100,200))
        ok prepare
        updateWorld root (\w -> w { clients = [game] })
        failure (command "Stop")
        assertThat "unknown game closed" . (== [game]) . clients =<< readWorld root
        updateWorld root (\w -> w { clients = [] })
        ok (command "Stop")
        let invalidMode = object ["width" .= (0::Int),"height" .= (0::Int),"fps" .= (0::Int)]
        failure (withContents "Prepare" (toJSON [invalidMode,Bool True]))
        updateWorld root (\w -> w { failMode = True })
        failure prepare
        assertThat "failed prepare must retain recovery snapshot" . isInfixOf "Preparing" =<< readFile snapshot
        updateWorld root (\w -> w { failMode = False })
        ok (command "Stop")
        ok (withContents "Navigate" (String "monitor"))
        current <- readWorld root
        assertThat "normal navigation reached hidden output" (all (\s -> not (focused s) || screen s /= "STREAM") (screens current))
        putStrLn "PASS: black-box Haskell lifecycle, IPC, real event adapters, recovery, graceful close, fail-closed ownership, mode validation, navigation, display preservation"

main :: IO ()
main = do
  name <- getProgName
  args <- getArgs
  if name `elem` ["hyprctl", "journalctl", "systemd-notify", "systemd-run", "steam", "hyprland_show_app"]
    then fixture name args
    else acceptance
