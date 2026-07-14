{
module Lexer (Token (..), lexer) where

import Data.Char (isHexDigit, toLower)
import Data.List (dropWhileEnd)
}

%wrapper "posn"

tokens :-
  $white+                           ;
  "{"                               { \_ _ -> TokenLCurl }
  "}"                               { \_ _ -> TokenRCurl }
  "("                               { \_ _ -> TokenLPar }
  ")"                               { \_ _ -> TokenRPar }
  "->"                              { \_ _ -> TokenArrow }
  ":="                              { \_ _ -> TokenColonEq }
  ","                               { \_ _ -> TokenComma }
  ":"                               { \_ _ -> TokenColon }
  function                          { \_ _ -> TokenFunction }
  let                               { \_ _ -> TokenLet }
  if                                { \_ _ -> TokenIf }
  switch                            { \_ _ -> TokenSwitch }
  case                              { \_ _ -> TokenCase }
  default                           { \_ _ -> TokenDefault }
  for                               { \_ _ -> TokenFor }
  break                             { \_ _ -> TokenBreak }
  continue                          { \_ _ -> TokenContinue }
  leave                             { \_ _ -> TokenLeave }
  true                              { \_ _ -> TokenTrue }
  false                             { \_ _ -> TokenFalse }
  object                            { \_ _ -> TokenObject }
  code                              { \_ _ -> TokenCode }
  hex \" ([0-9a-fA-F_] | '\\' .)* \" { \_ s -> TokenHex (hexStringLiteralToWord s) }
  [a-zA-Z\_\$]+ [a-zA-Z\_\$0-9\.]*  { \_ s -> TokenIdentifier s}
  \" ([^\"\r\n\\] | '\\' .)* \"     { \_ s -> TokenString (trimQuotes s) }
  0x [0-9a-fA-F]+                   { \_ s -> TokenHex s }
  [0-9]+                            { \_ s -> TokenDecimal s }
  "///" .*$                         { \_ s -> TokenInlineComment s }
  "//" .*$                          ;
  "/**" [.]* "*/"                   ;

{
lexer :: String -> [Token]
lexer = alexScanTokens

trimQuotes :: String -> String
trimQuotes = dropWhileEnd (== '"') . dropWhile (== '"')

hexStringLiteralToWord :: String -> String
hexStringLiteralToWord s =
  "0x" ++ digits ++ replicate (max 0 (64 - length digits)) '0'
  where
    digits = map toLower . filter isHexDigit . trimQuotes . drop 3 $ s

data Token
      = TokenLCurl
      | TokenRCurl
      | TokenLPar
      | TokenRPar
      | TokenArrow
      | TokenColonEq
      | TokenComma
      | TokenColon
      | TokenFunction
      | TokenLet
      | TokenIf
      | TokenSwitch
      | TokenCase
      | TokenDefault
      | TokenFor
      | TokenBreak
      | TokenContinue
      | TokenLeave
      | TokenTrue
      | TokenFalse
      | TokenObject
      | TokenCode
      | TokenIdentifier String
      | TokenString String
      | TokenHex String
      | TokenDecimal String
      | TokenInlineComment String
      | TokenMultilineComment String
  deriving Show
}
