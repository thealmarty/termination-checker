module CheckExpr where

import Control.Monad.State ( MonadState(get) )
import Evaluator ( eqVal, eval, lookupEnv, updateEnv )
import           Prelude
import           Types

-- checks that input Expr has the type v (second input)
-- k is the next generic value
-- env rho binds fresh generic values to variables
-- env gamma binds the type corresponding to these generic values
checkExpr :: Int -> Env -> Env -> Expr -> Value -> TypeCheck ()
checkExpr k rho gamma (Lam n e1) (VPi x va env t1) = do
  v_t1 <- eval (updateEnv env x (VGen k)) t1
  checkExpr (k + 1) (updateEnv rho n (VGen k)) (updateEnv gamma n va) e1 v_t1
checkExpr k rho gamma (Pi n t1 t2) VStar = do
  _ <- checkExpr k rho gamma t1 VStar
  v_t1 <- eval rho t1
  checkExpr (k + 1) (updateEnv rho n (VGen k)) (updateEnv gamma n v_t1) t2 VStar
checkExpr k rho gamma (Succ e2) VSize = checkExpr k rho gamma e2 VSize
checkExpr k rho gamma e v = do
  ev <- inferExpr k rho gamma e
  eqVal 0 ev v -- TODO: subtyping? (leqVal)

-- checks that input Expr is correct and infers its type v
inferExpr :: Int -> Env -> Env -> Expr -> TypeCheck Value
inferExpr _k _rho gamma (Var x) = return $ lookupEnv gamma x
inferExpr k rho gamma (App e1 e2) =
  case e2 of
    [] ->
      error $
      "inferExpr : App is applied to an empty list of expressions: " <> show e1 <>
      " is applied to " <>
      show e2 <>
      ", which is empty."
    [e] -> do
      v <- inferExpr k rho gamma e1
      case v of
        VPi x av env b -> do
          checkExpr k rho gamma e av
          v2 <- eval rho e
          eval (updateEnv env x v2) b
        _ ->
          error $
          "inferExpr : expected Pi with expression : " <> show e1 <> "," <>
          show v
    (hd:tl) -> inferExpr k rho gamma (App (App e1 [hd]) tl)
inferExpr _k _rho _gamma (Def n) = do
  sig <- get
  case lookupSig n sig of
    (DataSig _ _ _ tv) -> return tv
    (FunSig tv _ _) -> return tv
    (ConSig tv) ->
      error $
      "inferExpr: expecting type from data or function signature " <>
      show (Def n) <>
      " but found " <>
      show tv <>
      " from constructor signature. "
inferExpr _k _rho _gamma (Con n) = do
  sig <- get
  case lookupSig n sig of
    (ConSig tv) -> return tv
    (DataSig _ _ _ tv) ->
      error $
      "inferExpr: expecting type from data or function signature " <>
      show (Con n) <>
      " but found " <>
      show tv <>
      " from data type signature. "
    (FunSig tv _ _) ->
      error $
      "inferExpr: expecting type from data or function signature " <>
      show (Con n) <>
      " but found " <>
      show tv <>
      " from function signature. "
-- Pi, Lam, Size types, Star cannot be inferred
inferExpr _k _rho _gamma e =
  error $ "inferExpr: cannot infer the type of " <> show e

-- checks that input Expr denotes a valid type
checkType :: Int -> Env -> Env -> Expr -> TypeCheck ()
checkType _k _rho _gamma Star = return ()
checkType _k _rho _gamma Size = return ()
checkType k rho gamma (Pi x t1 t2) = do
  _ <- checkType k rho gamma t1
  v_t1 <- eval rho t1
  checkType (k + 1) (updateEnv rho x (VGen k)) (updateEnv gamma x v_t1) t2
checkType k rho gamma e = checkExpr k rho gamma e VStar

checkType0 :: Expr -> TypeCheck ()
checkType0 = checkType 0 [] []

-- check that input Expr is a star type
checkSType :: Int -> Env -> Env -> Expr -> TypeCheck ()
checkSType k rho gamma e = checkExpr k rho gamma e VStar
