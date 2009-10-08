{-# LANGUAGE ScopedTypeVariables #-}
module Language.KansasLava.VHDL.Testbench where

import Language.KansasLava hiding (entity,ports)
import Data.List(mapAccumL,intersperse)
import Data.Bits

import Data.Sized.Unsigned as U
import Data.Sized.Ix

import System.Random
import Control.Monad(liftM)

mkTestbench :: REIFY fun => String -> fun -> IO ()
mkTestbench name fun = do
  vhdl <- vhdlCircuit [] name fun
  writeFile (base ++ name ++ ".vhd") vhdl
  (inputs,outputs) <- ports fun
  putStrLn $ show inputs
  putStrLn $ show outputs
  writeFile (base ++ name ++ "_tb.vhd") $
            entity name ++ architecture name inputs outputs
  stimulus <- vectors inputs
  writeFile (base ++ name ++ ".input") stimulus
  where base = "/Volumes/Synthesis/synth/"


entity name = unlines
  ["library ieee;",
   "use ieee.std_logic_1164.all;",
   "use ieee.std_logic_textio.all;",
   "library std;",
   "use std.textio.all;",
   "library work;",
   "entity " ++ name ++ "_tb is",
   "begin",
   "end entity " ++ name ++ "_tb;"
  ]


architecture name inputs outputs = unlines $
  ["architecture sim of " ++ name ++ "_tb is"] ++
   signals ++
  ["begin",
   stimulus name inputs outputs,
   dut name inputs outputs,
   "end architecture sim;"]
  where signals = [
         "signal clk, rst : std_logic;",
         "constant input_size : integer := 16;",
         "constant output_size : integer := 16;",
         "signal input : " ++ portType inputs ++ ";",
         "signal output : " ++ portType outputs ++ ";"
          ]


dut name inputs outputs = unlines $ [
 "dut: entity work." ++ name,
 "port map ("] ++
 portAssigns inputs outputs ++
 ["\tclk =>clk, rst=>rst",
 ");"]

stimulus name inputs outputs = unlines $ [
  "runtest: process  is",
  "\tFILE " ++ inputfile ++  " : TEXT open read_mode IS \"" ++ name ++ ".input\";",
  "\tFILE " ++ outputfile ++ " : TEXT IS \"" ++ name ++ ".output\";",
  "\tVARIABLE line_in,line_out  : LINE;",
  "\tvariable input_var : " ++ portType inputs ++ ";",
  "\tvariable output_var : " ++ portType outputs ++ ";",

  "begin",
  "\tclk <= '0';",
  "\trst <= '1';",
  "\tclk <= '1', '0' after 10ns;",
  "\trst <= '0';",
  "\twhile not endfile (" ++ inputfile ++ ") loop",
  "\t\tREADLINE(" ++ inputfile ++ ", line_in);",
  "\t\tREAD(line_in,input_var);",
  "\t\tinput <= input_var;",
  "\t\tclk <= '1';",
  "\t\twait for 10ns;",
  "\t\tclk <= '0';",
  "\t\toutput_var := output;",
  "\t\tWRITE(line_out, output_var);",
  "\t\tWRITELINE(" ++ outputfile ++ ", line_out);",
  "\tend loop;",
  "\twait;",
  "end process;"
                ]
  where inputfile = name ++ "_input"
        outputfile = name ++ "_output"

-- Manipulating ports
ports fun = do
  reified <- reifyCircuit [] fun
  let inputs = [(name,ty) | ((Source,name),ty) <- theTypes reified]
      outputs = [(name,ty) | ((Sink,name),ty) <- theTypes reified]
  return (inputs,outputs)


portType ports = "std_logic_vector(0 to " ++ show (portLen ports - 1) ++ ")"
portLen ports = sum (map (baseTypeLength .snd) ports)

portAssigns inputs outputs = imap ++ omap
  where assign sig idx (n,1) =
          (idx + 1, "\t" ++ n ++ " => " ++ sig ++ "(" ++ show idx ++ "),")
        assign sig idx (n,k) =
          (idx + k, "\t" ++ n ++ " => " ++ sig ++ "(" ++ show idx ++" to " ++ show (idx + k - 1) ++ "),")
        (_,imap) = mapAccumL (assign "input") 0 [(n,baseTypeLength ty) | (Var n,ty) <- inputs]
        (_,omap) = mapAccumL (assign "output") 0 [(n,baseTypeLength ty) | (Var n,ty) <- outputs]


-- Generating the test vectors.
toBits :: Bits a => Int -> a -> String
toBits size val = map (\i -> if testBit val i then '1' else '0') upto
  where downto = reverse upto
        upto = [0..size-1]


vectors inputs = do
    setStdGen (mkStdGen 0)
    let vector = liftM concat $ mapM stim types
    vals <- sequence (replicate 100 $ vector)
    return $ unlines vals

  where stim B = do (v :: Int) <- randomRIO (0,1)
                    return $ toBits 1 v
        stim CB = do (v :: Int) <- randomRIO (0,1)
                     return $ toBits 1 v
        stim (S x) = do let bound = 2^(x-1)
                        (v :: Int) <- randomRIO (-bound,bound - 1)
                        return $ toBits x v
        stim (S x) = do (v :: Int) <- randomRIO (0,2^x- 1)
                        return $ toBits x v


        types = map snd inputs



add a b c d = xor2 d $ xor2 a (xor2 b c)