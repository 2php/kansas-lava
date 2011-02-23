-- | The 'Dot' module converts a Lava circuit into a graphical Graphviz format.
module Language.KansasLava.Testing.Output.Dot (writeDotCircuit) where

-- import Language.KansasLava.Entity
import Language.KansasLava.Types

import Data.Reify.Graph
import Text.Dot
import Data.List(intercalate)

-- | The 'writeDotCircuit' function converts a Lava circuit into a graphviz output.
writeDotCircuit :: FilePath  -- ^ Name of output dot file, can be relative or absolute path.
                -> Circuit   -- ^ The reified Lava circuit.
                -> IO Circuit
writeDotCircuit filename circuit = do
{-
   let (inputs',blob) = output' circuit
   let inputs = map fst inputs'
-}
   let (Circuit nodes circInputs circOutputs) = circuit
       -- inputs = inputs'

       showP :: (String,Type) -> String
       showP (v,ty) = "<" ++ v ++ ">" ++ v ++ "::" ++ show ty

       mkLabel :: String -> [(String,Type)] -> [(String,Type)] -> String
       mkLabel nm ins outs =
              (concatMap addSpecial $ nm) ++ "|{{"
           ++ join (map showP ins) ++ "}|{"
           ++ join (map showP outs) ++ "}}"

       -- TODO: insert types
       -- mkPLabel pname nm ins outs = "{" ++ (concatMap addSpecial $ show nm) ++ "|" ++ join pname ++ "}|{{"
       --     ++ join (map showP ins) ++ "}|{"
       --     ++ join (map showP outs) ++ "}}"

   writeFile filename $ showDot $ do
        attribute ("rankdir","LR")

        input_bar <- node [  ("label","INPUTS|{{" ++ join [ showP (show o,i) | (o,i) <- circInputs] ++ "}}")
                                         , ("shape","record")
                                         , ("style","filled")
                                         ]


        nds0 <- sequence [ do nd <- node [ ("label",mkLabel (show nm)
                                                               [ (v,ty) |(v,ty,_) <- ins ]
                                                               [ (v,ty) | (v,ty) <- outs] )
                                         , ("shape","record")
                                         , ("style",case nm of
                                                        TraceVal _ _ -> "rounded,filled"
                                                        _ -> "rounded")
                                         ]
                              return (n,nd)
                        | (n,Entity nm outs ins) <- nodes ]

        let nds = nds0

        output_bar <- node [ ("label","OUTPUTS|{{" ++ join [ showP (show i,ty) | (i,ty,_) <- circOutputs ] ++ "}}")
                                         , ("shape","record")
                                         , ("style","filled")
                                         ]

        let findNd n = case lookup n nds of
                             Nothing -> error $ "strange port: " ++ show (n,nds)
                             Just nd -> nd

        let drawEdge :: Driver Unique -> NodeId -> String -> Dot ()
            drawEdge dr n v = case dr of
                     Port nm' n' -> let (Just nd) = lookup n' nds
                                    in edge' nd (Just (show nm' ++ ":e")) n (Just (show v ++ ":w")) []
                     Pad v' | v' `elem` (map fst circInputs)
                                         -> edge' input_bar (Just (show (show v') ++ ":e")) n (Just (show v ++ ":w")) []
                            | otherwise  -> do nd' <- node [ ("label",show v')
                                                           ]
                                               edge' nd' Nothing n (Just (show v ++ ":w")) []
                     Lit i -> do nd' <- node [("label",show i),("shape","none")]
                                 edge' nd' Nothing n (Just (show v ++ ":w")) []
                     Generic i -> do nd' <- node [("label",show i),("shape","none")]
                                     edge' nd' Nothing n (Just (show v ++ ":w")) []
                     Error e -> do nd' <- node [("label",show e),("shape","none")]
                                   edge' nd' Nothing n (Just (show v ++ ":w")) []
                     ClkDom nm -> do nd' <- node [("label",show nm),("shape","none")]
                                     edge' nd' Nothing n (Just (show v ++ ":w")) []
                     Lits ls -> do let label = intercalate "," $ map  show ls
                                   nd' <- node [("label",label),("shape","none")]
                                   edge' nd' Nothing n (Just (show v ++ ":w")) []


        sequence_ [ drawEdge dr output_bar (show v)
                 | (v,_,dr) <- circOutputs
                 ]

        sequence_ [ drawEdge dr (findNd n) v
                 | (n,Entity _ _ ins) <- nodes
                 , (v,_,dr) <- ins
                 ]

        return ()

   return circuit -- for chaining purposes

-- addSpecial '>' = ['\\','>']
addSpecial :: Char -> String
addSpecial '>' = "&gt;";
addSpecial '<' = "&lt;";
addSpecial c = [c]

join :: [String] -> String
join [x] = x
join []  = ""
join (x:xs) = x ++ "|" ++ join xs

