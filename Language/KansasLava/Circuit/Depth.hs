module Language.KansasLava.Circuit.Depth
	( DepthOp(..)
	, findChains
	, depthTable
	) where


import Data.Reify
import Data.List as L
import qualified Data.Map as Map

import Language.KansasLava.Types


-- assumes no bad loops.

addDepthOp :: DepthOp -> Float -> Float
addDepthOp (AddDepth n) m = n + m
addDepthOp (NewDepth n) _ = n

findChains :: [(Id,DepthOp)] -> Circuit -> [[(Float,Unique)]]
findChains fn cir = reverse
		$ L.groupBy (\ x y -> fst x == fst y)
		$ L.sort
		$ [ (b,a) | (a,b) <- Map.toList res ]
	where
		res = Map.map findEntityChain $ Map.fromList $ theCircuit cir

		findEntityChain :: Entity Unique -> Float
		findEntityChain (Entity nm _ ins) =
			plus (maximum [ findDriverChain d | (_,_,d) <- ins ])
		   where plus = case lookup nm fn of
			          Nothing -> (+ 1)
			          Just f -> addDepthOp f

		findDriverChain :: Driver Unique -> Float
		findDriverChain (Port _ u) =
			case Map.lookup u res of
			  Nothing -> error $ "Can not find " ++ show u
			  Just i -> i
		findDriverChain (Pad _) = 0
		findDriverChain (Lit _) = 0
		findDriverChain (Error err) = error $ "Error: " ++ show err
                findDriverChain (ClkDom nm) = error $ "ClkDom: " ++ show nm
		findDriverChain (Generic g) = error $ "Generic: " ++ show g
                findDriverChain (Lits ls) = error $ "Lits: " ++ show ls


depthTable :: [(Id,DepthOp)]
depthTable =
	[ (Name "Memory" "register",NewDepth 0)
	, (Name "Memory" "BRAM", NewDepth 0)

	-- These are just pairing/projecting, and cost nothing in the final code
	, (Name "Lava" "fst", AddDepth 0)
	, (Name "Lava" "snd", AddDepth 0)
	, (Name "Lava" "pair", AddDepth 0)
	, (Name "Lava" "concat", AddDepth 0)
	, (Name "Lava" "index", AddDepth 0)
	, (Name "Lava" "id", AddDepth 0)
	, (Name "StdLogicVector" "toStdLogicVector", AddDepth 0)
	, (Name "StdLogicVector" "fromStdLogicVector", AddDepth 0)
	, (Name "StdLogicVector" "coerceStdLogicVector", AddDepth 0)
	, (Name "StdLogicVector" "spliceStdLogicVector", AddDepth 0)
        ]

data DepthOp = AddDepth Float
             | NewDepth Float
        deriving (Eq, Show)
