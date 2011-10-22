{-# LANGUAGE ScopedTypeVariables, RankNTypes, TypeFamilies, FlexibleContexts, ExistentialQuantification #-}
module Main where

import Language.KansasLava

import Data.Default


import qualified Matrix
import qualified Memory
import qualified Coerce
import qualified Others
import qualified Protocols
import qualified Regression

main :: IO ()
main = do
        let opt = def { verboseOpt = 4  -- 4 == show cases that failed
                      , testNever = ["max","min","abs","signum"] -- for now
                      }
        testDriver opt $ take 6 $ drop 0
                [ Matrix.tests
                , Memory.tests
                , Coerce.tests 
                , Others.tests
		, Protocols.tests 
		, Regression.tests
                ]

