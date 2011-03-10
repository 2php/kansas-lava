import Language.KansasLava.Types
import Language.KansasLava.Testing.Trace
import Language.KansasLava.Testing.Output.VCD

import Control.Applicative
import System.Environment

vcdDiff :: Trace -> Trace -> String
vcdDiff (Trace c1 i1 o1 p1) (Trace _ i2 o2 p2) = toVCD t
    where t = Trace c1 (mergeMaps i1 i2) (mergeMaps o1 o2) (mergeMaps p1 p2)
          prefixKey p (OVar i nm) = OVar i $ p ++ nm
          mergeMaps m1 m2 = [ (prefixKey "trace1_" k,v) | (k,v) <- m1 ]
                            ++
                            [ (prefixKey "trace2_" k,v) | (k,v) <- m2 ]

main :: IO ()
main = do
    args <- getArgs
    if length args < 3
        then do pname <- getProgName
                putStrLn "Need two ascii dumps and a signature to build diff."
                putStrLn $ "USAGE: " ++ pname ++ " X.shallow X.deep X.sig"
        else do let leftfile = args !! 0
                    rightfile = args !! 1
                    sigfile = args !! 2

                shallow <- lines <$> readFile leftfile
                deep    <- lines <$> readFile rightfile
                sig     <- read  <$> readFile sigfile

                let t1 = asciiToTrace shallow sig
                    t2 = asciiToTrace deep sig

                writeFile "diff.vcd" $ vcdDiff t1 t2
