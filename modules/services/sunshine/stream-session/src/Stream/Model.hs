{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}
module Stream.Model where

import Data.Aeson
import Data.List (isPrefixOf)
import GHC.Generics (Generic)
import Text.Read (readMaybe)

data Mode = Mode { width :: Int, height :: Int, fps :: Int }
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

data Phase = Preparing | Active | Closing | Recovery
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

data Window = Window
  { address :: String, pid :: Int, appClass :: String, title :: String
  , workspace :: String, fullscreen :: Int
  } deriving (Eq, Show, Generic, ToJSON, FromJSON)

data Snapshot = Snapshot
  { returnMonitor :: String, returnWorkspace :: String, returnCursor :: (Int, Int)
  , originalWindows :: [Window], existingPids :: [Int], ownedGames :: [Window], wantsSteam :: Bool
  , mode :: Mode, phase :: Phase
  } deriving (Eq, Show, Generic, ToJSON, FromJSON)

-- Requests are local, same-user IPC. Reconnect deliberately carries no new mode.
data Request = Prepare Mode Bool | Launch | Stop | Connected | Disconnected
  | Navigate String | Observe (Maybe String) | Status
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

validateMode :: [String] -> Either String Mode
validateMode [w,h,f] = case traverse readMaybe [w,h,f] of
  Just [x,y,z] | x >= 320 && x <= 7680 && y >= 200 && y <= 4320 && z >= 10 && z <= 144 -> Right (Mode x y z)
  _ -> Left "Client mode must be 320..7680 x 200..4320 at 10..144 FPS"
validateMode _ = Left "Expected client width, height and FPS"

sameWindow :: Window -> Window -> Bool
sameWindow a b = address a == address b && pid a == pid b && appClass a == appClass b

isGame :: Window -> Bool
isGame = isPrefixOf "steam_app_" . appClass

isBigPicture :: Window -> Bool
isBigPicture w = appClass w == "steam" && title w == "Steam Big Picture Mode"

-- Only a newly observed game, absent from the pre-session process/window set,
-- can be claimed. Recovery scans never infer ownership from class alone.
claimGame :: Snapshot -> Window -> Snapshot
claimGame s w
  | isGame w && pid w `notElem` existingPids s
      && not (any (\old -> pid old == pid w || appClass old == appClass w) (originalWindows s))
      && not (any (sameWindow w) (ownedGames s)) = s { ownedGames = w : ownedGames s }
  | otherwise = s

connectionTransition :: Request -> Snapshot -> Snapshot
connectionTransition Disconnected s = s
connectionTransition Connected s = s
connectionTransition _ s = s

idleMode :: Mode
idleMode = Mode 640 360 10
