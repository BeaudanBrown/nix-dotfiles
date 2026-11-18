{-# LANGUAGE OverloadedStrings #-}
module Main where

import Control.Monad (unless)
import Data.Aeson (decode, encode)
import Stream.Model

assert :: String -> Bool -> IO ()
assert label ok = unless ok (error label)

main :: IO ()
main = do
  let game = Window "0x123" 42 "steam_app_123" "game" "streaming" 2
      ordinary = Window "0x456" 43 "browser" "browser" "work" 0
      initial = Snapshot "DP-1" "work" (12,34) [ordinary] [43] [] True (Mode 3840 2160 60) Active
  assert "accept 4K60" (validateMode ["3840","2160","60"] == Right (Mode 3840 2160 60))
  assert "reject invalid modes" (all (either (const True) (const False) . validateMode)
    [["0","2160","60"],["3840","2160","0"],["3840","2160","99999"],["3840;exec","2160","60"],[]])
  assert "disconnect preserves entire snapshot" (connectionTransition Disconnected initial == initial)
  assert "reconnect preserves original mode and ownership" (connectionTransition Connected initial == initial)
  assert "claim new game" (ownedGames (claimGame initial game) == [game])
  assert "duplicate event is idempotent" (claimGame (claimGame initial game) game == claimGame initial game)
  assert "do not claim ordinary applications" (claimGame initial ordinary == initial)
  let preexisting = initial { originalWindows = [game] }
  assert "do not claim preexisting game" (claimGame preexisting game == preexisting)
  assert "do not claim replacement window of preexisting game" (claimGame preexisting game { address = "0x999" } == preexisting)
  let preexistingProcess = initial { existingPids = [42] }
  assert "do not claim preexisting process with no original window" (claimGame preexistingProcess game == preexistingProcess)
  assert "PID mismatch must not close reused address" (not (sameWindow game game { pid = 100 }))
  assert "session recovery roundtrip" (decode (encode initial) == Just initial)
  assert "command roundtrip" (decode (encode (Prepare (Mode 1920 1080 60) True)) == Just (Prepare (Mode 1920 1080 60) True))
  putStrLn "13 model checks passed"
