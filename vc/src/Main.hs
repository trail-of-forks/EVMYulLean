{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module Main (main) where

import Control.Monad (forM_, when, unless)
import Parser (calc, lexer)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Environment (getArgs)
import System.FilePath
    ( (<.>), (</>), takeBaseName, splitPath, dropExtension )
import qualified Data.HashSet as HashSet

import Types (
  FuncDef (..),
  Identifier,
  Literal (..),
  Stmt (..),
  getContracts,
  mkDefs,
  Expr(..), Formattable (src), Segment (..), nameOfNode, Import, ContractName, FileName, Imports, Code
 )
import Data.List (isPrefixOf, foldl', intercalate)
import qualified Data.List.NonEmpty as NE
import ProofGenerator
import PrimOps (yulPrimOps)
import Control.Monad.State (State, modify, get, runState)
import Preprocessor (preprocessFile, preprocessDefs)
import Utils (replaceMany, traverseDir, wordsWhen)
import Relude (ordNub)
import Data.List.Extra (replace)

readFuncDefs :: FilePath -> IO [FuncDef]
readFuncDefs = fmap (preprocessDefs . concatMap mkDefs . getContracts . reverse . calc . lexer . preprocessFile) . readFile

bodyOfNode :: Stmt -> [Stmt]
bodyOfNode (For pre c post body) = body ++ pre ++ [ExpressionStmt c] ++ post
bodyOfNode (If c body)           = body ++ [ExpressionStmt c]
bodyOfNode (Block body)          = body
bodyOfNode (Switch c legs dflt)  = ExpressionStmt c : concatMap snd legs ++ dflt
bodyOfNode _                     = []

superStructureOfAsts :: [FuncDef] -> [Segment]
superStructureOfAsts asts = snd $ foldl' produceSegment (HashSet.empty, []) asts
  where
    produceSegment (cache, segs) f@(FuncDef name contract _ _ body) =
      let abstractionsOfBody :: Bool -> (Import, Stmt) -> State (HashSet.HashSet String) [Segment]
          abstractionsOfBody isTopLevel ((name, _), body) = do
            blacklist <- get
            let abstractions = abstractionsOfBlock contract . bodyOfNode $ body
                primarySegment = Segment name (map fst abstractions) body $ if isTopLevel then (f, (contract, True)) else (f, (contract, False))
            subsegments <- concat <$> mapM (abstractionsOfBody False)
                                           (filter (not . alreadyExists blacklist . fst . fst) abstractions)
            let result = primarySegment : subsegments
            modify (flip (foldr (HashSet.insert . qualifiedName)) result)
            pure result
          (segs', cache') = runState (abstractionsOfBody True ((name, (contract, True)), Block body)) cache in
      (cache', segs ++ segs')

    alreadyExists :: HashSet.HashSet String -> String -> Bool
    alreadyExists blacklist name =
      case templateOfName name of
        TemplateFunction -> True
        _                -> name `HashSet.member` blacklist

    qualifiedName :: Segment -> String
    qualifiedName (Segment name _ _ (_, (contract, _))) = contract ++ "_" ++ name

    -- Do not analyse the body, we only want top--level abstractions at each state.
    -- TODO(later): Rewrite this in terms of general tree traversal.
    abstractionIdentifierOfNode :: ContractName -> Stmt -> [(Import, Stmt)]
    abstractionIdentifierOfNode contract node =
      case node of
        (Block block)                  -> abstractionsOfBlock' block
        (For pre c post body)          -> let preAbstrs  = abstractionsOfBlock' pre
                                              cAbstrs    = abstractionIdentifierOfNode' (ExpressionStmt c)
                                              postAbstrs = abstractionsOfBlock' post
                                              bodyAbstrs = abstractionsOfBlock' body
                                              thisNode   = ((nameOfNode node, (contract, False)), node) in
                                              thisNode : abstractedImports (concat [preAbstrs, cAbstrs, postAbstrs, bodyAbstrs])
        (If c body)                    -> let cAbstrs    = abstractionIdentifierOfNode' (ExpressionStmt c)
                                              bodyAbstrs = abstractionsOfBlock' body
                                              thisNode   = ((nameOfNode node, (contract, False)), node) in
                                              thisNode : abstractedImports (cAbstrs ++ bodyAbstrs)
        (ExpressionStmt (Call f args))
          | isPrimOp f                 -> []
          | otherwise                  -> let argsAbstrs = abstractionsOfBlock' (map ExpressionStmt args)
                                              thisNode   = ((f, (contract, True)), ExpressionStmt (Call f args)) in
                                              thisNode : abstractedImports argsAbstrs
        (Assignment _ rhs)             -> abstractedImports $ abstractionIdentifierOfNode' (ExpressionStmt rhs)
        (LetInit _ rhs)                -> abstractedImports $ abstractionIdentifierOfNode' (ExpressionStmt rhs)
        (Switch c legs dflt)           -> let cAbstrs     = abstractionIdentifierOfNode' (ExpressionStmt c)
                                              legsAbstrs  = concatMap (abstractionsOfBlock' . snd) legs
                                              dfltAbsrtrs = abstractionsOfBlock' dflt
                                              thisNode    = ((nameOfNode node, (contract, False)), node) in
                                              thisNode : abstractedImports (concat [cAbstrs, legsAbstrs, dfltAbsrtrs])
        _                              -> []
      where
        isPrimOp name = name `elem` yulPrimOps
        abstractionsOfBlock' = abstractionsOfBlock contract
        abstractionIdentifierOfNode' = abstractionIdentifierOfNode contract
        isControlFlow (name, _) = any (`isPrefixOf` name) ["for_", "if_", "switch_"]
        abstractedImports = filter (not . isControlFlow . fst)

    abstractionsOfBlock :: ContractName -> [Stmt] -> [(Import, Stmt)]
    abstractionsOfBlock = (=<<) . abstractionIdentifierOfNode

generatedDir :: String
generatedDir = "GeneratedEvmYul"

generatedSubdirName :: String -> String
generatedSubdirName = (generatedDir </>)

commonSubdirName :: String
commonSubdirName = "Common"

templatesSubdirName :: String
templatesSubdirName = "Templates"

templateSuffixGen :: String
templateSuffixGen = "_gen"

templateSuffixUser :: String
templateSuffixUser = "_user"

templateSuffixGlue :: String
templateSuffixGlue = ""

leanExt :: String
leanExt = "lean"

subdir :: FilePath -> FilePath -> FilePath
subdir = (</>) . (".." </>) . generatedSubdirName

data Template = TemplateFor | TemplateFunction | TemplateStmt | TemplateSwitch

data TemplateType = TTGen | TTUser | TTGlue

templateOfName :: String -> Template
templateOfName name
  | "for_" `isPrefixOf` name = TemplateFor
  | "if_" `isPrefixOf` name = TemplateStmt
  | "switch_" `isPrefixOf` name = TemplateSwitch
  | otherwise = TemplateFunction

suffixOfTemplateType :: TemplateType -> String
suffixOfTemplateType TTGen = templateSuffixGen
suffixOfTemplateType TTUser = templateSuffixUser
suffixOfTemplateType TTGlue = templateSuffixGlue

pathOfTemplate :: TemplateType -> Template -> FilePath
pathOfTemplate ttype template =
  templatesSubdirName </>
    case template of
      TemplateFor      -> suffix "evmyul_for"
      TemplateFunction -> suffix "evmyul_function"
      TemplateStmt     -> suffix "evmyul_stmt"
      TemplateSwitch   -> suffix "evmyul_stmt"
  where suffix template = template ++ suffixOfTemplateType ttype

importPrefixOfContract :: String -> Import -> String
importPrefixOfContract topLevelContract (s, (contract, isTopLevel)) =
  leanImportOfFile $ generatedSubdirName topLevelContract </> contract </> if isTopLevel then s else commonSubdirName </> s
  -- "import " ++ generatedSubdirName topLevelContract ++ "." ++ contract ++ (if isTopLevel then "" else "." ++ commonSubdirName) ++ "." ++ s

opensOfImports :: ContractName -> Imports -> String
opensOfImports topLevelContract imports =
  commonNamespace ++ userFNamespaces
  where
        commonNamespace = if not (all (snd . snd) imports) then let (_, (x, _)) = head imports in x ++ ".Common " else ""
        userFNamespaces = let res = ordNub . map (\(_, (contract, _)) -> contract) . filter (\(_, (_, hasContract)) -> hasContract) $ imports in
                          if null res then "" else unwords (leanFormatOfFilePath (generatedSubdirName topLevelContract) : res)

internalImports :: ContractName -> ContractName -> FileName -> TemplateType -> String
internalImports topLevelContract contract file ttype =
  case ttype of
    TTGen -> ""
    TTUser -> unlines [importWithSuffix templateSuffixGen]
    TTGlue -> unlines [importWithSuffix templateSuffixGen, importWithSuffix templateSuffixUser]
    where importWithSuffix suffix =
            "\n" ++ importPrefixOfContract topLevelContract (file ++ suffix, (contract, True))

generateGuarded :: Bool -> String -> String
generateGuarded c str = if c then "" else str

leanString :: String -> String
leanString = show

leanIdentifierList :: NE.NonEmpty Identifier -> String
leanIdentifierList ids = "[" ++ intercalate ", " (map leanString (NE.toList ids)) ++ "]"

leanLiteral :: Literal -> Maybe String
leanLiteral (Number n) = Just $ "(UInt256.ofNat " ++ show n ++ ")"
leanLiteral (Str _) = Nothing

leanSimpleExprFrom :: String -> Expr -> Maybe String
leanSimpleExprFrom _ (Lit lit) = leanLiteral lit
leanSimpleExprFrom s (Var ident) = Just $ "(lookupVar (" ++ s ++ ") " ++ leanString ident ++ ")"
leanSimpleExprFrom s (Call "add" [Var ident, Lit lit]) =
  (\rhs -> "(UInt256.add (lookupVar (" ++ s ++ ") " ++ leanString ident ++ ") " ++ rhs ++ ")") <$> leanLiteral lit
leanSimpleExprFrom s (Call "sub" [Var ident, Lit lit]) =
  (\rhs -> "(UInt256.sub (lookupVar (" ++ s ++ ") " ++ leanString ident ++ ") " ++ rhs ++ ")") <$> leanLiteral lit
leanSimpleExprFrom s (Call "eq" [Var ident, Lit lit]) =
  (\rhs -> "(UInt256.eq (lookupVar (" ++ s ++ ") " ++ leanString ident ++ ") " ++ rhs ++ ")") <$> leanLiteral lit
leanSimpleExprFrom _ _ = Nothing

leanSimpleExpr :: Expr -> Maybe String
leanSimpleExpr = leanSimpleExprFrom "s₀"

leanExprTerm :: Expr -> Maybe String
leanExprTerm (Lit lit) = (\lit' -> "(Expr.Lit " ++ lit' ++ ")") <$> leanLiteral lit
leanExprTerm (Var ident) = Just $ "(Expr.Var " ++ leanString ident ++ ")"
leanExprTerm _ = Nothing

leanExprTermList :: [Expr] -> Maybe String
leanExprTermList exprs =
  (\args -> "[" ++ intercalate ", " args ++ "]") <$> traverse leanExprTerm exprs

leanSimpleExprListFrom :: String -> [Expr] -> Maybe String
leanSimpleExprListFrom s exprs =
  (\args -> "[" ++ intercalate ", " args ++ "]") <$> traverse (leanSimpleExprFrom s) exprs

isPrimitiveSingletonAssignment :: Stmt -> Bool
isPrimitiveSingletonAssignment (LetInit ids (Call f [Var _, Lit _])) =
  length (NE.toList ids) == 1 && f `elem` ["add", "sub", "eq"]
isPrimitiveSingletonAssignment (Assignment ids (Call f [Var _, Lit _])) =
  length (NE.toList ids) == 1 && f `elem` ["add", "sub", "eq"]
isPrimitiveSingletonAssignment _ = False

isEqVarLitBreakIf :: Stmt -> Bool
isEqVarLitBreakIf (If (Call "eq" [Var _, Lit _]) [Break]) = True
isEqVarLitBreakIf _ = False

eqVarLitBreakIfCondFrom :: String -> Stmt -> Maybe String
eqVarLitBreakIfCondFrom s (If (Call "eq" [Var ident, Lit lit]) [Break]) =
  leanSimpleExprFrom s (Call "eq" [Var ident, Lit lit])
eqVarLitBreakIfCondFrom _ _ = Nothing

callAssignment :: Stmt -> Maybe (NE.NonEmpty Identifier, String, [Expr])
callAssignment (LetInit ids (Call f args))
  | f `notElem` yulPrimOps = Just (ids, f, args)
callAssignment (Assignment ids (Call f args))
  | f `notElem` yulPrimOps = Just (ids, f, args)
callAssignment _ = Nothing

symbolicPrefixAndCallAssignmentFrom :: String -> [Stmt] -> Maybe (String, NE.NonEmpty Identifier, String, [Expr])
symbolicPrefixAndCallAssignmentFrom _ [] = Nothing
symbolicPrefixAndCallAssignmentFrom s [stmt] =
  (\(ids, f, args) -> (s, ids, f, args)) <$> callAssignment stmt
symbolicPrefixAndCallAssignmentFrom s (stmt : stmts) = do
  s' <- symbolicStateAfterFrom s stmt
  symbolicPrefixAndCallAssignmentFrom s' stmts

symbolicStateAfterFrom :: String -> Stmt -> Maybe String
symbolicStateAfterFrom s (Declaration ids) =
  Just $ "List.foldr (fun var s => s.insert var ⟨0⟩) (" ++ s ++ ") " ++ leanIdentifierList ids
symbolicStateAfterFrom s (LetInit ids expr) =
  (\rhs -> "(" ++ s ++ ").insert " ++ leanString (NE.head ids) ++ " " ++ rhs) <$> leanSimpleExprFrom s expr
symbolicStateAfterFrom s (Assignment ids expr) =
  (\rhs -> "(" ++ s ++ ").insert " ++ leanString (NE.head ids) ++ " " ++ rhs) <$> leanSimpleExprFrom s expr
symbolicStateAfterFrom s (If (Call "eq" [Var ident, Lit lit]) [Break]) =
  (\rhs -> "(if " ++ rhs ++ " ≠ ⟨0⟩ then 💔 (" ++ s ++ ") else (" ++ s ++ "))") <$>
    leanSimpleExprFrom s (Call "eq" [Var ident, Lit lit])
symbolicStateAfterFrom _ _ = Nothing

symbolicStateAfter :: Stmt -> Maybe String
symbolicStateAfter = symbolicStateAfterFrom "s₀"

symbolicBlockStateAfter :: [Stmt] -> Maybe String
symbolicBlockStateAfter = symbolicBlockStateAfterFrom "s₀"

symbolicBlockStateAfterFrom :: String -> [Stmt] -> Maybe String
symbolicBlockStateAfterFrom = foldl step . Just
  where
    step Nothing _ = Nothing
    step (Just s) stmt = symbolicStateAfterFrom s stmt

breakIfBlockStateAfter :: [Stmt] -> Maybe (String, String)
breakIfBlockStateAfter [] = Nothing
breakIfBlockStateAfter (stmt : stmts) = do
  cond <- eqVarLitBreakIfCondFrom "s₀" stmt
  sAfter <- symbolicBlockStateAfterFrom "s₀" stmts
  pure (cond, sAfter)

symbolicFuelDepth :: Stmt -> Int
symbolicFuelDepth stmt
  | isEqVarLitBreakIf stmt = 7
  | isPrimitiveSingletonAssignment stmt = 6
  | otherwise = 1

symbolicFunctionFuelDepth :: Stmt -> Int
symbolicFunctionFuelDepth stmt
  | isEqVarLitBreakIf stmt = 8
  | isPrimitiveSingletonAssignment stmt = 7
  | otherwise = 2

symbolicBlockFuelDepth :: [Stmt] -> Int
symbolicBlockFuelDepth [] = 1
symbolicBlockFuelDepth (stmt : stmts) =
  1 + max (symbolicFuelDepth stmt) (symbolicBlockFuelDepth stmts)

fuelSplitProof :: Int -> String -> String -> String
fuelSplitProof depth lowSimp highSimp = unlines $ "  intro h" : go depth "  "
  where
    go 0 indent = [indent ++ highSimp]
    go n indent =
      [ indent ++ "cases fuel with"
      , indent ++ "| zero =>"
      , indent ++ "    " ++ lowSimp
      , indent ++ "| succ fuel =>"
      ] ++ go (n - 1) (indent ++ "    ")

fuelSplitLines :: Int -> String -> [String] -> [String]
fuelSplitLines depth lowSimp highLines = go depth "  "
  where
    go 0 indent = map (indent ++) highLines
    go n indent =
      [ indent ++ "cases fuel with"
      , indent ++ "| zero =>"
      , indent ++ "    " ++ lowSimp
      , indent ++ "| succ fuel =>"
      ] ++ go (n - 1) (indent ++ "    ")

evmYulVcPropAndProof :: FileName -> Stmt -> (String, String)
evmYulVcPropAndProof file stmt =
  case symbolicStateAfter stmt of
    Just sAfter ->
      ( "  s₉ = " ++ sAfter
      , fuelSplitProof
          (symbolicFuelDepth stmt)
          ("simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall, lookupVar] at h")
          ("simpa [VC_" ++ file ++ ", " ++ file ++ ", lookupVar] using h.symm")
      )
    Nothing ->
      ( "  exec fuel " ++ file ++ " codeOverride s₀ = .ok s₉"
      , unlines
          [ "  intro h"
          , "  exact h"
          ]
      )

evmYulFunctionVcPropAndProof :: FileName -> [Stmt] -> (String, String)
evmYulFunctionVcPropAndProof file [stmt] =
  case symbolicStateAfter stmt of
    Just sAfter ->
      ( "  s₉ = " ++ sAfter
      , fuelSplitProof
          (symbolicFunctionFuelDepth stmt)
          ("simp [" ++ file ++ ", FunctionDefinition.body, exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall] at h")
          ("simpa [VC_" ++ file ++ ", " ++ file ++ ", FunctionDefinition.body] using h.symm")
      )
    Nothing -> exactFunctionVcPropAndProof file
evmYulFunctionVcPropAndProof file stmts =
  case symbolicBlockStateAfter stmts of
    Just sAfter ->
      ( "  s₉ = " ++ sAfter
      , fuelSplitProof
          (symbolicBlockFuelDepth stmts)
          ("simp [" ++ file ++ ", FunctionDefinition.body, exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall, lookupVar] at h")
          ("simpa [VC_" ++ file ++ ", " ++ file ++ ", FunctionDefinition.body, lookupVar] using h.symm")
      )
    Nothing -> exactFunctionVcPropAndProof file

exactFunctionVcPropAndProof :: FileName -> (String, String)
exactFunctionVcPropAndProof file =
  ( "  exec fuel (.Block " ++ file ++ ".body) codeOverride s₀ = .ok s₉"
  , unlines
      [ "  intro h"
      , "  exact h"
      ]
  )

qualifiedFunctionNamespace :: ContractName -> ContractName -> String
qualifiedFunctionNamespace topLevelContract contract =
  leanFormatOfFilePath $ generatedSubdirName topLevelContract </> baseContract
  where
    baseContract = takeWhile (/= '.') contract

resolutionAssumptionDef :: ContractName -> FileName -> Imports -> String
resolutionAssumptionDef topLevelContract file imports =
  "def Resolutions_" ++ file ++ " (codeOverride : Option YulContract) : Prop :=\n" ++
    case clauses of
      [] -> "  True\n"
      _  -> intercalate " ∧\n" (map ("  " ++) clauses) ++ "\n"
  where
    topLevelCallees = ordNub
      [ (callee, calleeContract)
      | (callee, (calleeContract, True)) <- imports
      ]
    clauses =
      [ "(∀ s, State.isOk s → ResolvedFunction codeOverride s " ++ leanString callee ++ " " ++
          qualifiedFunctionNamespace topLevelContract calleeContract ++ "." ++ callee ++ ")"
      | (callee, calleeContract) <- topLevelCallees
      ]

evmYulCallBlockVcPropAndProof :: ContractName -> ContractName -> FileName -> [Stmt] -> Maybe (String, String)
evmYulCallBlockVcPropAndProof topLevelContract contract file [pref, callStmt] | Just cond <- eqVarLitBreakIfCondFrom "s₀" pref = do
  (ids, f, args) <- callAssignment callStmt
  leanArgs <- leanSimpleExprListFrom "s₀" args
  leanArgExprs <- leanExprTermList args
  let namespace = qualifiedFunctionNamespace topLevelContract contract
      qualified name = namespace ++ "." ++ name
      afunc = qualified ("AFunc_" ++ f)
      func = qualified f
      vars = leanIdentifierList ids
      lowSimp = "simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall, lookupVar] at h"
      breakProof =
        fuelSplitLines 8 lowSimp
          [ "cases s₀ <;> simpa [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall,"
          , "    reverse', cons', execPrimCall, primCall, State.setBreak, hbreak] using h.symm"
          ]
      callProof =
        fuelSplitLines 8 lowSimp $
          [ "refine functionCallSummary_of_exec_block_prefix_let_call"
          , "  (pref := <s " ++ src pref ++ " >)"
          , "  (argExprs := " ++ leanArgExprs ++ ")"
          , "  (argFuel := fuel.succ.succ.succ.succ.succ)"
          , "  (s₀ := s₀)"
          , "  (sPrefix := s₀)"
          , "  (sCall := s₀)"
          , "  ?_ hok hresolve ?_ ?_ ?_"
          , "· simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall,"
          , "    reverse', cons', execPrimCall, primCall, hfall]"
          , "· intro _ _ hbody"
          , "  exact " ++ qualified (f ++ "_bodyExact_implies_afunc") ++ " hbody"
          , "· simp [evalArgs, evalTail, eval, reverse', cons', lookupVar]"
          , "· simpa [" ++ file ++ "] using h"
          ]
  pure
    ( "  (" ++ cond ++ " ≠ ⟨0⟩ → s₉ = 💔 (s₀)) ∧\n" ++
      "  (" ++ cond ++ " = ⟨0⟩ →\n" ++
      "    State.isOk s₀ →\n" ++
      "    ResolvedFunction codeOverride (s₀) " ++ leanString f ++ " " ++ func ++ " →\n" ++
      "    PureFunctionCallVC (" ++ afunc ++ " codeOverride) " ++ func ++ " " ++ leanArgs ++ " " ++ vars ++ " (s₀) s₉)"
    , unlines $
        [ "  intro h"
        , "  constructor"
        , "  · intro hbreak"
        ] ++ map ("  " ++) breakProof ++
        [ "  · intro hfall"
        , "    intro hok"
        , "    intro hresolve"
        ] ++ map ("  " ++) callProof
    )
evmYulCallBlockVcPropAndProof topLevelContract contract file stmts = do
  (sCall, ids, f, args) <- symbolicPrefixAndCallAssignmentFrom "s₀" stmts
  leanArgs <- leanSimpleExprListFrom sCall args
  let namespace = qualifiedFunctionNamespace topLevelContract contract
      qualified name = namespace ++ "." ++ name
      afunc = qualified ("AFunc_" ++ f)
      func = qualified f
      vars = leanIdentifierList ids
      directProof =
        case stmts of
          [pref, callStmt] | Just (_, _, _) <- callAssignment callStmt -> do
            _ <- symbolicStateAfterFrom "s₀" pref
            leanArgExprs <- leanExprTermList args
            let lowSimp = "simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall, lookupVar] at h"
            prefixProof <-
              case pref of
                If (Call "eq" [Var ident, Lit lit]) [Break] -> do
                  litTerm <- leanLiteral lit
                  let condTerm = "UInt256.eq (lookupVar s₀ " ++ leanString ident ++ ") " ++ litTerm
                  pure
                    [ "· by_cases hcond : " ++ condTerm ++ " = ⟨0⟩"
                    , "  · simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall,"
                    , "      reverse', cons', execPrimCall, primCall, lookupVar, UInt256.ofNat, hcond]"
                    , "  · simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall,"
                    , "      reverse', cons', execPrimCall, primCall, lookupVar, UInt256.ofNat, hcond]"
                    ]
                _ ->
                  pure
                    [ "· simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall,"
                    , "    reverse', cons', execPrimCall, primCall, lookupVar]"
                    ]
            let highLines =
                  [ "refine functionCallSummary_of_exec_block_prefix_let_call"
                  , "  (pref := <s " ++ src pref ++ " >)"
                  , "  (argExprs := " ++ leanArgExprs ++ ")"
                  , "  (argFuel := fuel.succ.succ.succ.succ.succ)"
                  , "  (s₀ := s₀)"
                  , "  (sPrefix := " ++ sCall ++ ")"
                  , "  (sCall := " ++ sCall ++ ")"
                  , "  ?_ ?_ hresolve ?_ ?_ ?_"
                  ] ++ prefixProof ++
                  [ "· exact hok" ] ++
                  [ "· intro _ _ hbody"
                  , "  exact " ++ qualified (f ++ "_bodyExact_implies_afunc") ++ " hbody"
                  , "· simp [evalArgs, evalTail, eval, reverse', cons', lookupVar]"
                  , "· simpa [" ++ file ++ "] using h"
                  ]
            pure $ unlines $ ["  intro h", "  intro hok", "  intro hresolve"] ++ fuelSplitLines 8 lowSimp highLines
          _ -> Nothing
  pure
    ( case directProof of
        Just _ ->
          "  State.isOk (" ++ sCall ++ ") →\n" ++
          "  ResolvedFunction codeOverride (" ++ sCall ++ ") " ++ leanString f ++ " " ++ func ++ " →\n" ++
          "  PureFunctionCallVC (" ++ afunc ++ " codeOverride) " ++ func ++ " " ++ leanArgs ++ " " ++ vars ++ " (" ++ sCall ++ ") s₉"
        Nothing ->
          error $
            "unsupported EVMYulLean call block in " ++ file ++
            ": cannot yet generate a pure call-summary VC for " ++ f
    , case directProof of
        Just proof -> proof
        Nothing ->
          error $
            "unsupported EVMYulLean call block in " ++ file ++
            ": cannot yet prove a pure call-summary VC for " ++ f
    )

evmYulBlockVcPropAndProof :: ContractName -> ContractName -> FileName -> [Stmt] -> (String, String)
evmYulBlockVcPropAndProof topLevelContract contract file stmts =
  case evmYulCallBlockVcPropAndProof topLevelContract contract file stmts of
    Just result -> result
    Nothing ->
      case breakIfBlockStateAfter stmts of
        Just (cond, sAfter) ->
          ( "  (" ++ cond ++ " ≠ ⟨0⟩ → s₉ = 💔 (s₀)) ∧\n" ++
            "  (" ++ cond ++ " = ⟨0⟩ → s₉ = " ++ sAfter ++ ")"
          , unlines $
              [ "  intro h"
              , "  constructor"
              , "  · intro hbreak"
              ] ++
              map ("  " ++) (fuelSplitLines
                (symbolicBlockFuelDepth stmts)
                ("simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall, lookupVar] at h")
                [ "simpa [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall,"
                , "    reverse', cons', execPrimCall, primCall, hbreak] using h.symm"
                ]) ++
              [ "  · intro hfall"
              ] ++
              map ("  " ++) (fuelSplitLines
                (symbolicBlockFuelDepth stmts)
                ("simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall, lookupVar] at h")
                [ "cases s₀ <;> simpa [VC_" ++ file ++ ", " ++ file ++ ", State.insert, hfall] using h.symm" ])
          )
        Nothing ->
          case symbolicBlockStateAfter stmts of
            Just sAfter ->
              ( "  s₉ = " ++ sAfter
              , fuelSplitProof
                  (symbolicBlockFuelDepth stmts)
                  ("simp [" ++ file ++ ", exec, evalArgs, evalTail, eval, evalPrimCall, reverse', cons', execPrimCall, primCall, lookupVar] at h")
                  ("simpa [VC_" ++ file ++ ", " ++ file ++ ", lookupVar] using h.symm")
              )
            Nothing ->
              ( "  exec fuel (.Block " ++ file ++ ") codeOverride s₀ = .ok s₉"
              , unlines
                  [ "  intro h"
                  , "  exact h"
                  ]
              )

fillInStatement :: ContractName -> ContractName -> FileName -> Imports -> Code -> String -> String -> String -> (String, String, String)
fillInStatement topLevelContract contract file imports code gen user glue =
  (
    replaceIn TTGen gen,
    replaceIn TTUser user,
    replaceIn TTGlue glue
  )
  where leanImports = unlines . map (importPrefixOfContract topLevelContract) . ordNub $ imports
        astCode     = src code
        tactics     = tacticsOfStmt code
        opens       = opensOfImports topLevelContract imports
        (vcProp, vcProof) = evmYulVcPropAndProof file code

        replaceIn ttype =
          replaceMany [
            ("\\<statement_name>", file),
            ("\\<contract>",       contract),
            ("\\<imports>",        leanImports ++ internalImports topLevelContract contract file ttype),
            ("\\<code>",           astCode),
            ("\\<vc_prop>",        vcProp),
            ("\\<vc_proof>",       vcProof),
            ("\\<tacs>",           tactics),
            ("\\<opens>",          opens),
            ("\\<resolutions>",    resolutionAssumptionDef topLevelContract file imports)
          ]

fillInFor :: ContractName -> ContractName -> FileName -> Imports -> Code -> String -> String -> String -> (String, String, String)
fillInFor topLevelContract contract file imports stmt@(For _ c post body) gen user glue =
  (
    replaceIn TTGen gen,
    replaceIn TTUser user,
    replaceIn TTGlue glue
  )
  where leanImports = unlines . map (importPrefixOfContract topLevelContract) . ordNub $ imports
        astCode     = src (For [] c post body) -- The prefix of For has already been handled. Drop it.
        astCond     = src c
        astPost     = src (Block post)
        astBody     = src (Block body)
        tacsPost    = tacticsOfStmt (Block post)
        tacsBody    = tacticsOfStmt (Block body)
        tactics     = tacticsOfStmt stmt
        opens       = opensOfImports topLevelContract imports
        (vcProp, vcProof) = evmYulVcPropAndProof file (For [] c post body)
        (vcPostProp, vcPostProof) = evmYulBlockVcPropAndProof topLevelContract contract (file ++ "_post") post
        (vcBodyProp, vcBodyProof) = evmYulBlockVcPropAndProof topLevelContract contract (file ++ "_body") body

        replaceIn ttype =
          replaceMany [
            ("\\<statement_name>", file),
            ("\\<contract>",       contract),
            ("\\<imports>",        leanImports ++ internalImports topLevelContract contract file ttype),
            ("\\<code>",           astCode),
            ("\\<vc_prop>",        vcProp),
            ("\\<vc_proof>",       vcProof),
            ("\\<vc_post_prop>",   vcPostProp),
            ("\\<vc_post_proof>",  vcPostProof),
            ("\\<vc_body_prop>",   vcBodyProp),
            ("\\<vc_body_proof>",  vcBodyProof),
            ("\\<code_cond>",      astCond),
            ("\\<code_post>",      astPost),
            ("\\<code_body>",      astBody),
            ("\\<tacs_post>",      tacsPost),
            ("\\<tacs_body>",      tacsBody),
            ("\\<tacs>",           tactics),
            ("\\<opens>",          opens),
            ("\\<resolutions>",    resolutionAssumptionDef topLevelContract file imports)
          ]

fillInFor _ _ _ _ stmt _ _ _ = (
  "FillInFor called with stmt: " ++ show stmt,
  "FillInFor called with stmt: " ++ show stmt,
  "FillInFor called with stmt: " ++ show stmt
  )

fillInFunction :: ContractName -> FileName -> Imports -> FuncDef -> String -> String -> String -> (String, String, String)
fillInFunction topLevelContract file imports (FuncDef _ contract fargs ret body) gen user glue =
  (
    replaceIn TTGen gen,
    replaceIn TTUser user,
    replaceIn TTGlue glue
  )
  where leanImports  = unlines . map (importPrefixOfContract topLevelContract) . ordNub $ imports
        argsSepComma = intercalate ", " fargs
        argsSepSpace = unwords fargs
        modifiers    = " -> "
        return       = intercalate ", " ret
        returnSpace  = unwords ret
        fbody        = src (Block body)
        underscores  = generateGuarded (null (ret ++ fargs)) $ (intercalate " → " . map (const "_") $ ret ++ fargs) ++ " → "
        code         = unlines . map ("  " ++) . lines $ tacticsOfStmt' False (Block body) ++ finish
        namespace    = leanFormatOfFilePath $ generatedSubdirName topLevelContract </> contract
        funcArgs     = generateGuarded (null fargs) $ "(" ++ unwords fargs ++ " : Literal)"
        opens        = opensOfImports topLevelContract imports
        retVals      = generateGuarded (null ret) $ "(" ++ unwords ret ++ " : Identifier)"
        rValsAndArgs = generateGuarded (null (ret ++ fargs)) $ "{" ++ unwords ret ++ " " ++ argsSepSpace ++ "}"
        (vcProp, vcProof) = evmYulFunctionVcPropAndProof file body
        replaceIn ttype =
          replaceMany [
            ("\\<imports>",                       leanImports ++ internalImports topLevelContract contract file ttype),
            ("\\<statement_name>",                file),
            ("\\<args_sep_comma>",                argsSepComma),
            ("\\<args_sep_space>",                argsSepSpace),
            ("\\<return_modifiers>",              modifiers),
            ("\\<return_value>",                  return),
            ("\\<func_body>",                     fbody),
            ("\\<vc_prop>",                       vcProp),
            ("\\<vc_proof>",                      vcProof),
            ("\\<underscores_return_value_args>", underscores),
            ("\\<func_tactics>",                  code),
            ("\\<namespace>",                     namespace),
            ("\\<fargs>",                         funcArgs),
            ("\\<opens>",                         opens),
            ("\\<resolutions>",                    resolutionAssumptionDef topLevelContract file imports),
            ("\\<ret_vals>",                      retVals),
            ("\\<ret_vals_and_args>",             rValsAndArgs),
            ("\\<return_value_space>",            returnSpace)
          ]

writeSegment :: ContractName -> Segment -> IO ()
writeSegment topLevelContract (Segment name abstractions stmt (f, (contract, isTopLevel))) = do
  (gen, user, glue) <- template
  let (genFile, userFile, glueFile) = leanFiles
  writeFile genFile gen

  -- TODO(feature): Add the option to force override specific files.
  -- Do not overwrite the user file, as we risk overwriting user-defined proofs.
  userFileExists <- doesFileExist userFile
  unless userFileExists $ writeFile userFile user

  -- Glue files are mechanically generated wrappers around generated and user lemmas.
  -- Rewriting them lets template-level reasoning changes propagate without touching
  -- user-owned proofs.
  writeFile glueFile glue
  where
    leanFiles = (leanFileOfAbstr TTGen, leanFileOfAbstr TTUser, leanFileOfAbstr TTGlue)
      where tlContract               = subdir topLevelContract contract
            controlFlowOrAbstraction = if isTopLevel then "" else commonSubdirName
            fileName ttype           = name ++ suffixOfTemplateType ttype
            leanFileOfAbstr ttype    = tlContract </> controlFlowOrAbstraction </> fileName ttype <.> leanExt
    fileName = contract ++ if isTopLevel then "" else "." ++ commonSubdirName
    readTemplates template = do
      genFile <- readFile (pathOfTemplate TTGen template)
      userFile <- readFile (pathOfTemplate TTUser template)
      glueFile <- readFile (pathOfTemplate TTGlue template)
      pure (genFile, userFile, glueFile)
    template = case templateOfName name of
                 TemplateStmt     -> do (genFile, userFile, glueFile) <- readTemplates TemplateStmt
                                        pure $ fillInStatement topLevelContract fileName name abstractions stmt genFile userFile glueFile
                 TemplateFor      -> do (genFile, userFile, glueFile) <- readTemplates TemplateFor
                                        pure $ fillInFor topLevelContract fileName name abstractions stmt genFile userFile glueFile
                 TemplateFunction -> do (genFile, userFile, glueFile) <- readTemplates TemplateFunction
                                        pure $ fillInFunction topLevelContract name abstractions f genFile userFile glueFile
                 TemplateSwitch   -> do (genFile, userFile, glueFile) <- readTemplates TemplateStmt
                                        pure $ fillInStatement topLevelContract fileName name abstractions stmt (switchOfStmt genFile) (switchOfStmt userFile) (switchOfStmt glueFile)
    switchOfStmt = unlines . map (replace "If _ _" "Switch _ _ _" . replace "rw [If']" "rw [Switch']") . lines

writeSegments :: ContractName -> [Segment] -> IO ()
writeSegments topLevelContract segments = do
  createDirectoryIfMissing False $ ".." </> generatedSubdirName topLevelContract
  forM_ segments $ \seg@(Segment _ _ _ (_, (contract, isTopLevel))) -> do
    when isTopLevel $ createDirectoryIfMissing True $ subdir topLevelContract contract </> commonSubdirName
    writeSegment topLevelContract seg

-- | Run verification generator (given raw cmdline args).
vc :: [String] -> IO ()
vc [] = error "usage: vc <yul_file>"
vc (yulFile : _) = do
  asts <- readFuncDefs yulFile
  writeSegments topLevel $ superStructureOfAsts asts
  generatedFiles <- getAllImports
  writeFile "../GeneratedEvmYul.lean" . unlines . map (leanImportOfFile . concat . tail . splitPath) $ generatedFiles
  where topLevel = takeBaseName yulFile

getAllImports :: IO [String]
getAllImports = traverseDir (\acc f -> pure (acc ++ [f])) [] $ ".." </> generatedDir

leanFormatOfFilePath :: FilePath -> String
leanFormatOfFilePath = intercalate "." . wordsWhen (`elem` ['/']) . dropExtension

leanImportOfFile :: FilePath -> String
leanImportOfFile = ("import " ++) . leanFormatOfFilePath

-- | Clear (and create, if necessary) the target directory for generated files.
clear :: IO ()
clear = createDirectoryIfMissing False $ ".." </> generatedDir

main :: IO ()
main = vc =<< getArgs <* clear
